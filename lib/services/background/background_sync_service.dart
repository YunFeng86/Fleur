import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../providers/service_providers.dart';
import '../../db/isar_db.dart';
import '../../models/feed.dart';
import '../../repositories/article_repository.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/feed_repository.dart';
import '../accounts/account.dart';
import '../accounts/account_store.dart';
import '../logging/app_logger.dart';
import '../settings/app_settings.dart';
import '../settings/app_settings_store.dart';
import '../sync/backend_capabilities.dart';
import '../sync/outbox/outbox_store.dart';
import '../sync/refresh_all_coordinator.dart';
import '../sync/remote_client_factory.dart';
import '../sync/remote_subscription_structure_executor.dart';
import '../sync/sync_mutex.dart';
import '../sync/sync_service.dart';
import '../../utils/platform.dart';

const String kBackgroundSyncUniqueName = 'com.cloudwind.fleur.background.sync';
const String kBackgroundSyncTaskName = 'backgroundSync';

@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await AppLogger.ensureInitialized();
    } catch (e, st) {
      debugPrint('Background logger init failed: $e\n$st');
    }

    try {
      final runner = BackgroundSyncRunner();
      await runner.run(taskName: taskName, inputData: inputData);
      return true;
    } catch (e, st) {
      AppLogger.e(
        'Background sync failed',
        tag: 'bg',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  });
}

class BackgroundSyncService {
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (!supportsBackgroundSyncPlatform) return;
    try {
      await Workmanager().initialize(backgroundSyncCallbackDispatcher);
      _initialized = true;
    } on MissingPluginException {
      // Best-effort: running on an unsupported platform.
    } catch (e) {
      AppLogger.w('Background sync scheduler init failed', tag: 'bg', error: e);
    }
  }

  static Future<void> schedulePeriodic({required Duration frequency}) async {
    if (!supportsBackgroundSyncPlatform) return;
    await ensureInitialized();

    final effectiveFrequency = frequency.inMinutes < 15
        ? const Duration(minutes: 15)
        : frequency;

    try {
      await Workmanager().registerPeriodicTask(
        kBackgroundSyncUniqueName,
        kBackgroundSyncTaskName,
        frequency: effectiveFrequency,
        initialDelay: const Duration(minutes: 1),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
    } on MissingPluginException {
      // ignore: best-effort
    } catch (e) {
      AppLogger.w(
        'Background sync periodic scheduling failed',
        tag: 'bg',
        error: e,
      );
    }
  }

  static Future<void> cancelPeriodic() async {
    if (!supportsBackgroundSyncPlatform) return;
    try {
      await Workmanager().cancelByUniqueName(kBackgroundSyncUniqueName);
    } on MissingPluginException {
      // ignore: best-effort
    } catch (e) {
      AppLogger.w(
        'Background sync periodic cancellation failed',
        tag: 'bg',
        error: e,
      );
    }
  }
}

class BackgroundSyncRunner {
  BackgroundSyncRunner({
    AccountsState? accounts,
    AccountStore? accountStore,
    AppSettings? appSettings,
    AppSettingsStore? appSettingsStore,
    OutboxStore? outboxStore,
    Future<SharedPreferences> Function()? sharedPreferencesLoader,
    DateTime Function()? nowProvider,
    Future<Isar> Function({
      required String accountId,
      required String? dbName,
      required bool isPrimary,
    })?
    openIsarForAccountFn,
    Future<IsarLease> Function({
      required String accountId,
      required String? dbName,
      required bool isPrimary,
    })?
    acquireIsarLeaseForAccountFn,
    Future<T> Function<T>(String key, Future<T> Function() op)? runWithMutex,
    Future<void> Function(Account account)? refreshAllRemoteFeeds,
    Future<List<Feed>> Function(FeedRepository feeds, Account account)?
    loadAllFeeds,
    SyncServiceBase Function({
      required Account account,
      required FeedRepository feeds,
      required CategoryRepository categories,
      required ArticleRepository articles,
      required OutboxStore outbox,
      required AppSettingsStore appSettingsStore,
    })?
    syncServiceBuilder,
  }) : _accounts = accounts,
       _accountStore = accountStore ?? AccountStore(),
       _appSettings = appSettings,
       _appSettingsStore = appSettingsStore ?? AppSettingsStore(),
       _outboxStore = outboxStore ?? OutboxStore(),
       _sharedPreferencesLoader =
           sharedPreferencesLoader ?? SharedPreferences.getInstance,
       _nowProvider = nowProvider ?? DateTime.now,
       _openIsarForAccountFn = openIsarForAccountFn,
       _acquireIsarLeaseForAccountFn =
           acquireIsarLeaseForAccountFn ??
           AccountDbSessionManager.instance.acquireForAccount,
       _runWithMutex = runWithMutex ?? SyncMutex.instance.run,
       _refreshAllRemoteFeeds = refreshAllRemoteFeeds,
       _loadAllFeeds = loadAllFeeds,
       _syncServiceBuilder = syncServiceBuilder;

