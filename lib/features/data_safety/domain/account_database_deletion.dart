class AccountDatabaseDeletionIntent {
  const AccountDatabaseDeletionIntent({
    required this.accountId,
    required this.operationId,
  });

  final String accountId;
  final String operationId;
}

enum AccountDatabaseDeletionBlockReason {
  activeLease,
  ownershipMismatch,
  storageUnavailable,
  recoveryRequired,
  primaryAccount,
}

sealed class AccountDatabaseDeletionResult {
  const AccountDatabaseDeletionResult();

  bool get permitsDatasetCleanup =>
      this is AccountDatabaseDeleted || this is AccountDatabaseAlreadyDeleted;
}

final class AccountDatabaseDeleted extends AccountDatabaseDeletionResult {
  const AccountDatabaseDeleted({required this.auditId});

  final String auditId;
}

final class AccountDatabaseAlreadyDeleted
    extends AccountDatabaseDeletionResult {
  const AccountDatabaseAlreadyDeleted({required this.auditId});

  final String auditId;
}

final class AccountDatabaseDeletionBlocked
    extends AccountDatabaseDeletionResult {
  const AccountDatabaseDeletionBlocked({
    required this.reason,
    required this.supportCode,
  });

  final AccountDatabaseDeletionBlockReason reason;
  final String supportCode;
}

final class AccountDatabaseDeletionFailed
    extends AccountDatabaseDeletionResult {
  const AccountDatabaseDeletionFailed({required this.supportCode});

  final String supportCode;
}
