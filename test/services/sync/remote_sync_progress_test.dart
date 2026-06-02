import 'dart:async';
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
import 'package:fleur/services/extract/article_extractor.dart';
import 'package:fleur/services/notifications/notification_service.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/sync/fever/fever_sync_service.dart';
import 'package:fleur/services/sync/miniflux/miniflux_sync_service.dart';
import 'package:fleur/services/sync/outbox/outbox_store.dart';
import 'package:fleur/services/sync/sync_status_reporter.dart';

import '../../test_utils/critical_workflow_test_support.dart';
import '../../test_utils/isar_test_utils.dart';

class _FakeCredentialStore extends CredentialStore {
  @override
  Future<String?> getApiToken(String accountId, AccountType type) async {
    return '${type.name}-token';
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
  _RecordingArticleCacheService({this.onCache})
    : super(_UnusedCacheManager(), ImageMetaStore());

  final void Function()? onCache;

  @override
  Future<int> cacheArticles(
    Iterable<Article> articles, {
    int maxConcurrentArticles = 2,
    int maxImagesPerArticle = 24,
  }) async {
    onCache?.call();
    return articles.length;
  }
}

class _FakeArticleExtractor extends ArticleExtractor {
  _FakeArticleExtractor() : super(Dio());
}

class _SyncStatusSnapshot {
  const _SyncStatusSnapshot({
    required this.label,
    required this.current,
    required this.total,
  });

  final SyncStatusLabel label;
  final int? current;
  final int? total;
}

class _RecordingSyncStatusReporter extends SyncStatusReporter {
  final snapshots = <_SyncStatusSnapshot>[];

  @override
  SyncStatusTask startTask({
    required SyncStatusLabel label,
    String? detail,
    int? current,
    int? total,
  }) {
    final task = _RecordingSyncStatusTask(
      this,
      label: label,
      current: current,
      total: total,
    );
    task.record();
    return task;
  }

  bool saw({
    required SyncStatusLabel label,
    required int? current,
    required int? total,
  }) {
    return snapshots.any(
      (s) => s.label == label && s.current == current && s.total == total,
    );
  }
}

class _RecordingSyncStatusTask extends SyncStatusTask {
  _RecordingSyncStatusTask(
    this.reporter, {
    required SyncStatusLabel label,
    required int? current,
    required int? total,
  }) : _label = label,
       _current = current,
       _total = total;

  final _RecordingSyncStatusReporter reporter;
  SyncStatusLabel _label;
  int? _current;
  int? _total;

  void record() {
    reporter.snapshots.add(
      _SyncStatusSnapshot(label: _label, current: _current, total: _total),
    );
  }

  @override
  void update({
    SyncStatusLabel? label,
    Object? detail = syncStatusUnchanged,
    Object? current = syncStatusUnchanged,
    Object? total = syncStatusUnchanged,
  }) {
    _label = label ?? _label;
    if (!identical(current, syncStatusUnchanged)) {
      _current = current as int?;
    }
    if (!identical(total, syncStatusUnchanged)) {
      _total = total as int?;
    }
    record();
  }

  @override
  void complete({bool success = true}) {}
}

class _ConcurrencyProbe {
  static const _delay = Duration(milliseconds: 20);

  int active = 0;
  int maxActive = 0;
  final offsets = <int>[];
  final limits = <int>[];
  final batchSizes = <int>[];

  void resolve(
    RequestOptions options,
    RequestInterceptorHandler handler,
    Object? data, {
    int? offset,
    int? limit,
    int? batchSize,
  }) {
    if (offset != null) offsets.add(offset);
    if (limit != null) limits.add(limit);
    if (batchSize != null) batchSizes.add(batchSize);

    active += 1;
    if (active > maxActive) maxActive = active;

    unawaited(
      Future<void>(() async {
        await Future<void>.delayed(_delay);
        handler.resolve(Response<Object?>(requestOptions: options, data: data));
      }).whenComplete(() {
        active -= 1;
      }),
    );
  }
}

Dio _feverDio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final query = options.uri.query;
        Object? data;

