import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/features/accounts/accounts.dart';

void main() {
  test('accounts facade exposes the feature public API', () {
    final now = DateTime.utc(2026, 7, 22);
    final account = Account(
      id: 'local',
      type: AccountType.local,
      name: 'Local',
      isPrimary: true,
      createdAt: now,
      updatedAt: now,
    );
    final state = AccountsState(
      version: AccountStore.currentVersion,
      activeAccountId: account.id,
      accounts: [account],
    );
    final credentials = CredentialStore();
    final cleanup = AccountCleanupService(
      credentials: credentials,
      databaseCleanup: (_) async {},
    );
    final AccountsController Function() createController =
        AccountsController.new;

    expect(AccountTypeX.fromWire(account.type.wire), AccountType.local);
    expect(state.findById(account.id), same(account));
    expect(AccountStore(), isA<AccountStore>());
    expect(credentials, isA<CredentialStore>());
    expect(cleanup, isA<AccountCleanupService>());
    expect(createController(), isA<AccountsController>());
    expect(accountStoreProvider, isNotNull);
    expect(credentialStoreProvider, isNotNull);
    expect(accountsControllerProvider, isNotNull);
    expect(activeAccountProvider, isNotNull);
  });
}
