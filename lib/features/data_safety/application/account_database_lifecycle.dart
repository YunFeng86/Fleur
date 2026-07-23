import '../../accounts/domain/account.dart';
import '../domain/account_database_access.dart';
import '../domain/account_database_deletion.dart';

typedef AccountDatabaseAccountLookup =
    Future<Account?> Function(String accountId);

abstract interface class AccountDatabaseLifecycle {
  Future<AccountDatabaseAcquireResult> acquireExisting(
    AccountDatabaseRef account,
  );

  Future<AccountDatabaseAcquireResult> initialize(
    AccountDatabaseInitialization intent,
  );

  Future<AccountDatabaseDeletionResult> deleteForAccountRemoval(
    AccountDatabaseDeletionIntent intent,
  );
}