        if (query == 'api&groups') {
          data = <String, Object?>{'auth': 1, 'groups': const []};
        } else if (query == 'api&feeds') {
          data = <String, Object?>{
            'auth': 1,
            'feeds': [
              {
                'id': 10,
                'url': 'https://example.com/feed.xml',
                'title': 'Example Feed',
                'site_url': 'https://example.com',
              },
            ],
          };
        } else if (query == 'api&feeds&groups') {
          data = <String, Object?>{'auth': 1, 'feeds_groups': const []};
        } else if (query == 'api&unread_item_ids') {
          data = <String, Object?>{'auth': 1, 'unread_item_ids': '100,101,102'};
        } else if (query == 'api&saved_item_ids') {
          data = <String, Object?>{'auth': 1, 'saved_item_ids': ''};
        } else if (query.startsWith('api&items&with_ids=')) {
          final rawIds = Uri.decodeQueryComponent(
            query.substring('api&items&with_ids='.length),
          );
          final ids = rawIds
              .split(',')
              .map((value) => int.tryParse(value.trim()))
              .whereType<int>()
              .toList(growable: false);
          data = <String, Object?>{
            'auth': 1,
            'items': [
              for (final id in ids)
                {
                  'id': id,
                  'feed_id': 10,
                  'url': 'https://example.com/articles/$id',
                  'title': 'Fever Article $id',
                  'author': 'Fever Author',
                  'html': '<p>feed</p>',
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

Dio _feverConcurrencyDio(_ConcurrencyProbe probe, {required int itemCount}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final query = options.uri.query;
        Object? data;

        if (query == 'api&groups') {
          data = <String, Object?>{'auth': 1, 'groups': const []};
        } else if (query == 'api&feeds') {
          data = <String, Object?>{
            'auth': 1,
            'feeds': [
              {
                'id': 10,
                'url': 'https://example.com/feed.xml',
                'title': 'Example Feed',
                'site_url': 'https://example.com',
              },
            ],
          };
        } else if (query == 'api&feeds&groups') {
          data = <String, Object?>{'auth': 1, 'feeds_groups': const []};
        } else if (query == 'api&unread_item_ids') {
          data = <String, Object?>{
            'auth': 1,
            'unread_item_ids': [
              for (var id = 1; id <= itemCount; id++) id,
            ].join(','),
          };
        } else if (query == 'api&saved_item_ids') {
          data = <String, Object?>{'auth': 1, 'saved_item_ids': ''};
        } else if (query.startsWith('api&items&with_ids=')) {
          final rawIds = Uri.decodeQueryComponent(
            query.substring('api&items&with_ids='.length),
          );
          final ids = rawIds
              .split(',')
              .map((value) => int.tryParse(value.trim()))
              .whereType<int>()
              .toList(growable: false);
          data = <String, Object?>{
            'auth': 1,
            'items': [
              for (final id in ids)
                {
                  'id': id,
                  'feed_id': 10,
                  'url': 'https://example.com/articles/$id',
                  'title': 'Fever Article $id',
                  'author': 'Fever Author',
                  'html': '<p>feed</p>',
                  'created_on_time': 1770000000 + id,
                },
            ],
          };
          probe.resolve(options, handler, data, batchSize: ids.length);
          return;
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

Dio _minifluxDio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        Object? data;
        final path = options.uri.path;

        if (path == '/v1/categories') {
          data = [
            {'id': 1, 'title': 'General'},
          ];
        } else if (path == '/v1/feeds') {
          data = [
            {
              'id': 10,
              'feed_url': 'https://example.com/feed.xml',
              'title': 'Example Feed',
              'site_url': 'https://example.com',
              'description': 'Example',
              'category_id': 1,
            },
          ];
        } else if (path == '/v1/entries') {
          data = <String, Object?>{
            'total': 3,
            'entries': [
              for (final id in [100, 101, 102])
                {
                  'id': id,
                  'feed_id': 10,
                  'url': 'https://example.com/articles/$id',
                  'title': 'Miniflux Article $id',
                  'content': '<p>feed</p>',
                  'status': 'unread',
                  'starred': false,
                  'published_at': '2026-01-01T00:00:00Z',
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
            error: 'unexpected Miniflux request: ${options.method} $path',
          ),
        );
      },
    ),
  );
  return dio;
}

Dio _minifluxPagedDio(
  _ConcurrencyProbe probe, {
  required int totalEntries,
  required bool includeTotal,
}) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        Object? data;
        final path = options.uri.path;

        if (path == '/v1/categories') {
          data = [
            {'id': 1, 'title': 'General'},
          ];
        } else if (path == '/v1/feeds') {
          data = [
            {
              'id': 10,
              'feed_url': 'https://example.com/feed.xml',
              'title': 'Example Feed',
              'site_url': 'https://example.com',
              'description': 'Example',
              'category_id': 1,
            },
          ];
        } else if (path == '/v1/entries') {
          final query = options.uri.queryParameters;
          final limit = int.tryParse(query['limit'] ?? '') ?? 0;
          final offset = int.tryParse(query['offset'] ?? '0') ?? 0;
          final remaining = totalEntries - offset;
          final count = remaining <= 0
              ? 0
              : remaining < limit
              ? remaining
              : limit;
          data = <String, Object?>{
            if (includeTotal) 'total': totalEntries,
            'entries': [
              for (var i = 0; i < count; i++)
                {
                  'id': offset + i + 1,
                  'feed_id': 10,
                  'url': 'https://example.com/articles/${offset + i + 1}',
                  'title': 'Miniflux Article ${offset + i + 1}',
                  'content': '<p>feed</p>',
                  'status': 'unread',
                  'starred': false,
                  'published_at': '2026-01-01T00:00:00Z',
                },
            ],
          };
          probe.resolve(options, handler, data, offset: offset, limit: limit);
          return;
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
            error: 'unexpected Miniflux request: ${options.method} $path',
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  Isar? isar;
  Directory? tempDir;

  setUpAll(() async {
    await ensureIsarCoreInitialized();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fleur_sync_progress_');
    isar = await Isar.open(
      [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
      directory: tempDir!.path,
      name: 'remote_sync_progress_test',
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
    'Fever reports the article sync window before processing batches',
    () async {
      final reporter = _RecordingSyncStatusReporter();
      final service = FeverSyncService(
        account: buildTestAccount(
          type: AccountType.fever,
          baseUrl: 'https://fever.example.com',
        ),
        dio: _feverDio(),
        credentials: _FakeCredentialStore(),
        feeds: FeedRepository(isar!),
        categories: CategoryRepository(isar!),
        articles: ArticleRepository(isar!),
        outbox: _MemoryOutboxStore(),
        appSettingsStore: FakeAppSettingsStore(AppSettings.defaults()),
        notifications: _NoopNotificationService(),
        cache: _RecordingArticleCacheService(),
        extractor: _FakeArticleExtractor(),
        statusReporter: reporter,
      );

      await service.refreshFeedsSafe([1], notify: false);

      expect(
        reporter.saw(
          label: SyncStatusLabel.syncingUnreadArticles,
          current: 0,
          total: 3,
        ),
        isTrue,
      );
      expect(
        reporter.saw(
          label: SyncStatusLabel.syncingUnreadArticles,
          current: 3,
          total: 3,
        ),
        isTrue,
      );
    },
  );

  test(
    'Miniflux reports entries progress before prefetch work starts',
    () async {
      final reporter = _RecordingSyncStatusReporter();
      var sawProgressBeforeCache = false;
      final cache = _RecordingArticleCacheService(
        onCache: () {
          sawProgressBeforeCache = reporter.saw(
            label: SyncStatusLabel.syncingUnreadArticles,
            current: 3,
            total: 3,
          );
        },
      );
      final service = MinifluxSyncService(
        account: buildTestAccount(
          type: AccountType.miniflux,
          baseUrl: 'https://miniflux.example.com',
        ),
        dio: _minifluxDio(),
        credentials: _FakeCredentialStore(),
        feeds: FeedRepository(isar!),
        categories: CategoryRepository(isar!),
        articles: ArticleRepository(isar!),
        outbox: _MemoryOutboxStore(),
        appSettingsStore: FakeAppSettingsStore(
          AppSettings.defaults().copyWith(syncImages: true),
        ),
        cache: cache,
        extractor: _FakeArticleExtractor(),
        statusReporter: reporter,
      );

      await service.refreshFeedsSafe([1], notify: false);

      expect(sawProgressBeforeCache, isTrue);
      expect(
        reporter.saw(
          label: SyncStatusLabel.syncingUnreadArticles,
          current: 3,
          total: 3,
        ),
        isTrue,
      );
    },
  );

  test('Fever fetches item batches with remote fetch concurrency', () async {
    final probe = _ConcurrencyProbe();
    final service = FeverSyncService(
      account: buildTestAccount(
        type: AccountType.fever,
        baseUrl: 'https://fever.example.com',
      ),
      dio: _feverConcurrencyDio(probe, itemCount: 130),
      credentials: _FakeCredentialStore(),
      feeds: FeedRepository(isar!),
      categories: CategoryRepository(isar!),
      articles: ArticleRepository(isar!),
      outbox: _MemoryOutboxStore(),
      appSettingsStore: FakeAppSettingsStore(
        AppSettings.defaults().copyWith(
          remoteEntriesLimit: 130,
          remoteFetchConcurrency: 2,
        ),
      ),
      notifications: _NoopNotificationService(),
      cache: _RecordingArticleCacheService(),
      extractor: _FakeArticleExtractor(),
    );

    await service.syncNow(notify: false);

    final articles = await isar!.articles.where().findAll();
    expect(articles, hasLength(130));
    expect(probe.batchSizes, [50, 50, 30]);
    expect(probe.maxActive, 2);
  });

  test(
    'Miniflux fetches limited entry pages with remote fetch concurrency',
    () async {
      final probe = _ConcurrencyProbe();
      final service = MinifluxSyncService(
        account: buildTestAccount(
          type: AccountType.miniflux,
          baseUrl: 'https://miniflux.example.com',
        ),
        dio: _minifluxPagedDio(probe, totalEntries: 450, includeTotal: true),
        credentials: _FakeCredentialStore(),
        feeds: FeedRepository(isar!),
        categories: CategoryRepository(isar!),
        articles: ArticleRepository(isar!),
        outbox: _MemoryOutboxStore(),
        appSettingsStore: FakeAppSettingsStore(
          AppSettings.defaults().copyWith(
            remoteEntriesLimit: 450,
            remoteFetchConcurrency: 2,
          ),
        ),
        cache: _RecordingArticleCacheService(),
        extractor: _FakeArticleExtractor(),
      );

      await service.syncNow();

      final articles = await isar!.articles.where().findAll();
      expect(articles, hasLength(450));
      expect(probe.offsets, [0, 200, 400]);
      expect(probe.limits, [200, 200, 50]);
      expect(probe.maxActive, 2);
    },
  );

  test(
    'Miniflux unlimited sync uses total for concurrent pagination',
    () async {
      final probe = _ConcurrencyProbe();
      final service = MinifluxSyncService(
        account: buildTestAccount(
          type: AccountType.miniflux,
          baseUrl: 'https://miniflux.example.com',
        ),
        dio: _minifluxPagedDio(probe, totalEntries: 450, includeTotal: true),
        credentials: _FakeCredentialStore(),
        feeds: FeedRepository(isar!),
        categories: CategoryRepository(isar!),
        articles: ArticleRepository(isar!),
        outbox: _MemoryOutboxStore(),
        appSettingsStore: FakeAppSettingsStore(
          AppSettings.defaults().copyWith(
            remoteEntriesLimit: 0,
            remoteFetchConcurrency: 2,
          ),
        ),
        cache: _RecordingArticleCacheService(),
        extractor: _FakeArticleExtractor(),
      );

      await service.syncNow();

      final articles = await isar!.articles.where().findAll();
      expect(articles, hasLength(450));
      expect(probe.offsets, [0, 200, 400]);
      expect(probe.limits, [200, 200, 50]);
      expect(probe.maxActive, 2);
    },
  );

  test(
    'Miniflux unlimited sync without total falls back to serial pages',
    () async {
      final probe = _ConcurrencyProbe();
      final service = MinifluxSyncService(
        account: buildTestAccount(
          type: AccountType.miniflux,
          baseUrl: 'https://miniflux.example.com',
        ),
        dio: _minifluxPagedDio(probe, totalEntries: 250, includeTotal: false),
        credentials: _FakeCredentialStore(),
        feeds: FeedRepository(isar!),
        categories: CategoryRepository(isar!),
        articles: ArticleRepository(isar!),
        outbox: _MemoryOutboxStore(),
        appSettingsStore: FakeAppSettingsStore(
          AppSettings.defaults().copyWith(
            remoteEntriesLimit: 0,
            remoteFetchConcurrency: 4,
          ),
        ),
        cache: _RecordingArticleCacheService(),
        extractor: _FakeArticleExtractor(),
      );

      await service.syncNow();

      final articles = await isar!.articles.where().findAll();
      expect(articles, hasLength(250));
      expect(probe.offsets, [0, 200]);
      expect(probe.limits, [200, 200]);
      expect(probe.maxActive, 1);
    },
  );
}
