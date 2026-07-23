class AccountDatabaseRef {
  const AccountDatabaseRef({required this.accountId});

  final String accountId;
}

class AccountDatabaseInitialization {
  const AccountDatabaseInitialization({
    required this.accountId,
    required this.operationId,
  });

  final String accountId;
  final String operationId;
}

enum AccountDatabaseAccessFailureKind {
  blockedByAnotherProcess,
  ownershipMismatch,
  storageUnavailable,
  migrationFailed,
  validationFailed,
  recoveryRequired,
  dataMissing,
  initializationRequired,
}

abstract interface class AccountDatabaseLease {
  String get accountId;

  Future<void> release();
}

sealed class AccountDatabaseAcquireResult {
  const AccountDatabaseAcquireResult();
}

final class AccountDatabaseReady extends AccountDatabaseAcquireResult {
  const AccountDatabaseReady({
    required this.lease,
    required this.initializedNow,
  });

  final AccountDatabaseLease lease;
  final bool initializedNow;
}

final class AccountDatabaseAccessFailure extends AccountDatabaseAcquireResult
    implements Exception {
  const AccountDatabaseAccessFailure({
    required this.kind,
    required this.accountId,
    required this.supportCode,
  });

  final AccountDatabaseAccessFailureKind kind;
  final String accountId;
  final String supportCode;

  @override
  String toString() {
    return 'AccountDatabaseAccessFailure('
        'kind: $kind, accountId: $accountId, supportCode: $supportCode)';
  }
}
