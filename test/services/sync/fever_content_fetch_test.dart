import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/repositories/article_repository.dart';
import 'package:fleur/repositories/category_repository.dart';
import 'package:fleur/repositories/feed_repository.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/accounts/credential_store.dart';
import 'package:fleur/services/cache/article_cache_service.dart';
import 'package:fleur/services/cache/image_meta_store.dart';
import 'package:fleur/services/extract/article_extractor.dart';
import 'package:fleur/services/notifications/notification_service.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/sync/fever/fever_sync_service.dart';
import 'package:fleur/services/sync/outbox/outbox_store.dart';

import '../../test_utils/critical_workflow_test_support.dart';
import '../../test_utils/isar_test_utils.dart';

class _FakeCredentialStore extends CredentialStore {
  @override
  Future<String?> getApiToken(String accountId, AccountType type) async {
    return 'fever-token';
  }

  @override
  Future<({String username, String password})?> getBasicAuth(
    String accountId,
    AccountType type,
  ) async {
    return null;
  }
}

class _MemoryOutboxStore extends OutboxStore {
  @override
  Future<List<OutboxAction>> load(String accountId) async {
    return const <OutboxAction>[];
  }

  @override
  Future<void> save(String accountId, List<OutboxAction> actions) async {}
}

class _NoopNotificationService extends NotificationService {
  @override
  Future<void> showNewArticlesSummaryNotification(
    int count, {
    String? localeTag,
  }) async {}
}

class _UnusedCacheManager extends Fake implements BaseCacheManager {}

class _RecordingArticleCacheService extends ArticleCacheService {
  _RecordingArticleCacheService()
    : super(_UnusedCacheManager(), ImageMetaStore());

  final cachedArticleBatches = <List<Article>>[];
  final prefetchedHtml = <String>[];

  @override
  Future<int> cacheArticles(
    Iterable<Article> articles, {
    int maxConcurrentArticles = 2,
    int maxImagesPerArticle = 24,
  }) async {
    final batch = articles.toList(growable: false);
    cachedArticleBatches.add(batch);
    return batch.length;
  }

  @override
  Future<void> prefetchImagesFromHtml(
    String html, {
    required Uri? baseUrl,
    int maxImages = 24,
    int maxConcurrent = 4,
    bool recordSizes = true,
  }) async {
    prefetchedHtml.add(html);
  }
}

class _FakeArticleExtractor extends ArticleExtractor {
  _FakeArticleExtractor({
    this.html = '<article>extracted</article>',
    this.error,
  }) : super(Dio());

  final String html;
  final Object? error;
  final urls = <String>[];
  final userAgents = <String?>[];

  @override
  Future<ExtractedArticle> extract(String url, {String? userAgent}) async {
    urls.add(url);
    userAgents.add(userAgent);
    final err = error;
    if (err != null) throw err;
    return ExtractedArticle(title: 'Extracted', contentHtml: html);
  }
}

