import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/features/data_safety/data/account_database_session_pool.dart';
import 'package:fleur/features/data_safety/data/isar_account_database_driver.dart';
import 'package:fleur/features/data_safety/data/isar_account_database_lifecycle.dart';
import 'package:fleur/features/data_safety/data_safety.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/repositories/article_repository.dart';
import 'package:fleur/repositories/category_repository.dart';
import 'package:fleur/repositories/feed_repository.dart';
import 'package:fleur/services/background/background_sync_service.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/app_settings_store.dart';
import 'package:fleur/services/sync/fever/fever_sync_service.dart';
import 'package:fleur/services/sync/google_reader/google_reader_sync_service.dart';
import 'package:fleur/services/sync/miniflux/miniflux_sync_service.dart';
import 'package:fleur/services/sync/sync_service.dart';
import 'package:fleur/services/sync/outbox/outbox_store.dart';
import 'package:fleur/utils/platform.dart';

import '../../test_utils/critical_workflow_test_support.dart';

Future<T> _runWithoutMutex<T>(String key, Future<T> Function() op) => op();

class _FakeIsar extends Fake implements Isar {
  var closeCalls = 0;

  @override
  Future<bool> close({bool deleteFromDisk = false}) async {
    closeCalls++;
    return true;
  }
}

class _FakeIsarLease implements IsarLease {
  _FakeIsarLease(this.isar);

  var releaseCalls = 0;

  @override
  final Isar isar;

  @override
  Future<void> release() async {
    releaseCalls++;
  }
}

class _OpaqueAccountDatabaseLease implements AccountDatabaseLease {
  _OpaqueAccountDatabaseLease(this.accountId);

  @override
  final String accountId;
  var releaseCalls = 0;

  @override
  Future<void> release() async {
    releaseCalls++;
  }
}

class _ReadyAccountDatabaseLifecycle implements AccountDatabaseLifecycle {
  _ReadyAccountDatabaseLifecycle(this.lease);

  final AccountDatabaseLease lease;

  @override
  Future<AccountDatabaseAcquireResult> acquireExisting(
    AccountDatabaseRef account,
  ) async {
    return AccountDatabaseReady(lease: lease, initializedNow: false);
  }

  @override
  Future<AccountDatabaseAcquireResult> initialize(
    AccountDatabaseInitialization intent,
  ) async {
    return AccountDatabaseReady(lease: lease, initializedNow: true);
  }

  @override
  Future<AccountDatabaseDeletionResult> deleteForAccountRemoval(
    AccountDatabaseDeletionIntent intent,
  ) {
    throw UnimplementedError();
  }
}

