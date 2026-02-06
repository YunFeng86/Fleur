import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../services/rss/feed_parser.dart';
import '../services/rss/rss_client.dart';
import '../services/sync/sync_service.dart';
import '../services/extract/article_extractor.dart';
import '../services/cache/article_cache_service.dart';
import '../services/cache/image_meta_store.dart';
import '../services/cache/favicon_store.dart';
import '../services/notifications/notification_service.dart';
import '../services/network/favicon_service.dart';
import 'repository_providers.dart';
import 'app_settings_providers.dart';

final dioProvider = Provider<Dio>((ref) {
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
});

final rssClientProvider = Provider<RssClient>((ref) {
  return RssClient(ref.watch(dioProvider));
});

final feedParserProvider = Provider<FeedParser>((ref) => FeedParser());

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final feeds = ref.watch(feedRepositoryProvider);
  final categories = ref.watch(categoryRepositoryProvider);
  final articles = ref.watch(articleRepositoryProvider);
  final client = ref.watch(rssClientProvider);
  final parser = ref.watch(feedParserProvider);
  final notifications = ref.watch(notificationServiceProvider);
  return SyncService(
    feeds: feeds,
    categories: categories,
    articles: articles,
    client: client,
    parser: parser,
    notifications: notifications,
    cache: ref.watch(articleCacheServiceProvider),
    appSettingsStore: ref.watch(appSettingsStoreProvider),
  );
});

final articleExtractorProvider = Provider<ArticleExtractor>((ref) {
  return ArticleExtractor(ref.watch(dioProvider));
});

final cacheManagerProvider = Provider<BaseCacheManager>((ref) {
  return CacheManager(
    Config(
      'flutter_reader_images',
      stalePeriod: const Duration(days: 45),
      maxNrOfCacheObjects: 1200,
    ),
  );
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
  return ArticleCacheService(
    ref.watch(cacheManagerProvider),
    ref.watch(imageMetaStoreProvider),
  );
});
