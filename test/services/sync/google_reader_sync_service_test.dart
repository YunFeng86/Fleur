import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

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
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/sync/google_reader/google_reader_sync_service.dart';
import 'package:fleur/services/sync/outbox/outbox_store.dart';
import 'package:fleur/services/sync/remote_article_action_executor.dart';

import '../../test_utils/critical_workflow_test_support.dart';
import '../../test_utils/isar_test_utils.dart';

void main() {
  Isar? isar;
  Directory? tempDir;

  setUpAll(() async {
    await ensureIsarCoreInitialized();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'fleur_google_reader_sync_',
    );
    isar = await Isar.open(
      [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
      directory: tempDir!.path,
      name: 'google_reader_sync_service_test',
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

  test(
    'syncNow mirrors subscriptions and imports read/star item state',
    () async {
      final requests = <_RecordedRequest>[];
      final service = GoogleReaderSyncService(
        account: buildTestAccount(
          type: AccountType.googleReader,
          baseUrl: 'https://reader.example.com',
        ),
        dio: _googleReaderDio(requests),
        credentials: _FakeCredentialStore(),
        feeds: FeedRepository(isar!),
        categories: CategoryRepository(isar!),
        articles: ArticleRepository(isar!),
        outbox: _MemoryOutboxStore(),
        appSettingsStore: FakeAppSettingsStore(
          AppSettings.defaults().copyWith(remoteEntriesLimit: 10),
        ),
        cache: _unusedCache(),
      );

      final results = await service.syncNow();

      expect(results.single.feedId, -1);
      expect(results.single.incomingCount, 1);
      expect(results.single.newCount, 1);

      final feed = await FeedRepository(
        isar!,
      ).getByRemoteId('feed/https://example.com/feed.xml');
      final category = await CategoryRepository(
        isar!,
      ).getByRemoteId('user/-/label/Tech');
      final articles = await isar!.articles.where().findAll();

      expect(feed, isNotNull);
      expect(feed?.title, 'Example Feed');
      expect(feed?.url, 'https://example.com/feed.xml');
      expect(feed?.categoryId, category?.id);
      expect(category?.name, 'Tech');

      expect(articles, hasLength(1));
      final article = articles.single;
      expect(article.feedId, feed?.id);
      expect(article.categoryId, category?.id);
      expect(article.remoteId, 'tag:reader.example,2026:item/0001');
      expect(article.link, 'https://example.com/posts/one');
      expect(article.title, 'First item');
      expect(article.contentHtml, '<p>Hello</p>');
      expect(article.isRead, isTrue);
      expect(article.isStarred, isTrue);
      expect(article.publishedAt.millisecondsSinceEpoch, 1700000000 * 1000);

      expect(requests.map((request) => '${request.method} ${request.path}'), [
        'GET /reader/api/0/subscription/list',
        'GET /reader/api/0/stream/items/ids',
        'GET /reader/api/0/token',
        'POST /reader/api/0/stream/items/contents',
      ]);
      expect(
        requests[1].queryParameters['s'],
        GoogleReaderRemoteArticleActionExecutor.readingListState,
      );
    },
  );

  test('refreshFeedSafe uses the feed stream id for scoped refresh', () async {
    final requests = <_RecordedRequest>[];
    final service = GoogleReaderSyncService(
      account: buildTestAccount(
        type: AccountType.googleReader,
        baseUrl: 'https://reader.example.com',
      ),
      dio: _googleReaderDio(requests),
      credentials: _FakeCredentialStore(),
      feeds: FeedRepository(isar!),
      categories: CategoryRepository(isar!),
      articles: ArticleRepository(isar!),
      outbox: _MemoryOutboxStore(),
      appSettingsStore: FakeAppSettingsStore(
        AppSettings.defaults().copyWith(remoteEntriesLimit: 10),
      ),
      cache: _unusedCache(),
    );

    await service.syncNow();
    final feed = await FeedRepository(
      isar!,
    ).getByRemoteId('feed/https://example.com/feed.xml');
    requests.clear();

    final result = await service.refreshFeedSafe(feed!.id);

    expect(result.feedId, feed.id);
    expect(result.incomingCount, 1);
    expect(result.newCount, 0);
    final idsRequest = requests.firstWhere(
      (request) => request.path == '/reader/api/0/stream/items/ids',
    );
    expect(
      idsRequest.queryParameters['s'],
      'feed/https://example.com/feed.xml',
    );
  });
}

Dio _googleReaderDio(List<_RecordedRequest> requests) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(_RecordedRequest.fromOptions(options));
        final data = switch ((options.method, options.uri.path)) {
          ('GET', '/reader/api/0/subscription/list') => {
            'subscriptions': [
              {
                'id': 'feed/https://example.com/feed.xml',
                'url': 'https://example.com/feed.xml',
                'title': 'Example Feed',
                'htmlUrl': 'https://example.com',
                'categories': [
                  {'id': 'user/-/label/Tech', 'label': 'Tech'},
                ],
              },
            ],
          },
          ('GET', '/reader/api/0/stream/items/ids') => {
            'itemRefs': [
              {'id': 'tag:reader.example,2026:item/0001'},
            ],
          },
          ('GET', '/reader/api/0/token') => 'write-token',
          ('POST', '/reader/api/0/stream/items/contents') => {
            'items': [
              {
                'id': 'tag:reader.example,2026:item/0001',
                'title': 'First item',
                'author': 'Author',
                'published': 1700000000,
                'alternate': [
                  {'href': 'https://example.com/posts/one'},
                ],
                'content': {'content': '<p>Hello</p>'},
                'origin': {
                  'streamId': 'feed/https://example.com/feed.xml',
                  'title': 'Example Feed',
                  'htmlUrl': 'https://example.com',
                },
                'categories': [
                  'user/123/state/com.google/read',
                  'user/123/state/com.google/starred',
                ],
              },
            ],
          },
          _ => throw StateError(
            'Unexpected request: ${options.method} ${options.uri}',
          ),
        };
        handler.resolve(Response<Object?>(requestOptions: options, data: data));
      },
    ),
  );
  return dio;
}

ArticleCacheService _unusedCache() {
  return ArticleCacheService(_UnusedCacheManager(), ImageMetaStore());
}

class _FakeCredentialStore extends CredentialStore {
  @override
  Future<String?> getApiToken(String accountId, AccountType type) async {
    return 'auth-token';
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

class _UnusedCacheManager extends Fake implements BaseCacheManager {}

class _RecordedRequest {
  _RecordedRequest({
    required this.method,
    required this.path,
    required this.queryParameters,
    required this.data,
  });

  factory _RecordedRequest.fromOptions(RequestOptions options) {
    return _RecordedRequest(
      method: options.method,
      path: options.uri.path,
      queryParameters: Map<String, String>.from(options.uri.queryParameters),
      data: options.data,
    );
  }

  final String method;
  final String path;
  final Map<String, String> queryParameters;
  final Object? data;
}