class _FakeCacheManager extends Fake implements BaseCacheManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AccountsState buildAccountsState({
    AccountType type = AccountType.miniflux,
    String id = 'remote-account',
    String? baseUrl = 'https://example.com',
    bool isPrimary = true,
    bool databaseInitialized = true,
  }) {
    final account = buildTestAccount(
      id: id,
      type: type,
      baseUrl: baseUrl,
      isPrimary: isPrimary,
      databaseInitialized: databaseInitialized,
    );
    return AccountsState(
      version: AccountStore.currentVersion,
      activeAccountId: account.id,
      accounts: [account],
    );
  }

  AppSettingsStore buildAppSettingsStore(AppSettings settings) {
    return FakeAppSettingsStore(settings);
  }

  testWidgets('returns early without opening DB when there is no work', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    var openCalls = 0;
    final runner = BackgroundSyncRunner(
      accounts: buildAccountsState(),
      appSettingsStore: buildAppSettingsStore(
        AppSettings.defaults().copyWith(
          sourceRefreshMinutes: null,
          syncEnabled: false,
        ),
      ),
      outboxStore: FakeOutboxStore(),
      runWithMutex: _runWithoutMutex,
      openIsarForAccountFn:
          ({required accountId, required dbName, required isPrimary}) async {
            openCalls++;
            throw UnimplementedError('DB should not be opened');
          },
      syncServiceBuilder:
          ({
            required account,
            required feeds,
            required categories,
            required articles,
            required outbox,
            required appSettingsStore,
          }) {
            throw UnimplementedError('syncServiceBuilder should not be called');
          },
    );

    await runner.run(
      taskName: kBackgroundSyncTaskName,
      inputData: const <String, dynamic>{},
    );

    expect(openCalls, 0);
  });

  testWidgets('does not initialize a pending account in the background', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues(<String, Object>{});

    var openCalls = 0;
    final runner = BackgroundSyncRunner(
      accounts: buildAccountsState(databaseInitialized: false),
      appSettingsStore: buildAppSettingsStore(
        AppSettings.defaults().copyWith(syncEnabled: true),
      ),
      outboxStore: FakeOutboxStore(),
      runWithMutex: _runWithoutMutex,
      openIsarForAccountFn:
          ({required accountId, required dbName, required isPrimary}) async {
            openCalls++;
            throw UnimplementedError('pending database must not be opened');
          },
    );

    await runner.run(
      taskName: kBackgroundSyncTaskName,
      inputData: const <String, dynamic>{},
    );

    expect(openCalls, 0);
  });

  testWidgets('flushes outbox only when refresh is disabled', (tester) async {
    debugFleurTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final outbox = FakeOutboxStore();
    final accountId = buildAccountsState().activeAccountId;
    await outbox.save(accountId, [
      OutboxAction(
        type: OutboxActionType.markRead,
        remoteEntryId: 1,
        value: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    final syncService = FakeSyncService();
    final isar = _FakeIsar();
    final runner = BackgroundSyncRunner(
      accounts: buildAccountsState(),
      appSettingsStore: buildAppSettingsStore(
        AppSettings.defaults().copyWith(
          sourceRefreshMinutes: null,
          syncEnabled: false,
        ),
      ),
      outboxStore: outbox,
      runWithMutex: _runWithoutMutex,
      refreshAllRemoteFeeds: (_) async {},
      openIsarForAccountFn:
          ({required accountId, required dbName, required isPrimary}) async =>
              isar,
      syncServiceBuilder:
          ({
            required account,
            required feeds,
            required categories,
            required articles,
            required outbox,
            required appSettingsStore,
          }) {
            return syncService;
          },
    );

    await runner.run(
      taskName: kBackgroundSyncTaskName,
      inputData: const <String, dynamic>{},
    );

    expect(syncService.flushCalls, 1);
    expect(syncService.refreshCalls, isEmpty);
    expect(isar.closeCalls, 1);
  });

  testWidgets(
    'default DB session path releases lease instead of closing Isar',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugFleurTargetPlatformOverride = null);

      final outbox = FakeOutboxStore();
      final accountId = buildAccountsState().activeAccountId;
      await outbox.save(accountId, [
        OutboxAction(
          type: OutboxActionType.markRead,
          remoteEntryId: 1,
          value: true,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ]);
      final syncService = FakeSyncService();
      final isar = _FakeIsar();
      final lease = _FakeIsarLease(isar);

      final runner = BackgroundSyncRunner(
        accounts: buildAccountsState(),
        appSettingsStore: buildAppSettingsStore(
          AppSettings.defaults().copyWith(
            sourceRefreshMinutes: null,
            syncEnabled: false,
          ),
        ),
        outboxStore: outbox,
        runWithMutex: _runWithoutMutex,
        refreshAllRemoteFeeds: (_) async {},
        acquireIsarLeaseForAccountFn:
            ({required accountId, required dbName, required isPrimary}) async =>
                lease,
        syncServiceBuilder:
            ({
              required account,
              required feeds,
              required categories,
              required articles,
              required outbox,
              required appSettingsStore,
            }) {
              return syncService;
            },
      );

      await runner.run(
        taskName: kBackgroundSyncTaskName,
        inputData: const <String, dynamic>{},
      );

      expect(syncService.flushCalls, 1);
      expect(lease.releaseCalls, 1);
      expect(isar.closeCalls, 0);
    },
  );

  testWidgets('lifecycle path skips work on semantic database failure', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final accounts = buildAccountsState();
    final accountId = accounts.activeAccountId;
    final outbox = FakeOutboxStore();
    await outbox.save(accountId, [
      OutboxAction(
        type: OutboxActionType.markRead,
        remoteEntryId: 1,
        value: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    var openCalls = 0;
    final lifecycle = IsarAccountDatabaseLifecycle(
      findAccount: (id) async => accounts.findById(id),
      sessions: AccountDbSessionManager(
        resolveTarget:
            ({required accountId, dbName, required isPrimary}) async {
              return AccountDbTarget(
                accountId: accountId,
                directory: '/test/database',
                name: dbName ?? accountId,
                isPrimary: isPrimary,
              );
            },
        openTarget: (target, mode) async {
          openCalls++;
          throw DbOpenFailure(
            kind: DbOpenFailureKind.transient,
            directory: target.directory,
            name: target.name,
            error: StateError('database locked'),
          );
        },
      ),
    );
    final runner = BackgroundSyncRunner(
      accounts: accounts,
      appSettingsStore: buildAppSettingsStore(
        AppSettings.defaults().copyWith(
          sourceRefreshMinutes: null,
          syncEnabled: false,
        ),
      ),
      outboxStore: outbox,
      databaseLifecycle: lifecycle,
      runWithMutex: _runWithoutMutex,
    );

    await runner.run(
      taskName: kBackgroundSyncTaskName,
      inputData: const <String, dynamic>{},
    );

    expect(openCalls, 1);
    expect((await outbox.load(accountId)).length, 1);
  });

  testWidgets('lifecycle path releases a lease when runtime binding fails', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final accounts = buildAccountsState();
    final accountId = accounts.activeAccountId;
    final outbox = FakeOutboxStore();
    await outbox.save(accountId, [
      OutboxAction(
        type: OutboxActionType.markRead,
        remoteEntryId: 1,
        value: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    final lease = _OpaqueAccountDatabaseLease(accountId);
    final runner = BackgroundSyncRunner(
      accounts: accounts,
      appSettingsStore: buildAppSettingsStore(
        AppSettings.defaults().copyWith(
          sourceRefreshMinutes: null,
          syncEnabled: false,
        ),
      ),
      outboxStore: outbox,
      databaseLifecycle: _ReadyAccountDatabaseLifecycle(lease),
      runWithMutex: _runWithoutMutex,
    );

    await runner.run(
      taskName: kBackgroundSyncTaskName,
      inputData: const <String, dynamic>{},
    );

    expect(lease.releaseCalls, 1);
    expect((await outbox.load(accountId)).length, 1);
  });

  testWidgets('lifecycle path releases its database lease after work', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final accounts = buildAccountsState();
    final accountId = accounts.activeAccountId;
    final outbox = FakeOutboxStore();
    await outbox.save(accountId, [
      OutboxAction(
        type: OutboxActionType.markRead,
        remoteEntryId: 1,
        value: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    final isar = _FakeIsar();
    final lifecycle = IsarAccountDatabaseLifecycle(
      findAccount: (id) async => accounts.findById(id),
      sessions: AccountDbSessionManager(
        resolveTarget:
            ({required accountId, dbName, required isPrimary}) async {
              return AccountDbTarget(
                accountId: accountId,
                directory: '/test/database',
                name: dbName ?? accountId,
                isPrimary: isPrimary,
              );
            },
        openTarget: (target, mode) async => isar,
      ),
    );
    final syncService = FakeSyncService();
    final runner = BackgroundSyncRunner(
      accounts: accounts,
      appSettingsStore: buildAppSettingsStore(
        AppSettings.defaults().copyWith(
          sourceRefreshMinutes: null,
          syncEnabled: false,
        ),
      ),
      outboxStore: outbox,
      databaseLifecycle: lifecycle,
      runWithMutex: _runWithoutMutex,
      syncServiceBuilder:
          ({
            required account,
            required feeds,
            required categories,
            required articles,
            required outbox,
            required appSettingsStore,
          }) => syncService,
    );

    await runner.run(
      taskName: kBackgroundSyncTaskName,
      inputData: const <String, dynamic>{},
    );

    expect(syncService.flushCalls, 1);
    expect(isar.closeCalls, 1);
  });

  testWidgets(
    'local accounts ignore outbox-only background work and keep DB closed',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugFleurTargetPlatformOverride = null);

      final outbox = FakeOutboxStore();
      final accounts = buildAccountsState(
        type: AccountType.local,
        id: 'local-account',
        baseUrl: null,
      );
      await outbox.save(accounts.activeAccountId, [
        OutboxAction(
          type: OutboxActionType.markRead,
          remoteEntryId: 1,
          value: true,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ]);

      var openCalls = 0;
      final runner = BackgroundSyncRunner(
        accounts: accounts,
        appSettingsStore: buildAppSettingsStore(
          AppSettings.defaults().copyWith(
            sourceRefreshMinutes: null,
            syncEnabled: false,
          ),
        ),
        outboxStore: outbox,
        runWithMutex: _runWithoutMutex,
        openIsarForAccountFn:
            ({required accountId, required dbName, required isPrimary}) async {
              openCalls++;
              throw UnimplementedError('DB should not be opened');
            },
        syncServiceBuilder:
            ({
              required account,
              required feeds,
              required categories,
              required articles,
              required outbox,
              required appSettingsStore,
            }) {
              throw UnimplementedError(
                'syncServiceBuilder should not be called',
              );
            },
      );

      await runner.run(
        taskName: kBackgroundSyncTaskName,
        inputData: const <String, dynamic>{},
      );

      expect(openCalls, 0);
    },
  );

  testWidgets('flushes outbox and syncs account when both are needed', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final outbox = FakeOutboxStore();
    final accountId = buildAccountsState().activeAccountId;
    await outbox.save(accountId, [
      OutboxAction(
        type: OutboxActionType.markRead,
        remoteEntryId: 1,
        value: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ]);
    final syncService = FakeSyncService();
    final isar = _FakeIsar();
    final feed = Feed()
      ..id = 1
      ..url = 'https://example.com/feed.xml'
      ..title = 'Feed 1';
    final runner = BackgroundSyncRunner(
      accounts: buildAccountsState(),
      appSettingsStore: buildAppSettingsStore(
        AppSettings.defaults().copyWith(
          sourceRefreshMinutes: null,
          syncEnabled: true,
        ),
      ),
      outboxStore: outbox,
      runWithMutex: _runWithoutMutex,
      refreshAllRemoteFeeds: (_) async {},
      openIsarForAccountFn:
          ({required accountId, required dbName, required isPrimary}) async =>
              isar,
      loadAllFeeds: (feeds, account) async => [feed],
      syncServiceBuilder:
          ({
            required account,
            required feeds,
            required categories,
            required articles,
            required outbox,
            required appSettingsStore,
          }) {
            return syncService;
          },
    );

    await runner.run(
      taskName: kBackgroundSyncTaskName,
      inputData: const <String, dynamic>{},
    );

    expect(syncService.flushCalls, 1);
    expect(syncService.refreshCalls, [
      [1],
    ]);
    expect(isar.closeCalls, 1);
  });

  testWidgets(
    'remote-backed accounts still run account sync with an empty local mirror',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugFleurTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final syncService = FakeSyncService();
      final isar = _FakeIsar();
      final runner = BackgroundSyncRunner(
        accounts: buildAccountsState(),
        appSettingsStore: buildAppSettingsStore(
          AppSettings.defaults().copyWith(
            sourceRefreshMinutes: null,
            syncEnabled: true,
          ),
        ),
        outboxStore: FakeOutboxStore(),
        runWithMutex: _runWithoutMutex,
        refreshAllRemoteFeeds: (_) async {},
        openIsarForAccountFn:
            ({required accountId, required dbName, required isPrimary}) async =>
                isar,
        loadAllFeeds: (feeds, account) async => <Feed>[],
        syncServiceBuilder:
            ({
              required account,
              required feeds,
              required categories,
              required articles,
              required outbox,
              required appSettingsStore,
            }) {
              return syncService;
            },
      );

      await runner.run(
        taskName: kBackgroundSyncTaskName,
        inputData: const <String, dynamic>{},
      );

      expect(syncService.refreshCalls, [<int>[]]);
      expect(isar.closeCalls, 1);
    },
  );

  testWidgets('local background source refresh syncs local feeds', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final syncService = FakeSyncService();
    final isar = _FakeIsar();
    final feed = Feed()
      ..id = 1
      ..url = 'https://example.com/feed.xml'
      ..title = 'Feed 1';
    final runner = BackgroundSyncRunner(
      accounts: buildAccountsState(
        type: AccountType.local,
        id: 'local-account',
        baseUrl: null,
      ),
      appSettingsStore: buildAppSettingsStore(
        AppSettings.defaults().copyWith(
          sourceRefreshMinutes: 30,
          syncEnabled: true,
        ),
      ),
      outboxStore: FakeOutboxStore(),
      runWithMutex: _runWithoutMutex,
      openIsarForAccountFn:
          ({required accountId, required dbName, required isPrimary}) async =>
              isar,
      loadAllFeeds: (feeds, account) async => [feed],
      syncServiceBuilder:
          ({
            required account,
            required feeds,
            required categories,
            required articles,
            required outbox,
            required appSettingsStore,
          }) {
            return syncService;
          },
    );

    await runner.run(
      taskName: kBackgroundSyncTaskName,
      inputData: const <String, dynamic>{},
    );

    expect(syncService.refreshCalls, [
      [1],
    ]);
    expect(isar.closeCalls, 1);
  });

  testWidgets(
    'miniflux background source refresh triggers upstream refresh before sync',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugFleurTargetPlatformOverride = null);
      SharedPreferences.setMockInitialValues(<String, Object>{});

      final events = <String>[];
      final syncService = FakeSyncService(
        onRefresh: (feedIds) async {
          events.add('sync');
          return const BatchRefreshResult(<FeedRefreshResult>[]);
        },
      );
      final isar = _FakeIsar();
      final feed = Feed()
        ..id = 1
        ..url = 'https://example.com/feed.xml'
        ..title = 'Feed 1';
      final runner = BackgroundSyncRunner(
        accounts: buildAccountsState(type: AccountType.miniflux),
        appSettingsStore: buildAppSettingsStore(
          AppSettings.defaults().copyWith(
            sourceRefreshMinutes: 30,
            syncEnabled: true,
          ),
        ),
        outboxStore: FakeOutboxStore(),
        runWithMutex: _runWithoutMutex,
        refreshAllRemoteFeeds: (_) async {
          events.add('upstream');
        },
        openIsarForAccountFn:
            ({required accountId, required dbName, required isPrimary}) async =>
                isar,
        loadAllFeeds: (feeds, account) async => [feed],
        syncServiceBuilder:
            ({
              required account,
              required feeds,
              required categories,
              required articles,
              required outbox,
              required appSettingsStore,
            }) {
              return syncService;
            },
      );

      await runner.run(
        taskName: kBackgroundSyncTaskName,
        inputData: const <String, dynamic>{},
      );

      expect(events, ['upstream', 'sync']);
      expect(syncService.refreshCalls, [
        [1],
      ]);
      expect(isar.closeCalls, 1);
    },
  );

  testWidgets(
    'skips local source refresh when gating interval has not elapsed',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugFleurTargetPlatformOverride = null);

      SharedPreferences.setMockInitialValues({
        'background_sync:last_source_refresh:local-account': DateTime.utc(
          2026,
          1,
          1,
          0,
          10,
        ).millisecondsSinceEpoch,
      });

      var openCalls = 0;
      final runner = BackgroundSyncRunner(
        accounts: buildAccountsState(
          type: AccountType.local,
          id: 'local-account',
          baseUrl: null,
        ),
        appSettingsStore: buildAppSettingsStore(
          AppSettings.defaults().copyWith(
            sourceRefreshMinutes: 30,
            syncEnabled: true,
          ),
        ),
        outboxStore: FakeOutboxStore(),
        runWithMutex: _runWithoutMutex,
        nowProvider: () => DateTime.utc(2026, 1, 1, 0, 20),
        openIsarForAccountFn:
            ({required accountId, required dbName, required isPrimary}) async {
              openCalls++;
              throw UnimplementedError('DB should not be opened');
            },
        syncServiceBuilder:
            ({
              required account,
              required feeds,
              required categories,
              required articles,
              required outbox,
              required appSettingsStore,
            }) {
              throw UnimplementedError(
                'syncServiceBuilder should not be called',
              );
            },
      );

      await runner.run(
        taskName: kBackgroundSyncTaskName,
        inputData: const <String, dynamic>{},
      );

      expect(openCalls, 0);
    },
  );

  testWidgets('fever background account sync runs without upstream refresh', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues(<String, Object>{});

    var upstreamCalls = 0;
    final syncService = FakeSyncService();
    final isar = _FakeIsar();
    final runner = BackgroundSyncRunner(
      accounts: buildAccountsState(type: AccountType.fever),
      appSettingsStore: buildAppSettingsStore(
        AppSettings.defaults().copyWith(
          sourceRefreshMinutes: null,
          syncEnabled: true,
        ),
      ),
      outboxStore: FakeOutboxStore(),
      runWithMutex: _runWithoutMutex,
      refreshAllRemoteFeeds: (_) async {
        upstreamCalls++;
      },
      openIsarForAccountFn:
          ({required accountId, required dbName, required isPrimary}) async =>
              isar,
      loadAllFeeds: (feeds, account) async => <Feed>[],
      syncServiceBuilder:
          ({
            required account,
            required feeds,
            required categories,
            required articles,
            required outbox,
            required appSettingsStore,
          }) {
            return syncService;
          },
    );

    await runner.run(
      taskName: kBackgroundSyncTaskName,
      inputData: const <String, dynamic>{},
    );

    expect(upstreamCalls, 0);
    expect(syncService.refreshCalls, [<int>[]]);
    expect(isar.closeCalls, 1);
  });

  testWidgets(
    'skips account sync when iOS gating says interval has not elapsed',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugFleurTargetPlatformOverride = null);

      SharedPreferences.setMockInitialValues({
        'background_sync:last_account_sync:remote-account': DateTime.utc(
          2026,
          1,
          1,
          0,
          10,
        ).millisecondsSinceEpoch,
      });

      final outbox = FakeOutboxStore();
      final accountId = buildAccountsState().activeAccountId;
      await outbox.save(accountId, [
        OutboxAction(
          type: OutboxActionType.markRead,
          remoteEntryId: 1,
          value: true,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ]);
      final syncService = FakeSyncService();
      final isar = _FakeIsar();
      final runner = BackgroundSyncRunner(
        accounts: buildAccountsState(),
        appSettingsStore: buildAppSettingsStore(
          AppSettings.defaults().copyWith(
            sourceRefreshMinutes: null,
            syncEnabled: true,
          ),
        ),
        outboxStore: outbox,
        runWithMutex: _runWithoutMutex,
        nowProvider: () => DateTime.utc(2026, 1, 1, 0, 20),
        openIsarForAccountFn:
            ({required accountId, required dbName, required isPrimary}) async =>
                isar,
        syncServiceBuilder:
            ({
              required account,
              required feeds,
              required categories,
              required articles,
              required outbox,
              required appSettingsStore,
            }) {
              return syncService;
            },
      );

      await runner.run(
        taskName: kBackgroundSyncTaskName,
        inputData: const <String, dynamic>{},
      );

      expect(syncService.flushCalls, 1);
      expect(syncService.refreshCalls, isEmpty);
      expect(isar.closeCalls, 1);
    },
  );

  test(
    'shared sync assembly keeps service selection and Dio defaults aligned',
    () {
      final isar = _FakeIsar();
      final dio = createAppDio();
      final cache = createArticleCacheService(
        cacheManager: _FakeCacheManager(),
      );
      final extractor = createArticleExtractor(dio: dio);
      final notifications = createNotificationService();
      final outbox = FakeOutboxStore();
      final appSettingsStore = FakeAppSettingsStore(AppSettings.defaults());
      final feeds = FeedRepository(isar);
      final categories = CategoryRepository(isar);
      final articles = ArticleRepository(isar);

      expect(dio.options.connectTimeout, const Duration(seconds: 10));
      expect(dio.options.receiveTimeout, const Duration(seconds: 20));
      expect(dio.options.sendTimeout, const Duration(seconds: 10));
      expect(dio.options.maxRedirects, 5);

      final localService = buildSyncServiceForAccount(
        account: buildTestAccount(type: AccountType.local),
        feeds: feeds,
        categories: categories,
        articles: articles,
        outbox: outbox,
        appSettingsStore: appSettingsStore,
        dio: dio,
        credentials: createCredentialStore(),
        notifications: notifications,
        cache: cache,
        extractor: extractor,
      );
      final minifluxService = buildSyncServiceForAccount(
        account: buildTestAccount(
          type: AccountType.miniflux,
          baseUrl: 'https://example.com',
        ),
        feeds: feeds,
        categories: categories,
        articles: articles,
        outbox: outbox,
        appSettingsStore: appSettingsStore,
        dio: dio,
        credentials: createCredentialStore(),
        notifications: notifications,
        cache: cache,
        extractor: extractor,
      );
      final feverService = buildSyncServiceForAccount(
        account: buildTestAccount(
          type: AccountType.fever,
          baseUrl: 'https://example.com',
        ),
        feeds: feeds,
        categories: categories,
        articles: articles,
        outbox: outbox,
        appSettingsStore: appSettingsStore,
        dio: dio,
        credentials: createCredentialStore(),
        notifications: notifications,
        cache: cache,
        extractor: extractor,
      );
      final googleReaderService = buildSyncServiceForAccount(
        account: buildTestAccount(
          type: AccountType.googleReader,
          baseUrl: 'https://example.com',
        ),
        feeds: feeds,
        categories: categories,
        articles: articles,
        outbox: outbox,
        appSettingsStore: appSettingsStore,
        dio: dio,
        credentials: createCredentialStore(),
        notifications: notifications,
        cache: cache,
        extractor: extractor,
      );

      expect(localService, isA<SyncService>());
      expect(minifluxService, isA<MinifluxSyncService>());
      expect(feverService, isA<FeverSyncService>());
      expect(googleReaderService, isA<GoogleReaderSyncService>());
    },
  );
}
