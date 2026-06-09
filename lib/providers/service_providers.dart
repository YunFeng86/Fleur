import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'account_providers.dart';
import '../services/accounts/account.dart';
import '../services/accounts/credential_store.dart';
import '../services/rss/feed_parser.dart';
import '../services/rss/feed_discovery_service.dart';
import '../services/rss/rss_client.dart';
import '../services/sync/sync_service.dart';
import '../services/sync/miniflux/miniflux_sync_service.dart';
import '../services/sync/fever/fever_sync_service.dart';
import '../services/sync/google_reader/google_reader_sync_service.dart';
import '../services/sync/outbox/outbox_store.dart';
import '../services/sync/remote_client_factory.dart';
import '../services/sync/sync_status_reporter.dart';
import 'sync_status_providers.dart';
import '../services/actions/article_action_service.dart';
import '../services/extract/article_extractor.dart';
import '../services/ai/ai_request_queue.dart';
import '../services/ai/ai_service_client.dart';
import '../services/cache/article_cache_service.dart';
import '../services/cache/ai_content_cache_store.dart';
import '../services/cache/image_meta_store.dart';
import '../services/cache/favicon_store.dart';
import '../services/notifications/notification_service.dart';
import '../services/network/favicon_service.dart';
import '../services/settings/app_settings_store.dart';
import '../services/translation/translation_service.dart';
import '../repositories/article_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/feed_repository.dart';
import 'repository_providers.dart';
import 'app_settings_providers.dart';

Dio createAppDio() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 10),
      followRedirects: true,
      maxRedirects: 5,
    ),
  );
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true,
      ),
    );
  }
  return dio;
}

RssClient createRssClient(Dio dio) => RssClient(dio);

FeedParser createFeedParser() => FeedParser();

CredentialStore createCredentialStore() => CredentialStore();

NotificationService createNotificationService() => NotificationService();

BaseCacheManager createArticleCacheManager() {
  return CacheManager(
    Config(
      'fleur_images',
      stalePeriod: const Duration(days: 45),
      maxNrOfCacheObjects: 1200,
    ),
  );
}

ArticleCacheService createArticleCacheService({
  BaseCacheManager? cacheManager,
  ImageMetaStore? imageMetaStore,
}) {
  return ArticleCacheService(
    cacheManager ?? createArticleCacheManager(),
    imageMetaStore ?? ImageMetaStore(),
  );
}

ArticleExtractor createArticleExtractor({required Dio dio}) {
  return ArticleExtractor(dio);
}

SyncServiceBase buildSyncServiceForAccount({
  required Account account,
  required FeedRepository feeds,
  required CategoryRepository categories,
  required ArticleRepository articles,
  required OutboxStore outbox,
  required AppSettingsStore appSettingsStore,
  required Dio dio,
  required CredentialStore credentials,
  required NotificationService notifications,
  required ArticleCacheService cache,
  required ArticleExtractor extractor,
  SyncStatusReporter? statusReporter,
}) {
  switch (account.type) {
    case AccountType.local:
      return SyncService(
        feeds: feeds,
        categories: categories,
        articles: articles,
        client: createRssClient(dio),
        parser: createFeedParser(),
        notifications: notifications,
        cache: cache,
        extractor: extractor,
        appSettingsStore: appSettingsStore,
        statusReporter: statusReporter,
      );
    case AccountType.miniflux:
      return MinifluxSyncService(
        account: account,
        dio: dio,
        credentials: credentials,
        feeds: feeds,
        categories: categories,
        articles: articles,
        outbox: outbox,
        appSettingsStore: appSettingsStore,
        cache: cache,
        extractor: extractor,
        statusReporter: statusReporter,
      );
    case AccountType.fever:
      return FeverSyncService(
        account: account,
        dio: dio,
        credentials: credentials,
        feeds: feeds,
        categories: categories,
        articles: articles,
        outbox: outbox,
        appSettingsStore: appSettingsStore,
        notifications: notifications,
        cache: cache,
        extractor: extractor,
        statusReporter: statusReporter,
      );
    case AccountType.googleReader:
      return GoogleReaderSyncService(
        account: account,
        dio: dio,
        credentials: credentials,
        feeds: feeds,
        categories: categories,
        articles: articles,
        outbox: outbox,
        appSettingsStore: appSettingsStore,
        cache: cache,
        statusReporter: statusReporter,
      );
  }
}

final dioProvider = Provider<Dio>((ref) => createAppDio());