  final AccountsState? _accounts;
  final AccountStore _accountStore;
  final AppSettings? _appSettings;
  final AppSettingsStore _appSettingsStore;
  final OutboxStore _outboxStore;
  final Future<SharedPreferences> Function() _sharedPreferencesLoader;
  final DateTime Function() _nowProvider;
  final Future<Isar> Function({
    required String accountId,
    required String? dbName,
    required bool isPrimary,
  })?
  _openIsarForAccountFn;
  final Future<IsarLease> Function({
    required String accountId,
    required String? dbName,
    required bool isPrimary,
  })
  _acquireIsarLeaseForAccountFn;
  final Future<T> Function<T>(String key, Future<T> Function() op)
  _runWithMutex;
  final Future<void> Function(Account account)? _refreshAllRemoteFeeds;
  final Future<List<Feed>> Function(FeedRepository feeds, Account account)?
  _loadAllFeeds;
  final SyncServiceBase Function({
    required Account account,
    required FeedRepository feeds,
    required CategoryRepository categories,
    required ArticleRepository articles,
    required OutboxStore outbox,
    required AppSettingsStore appSettingsStore,
  })?
  _syncServiceBuilder;

  static const String _lastAccountSyncKeyPrefix =
      'background_sync:last_account_sync:';
  static const String _lastSourceRefreshKeyPrefix =
      'background_sync:last_source_refresh:';
  static const Duration _backgroundAccountSyncInterval = Duration(minutes: 15);

