import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/accounts/account_store.dart';
import 'package:fleur/services/sync/google_reader/google_reader_provider_profile.dart';

void main() {
  test('updateAccountConnection updates only connection fields', () async {
    final now = DateTime.utc(2026, 1, 1);
    final account = Account(
      id: 'reader',
      type: AccountType.googleReader,
      name: 'Reader',
      baseUrl: 'https://old.example.com',
      profileId: GoogleReaderProviderProfiles.genericId,
      isPrimary: true,
      createdAt: now,
      updatedAt: now,
    );
    final store = _MemoryAccountStore(
      AccountsState(
        version: AccountStore.currentVersion,
        activeAccountId: account.id,
        accounts: [account],
      ),
    );
    final container = ProviderContainer(
      overrides: [accountStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await container.read(accountsControllerProvider.future);
    await container
        .read(accountsControllerProvider.notifier)
        .updateAccountConnection(
          accountId: account.id,
          baseUrl: ' https://rss.example.com ',
          profileId: ' ${GoogleReaderProviderProfiles.freshRssId} ',
        );

    final updated = store.state.accounts.single;
    expect(updated.id, account.id);
    expect(updated.type, account.type);
    expect(updated.name, account.name);
    expect(updated.isPrimary, isTrue);
    expect(updated.createdAt, account.createdAt);
    expect(updated.baseUrl, 'https://rss.example.com');
    expect(updated.profileId, GoogleReaderProviderProfiles.freshRssId);
    expect(updated.updatedAt, isNot(account.updatedAt));
  });
}

class _MemoryAccountStore extends AccountStore {
  _MemoryAccountStore(this.state);

  AccountsState state;

  @override
  Future<AccountsState> loadOrCreate() async => state;

  @override
  Future<void> save(AccountsState state) async {
    this.state = state;
  }
}
