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
import 'package:fleur/services/sync/miniflux/miniflux_sync_service.dart';
import 'package:fleur/services/sync/outbox/outbox_store.dart';

import '../../test_utils/critical_workflow_test_support.dart';
import '../../test_utils/isar_test_utils.dart';

class _FakeCredentialStore extends CredentialStore {
  @override
  Future<String?> getApiToken(String accountId, AccountType type) async {
    return 'remote-token';
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

ArticleCacheService _unusedCache() {
  return ArticleCacheService(_UnusedCacheManager(), ImageMetaStore());
}

AppSettings _subscriptionsOnlySettings() {
  return AppSettings.defaults().copyWith(remoteEntriesLimit: -1);
}

Dio _minifluxDio({
  required List<Map<String, Object?>> Function() categories,
  required List<Map<String, Object?>> Function() feeds,
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        Object? data;
        if (options.method == 'GET' && options.uri.path == '/v1/categories') {
          data = categories();
        } else if (options.method == 'GET' && options.uri.path == '/v1/feeds') {
          data = feeds();
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
            error:
                'unexpected Miniflux request: ${options.method} ${options.uri.path}',
          ),
        );
      },
    ),
  );
  return dio;
}

Dio _feverDio({
  required List<Map<String, Object?>> Function() groups,
  required List<Map<String, Object?>> Function() feeds,
  required List<Map<String, Object?>> Function() feedsGroups,
  bool Function()? failFeedsGroups,
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final query = options.uri.query;
        Object? data;
        if (query == 'api&groups') {
          data = <String, Object?>{'auth': 1, 'groups': groups()};
        } else if (query == 'api&feeds') {
          data = <String, Object?>{'auth': 1, 'feeds': feeds()};
        } else if (query == 'api&feeds&groups') {
          if (failFeedsGroups?.call() == true) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: const SocketException('offline'),
              ),
            );
            return;
          }
          data = <String, Object?>{'auth': 1, 'feeds_groups': feedsGroups()};
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

Future<void> _seedArticle(
  Isar isar, {
  required int feedId,
  int? categoryId,
  required String link,
}) {
  final now = DateTime.utc(2026, 3, 1);
  return isar.writeTxn(() async {
    await isar.articles.put(
      Article()
        ..feedId = feedId
        ..categoryId = categoryId
        ..link = link
        ..title = 'Seed'
        ..publishedAt = now
        ..fetchedAt = now
        ..updatedAt = now,
    );
  });
}

Future<void> _seedRemoteCategory(
  Isar isar, {
  required int id,
  required String remoteId,
  required String name,
}) {
  final now = DateTime.utc(2026, 3, 1);
  return isar.writeTxn(() async {
    await isar.categorys.put(
      Category()
        ..id = id
        ..remoteId = remoteId
        ..name = name
        ..createdAt = now
        ..updatedAt = now,
    );
  });
}

Future<void> _seedRemoteFeed(
  Isar isar, {
  required int id,
  required String remoteId,
  required String url,
  required String title,
  int? categoryId,
}) {
  final now = DateTime.utc(2026, 3, 1);
  return isar.writeTxn(() async {
    await isar.feeds.put(
      Feed()
        ..id = id
        ..remoteId = remoteId
        ..url = url
        ..title = title
        ..categoryId = categoryId
        ..createdAt = now
        ..updatedAt = now,
    );
  });
}