Dio _feverDio({
  String? unreadIds,
  String itemHtml = '<p>feed</p>',
  int feedCount = 1,
  int itemCount = 1,
  List<Map<String, Object?>> groups = const [],
}) {
  final generatedItemIds = List.generate(itemCount, (index) => 100 + index);
  final unreadItemIds = unreadIds ?? generatedItemIds.join(',');
  final feeds = List.generate(feedCount, (index) {
    return <String, Object?>{
      'id': 10 + index,
      'url': feedCount == 1
          ? 'https://example.com/feed.xml'
          : 'https://example.com/feed_$index.xml',
      'title': feedCount == 1 ? 'Example Feed' : 'Example Feed $index',
      'site_url': 'https://example.com',
    };
  });

  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final query = options.uri.query;
        Object? data;

        if (query == 'api&groups') {
          data = <String, Object?>{'auth': 1, 'groups': groups};
        } else if (query == 'api&feeds') {
          data = <String, Object?>{'auth': 1, 'feeds': feeds};
        } else if (query == 'api&feeds&groups') {
          data = <String, Object?>{'auth': 1, 'feeds_groups': const []};
        } else if (query == 'api&unread_item_ids') {
          data = <String, Object?>{'auth': 1, 'unread_item_ids': unreadItemIds};
        } else if (query == 'api&saved_item_ids') {
          data = <String, Object?>{'auth': 1, 'saved_item_ids': ''};
        } else if (query.startsWith('api&items&with_ids=')) {
          final rawIds = Uri.decodeQueryComponent(
            query.substring('api&items&with_ids='.length),
          );
          final requestedIds = rawIds
              .split(',')
              .map((value) => int.tryParse(value.trim()))
              .whereType<int>()
              .toList(growable: false);
          data = <String, Object?>{
            'auth': 1,
            'items': [
              for (final id in requestedIds)
                {
                  'id': id,
                  'feed_id':
                      10 +
                      (generatedItemIds.indexOf(id).clamp(0, feedCount - 1) %
                          feedCount),
                  'url': 'https://example.com/articles/$id',
                  'title': 'Fever Article $id',
                  'author': 'Fever Author',
                  'html': itemHtml,
                  'created_on_time': 1770000000 + id,
                },
            ],
          };
        }

        if (data != null) {
          handler.resolve(
            Response<Object?>(requestOptions: options, data: data),
          );
          return;
        }

        handler.reject(
          DioException(
            requestOptions: options,
            error: 'unexpected Fever request: ${options.method} $query',
          ),
        );
      },
    ),
  );
  return dio;
}

Future<List<Article>> _syncFeverArticles(
  Isar isar, {
  required AppSettings settings,
  required _RecordingArticleCacheService cache,
  required _FakeArticleExtractor extractor,
  Dio? dio,
}) async {
  final service = FeverSyncService(
    account: buildTestAccount(
      type: AccountType.fever,
      baseUrl: 'https://fever.example.com',
    ),
    dio: dio ?? _feverDio(itemHtml: '<p>feed <img src="/feed.png"></p>'),
    credentials: _FakeCredentialStore(),
    feeds: FeedRepository(isar),
    categories: CategoryRepository(isar),
    articles: ArticleRepository(isar),
    outbox: _MemoryOutboxStore(),
    appSettingsStore: FakeAppSettingsStore(settings),
    notifications: _NoopNotificationService(),
    cache: cache,
    extractor: extractor,
  );

  await service.syncNow(notify: false);
  return isar.articles.where().findAll();
}

