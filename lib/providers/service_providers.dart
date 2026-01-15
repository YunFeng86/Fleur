import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/rss/feed_parser.dart';
import '../services/rss/rss_client.dart';
import '../services/sync/sync_service.dart';
import '../services/extract/article_extractor.dart';
import 'repository_providers.dart';

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

final syncServiceProvider = Provider<SyncService>((ref) {
  final feeds = ref.watch(feedRepositoryProvider);
  final articles = ref.watch(articleRepositoryProvider);
  final client = ref.watch(rssClientProvider);
  final parser = ref.watch(feedParserProvider);
  return SyncService(feeds: feeds, articles: articles, client: client, parser: parser);
});

final articleExtractorProvider = Provider<ArticleExtractor>((ref) {
  return ArticleExtractor(ref.watch(dioProvider));
});