void main() {
  Isar? isar;
  Directory? tempDir;

  setUpAll(() async {
    await ensureIsarCoreInitialized();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'fleur_remote_subscription_mirror_',
    );
    isar = await Isar.open(
      [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
      directory: tempDir!.path,
      name: 'remote_subscription_mirror_test',
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
    'Miniflux sync keeps remote identities and prunes missing mirrors',
    () async {
      var categories = <Map<String, Object?>>[
        {'id': 1, 'title': 'Old Category'},
        {'id': 2, 'title': 'Removed Category'},
      ];
      var feeds = <Map<String, Object?>>[
        {
          'id': 10,
          'feed_url': 'https://example.com/old.xml',
          'title': 'Old Feed',
          'site_url': 'https://example.com',
          'description': 'old description',
          'category': {'id': 1, 'title': 'Old Category'},
        },
        {
          'id': 11,
          'feed_url': 'https://example.com/removed.xml',
          'title': 'Removed Feed',
          'category': {'id': 2, 'title': 'Removed Category'},
        },
      ];

      final service = MinifluxSyncService(
        account: buildTestAccount(
          type: AccountType.miniflux,
          baseUrl: 'https://miniflux.example.com',
        ),
        dio: _minifluxDio(categories: () => categories, feeds: () => feeds),
        credentials: _FakeCredentialStore(),
        feeds: FeedRepository(isar!),
        categories: CategoryRepository(isar!),
        articles: ArticleRepository(isar!),
        outbox: _MemoryOutboxStore(),
        appSettingsStore: FakeAppSettingsStore(_subscriptionsOnlySettings()),
        cache: _unusedCache(),
        extractor: ArticleExtractor(Dio()),
      );

      await service.syncNow();
      final firstFeed = await FeedRepository(isar!).getByRemoteId('10');
      final firstRemovedFeed = await FeedRepository(isar!).getByRemoteId('11');
      final firstCategory = await CategoryRepository(isar!).getByRemoteId('1');
      expect(firstFeed, isNotNull);
      expect(firstRemovedFeed, isNotNull);
      expect(firstCategory, isNotNull);

      await _seedArticle(
        isar!,
        feedId: firstFeed!.id,
        categoryId: firstCategory!.id,
        link: 'https://example.com/articles/kept',
      );
      await _seedArticle(
        isar!,
        feedId: firstRemovedFeed!.id,
        categoryId: firstRemovedFeed.categoryId,
        link: 'https://example.com/articles/removed',
      );

      categories = <Map<String, Object?>>[
        {'id': 1, 'title': 'Renamed Category'},
      ];
      feeds = <Map<String, Object?>>[
        {
          'id': 10,
          'feed_url': 'https://example.com/new.xml',
          'title': 'Renamed Feed',
          'site_url': 'https://renamed.example.com',
          'description': 'new description',
          'category': {'id': 1, 'title': 'Renamed Category'},
        },
      ];

      await service.syncNow();

      final updatedFeed = await FeedRepository(isar!).getByRemoteId('10');
      final updatedCategory = await CategoryRepository(
        isar!,
      ).getByRemoteId('1');
      final removedFeed = await FeedRepository(isar!).getByRemoteId('11');
      final removedCategory = await CategoryRepository(
        isar!,
      ).getByRemoteId('2');
      final articles = await isar!.articles.where().findAll();

      expect(updatedFeed?.id, firstFeed.id);
      expect(updatedFeed?.url, 'https://example.com/new.xml');
      expect(updatedFeed?.title, 'Renamed Feed');
      expect(updatedFeed?.categoryId, updatedCategory?.id);
      expect(updatedCategory?.id, firstCategory.id);
      expect(updatedCategory?.name, 'Renamed Category');
      expect(removedFeed, isNull);
      expect(removedCategory, isNull);
      expect(articles, hasLength(1));
      expect(articles.single.feedId, firstFeed.id);
      expect(articles.single.categoryId, firstCategory.id);
    },
  );

  test(
    'Fever sync keeps remote identities and prunes missing mirrors',
    () async {
      var groups = <Map<String, Object?>>[
        {'id': 1, 'title': 'Old Group'},
        {'id': 2, 'title': 'Removed Group'},
      ];
      var feeds = <Map<String, Object?>>[
        {
          'id': 10,
          'url': 'https://example.com/old.xml',
          'title': 'Old Feed',
          'site_url': 'https://example.com',
        },
        {
          'id': 11,
          'url': 'https://example.com/removed.xml',
          'title': 'Removed Feed',
        },
      ];
      var feedsGroups = <Map<String, Object?>>[
        {'group_id': 1, 'feed_ids': '10'},
        {'group_id': 2, 'feed_ids': '11'},
      ];

      final service = FeverSyncService(
        account: buildTestAccount(
          type: AccountType.fever,
          baseUrl: 'https://fever.example.com',
        ),
        dio: _feverDio(
          groups: () => groups,
          feeds: () => feeds,
          feedsGroups: () => feedsGroups,
        ),
        credentials: _FakeCredentialStore(),
        feeds: FeedRepository(isar!),
        categories: CategoryRepository(isar!),
        articles: ArticleRepository(isar!),
        outbox: _MemoryOutboxStore(),
        appSettingsStore: FakeAppSettingsStore(_subscriptionsOnlySettings()),
        notifications: _NoopNotificationService(),
        cache: _unusedCache(),
        extractor: ArticleExtractor(Dio()),
      );

      await service.syncNow(notify: false);
      final firstFeed = await FeedRepository(isar!).getByRemoteId('10');
      final firstRemovedFeed = await FeedRepository(isar!).getByRemoteId('11');
      final firstCategory = await CategoryRepository(isar!).getByRemoteId('1');
      expect(firstFeed, isNotNull);
      expect(firstRemovedFeed, isNotNull);
      expect(firstCategory, isNotNull);

      await _seedArticle(
        isar!,
        feedId: firstFeed!.id,
        categoryId: firstCategory!.id,
        link: 'https://example.com/articles/kept',
      );
      await _seedArticle(
        isar!,
        feedId: firstRemovedFeed!.id,
        categoryId: firstRemovedFeed.categoryId,
        link: 'https://example.com/articles/removed',
      );

      groups = <Map<String, Object?>>[
        {'id': 1, 'title': 'Renamed Group'},
      ];
      feeds = <Map<String, Object?>>[
        {
          'id': 10,
          'url': 'https://example.com/new.xml',
          'title': 'Renamed Feed',
          'site_url': 'https://renamed.example.com',
        },
      ];
      feedsGroups = <Map<String, Object?>>[
        {'group_id': 1, 'feed_ids': '10'},
      ];

      await service.syncNow(notify: false);

      final updatedFeed = await FeedRepository(isar!).getByRemoteId('10');
      final updatedCategory = await CategoryRepository(
        isar!,
      ).getByRemoteId('1');
      final removedFeed = await FeedRepository(isar!).getByRemoteId('11');
      final removedCategory = await CategoryRepository(
        isar!,
      ).getByRemoteId('2');
      final articles = await isar!.articles.where().findAll();

      expect(updatedFeed?.id, firstFeed.id);
      expect(updatedFeed?.url, 'https://example.com/new.xml');
      expect(updatedFeed?.title, 'Renamed Feed');
      expect(updatedFeed?.categoryId, updatedCategory?.id);
      expect(updatedCategory?.id, firstCategory.id);
      expect(updatedCategory?.name, 'Renamed Group');
      expect(removedFeed, isNull);
      expect(removedCategory, isNull);
      expect(articles, hasLength(1));
      expect(articles.single.feedId, firstFeed.id);
      expect(articles.single.categoryId, firstCategory.id);
    },
  );

  test(
    'Miniflux sync skips feed prune when remote feed list is empty',
    () async {
      var categories = <Map<String, Object?>>[
        {'id': 1, 'title': 'Category'},
      ];
      var feeds = <Map<String, Object?>>[
        {
          'id': 10,
          'feed_url': 'https://example.com/feed.xml',
          'title': 'Feed',
          'category': {'id': 1, 'title': 'Category'},
        },
      ];

      final service = MinifluxSyncService(
        account: buildTestAccount(
          type: AccountType.miniflux,
          baseUrl: 'https://miniflux.example.com',
        ),
        dio: _minifluxDio(categories: () => categories, feeds: () => feeds),
        credentials: _FakeCredentialStore(),
        feeds: FeedRepository(isar!),
        categories: CategoryRepository(isar!),
        articles: ArticleRepository(isar!),
        outbox: _MemoryOutboxStore(),
        appSettingsStore: FakeAppSettingsStore(_subscriptionsOnlySettings()),
        cache: _unusedCache(),
        extractor: ArticleExtractor(Dio()),
      );

      await service.syncNow();
      final firstFeed = await FeedRepository(isar!).getByRemoteId('10');
      final firstCategory = await CategoryRepository(isar!).getByRemoteId('1');
      expect(firstFeed, isNotNull);
      expect(firstCategory, isNotNull);

      await _seedArticle(
        isar!,
        feedId: firstFeed!.id,
        categoryId: firstCategory!.id,
        link: 'https://example.com/articles/kept',
      );

      categories = <Map<String, Object?>>[
        {'id': 1, 'title': 'Category'},
      ];
      feeds = const <Map<String, Object?>>[];

      await service.syncNow();

      final keptFeed = await FeedRepository(isar!).getByRemoteId('10');
      final articles = await isar!.articles.where().findAll();

      expect(keptFeed, isNotNull);
      expect(keptFeed?.categoryId, firstCategory.id);
      expect(articles, hasLength(1));
      expect(articles.single.feedId, firstFeed.id);
      expect(articles.single.categoryId, firstCategory.id);
    },
  );

  test(
    'Miniflux sync preserves categories when category list is empty',
    () async {
      var categories = <Map<String, Object?>>[
        {'id': 1, 'title': 'Category'},
      ];
      var feeds = <Map<String, Object?>>[
        {
          'id': 10,
          'feed_url': 'https://example.com/feed.xml',
          'title': 'Feed',
          'category': {'id': 1, 'title': 'Category'},
        },
      ];

      final service = MinifluxSyncService(
        account: buildTestAccount(
          type: AccountType.miniflux,
          baseUrl: 'https://miniflux.example.com',
        ),
        dio: _minifluxDio(categories: () => categories, feeds: () => feeds),
        credentials: _FakeCredentialStore(),
        feeds: FeedRepository(isar!),
        categories: CategoryRepository(isar!),
        articles: ArticleRepository(isar!),
        outbox: _MemoryOutboxStore(),
        appSettingsStore: FakeAppSettingsStore(_subscriptionsOnlySettings()),
        cache: _unusedCache(),
        extractor: ArticleExtractor(Dio()),
      );

      await service.syncNow();
      final firstFeed = await FeedRepository(isar!).getByRemoteId('10');
      final firstCategory = await CategoryRepository(isar!).getByRemoteId('1');
      expect(firstFeed, isNotNull);
      expect(firstCategory, isNotNull);

      await _seedArticle(
        isar!,
        feedId: firstFeed!.id,
        categoryId: firstCategory!.id,
        link: 'https://example.com/articles/kept',
      );

      categories = const <Map<String, Object?>>[];
      feeds = <Map<String, Object?>>[
        {
          'id': 10,
          'feed_url': 'https://example.com/feed.xml',
          'title': 'Updated Feed',
          'category_id': 1,
        },
      ];

      await service.syncNow();

      final updatedFeed = await FeedRepository(isar!).getByRemoteId('10');
      final keptCategory = await CategoryRepository(isar!).getByRemoteId('1');
      final articles = await isar!.articles.where().findAll();

      expect(keptCategory, isNotNull);
      expect(updatedFeed?.title, 'Updated Feed');
      expect(updatedFeed?.categoryId, firstCategory.id);
      expect(articles, hasLength(1));
      expect(articles.single.categoryId, firstCategory.id);
    },
  );

  test('Miniflux sync protects feed when remote id conflicts on url', () async {
    var categories = <Map<String, Object?>>[
      {'id': 1, 'title': 'Category'},
    ];
    var feeds = <Map<String, Object?>>[
      {
        'id': 77,
        'feed_url': 'https://example.com/feed.xml/',
        'title': 'Original Feed',
        'category': {'id': 1, 'title': 'Category'},
      },
      {
        'id': 88,
        'feed_url': 'https://example.com/removed.xml',
        'title': 'Removed Feed',
        'category': {'id': 1, 'title': 'Category'},
      },
    ];

    final service = MinifluxSyncService(
      account: buildTestAccount(
        type: AccountType.miniflux,
        baseUrl: 'https://miniflux.example.com',
      ),
      dio: _minifluxDio(categories: () => categories, feeds: () => feeds),
      credentials: _FakeCredentialStore(),
      feeds: FeedRepository(isar!),
      categories: CategoryRepository(isar!),
      articles: ArticleRepository(isar!),
      outbox: _MemoryOutboxStore(),
      appSettingsStore: FakeAppSettingsStore(_subscriptionsOnlySettings()),
      cache: _unusedCache(),
      extractor: ArticleExtractor(Dio()),
    );

    await service.syncNow();
    final originalFeed = await FeedRepository(isar!).getByRemoteId('77');
    final removedFeed = await FeedRepository(isar!).getByRemoteId('88');
    final category = await CategoryRepository(isar!).getByRemoteId('1');
    expect(originalFeed, isNotNull);
    expect(removedFeed, isNotNull);
    expect(category, isNotNull);

    await _seedArticle(
      isar!,
      feedId: originalFeed!.id,
      categoryId: category!.id,
      link: 'https://example.com/articles/kept',
    );
    await _seedArticle(
      isar!,
      feedId: removedFeed!.id,
      categoryId: category.id,
      link: 'https://example.com/articles/removed',
    );

    feeds = <Map<String, Object?>>[
      {
        'id': 91,
        'feed_url': 'https://example.com/feed.xml',
        'title': 'Conflicting Feed',
        'category': {'id': 1, 'title': 'Category'},
      },
    ];

    await service.syncNow();

    final keptFeed = await FeedRepository(isar!).getByRemoteId('77');
    final conflictingFeed = await FeedRepository(isar!).getByRemoteId('91');
    final prunedFeed = await FeedRepository(isar!).getByRemoteId('88');
    final articles = await isar!.articles.where().findAll();

    expect(keptFeed?.id, originalFeed.id);
    expect(keptFeed?.title, 'Original Feed');
    expect(conflictingFeed, isNull);
    expect(prunedFeed, isNull);
    expect(articles, hasLength(1));
    expect(articles.single.feedId, originalFeed.id);
  });

  test(
    'Miniflux sync prunes unprotected categories when all returned categories conflict',
    () async {
      final categories = <Map<String, Object?>>[
        {'id': 91, 'title': 'Category'},
      ];
      const feeds = <Map<String, Object?>>[];

      await _seedRemoteCategory(isar!, id: 1, remoteId: '77', name: 'Category');
      await _seedRemoteCategory(
        isar!,
        id: 2,
        remoteId: '88',
        name: 'Removed Category',
      );

      final service = MinifluxSyncService(
        account: buildTestAccount(
          type: AccountType.miniflux,
          baseUrl: 'https://miniflux.example.com',
        ),
        dio: _minifluxDio(categories: () => categories, feeds: () => feeds),
        credentials: _FakeCredentialStore(),
        feeds: FeedRepository(isar!),
        categories: CategoryRepository(isar!),
        articles: ArticleRepository(isar!),
        outbox: _MemoryOutboxStore(),
        appSettingsStore: FakeAppSettingsStore(_subscriptionsOnlySettings()),
        cache: _unusedCache(),
        extractor: ArticleExtractor(Dio()),
      );

      await service.syncNow();

      expect(await CategoryRepository(isar!).getByRemoteId('77'), isNotNull);
      expect(await CategoryRepository(isar!).getByRemoteId('88'), isNull);
      expect(await CategoryRepository(isar!).getByRemoteId('91'), isNull);
    },
  );

  test(
    'Miniflux sync keeps categories when only inline category conflicts are seen',
    () async {
      const categories = <Map<String, Object?>>[];
      final feeds = <Map<String, Object?>>[
        {
          'id': 10,
          'feed_url': 'https://example.com/feed.xml',
          'title': 'Feed',
          'category': {'id': 91, 'title': 'Category'},
        },
      ];

      await _seedRemoteCategory(isar!, id: 1, remoteId: '77', name: 'Category');
      await _seedRemoteCategory(
        isar!,
        id: 2,
        remoteId: '88',
        name: 'Existing Category',
      );

      final service = MinifluxSyncService(
        account: buildTestAccount(
          type: AccountType.miniflux,
          baseUrl: 'https://miniflux.example.com',
        ),
        dio: _minifluxDio(categories: () => categories, feeds: () => feeds),
        credentials: _FakeCredentialStore(),
        feeds: FeedRepository(isar!),
        categories: CategoryRepository(isar!),
        articles: ArticleRepository(isar!),
        outbox: _MemoryOutboxStore(),
        appSettingsStore: FakeAppSettingsStore(_subscriptionsOnlySettings()),
        cache: _unusedCache(),
        extractor: ArticleExtractor(Dio()),
      );

      await service.syncNow();

      expect(await CategoryRepository(isar!).getByRemoteId('77'), isNotNull);
      expect(await CategoryRepository(isar!).getByRemoteId('88'), isNotNull);
      expect(await CategoryRepository(isar!).getByRemoteId('91'), isNull);
    },
  );

  test(
    'Fever sync protects feed conflict while pruning unprotected feeds',
    () async {
      const groups = <Map<String, Object?>>[];
      final feeds = <Map<String, Object?>>[
        {
          'id': 91,
          'url': 'https://example.com/feed.xml',
          'title': 'Conflicting Feed',
          'site_url': 'https://example.com',
        },
      ];
      const feedsGroups = <Map<String, Object?>>[];

      await _seedRemoteFeed(
        isar!,
        id: 1,
        remoteId: '77',
        url: 'https://example.com/feed.xml/',
        title: 'Original Feed',
      );
      await _seedRemoteFeed(
        isar!,
        id: 2,
        remoteId: '88',
        url: 'https://example.com/removed.xml',
        title: 'Removed Feed',
      );
      await _seedArticle(
        isar!,
        feedId: 1,
        link: 'https://example.com/articles/kept',
      );
      await _seedArticle(
        isar!,
        feedId: 2,
        link: 'https://example.com/articles/removed',
      );

      final service = FeverSyncService(
        account: buildTestAccount(
          type: AccountType.fever,
          baseUrl: 'https://fever.example.com',
        ),
        dio: _feverDio(
          groups: () => groups,
          feeds: () => feeds,
          feedsGroups: () => feedsGroups,
        ),
        credentials: _FakeCredentialStore(),
        feeds: FeedRepository(isar!),
        categories: CategoryRepository(isar!),
        articles: ArticleRepository(isar!),
        outbox: _MemoryOutboxStore(),
        appSettingsStore: FakeAppSettingsStore(_subscriptionsOnlySettings()),
        notifications: _NoopNotificationService(),
        cache: _unusedCache(),
        extractor: ArticleExtractor(Dio()),
      );

      await service.syncNow(notify: false);

      final keptFeed = await FeedRepository(isar!).getByRemoteId('77');
      final conflictingFeed = await FeedRepository(isar!).getByRemoteId('91');
      final prunedFeed = await FeedRepository(isar!).getByRemoteId('88');
      final articles = await isar!.articles.where().findAll();

      expect(keptFeed?.title, 'Original Feed');
      expect(conflictingFeed, isNull);
      expect(prunedFeed, isNull);
      expect(articles, hasLength(1));
      expect(articles.single.feedId, 1);
    },
  );

  test(
    'Fever sync prunes unprotected categories when all returned groups conflict',
    () async {
      final groups = <Map<String, Object?>>[
        {'id': 91, 'title': 'Category'},
      ];
      const feeds = <Map<String, Object?>>[];
      const feedsGroups = <Map<String, Object?>>[];

      await _seedRemoteCategory(isar!, id: 1, remoteId: '77', name: 'Category');
      await _seedRemoteCategory(
        isar!,
        id: 2,
        remoteId: '88',
        name: 'Removed Category',
      );

      final service = FeverSyncService(
        account: buildTestAccount(
          type: AccountType.fever,
          baseUrl: 'https://fever.example.com',
        ),
        dio: _feverDio(
          groups: () => groups,
          feeds: () => feeds,
          feedsGroups: () => feedsGroups,
        ),
        credentials: _FakeCredentialStore(),
        feeds: FeedRepository(isar!),
        categories: CategoryRepository(isar!),
        articles: ArticleRepository(isar!),
        outbox: _MemoryOutboxStore(),
        appSettingsStore: FakeAppSettingsStore(_subscriptionsOnlySettings()),
        notifications: _NoopNotificationService(),
        cache: _unusedCache(),
        extractor: ArticleExtractor(Dio()),
      );

      await service.syncNow(notify: false);

      expect(await CategoryRepository(isar!).getByRemoteId('77'), isNotNull);
      expect(await CategoryRepository(isar!).getByRemoteId('88'), isNull);
      expect(await CategoryRepository(isar!).getByRemoteId('91'), isNull);
    },
  );

  test(
    'Fever sync preserves category relationships when feeds_groups fetch fails',
    () async {
      var groups = <Map<String, Object?>>[
        {'id': 1, 'title': 'Old Group'},
      ];
      var feeds = <Map<String, Object?>>[
        {
          'id': 10,
          'url': 'https://example.com/feed.xml',
          'title': 'Old Feed',
          'site_url': 'https://example.com',
        },
      ];
      var feedsGroups = <Map<String, Object?>>[
        {'group_id': 1, 'feed_ids': '10'},
      ];
      var failFeedsGroups = false;

      final service = FeverSyncService(
        account: buildTestAccount(
          type: AccountType.fever,
          baseUrl: 'https://fever.example.com',
        ),
        dio: _feverDio(
          groups: () => groups,
          feeds: () => feeds,
          feedsGroups: () => feedsGroups,
          failFeedsGroups: () => failFeedsGroups,
        ),
        credentials: _FakeCredentialStore(),
        feeds: FeedRepository(isar!),
        categories: CategoryRepository(isar!),
        articles: ArticleRepository(isar!),
        outbox: _MemoryOutboxStore(),
        appSettingsStore: FakeAppSettingsStore(_subscriptionsOnlySettings()),
        notifications: _NoopNotificationService(),
        cache: _unusedCache(),
        extractor: ArticleExtractor(Dio()),
      );

      await service.syncNow(notify: false);
      final firstFeed = await FeedRepository(isar!).getByRemoteId('10');
      final firstCategory = await CategoryRepository(isar!).getByRemoteId('1');
      expect(firstFeed, isNotNull);
      expect(firstCategory, isNotNull);

      await _seedArticle(
        isar!,
        feedId: firstFeed!.id,
        categoryId: firstCategory!.id,
        link: 'https://example.com/articles/kept',
      );

      groups = <Map<String, Object?>>[
        {'id': 1, 'title': 'Renamed Group'},
      ];
      feeds = <Map<String, Object?>>[
        {
          'id': 10,
          'url': 'https://example.com/feed.xml',
          'title': 'Updated Feed',
          'site_url': 'https://updated.example.com',
        },
      ];
      feedsGroups = const <Map<String, Object?>>[];
      failFeedsGroups = true;

      await service.syncNow(notify: false);

      final updatedFeed = await FeedRepository(isar!).getByRemoteId('10');
      final updatedCategory = await CategoryRepository(
        isar!,
      ).getByRemoteId('1');
      final articles = await isar!.articles.where().findAll();

      expect(updatedCategory?.id, firstCategory.id);
      expect(updatedCategory?.name, 'Renamed Group');
      expect(updatedFeed?.id, firstFeed.id);
      expect(updatedFeed?.title, 'Updated Feed');
      expect(updatedFeed?.siteUrl, 'https://updated.example.com');
      expect(updatedFeed?.categoryId, firstCategory.id);
      expect(articles, hasLength(1));
      expect(articles.single.categoryId, firstCategory.id);
    },
  );

  test('Fever sync skips feed prune when remote feed list is empty', () async {
    var groups = <Map<String, Object?>>[
      {'id': 1, 'title': 'Group'},
    ];
    var feeds = <Map<String, Object?>>[
      {
        'id': 10,
        'url': 'https://example.com/feed.xml',
        'title': 'Feed',
        'site_url': 'https://example.com',
      },
    ];
    var feedsGroups = <Map<String, Object?>>[
      {'group_id': 1, 'feed_ids': '10'},
    ];

    final service = FeverSyncService(
      account: buildTestAccount(
        type: AccountType.fever,
        baseUrl: 'https://fever.example.com',
      ),
      dio: _feverDio(
        groups: () => groups,
        feeds: () => feeds,
        feedsGroups: () => feedsGroups,
      ),
      credentials: _FakeCredentialStore(),
      feeds: FeedRepository(isar!),
      categories: CategoryRepository(isar!),
      articles: ArticleRepository(isar!),
      outbox: _MemoryOutboxStore(),
      appSettingsStore: FakeAppSettingsStore(_subscriptionsOnlySettings()),
      notifications: _NoopNotificationService(),
      cache: _unusedCache(),
      extractor: ArticleExtractor(Dio()),
    );

    await service.syncNow(notify: false);
    final firstFeed = await FeedRepository(isar!).getByRemoteId('10');
    final firstCategory = await CategoryRepository(isar!).getByRemoteId('1');
    expect(firstFeed, isNotNull);
    expect(firstCategory, isNotNull);

    await _seedArticle(
      isar!,
      feedId: firstFeed!.id,
      categoryId: firstCategory!.id,
      link: 'https://example.com/articles/kept',
    );

    groups = <Map<String, Object?>>[
      {'id': 1, 'title': 'Group'},
    ];
    feeds = const <Map<String, Object?>>[];
    feedsGroups = const <Map<String, Object?>>[];

    await service.syncNow(notify: false);

    final keptFeed = await FeedRepository(isar!).getByRemoteId('10');
    final articles = await isar!.articles.where().findAll();

    expect(keptFeed, isNotNull);
    expect(keptFeed?.categoryId, firstCategory.id);
    expect(articles, hasLength(1));
    expect(articles.single.feedId, firstFeed.id);
    expect(articles.single.categoryId, firstCategory.id);
  });

  test('Fever sync preserves categories when group list is empty', () async {
    var groups = <Map<String, Object?>>[
      {'id': 1, 'title': 'Group'},
    ];
    var feeds = <Map<String, Object?>>[
      {
        'id': 10,
        'url': 'https://example.com/feed.xml',
        'title': 'Feed',
        'site_url': 'https://example.com',
      },
    ];
    var feedsGroups = <Map<String, Object?>>[
      {'group_id': 1, 'feed_ids': '10'},
    ];

    final service = FeverSyncService(
      account: buildTestAccount(
        type: AccountType.fever,
        baseUrl: 'https://fever.example.com',
      ),
      dio: _feverDio(
        groups: () => groups,
        feeds: () => feeds,
        feedsGroups: () => feedsGroups,
      ),
      credentials: _FakeCredentialStore(),
      feeds: FeedRepository(isar!),
      categories: CategoryRepository(isar!),
      articles: ArticleRepository(isar!),
      outbox: _MemoryOutboxStore(),
      appSettingsStore: FakeAppSettingsStore(_subscriptionsOnlySettings()),
      notifications: _NoopNotificationService(),
      cache: _unusedCache(),
      extractor: ArticleExtractor(Dio()),
    );

    await service.syncNow(notify: false);
    final firstFeed = await FeedRepository(isar!).getByRemoteId('10');
    final firstCategory = await CategoryRepository(isar!).getByRemoteId('1');
    expect(firstFeed, isNotNull);
    expect(firstCategory, isNotNull);

    await _seedArticle(
      isar!,
      feedId: firstFeed!.id,
      categoryId: firstCategory!.id,
      link: 'https://example.com/articles/kept',
    );

    groups = const <Map<String, Object?>>[];
    feeds = <Map<String, Object?>>[
      {
        'id': 10,
        'url': 'https://example.com/feed.xml',
        'title': 'Updated Feed',
        'site_url': 'https://updated.example.com',
      },
    ];
    feedsGroups = const <Map<String, Object?>>[];

    await service.syncNow(notify: false);

    final updatedFeed = await FeedRepository(isar!).getByRemoteId('10');
    final keptCategory = await CategoryRepository(isar!).getByRemoteId('1');
    final articles = await isar!.articles.where().findAll();

    expect(keptCategory, isNotNull);
    expect(updatedFeed?.title, 'Updated Feed');
    expect(updatedFeed?.categoryId, firstCategory.id);
    expect(articles, hasLength(1));
    expect(articles.single.categoryId, firstCategory.id);
  });

  test(
    'Fever sync clears categories when feeds_groups is empty and trustworthy',
    () async {
      var groups = <Map<String, Object?>>[
        {'id': 1, 'title': 'Group'},
      ];
      var feeds = <Map<String, Object?>>[
        {
          'id': 10,
          'url': 'https://example.com/feed.xml',
          'title': 'Feed',
          'site_url': 'https://example.com',
        },
      ];
      var feedsGroups = <Map<String, Object?>>[
        {'group_id': 1, 'feed_ids': '10'},
      ];

      final service = FeverSyncService(
        account: buildTestAccount(
          type: AccountType.fever,
          baseUrl: 'https://fever.example.com',
        ),
        dio: _feverDio(
          groups: () => groups,
          feeds: () => feeds,
          feedsGroups: () => feedsGroups,
        ),
        credentials: _FakeCredentialStore(),
        feeds: FeedRepository(isar!),
        categories: CategoryRepository(isar!),
        articles: ArticleRepository(isar!),
        outbox: _MemoryOutboxStore(),
        appSettingsStore: FakeAppSettingsStore(_subscriptionsOnlySettings()),
        notifications: _NoopNotificationService(),
        cache: _unusedCache(),
        extractor: ArticleExtractor(Dio()),
      );

      await service.syncNow(notify: false);
      final firstFeed = await FeedRepository(isar!).getByRemoteId('10');
      final firstCategory = await CategoryRepository(isar!).getByRemoteId('1');
      expect(firstFeed, isNotNull);
      expect(firstCategory, isNotNull);

      await _seedArticle(
        isar!,
        feedId: firstFeed!.id,
        categoryId: firstCategory!.id,
        link: 'https://example.com/articles/cleared',
      );

      groups = <Map<String, Object?>>[
        {'id': 1, 'title': 'Group'},
      ];
      feedsGroups = const <Map<String, Object?>>[];

      await service.syncNow(notify: false);

      final updatedFeed = await FeedRepository(isar!).getByRemoteId('10');
      final keptCategory = await CategoryRepository(isar!).getByRemoteId('1');
      final articles = await isar!.articles.where().findAll();

      expect(keptCategory, isNotNull);
      expect(updatedFeed?.categoryId, isNull);
      expect(articles, hasLength(1));
      expect(articles.single.categoryId, isNull);
    },
  );
}
