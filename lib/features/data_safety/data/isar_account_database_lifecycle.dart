import '../../../db/isar_db.dart';
import '../application/account_database_lifecycle.dart';
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