  Future<void> run({
    required String taskName,
    required Map<String, dynamic>? inputData,
  }) async {
    if (taskName != kBackgroundSyncTaskName &&
        taskName != kBackgroundSyncUniqueName &&
        taskName != Workmanager.iOSBackgroundTask) {
      return;
    }

    await _runWithMutex('sync', () async {
      final accounts = _accounts ?? await _accountStore.loadOrCreate();
      final activeAccount =
          accounts.findById(accounts.activeAccountId) ??
          accounts.accounts.first;
      final capabilities = BackendCapabilities.forAccountType(
        activeAccount.type,
      );
      final appSettings = _appSettings ?? await _appSettingsStore.load();

      final sourceRefreshMinutes = appSettings.sourceRefreshMinutes ?? 0;
      var shouldRefreshSources =
          appSettings.syncEnabled &&
          sourceRefreshMinutes > 0 &&
          capabilities.isVisible(BackendFeature.refreshAllSources);

      if (shouldRefreshSources) {
        shouldRefreshSources = await _shouldRunInterval(
          key: '$_lastSourceRefreshKeyPrefix${activeAccount.id}',
          minInterval: Duration(minutes: sourceRefreshMinutes),
          failureMessage:
              'Background source refresh gating failed; continuing with refresh',
        );
      }

      var shouldSyncAccount =
          appSettings.syncEnabled &&
          capabilities.isRemoteBacked &&
          !shouldRefreshSources;

      // iOS can wake the app more frequently than the requested cadence
      // (BGTaskScheduler is best-effort). Gate account sync work in Dart.
      if (shouldSyncAccount && isIOS) {
        shouldSyncAccount = await _shouldRunInterval(
          key: '$_lastAccountSyncKeyPrefix${activeAccount.id}',
          minInterval: _backgroundAccountSyncInterval,
          failureMessage:
              'Background account sync gating failed; continuing with sync',
        );
      }

      // Avoid opening Isar when there's nothing to do.
      final hasPendingOutbox =
          capabilities.isOutboxCapable &&
          (await _outboxStore.load(activeAccount.id)).isNotEmpty;
      if (!shouldRefreshSources && !shouldSyncAccount && !hasPendingOutbox) {
        return;
      }

      late final Isar isar;
      IsarLease? lease;
      try {
        final openIsarForAccountFn = _openIsarForAccountFn;
        if (openIsarForAccountFn == null) {
          lease = await _acquireIsarLeaseForAccountFn(
            accountId: activeAccount.id,
            dbName: activeAccount.dbName,
            isPrimary: activeAccount.isPrimary,
          );
          isar = lease.isar;
        } else {
          isar = await openIsarForAccountFn(
            accountId: activeAccount.id,
            dbName: activeAccount.dbName,
            isPrimary: activeAccount.isPrimary,
          );
        }
      } on DbOpenFailure catch (e) {
        AppLogger.w(
          'Background sync skipped: failed to open DB (${e.kind})',
          tag: 'sync',
          error: e.error,
        );
        return;
      } catch (e) {
        AppLogger.w(
          'Background sync skipped: failed to open DB',
          tag: 'sync',
          error: e,
        );
        return;
      }

      try {
        final feeds = FeedRepository(isar);
        final categories = CategoryRepository(isar);
        final articles = ArticleRepository(isar);
        final dio = createAppDio();
        final credentials = createCredentialStore();
        final syncServiceBuilder = _syncServiceBuilder;
        final loadAllFeeds = _loadAllFeeds;
        final notifications = createNotificationService();

        final svc = syncServiceBuilder != null
            ? syncServiceBuilder(
                account: activeAccount,
                feeds: feeds,
                categories: categories,
                articles: articles,
                outbox: _outboxStore,
                appSettingsStore: _appSettingsStore,
              )
            : buildSyncServiceForAccount(
                account: activeAccount,
                feeds: feeds,
                categories: categories,
                articles: articles,
                outbox: _outboxStore,
                appSettingsStore: _appSettingsStore,
                dio: dio,
                credentials: credentials,
                notifications: notifications,
                cache: createArticleCacheService(),
                extractor: createArticleExtractor(dio: dio),
              );

        if (hasPendingOutbox) {
          await _flushOutboxSafe(activeAccount, svc);
        }

        if (!shouldRefreshSources && !shouldSyncAccount) return;

        final allFeeds = loadAllFeeds != null
            ? await loadAllFeeds(feeds, activeAccount)
            : await feeds.getAll();
        if (allFeeds.isEmpty &&
            !capabilities.isRemoteBacked &&
            !shouldRefreshSources) {
          return;
        }

        final concurrency = appSettings.autoRefreshConcurrency;
        RefreshSourcesUpstreamRefresh? refreshAllRemoteFeeds;
        if (shouldRefreshSources &&
            capabilities.refreshesRemoteSourcesUpstream) {
          final injectedRefresh = _refreshAllRemoteFeeds;
          refreshAllRemoteFeeds = injectedRefresh == null
              ? () async {
                  final client = await RemoteClientFactory(
                    dio: dio,
                    credentials: credentials,
                  ).miniflux(activeAccount);
                  await MinifluxRemoteSubscriptionStructureExecutor(
                    client,
                  ).refreshAllFeeds();
                }
              : () => injectedRefresh(activeAccount);
        }

        final result = shouldRefreshSources
            ? await RefreshSourcesCoordinator(
                capabilities: capabilities,
                feeds: feeds,
                syncService: svc,
                refreshAllRemoteFeeds: refreshAllRemoteFeeds,
              ).refreshSources(
                trigger: RefreshSourcesTrigger.background,
                maxConcurrent: concurrency,
                notify: true,
                feedsOverride: allFeeds,
              )
            : await AccountSyncCoordinator(
                capabilities: capabilities,
                feeds: feeds,
                syncService: svc,
              ).syncAccount(
                trigger: AccountSyncTrigger.background,
                maxConcurrent: concurrency,
                notify: true,
                feedsOverride: allFeeds,
              );
        final err = result.firstError;
        if (err != null) {
          AppLogger.w(
            shouldRefreshSources
                ? 'Background source refresh failed'
                : 'Background account sync failed',
            tag: 'bg',
            error: err,
            stackTrace: result.stackTrace,
          );
        }
      } finally {
        final dbLease = lease;
        if (dbLease != null) {
          await dbLease.release();
        } else {
          await isar.close();
        }
      }
    });
  }

  Future<bool> _shouldRunInterval({
    required String key,
    required Duration minInterval,
    required String failureMessage,
  }) async {
    final now = _nowProvider();
    try {
      final prefs = await _sharedPreferencesLoader();
      final lastMs = prefs.getInt(key);
      if (lastMs != null) {
        final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
        if (now.difference(last) < minInterval) {
          return false;
        }
      }
      // Record attempt early to prevent repeated costly wakeups.
      await prefs.setInt(key, now.millisecondsSinceEpoch);
      return true;
    } catch (e) {
      AppLogger.w(failureMessage, tag: 'bg', error: e);
      return true;
    }
  }

  Future<void> _flushOutboxSafe(Account account, SyncServiceBase svc) async {
    if (!BackendCapabilities.forAccountType(account.type).isOutboxCapable) {
      return;
    }
    final OutboxFlushCapable? flushCapable = switch (svc) {
      OutboxFlushCapable service => service,
      _ => null,
    };
    if (flushCapable == null) return;
    await flushCapable.flushOutboxSafe();
  }
}
