import 'dart:io';

import '../../../db/isar_db.dart';
import 'package:isar_community/isar.dart';

import '../../accounts/domain/account.dart';
import '../application/account_database_lifecycle.dart';
import '../domain/account_database_access.dart';
import '../domain/account_database_deletion.dart';

class IsarAccountDatabaseLifecycle implements AccountDatabaseLifecycle {
  IsarAccountDatabaseLifecycle({
    required AccountDatabaseAccountLookup findAccount,
    AccountDbSessionManager? sessions,
    Future<void> Function(Duration duration)? sleep,
  }) : _findAccount = findAccount,
       _sessions = sessions ?? AccountDbSessionManager.instance,
       _sleep = sleep ?? ((duration) => Future<void>.delayed(duration));

  final AccountDatabaseAccountLookup _findAccount;
  final AccountDbSessionManager _sessions;
  final Future<void> Function(Duration duration) _sleep;

  @override
  Future<AccountDatabaseAcquireResult> acquireExisting(
    AccountDatabaseRef accountRef,
  ) {
    return _withAccount(accountRef.accountId, (account) {
      if (!account.databaseInitialized) {
        return Future<AccountDatabaseAcquireResult>.value(
          _accessFailure(
            account.id,
            AccountDatabaseAccessFailureKind.initializationRequired,
          ),
        );
      }
      return _acquire(
        account.id,
        initializedNow: false,
        acquire: () {
          return _sessions.acquireExistingForAccount(
            accountId: account.id,
            dbName: account.dbName,
            isPrimary: account.isPrimary,
          );
        },
      );
    });
  }

  Future<AccountDatabaseAcquireResult> _withAccount(
    String accountId,
    Future<AccountDatabaseAcquireResult> Function(Account account) operation,
  ) async {
    try {
      final account = await _findAccount(accountId);
      if (account == null) {
        return _accessFailure(
          accountId,
          AccountDatabaseAccessFailureKind.dataMissing,
        );
      }
      return operation(account);
    } catch (_) {
      return _accessFailure(
        accountId,
        AccountDatabaseAccessFailureKind.storageUnavailable,
      );
    }
  }

  @override
  Future<AccountDatabaseAcquireResult> initialize(
    AccountDatabaseInitialization intent,
  ) {
    return _withAccount(intent.accountId, (account) {
      if (account.databaseInitialized) {
        return _acquire(
          account.id,
          initializedNow: false,
          acquire: () {
            return _sessions.acquireExistingForAccount(
              accountId: account.id,
              dbName: account.dbName,
              isPrimary: account.isPrimary,
            );
          },
        );
      }
      return _acquire(
        account.id,
        initializedNow: true,
        acquire: () {
          return _sessions.initializeForAccount(
            accountId: account.id,
            dbName: account.dbName,
            isPrimary: account.isPrimary,
          );
        },
      );
    });
  }

  Future<AccountDatabaseAcquireResult> _acquire(
    String accountId, {
    required bool initializedNow,
    required Future<AccountDbLease> Function() acquire,
  }) async {
    try {
      final lease = await acquire();
      return AccountDatabaseReady(
        lease: IsarAccountDatabaseLease(accountId: accountId, lease: lease),
        initializedNow: initializedNow,
      );
    } on DbOpenFailure catch (error) {
      return _accessFailure(accountId, _mapAccessFailure(error.kind));
    } on FileSystemException catch (_) {
      return _accessFailure(
        accountId,
        AccountDatabaseAccessFailureKind.storageUnavailable,
      );
    } catch (_) {
      return _accessFailure(
        accountId,
        AccountDatabaseAccessFailureKind.migrationFailed,
      );
    }
  }

  AccountDatabaseAccessFailure _accessFailure(
    String accountId,
    AccountDatabaseAccessFailureKind kind,
  ) {
    return AccountDatabaseAccessFailure(
      kind: kind,
      accountId: accountId,
      supportCode: 'database-access:$accountId:${kind.name}',
    );
  }

  AccountDatabaseAccessFailureKind _mapAccessFailure(DbOpenFailureKind kind) {
    return switch (kind) {
      DbOpenFailureKind.transient =>
        AccountDatabaseAccessFailureKind.blockedByAnotherProcess,
      DbOpenFailureKind.environmental =>
        AccountDatabaseAccessFailureKind.storageUnavailable,
      DbOpenFailureKind.recoveryRequired =>
        AccountDatabaseAccessFailureKind.recoveryRequired,
      DbOpenFailureKind.dataMissing =>
        AccountDatabaseAccessFailureKind.dataMissing,
      DbOpenFailureKind.ownershipMismatch =>
        AccountDatabaseAccessFailureKind.ownershipMismatch,
    };
  }

  @override
  Future<AccountDatabaseDeletionResult> deleteForAccountRemoval(
    AccountDatabaseDeletionIntent intent,
  ) async {
    final account = await _findAccount(intent.accountId);
    if (account == null) {
      return AccountDatabaseAlreadyDeleted(auditId: intent.operationId);
    }
    if (account.isPrimary) {
      return AccountDatabaseDeletionBlocked(
        reason: AccountDatabaseDeletionBlockReason.primaryAccount,
        supportCode: '${intent.operationId}:primary-account',
      );
    }

    const delays = <Duration>[
      Duration(milliseconds: 150),
      Duration(milliseconds: 300),
      Duration(milliseconds: 600),
      Duration(milliseconds: 1200),
    ];
    for (var attempt = 0; ; attempt++) {
      try {
        final deleted = await _sessions.deleteIdleForAccount(
          accountId: account.id,
          dbName: account.dbName,
          isPrimary: account.isPrimary,
        );
        return deleted
            ? AccountDatabaseDeleted(auditId: intent.operationId)
            : AccountDatabaseAlreadyDeleted(auditId: intent.operationId);
      } on DbOpenFailure catch (error) {
        if (error.kind == DbOpenFailureKind.transient &&
            attempt < delays.length) {
          await _sleep(delays[attempt]);
          continue;
        }
        return _mapBlockedFailure(intent, error);
      } catch (_) {
        return AccountDatabaseDeletionFailed(
          supportCode: '${intent.operationId}:unexpected',
        );
      }
    }
  }

  AccountDatabaseDeletionResult _mapBlockedFailure(
    AccountDatabaseDeletionIntent intent,
    DbOpenFailure error,
  ) {
    final reason = switch (error.kind) {
      DbOpenFailureKind.transient =>
        AccountDatabaseDeletionBlockReason.activeLease,
      DbOpenFailureKind.ownershipMismatch =>
        AccountDatabaseDeletionBlockReason.ownershipMismatch,
      DbOpenFailureKind.recoveryRequired =>
        AccountDatabaseDeletionBlockReason.recoveryRequired,
      DbOpenFailureKind.environmental || DbOpenFailureKind.dataMissing =>
        AccountDatabaseDeletionBlockReason.storageUnavailable,
    };
    return AccountDatabaseDeletionBlocked(
      reason: reason,
      supportCode: '${intent.operationId}:${reason.name}',
    );
  }
}

class IsarAccountDatabaseLease implements AccountDatabaseLease {
  IsarAccountDatabaseLease({required this.accountId, required this.lease});

  @override
  final String accountId;
  final AccountDbLease lease;

  Isar get isar => lease.isar;

  @override
  Future<void> release() => lease.release();
}

Isar bindIsarAccountDatabaseLease(AccountDatabaseLease lease) {
  if (lease is! IsarAccountDatabaseLease) {
    throw StateError('Account database lease is not backed by Isar.');
  }
  return lease.isar;
}
