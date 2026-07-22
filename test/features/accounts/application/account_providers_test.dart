import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/features/accounts/accounts.dart';
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

  test('failed add does not publish an unpersisted account', () async {
    final initial = _localState();
    final store = _ThrowingAccountStore(initial);
    final container = ProviderContainer(
      overrides: [accountStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await container.read(accountsControllerProvider.future);

    await expectLater(
      container
          .read(accountsControllerProvider.notifier)
          .addAccount(type: AccountType.fever, name: 'Remote'),
      throwsStateError,
    );

    final visible = container.read(accountsControllerProvider).requireValue;
    expect(visible.accounts, hasLength(1));
    expect(visible.accounts.single.id, 'local');
    expect(store.state.accounts, hasLength(1));
  });

  test(
    'failed active-account save keeps the previous active account',
    () async {
      final now = DateTime.utc(2026, 1, 1);
      final local = Account(
        id: 'local',
        type: AccountType.local,
        name: 'Local',
        isPrimary: true,
        createdAt: now,
        updatedAt: now,
      );
      final remote = Account(
        id: 'remote',
        type: AccountType.miniflux,
        name: 'Remote',
        createdAt: now,
        updatedAt: now,
      );
      final store = _ThrowingAccountStore(
        AccountsState(
          version: AccountStore.currentVersion,
          activeAccountId: local.id,
          accounts: [local, remote],
        ),
      );
      final container = ProviderContainer(
        overrides: [accountStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      await container.read(accountsControllerProvider.future);

      await expectLater(
        container
            .read(accountsControllerProvider.notifier)
            .setActive(remote.id),
        throwsStateError,
      );

      expect(
        container.read(accountsControllerProvider).requireValue.activeAccountId,
        local.id,
      );
      expect(store.state.activeAccountId, local.id);
    },
  );
}

AccountsState _localState() {
  final now = DateTime.utc(2026, 1, 1);
  final account = Account(
    id: 'local',
    type: AccountType.local,
    name: 'Local',
    isPrimary: true,
    createdAt: now,
    updatedAt: now,
  );
  return AccountsState(
    version: AccountStore.currentVersion,
    activeAccountId: account.id,
    accounts: [account],
  );
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

class _ThrowingAccountStore extends AccountStore {
  _ThrowingAccountStore(this.state);

  AccountsState state;

  @override
  Future<AccountsState> loadOrCreate() async => state;

  @override
  Future<void> save(AccountsState state) async {
    throw StateError('Injected account save failure');
  }
}
