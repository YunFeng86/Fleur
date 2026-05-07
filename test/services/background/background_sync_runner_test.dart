import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fleur/models/feed.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/repositories/article_repository.dart';
import 'package:fleur/repositories/category_repository.dart';
import 'package:fleur/repositories/feed_repository.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/accounts/account_store.dart';
import 'package:fleur/services/background/background_sync_service.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/app_settings_store.dart';
import 'package:fleur/services/sync/fever/fever_sync_service.dart';
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

class _FakeCacheManager extends Fake implements BaseCacheManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AccountsState buildAccountsState({
    AccountType type = AccountType.miniflux,
    String id = 'remote-account',
    String? baseUrl = 'https://example.com',
    bool isPrimary = true,
  }) {
    final account = buildTestAccount(
      id: id,
      type: type,
      baseUrl: baseUrl,
      isPrimary: isPrimary,
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
          autoRefreshMinutes: null,
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
          autoRefreshMinutes: null,
          syncEnabled: false,
        ),
      ),
      outboxStore: outbox,
      runWithMutex: _runWithoutMutex,
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
            autoRefreshMinutes: null,
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

  testWidgets('flushes outbox and refreshes feeds when both are needed', (
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
          autoRefreshMinutes: 30,
          syncEnabled: true,
        ),
      ),
      outboxStore: outbox,
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

    expect(syncService.flushCalls, 1);
    expect(syncService.refreshCalls, [
      [1],
    ]);
    expect(isar.closeCalls, 1);
  });

  testWidgets(
    'remote-backed accounts still run refresh flow with an empty local mirror',
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
            autoRefreshMinutes: 30,
            syncEnabled: true,
          ),
        ),
        outboxStore: FakeOutboxStore(),
        runWithMutex: _runWithoutMutex,
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

  testWidgets('skips refresh when iOS gating says interval has not elapsed', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    SharedPreferences.setMockInitialValues({
      'background_sync:last_refresh:remote-account': DateTime.utc(
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
          autoRefreshMinutes: 30,
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
  });

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

      expect(localService, isA<SyncService>());
      expect(minifluxService, isA<MinifluxSyncService>());
      expect(feverService, isA<FeverSyncService>());
    },
  );
}