final remoteClientFactoryProvider = Provider<RemoteClientFactory>((ref) {
  return RemoteClientFactory(
    dio: ref.watch(dioProvider),
    credentials: ref.watch(credentialStoreProvider),
  );
}, dependencies: [dioProvider, credentialStoreProvider]);

final rssClientProvider = Provider<RssClient>((ref) {
  return createRssClient(ref.watch(dioProvider));
});

final feedParserProvider = Provider<FeedParser>((ref) => createFeedParser());

final feedDiscoveryServiceProvider = Provider<FeedDiscoveryService>((ref) {
  return FeedDiscoveryService(
    ref.watch(dioProvider),
    parser: ref.watch(feedParserProvider),
  );
}, dependencies: [dioProvider, feedParserProvider]);

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return createNotificationService();
});

final outboxStoreProvider = Provider<OutboxStore>((ref) => OutboxStore());

final syncServiceProvider = Provider<SyncServiceBase>(
  (ref) {
    final account = ref.watch(activeAccountProvider);
    final feeds = ref.watch(feedRepositoryProvider);
    final categories = ref.watch(categoryRepositoryProvider);
    final articles = ref.watch(articleRepositoryProvider);
    final reporter = ref.watch(syncStatusReporterProvider);
    return buildSyncServiceForAccount(
      account: account,
      feeds: feeds,
      categories: categories,
      articles: articles,
      outbox: ref.watch(outboxStoreProvider),
      appSettingsStore: ref.watch(appSettingsStoreProvider),
      dio: ref.watch(dioProvider),
      credentials: ref.watch(credentialStoreProvider),
      notifications: ref.watch(notificationServiceProvider),
      cache: ref.watch(articleCacheServiceProvider),
      extractor: ref.watch(articleExtractorProvider),
      statusReporter: reporter,
    );
  },
  dependencies: [
    activeAccountProvider,
    feedRepositoryProvider,
    categoryRepositoryProvider,
    articleRepositoryProvider,
    notificationServiceProvider,
    articleCacheServiceProvider,
    articleExtractorProvider,
    appSettingsStoreProvider,
    dioProvider,
    credentialStoreProvider,
    outboxStoreProvider,
    syncStatusReporterProvider,
  ],
);

final articleExtractorProvider = Provider<ArticleExtractor>((ref) {
  return createArticleExtractor(dio: ref.watch(dioProvider));
});

final aiRequestQueueProvider = Provider<AiRequestQueue>((ref) {
  return AiRequestQueue(maxConcurrent: 2);
});

final aiServiceClientProvider = Provider<AiServiceClient>((ref) {
  return AiServiceClient(dio: ref.watch(dioProvider));
}, dependencies: [dioProvider]);

final translationServiceProvider = Provider<TranslationService>((ref) {
  return TranslationService(dio: ref.watch(dioProvider));
}, dependencies: [dioProvider]);

final aiContentCacheStoreProvider = Provider<AiContentCacheStore>((ref) {
  return AiContentCacheStore();
});

final cacheManagerProvider = Provider<BaseCacheManager>((ref) {
  return createArticleCacheManager();
});

final faviconStoreProvider = Provider<FaviconStore>((ref) {
  return FaviconStore();
});

final faviconServiceProvider = Provider<FaviconService>((ref) {
  return FaviconService(
    dio: ref.watch(dioProvider),
    store: ref.watch(faviconStoreProvider),
  );
});

final imageMetaStoreProvider = Provider<ImageMetaStore>((ref) {
  return ImageMetaStore();
});

final articleCacheServiceProvider = Provider<ArticleCacheService>((ref) {
  return createArticleCacheService(
    cacheManager: ref.watch(cacheManagerProvider),
    imageMetaStore: ref.watch(imageMetaStoreProvider),
  );
});

final articleActionServiceProvider = Provider<ArticleActionService>(
  (ref) {
    return ArticleActionService(
      account: ref.watch(activeAccountProvider),
      articles: ref.watch(articleRepositoryProvider),
      feeds: ref.watch(feedRepositoryProvider),
      categories: ref.watch(categoryRepositoryProvider),
      dio: ref.watch(dioProvider),
      credentials: ref.watch(credentialStoreProvider),
      outbox: ref.watch(outboxStoreProvider),
    );
  },
  dependencies: [
    activeAccountProvider,
    articleRepositoryProvider,
    feedRepositoryProvider,
    categoryRepositoryProvider,
    dioProvider,
    credentialStoreProvider,
    outboxStoreProvider,
  ],
);
