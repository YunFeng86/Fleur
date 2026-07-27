import 'dart:io';

import '../../../services/logging/app_logger.dart';
import '../../../services/sync/outbox/outbox_store.dart';
import '../../../utils/path_manager.dart';
import '../../data_safety/data_safety.dart';
import '../domain/account.dart';
import 'credential_store.dart';

class AccountCleanupFailure {
  const AccountCleanupFailure({
    required this.operation,
    required this.fileKind,
    required this.error,
    required this.stackTrace,
  });

  final String operation;
  final String fileKind;
  final Object error;
  final StackTrace stackTrace;
}

class AccountCleanupException implements Exception {
  AccountCleanupException(Iterable<AccountCleanupFailure> failures)
    : failures = List<AccountCleanupFailure>.unmodifiable(failures);

  final List<AccountCleanupFailure> failures;

  @override
  String toString() {
    final steps = failures
        .map((failure) => '${failure.operation}:${failure.fileKind}')
        .join(', ');
    return 'AccountCleanupException: cleanup failed for $steps';
  }
}

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

    final failures = <AccountCleanupFailure>[];
    await _runCleanupStep(
      account,
      failures,
      operation: 'deleteCredentials',
      fileKind: 'apiToken',
      action: () => _credentials.deleteApiToken(account.id, account.type),
    );
    await _runCleanupStep(
      account,
      failures,
      operation: 'deleteCredentials',
      fileKind: 'basicAuth',
      action: () => _credentials.deleteBasicAuth(account.id, account.type),
    );
    await _deleteOutboxState(account, failures);

    if (failures.isNotEmpty) throw AccountCleanupException(failures);
  }

  Future<void> _deleteOutboxState(
    Account account,
    List<AccountCleanupFailure> failures,
  ) async {
    await _runCleanupStep(
      account,
      failures,
      operation: 'deleteOutbox',
      fileKind: 'outboxSnapshots',
      action: () => _outbox.clear(account.id),
    );

    // This lock name belonged to the previous SyncMutex-based outbox path and
    // is no longer opened by current code. DurableJsonStore's adjacent lock is
    // intentionally retained so waiters always coordinate on one inode.
    late final Directory dir;
    try {
      dir = await PathManager.getStateDir();
    } catch (e, st) {
      _recordCleanupFailure(
        account,
        failures,
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
      await _runCleanupStep(
        account,
        failures,
        operation: 'deleteOutbox',
        fileKind: candidate.kind,
        action: () async {
          final file = File(candidate.path);
          if (await file.exists()) {
            await file.delete();
          }
        },
      );
    }
  }

  Future<void> _runCleanupStep(
    Account account,
    List<AccountCleanupFailure> failures, {
    required String operation,
    required String fileKind,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
    } catch (error, stackTrace) {
      _recordCleanupFailure(
        account,
        failures,
        operation: operation,
        fileKind: fileKind,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static void _recordCleanupFailure(
    Account account,
    List<AccountCleanupFailure> failures, {
    required String operation,
    required String fileKind,
    required Object error,
    required StackTrace stackTrace,
  }) {
    failures.add(
      AccountCleanupFailure(
        operation: operation,
        fileKind: fileKind,
        error: error,
        stackTrace: stackTrace,
      ),
    );
    _logCleanupFailure(
      account,
      operation: operation,
      fileKind: fileKind,
      error: error,
      stackTrace: stackTrace,
    );
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
