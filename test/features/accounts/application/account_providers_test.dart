import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/features/data_safety/data_safety.dart';
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

  test('addAccount creates an uninitialized account', () async {
    final store = _MemoryAccountStore(_localState());
    final container = ProviderContainer(
      overrides: [accountStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await container.read(accountsControllerProvider.future);

    final id = await container
        .read(accountsControllerProvider.notifier)
        .addAccount(type: AccountType.fever, name: 'Remote');

    final added = store.state.findById(id);
    expect(added, isNotNull);
    expect(added!.databaseInitialized, isFalse);
  });

  test(
    'addAccount rejects a database target owned by another account',
    () async {
      final initial = _localState();
      final existing = Account(
        id: 'existing',
        type: AccountType.miniflux,
        name: 'Existing',
        dbName: 'shared_database',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final store = _MemoryAccountStore(
        AccountsState(
          version: initial.version,
          activeAccountId: initial.activeAccountId,
          accounts: [...initial.accounts, existing],
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
            .addAccount(
              type: AccountType.fever,
              name: 'Conflicting',
              dbName: 'shared_database',
            ),
        throwsStateError,
      );

      expect(store.state.accounts, hasLength(2));
    },
  );

  test('markDatabaseInitialized persists true only once', () async {
    final initial = _localState(databaseInitialized: false);
    final store = _MemoryAccountStore(initial);
    final container = ProviderContainer(
      overrides: [accountStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await container.read(accountsControllerProvider.future);
    final controller = container.read(accountsControllerProvider.notifier);

    await controller.markDatabaseInitialized('local');
    final firstUpdated = store.state.accounts.single;
    expect(firstUpdated.databaseInitialized, isTrue);
    expect(store.saveCalls, 1);

    await controller.markDatabaseInitialized('local');
    final secondUpdated = store.state.accounts.single;
    expect(secondUpdated.databaseInitialized, isTrue);
    expect(secondUpdated.updatedAt, firstUpdated.updatedAt);
    expect(store.saveCalls, 1);
  });

  test('failed cleanup restores the account and previous active id', () async {
    final initial = _twoAccountState(activeRemote: true);
    final store = _MemoryAccountStore(initial);
    final container = ProviderContainer(
      overrides: [
        accountStoreProvider.overrideWithValue(store),
        accountCleanupProvider.overrideWithValue(_FailingAccountCleanup()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(accountsControllerProvider.future);

    await expectLater(
      container
          .read(accountsControllerProvider.notifier)
          .deleteAccount('remote'),
      throwsStateError,
    );

    final persisted = store.state;
    final visible = container.read(accountsControllerProvider).requireValue;
    expect(persisted.activeAccountId, 'remote');
    expect(persisted.findById('remote')!.deletionPending, isFalse);
    expect(visible.activeAccountId, 'remote');
    expect(visible.findById('remote')!.deletionPending, isFalse);
    expect(store.saveCalls, 2);
  });

  test('final save failure leaves a retryable pending deletion', () async {
    final store = _FailOnSaveAccountStore(
      _twoAccountState(activeRemote: true),
      failOnCalls: {2},
    );
    final cleanup = _RecordingAccountCleanup();
    final container = ProviderContainer(
      overrides: [
        accountStoreProvider.overrideWithValue(store),
        accountCleanupProvider.overrideWithValue(cleanup),
      ],
    );
    addTearDown(container.dispose);
    await container.read(accountsControllerProvider.future);
    final controller = container.read(accountsControllerProvider.notifier);

    await expectLater(controller.deleteAccount('remote'), throwsStateError);

    final pending = container.read(accountsControllerProvider).requireValue;
    expect(pending.activeAccountId, 'local');
    expect(pending.findById('remote')!.deletionPending, isTrue);
    expect(store.state.findById('remote')!.deletionPending, isTrue);

    await controller.deleteAccount('remote');

    expect(store.state.findById('remote'), isNull);
    expect(
      container.read(accountsControllerProvider).requireValue.accounts,
      hasLength(1),
    );
    expect(cleanup.calls, 2);
  });

  test('build resumes a persisted pending deletion', () async {
    final store = _MemoryAccountStore(_twoAccountState(pendingRemote: true));
    final cleanup = _RecordingAccountCleanup();
    final container = ProviderContainer(
      overrides: [
        accountStoreProvider.overrideWithValue(store),
        accountCleanupProvider.overrideWithValue(cleanup),
      ],
    );
    addTearDown(container.dispose);

    final loaded = await container.read(accountsControllerProvider.future);

    expect(loaded.findById('remote'), isNull);
    expect(store.state.findById('remote'), isNull);
    expect(cleanup.calls, 1);
  });

  test('failed startup recovery keeps pending account inactive', () async {
    final store = _MemoryAccountStore(_twoAccountState(pendingRemote: true));
    final container = ProviderContainer(
      overrides: [
        accountStoreProvider.overrideWithValue(store),
        accountCleanupProvider.overrideWithValue(_FailingAccountCleanup()),
      ],
    );
    addTearDown(container.dispose);

    final loaded = await container.read(accountsControllerProvider.future);
    expect(loaded.activeAccountId, 'local');
    expect(loaded.findById('remote')!.deletionPending, isTrue);

    await container
        .read(accountsControllerProvider.notifier)
        .setActive('remote');

    expect(
      container.read(accountsControllerProvider).requireValue.activeAccountId,
      'local',
    );
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

AccountsState _localState({bool databaseInitialized = true}) {
  final now = DateTime.utc(2026, 1, 1);
  final account = Account(
    id: 'local',
    type: AccountType.local,
    name: 'Local',
    isPrimary: true,
    databaseInitialized: databaseInitialized,
    createdAt: now,
    updatedAt: now,
  );
  return AccountsState(
    version: AccountStore.currentVersion,
    activeAccountId: account.id,
    accounts: [account],
  );
}

AccountsState _twoAccountState({
  bool activeRemote = false,
  bool pendingRemote = false,
}) {
  final local = _localState().accounts.single;
  final now = DateTime.utc(2026, 1, 1);
  final remote = Account(
    id: 'remote',
    type: AccountType.miniflux,
    name: 'Remote',
    deletionPending: pendingRemote,
    createdAt: now,
    updatedAt: now,
  );
  return AccountsState(
    version: AccountStore.currentVersion,
    activeAccountId: activeRemote ? remote.id : local.id,
    accounts: [local, remote],
  );
}

class _MemoryAccountStore extends AccountStore {
  _MemoryAccountStore(this.state);

  AccountsState state;
  int saveCalls = 0;

  @override
  Future<AccountsState> loadOrCreate() async => state;

  @override
  Future<void> save(AccountsState state) async {
    saveCalls++;
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

class _FailOnSaveAccountStore extends _MemoryAccountStore {
  _FailOnSaveAccountStore(super.state, {required this.failOnCalls});

  final Set<int> failOnCalls;

  @override
  Future<void> save(AccountsState state) async {
    saveCalls++;
    if (failOnCalls.contains(saveCalls)) {
      throw StateError('Injected account save failure');
    }
    this.state = state;
  }
}

class _RecordingAccountCleanup extends AccountCleanupService {
  _RecordingAccountCleanup()
    : super(
        credentials: CredentialStore(),
        databaseLifecycle: createAccountDatabaseLifecycle(
          findAccount: (_) async => null,
        ),
      );

  int calls = 0;

  @override
  Future<void> deleteAccountData(Account account) async {
    calls++;
  }
}

class _FailingAccountCleanup extends AccountCleanupService {
  _FailingAccountCleanup()
    : super(
        credentials: CredentialStore(),
        databaseLifecycle: createAccountDatabaseLifecycle(
          findAccount: (_) async => null,
        ),
      );

  @override
  Future<void> deleteAccountData(Account account) async {
    throw StateError('Injected cleanup failure');
  }
}
