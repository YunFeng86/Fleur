import 'dart:io';

import '../../../services/logging/app_logger.dart';
import '../../../services/sync/outbox/outbox_store.dart';
import '../../../utils/path_manager.dart';
import '../../data_safety/data_safety.dart';
import '../domain/account.dart';
import 'credential_store.dart';

class AccountCleanupService {
  AccountCleanupService({
    required CredentialStore credentials,
    required AccountDatabaseLifecycle databaseLifecycle,
    OutboxStore? outbox,
  }) : _credentials = credentials,
       _outbox = outbox ?? OutboxStore(),
       _databaseLifecycle = databaseLifecycle;

  final CredentialStore _credentials;
  final OutboxStore _outbox;
  final AccountDatabaseLifecycle _databaseLifecycle;

  Future<void> deleteAccountData(Account account) async {
    // Never delete primary DB automatically; keep a safe fallback.
    if (account.isPrimary) return;

    // Delete the ownership-checked database first. If this fails, keep account
    // metadata and reconstructable state visible so the operation can retry.
    await _deleteAccountDatabase(account);

    // Credentials (best-effort).
    try {
      await _credentials.deleteApiToken(account.id, account.type);
    } catch (e, st) {
      _logCleanupFailure(
        account,
        operation: 'deleteCredentials',
        fileKind: 'apiToken',
        error: e,
        stackTrace: st,
      );
    }
    try {
      await _credentials.deleteBasicAuth(account.id, account.type);
    } catch (e, st) {
      _logCleanupFailure(
        account,
        operation: 'deleteCredentials',
        fileKind: 'basicAuth',
        error: e,
        stackTrace: st,
      );
    }

    await _deleteOutboxState(account);
  }

  Future<void> _deleteOutboxState(Account account) async {
    try {
      await _outbox.clear(account.id);
    } catch (e, st) {
      _logCleanupFailure(
        account,
        operation: 'deleteOutbox',
        fileKind: 'outboxSnapshots',
        error: e,
        stackTrace: st,
      );
    }

    // This lock name belonged to the previous SyncMutex-based outbox path and
    // is no longer opened by current code. DurableJsonStore's adjacent lock is
    // intentionally retained so waiters always coordinate on one inode.
    late final Directory dir;
    try {
      dir = await PathManager.getStateDir();
    } catch (e, st) {
      _logCleanupFailure(
        account,
        operation: 'resolveOutboxDirectory',
        fileKind: 'outboxDirectory',
        error: e,
        stackTrace: st,
      );
      return;
    }

    final separator = Platform.pathSeparator;
    final safeLockId = account.id.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final candidates = <({String path, String kind})>[
      (
        path: '${dir.path}${separator}mutex_outbox_$safeLockId.lock',
        kind: 'legacyOutboxLock',
      ),
    ];

    for (final candidate in candidates) {
      try {
        final file = File(candidate.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e, st) {
        _logCleanupFailure(
          account,
          operation: 'deleteOutbox',
          fileKind: candidate.kind,
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  Future<void> _deleteAccountDatabase(Account account) async {
    final result = await _databaseLifecycle.deleteForAccountRemoval(
      AccountDatabaseDeletionIntent(
        accountId: account.id,
        operationId:
            'delete:${account.id}:${account.updatedAt.microsecondsSinceEpoch}',
      ),
    );
    if (result.permitsDatasetCleanup) return;

    final supportCode = switch (result) {
      AccountDatabaseDeletionBlocked(:final supportCode) => supportCode,
      AccountDatabaseDeletionFailed(:final supportCode) => supportCode,
      _ => 'delete:${account.id}:unexpected-result',
    };
    throw StateError('Account database deletion blocked: $supportCode');
  }

  static void _logCleanupFailure(
    Account account, {
    required String operation,
    required String fileKind,
    required Object error,
    required StackTrace stackTrace,
    int? attempt,
  }) {
    AppLogger.w(
      'Account cleanup failed',
      tag: 'account',
      error: _safeCleanupError(error),
      stackTrace: stackTrace,
      context: <String, Object?>{
        'operation': operation,
        'accountId': account.id,
        'accountType': account.type.wire,
        'attempt': attempt,
        'fileKind': fileKind,
      },
    );
  }

  static String _safeCleanupError(Object error) {
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      if (code != null) return 'FileSystemException(osErrorCode=$code)';
      return 'FileSystemException';
    }
    return error.runtimeType.toString();
  }
}
