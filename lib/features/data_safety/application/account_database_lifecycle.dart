import '../../accounts/domain/account.dart';
import '../domain/account_database_deletion.dart';

typedef AccountDatabaseAccountLookup =
    Future<Account?> Function(String accountId);

abstract interface class AccountDatabaseLifecycle {
  Future<AccountDatabaseDeletionResult> deleteForAccountRemoval(
    AccountDatabaseDeletionIntent intent,
  );
}
