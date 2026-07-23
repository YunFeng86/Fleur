import 'dart:io';

import '../../../db/isar_db.dart';
import '../../../services/logging/app_logger.dart';
import '../../../services/sync/outbox/outbox_store.dart';
import '../../../utils/path_manager.dart';
import '../domain/account.dart';
import 'credential_store.dart';

class AccountCleanupService {
  AccountCleanupService({
    required CredentialStore credentials,
    OutboxStore? outbox,
    Future<void> Function(Account account)? databaseCleanup,
  }) : _credentials = credentials,
       _outbox = outbox ?? OutboxStore(),
       _databaseCleanup = databaseCleanup;

  final CredentialStore _credentials;
  final OutboxStore _outbox;
  final Future<void> Function(Account account)? _databaseCleanup;

  Future<void> deleteAccountData(Account account) async {
    // Never delete primary DB automatically; keep a safe fallback.
    if (account.isPrimary) return;

    // Delete the ownership-checked database first. If this fails, keep account
    // metadata and reconstructable state visible so the operation can retry.
    final databaseCleanup = _databaseCleanup;
    if (databaseCleanup == null) {
      await _deleteIsarWithRetry(account);
    } else {
      await databaseCleanup(account);
    }

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

  Future<void> _deleteIsarWithRetry(Account account) async {
    const attempts = 5;
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var i = 0; i < attempts; i++) {
      try {
        await AccountDbSessionManager.instance.deleteIdleForAccount(
          accountId: account.id,
          dbName: account.dbName,
          isPrimary: account.isPrimary,
        );
        return;
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;
        if (i == attempts - 1) {
          _logCleanupFailure(
            account,
            operation: 'deleteDb',
            fileKind: 'isar',
            attempt: i + 1,
            error: e,
            stackTrace: st,
          );
        }
        // Backoff: 150ms, 300ms, 600ms...
        final delayMs = 150 * (1 << i);
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
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