void main() {
  Isar? isar;
  Directory? tempDir;

  setUpAll(() async {
    await ensureIsarCoreInitialized();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fleur_fever_fetch_');
    isar = await Isar.open(
      [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
      directory: tempDir!.path,
      name: 'fever_content_fetch_test',
    );
  });

  tearDown(() async {
    await isar?.close();
    final dir = tempDir;
    tempDir = null;
    isar = null;
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  test('fetches and stores extracted content for new Fever articles', () async {
    final cache = _RecordingArticleCacheService();
    final extractor = _FakeArticleExtractor(
      html: '<article>readable <img src="/full.png"></article>',
    );

    final articles = await _syncFeverArticles(
      isar!,
      settings: AppSettings.defaults().copyWith(
        syncWebPages: true,
        syncImages: false,
        webUserAgent: 'Fleur Test UA',
      ),
      cache: cache,
      extractor: extractor,
    );

    expect(extractor.urls, ['https://example.com/articles/100']);
    expect(extractor.userAgents, ['Fleur Test UA']);
    expect(articles.single.extractedContentHtml, contains('readable'));
    expect(articles.single.contentSource, ContentSource.extracted);
    expect(cache.cachedArticleBatches, isEmpty);
    expect(cache.prefetchedHtml, isEmpty);
  });

  test('caches feed HTML images when syncImages is enabled', () async {
    final cache = _RecordingArticleCacheService();
    final extractor = _FakeArticleExtractor();

    final articles = await _syncFeverArticles(
      isar!,
      settings: AppSettings.defaults().copyWith(
        syncWebPages: false,
        syncImages: true,
      ),
      cache: cache,
      extractor: extractor,
    );

    expect(extractor.urls, isEmpty);
    expect(cache.cachedArticleBatches, hasLength(1));
    expect(cache.cachedArticleBatches.single.single.id, articles.single.id);
    expect(
      cache.cachedArticleBatches.single.single.contentHtml,
      contains('/feed.png'),
    );
    expect(cache.prefetchedHtml, isEmpty);
  });

  test('skips non-finite Fever group ids during sync', () async {
    final cache = _RecordingArticleCacheService();
    final extractor = _FakeArticleExtractor();

    final articles = await _syncFeverArticles(
      isar!,
      settings: AppSettings.defaults().copyWith(
        syncWebPages: false,
        syncImages: false,
      ),
      cache: cache,
      extractor: extractor,
      dio: _feverDio(
        groups: [
          {'id': double.infinity, 'title': 'Invalid Group'},
        ],
      ),
    );

    expect(articles, hasLength(1));
    expect(await CategoryRepository(isar!).getByRemoteId('Infinity'), isNull);
  });

  test(
    'prefetches extracted HTML images when both toggles are enabled',
    () async {
      final cache = _RecordingArticleCacheService();
      final extractor = _FakeArticleExtractor(
        html: '<article>full <img src="/full.png"></article>',
      );

      await _syncFeverArticles(
        isar!,
        settings: AppSettings.defaults().copyWith(
          syncWebPages: true,
          syncImages: true,
        ),
        cache: cache,
        extractor: extractor,
      );

      expect(cache.cachedArticleBatches, hasLength(1));
      expect(cache.prefetchedHtml, hasLength(1));
      expect(cache.prefetchedHtml.single, contains('/full.png'));
    },
  );

  test('limits web page extraction across the whole Fever sync', () async {
    final cache = _RecordingArticleCacheService();
    final extractor = _FakeArticleExtractor(
      html: '<article>full <img src="/full.png"></article>',
    );

    final articles = await _syncFeverArticles(
      isar!,
      settings: AppSettings.defaults().copyWith(
        syncWebPages: true,
        syncImages: false,
      ),
      cache: cache,
      extractor: extractor,
      dio: _feverDio(
        feedCount: 10,
        itemCount: 12,
        itemHtml: '<p>feed <img src="/feed.png"></p>',
      ),
    );

    expect(articles, hasLength(12));
    expect(extractor.urls, hasLength(8));
    expect(
      articles.where((article) => article.extractedContentHtml != null),
      hasLength(8),
    );
  });

  test('does not call extractor when syncWebPages is disabled', () async {
    final cache = _RecordingArticleCacheService();
    final extractor = _FakeArticleExtractor();

    final articles = await _syncFeverArticles(
      isar!,
      settings: AppSettings.defaults().copyWith(
        syncWebPages: false,
        syncImages: false,
      ),
      cache: cache,
      extractor: extractor,
    );

    expect(extractor.urls, isEmpty);
    expect(articles.single.extractedContentHtml, isNull);
    expect(articles.single.contentSource, ContentSource.feed);
  });

  test(
    'marks extraction failed when extractor returns empty content',
    () async {
      final cache = _RecordingArticleCacheService();
      final extractor = _FakeArticleExtractor(html: '   ');

      final articles = await _syncFeverArticles(
        isar!,
        settings: AppSettings.defaults().copyWith(
          syncWebPages: true,
          syncImages: false,
        ),
        cache: cache,
        extractor: extractor,
      );

      expect(articles.single.extractedContentHtml, isNull);
      expect(articles.single.contentSource, ContentSource.extractionFailed);
    },
  );

  test('swallows extraction errors without failing sync', () async {
    final cache = _RecordingArticleCacheService();
    final extractor = _FakeArticleExtractor(error: StateError('network'));

    final articles = await _syncFeverArticles(
      isar!,
      settings: AppSettings.defaults().copyWith(
        syncWebPages: true,
        syncImages: false,
      ),
      cache: cache,
      extractor: extractor,
    );

    expect(extractor.urls, ['https://example.com/articles/100']);
    expect(articles.single.extractedContentHtml, isNull);
    expect(articles.single.contentSource, ContentSource.feed);
  });
}
