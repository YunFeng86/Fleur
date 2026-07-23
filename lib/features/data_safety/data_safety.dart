import 'application/account_database_lifecycle.dart';
import 'data/isar_account_database_lifecycle.dart';

export 'application/account_database_lifecycle.dart'
    show AccountDatabaseAccountLookup, AccountDatabaseLifecycle;
export 'domain/account_database_deletion.dart'
    show
        AccountDatabaseAlreadyDeleted,
        AccountDatabaseDeleted,
        AccountDatabaseDeletionBlocked,
        AccountDatabaseDeletionBlockReason,
        AccountDatabaseDeletionFailed,
        AccountDatabaseDeletionIntent,
        AccountDatabaseDeletionResult;

AccountDatabaseLifecycle createAccountDatabaseLifecycle({
  required AccountDatabaseAccountLookup findAccount,
}) {
  return IsarAccountDatabaseLifecycle(findAccount: findAccount);
}
