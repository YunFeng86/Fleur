import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
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
import 'package:fleur/services/actions/article_action_service.dart';
import 'package:fleur/services/sync/outbox/outbox_store.dart';

import '../../test_utils/isar_test_utils.dart';

class _FakeCredentialStore extends CredentialStore {
  _FakeCredentialStore({this.apiToken});

  final String? apiToken;

  @override
  Future<String?> getApiToken(String accountId, AccountType type) async {
    return apiToken;
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
  final Map<String, List<OutboxAction>> _actions =
      <String, List<OutboxAction>>{};

  @override
  Future<List<OutboxAction>> load(String accountId) async {
    return List<OutboxAction>.from(
      _actions[accountId] ?? const <OutboxAction>[],
    );
  }

  @override
  Future<void> save(String accountId, List<OutboxAction> actions) async {
    _actions[accountId] = List<OutboxAction>.from(actions);
  }

  @override
  Future<void> enqueue(String accountId, OutboxAction action) async {
    final current = List<OutboxAction>.from(_actions[accountId] ?? const []);
    current.add(action);
    _actions[accountId] = current;
  }

  @override
  Future<void> remove(String accountId, OutboxAction action) async {
    final current = List<OutboxAction>.from(_actions[accountId] ?? const []);
    current.removeWhere(
      (candidate) =>
          candidate.type == action.type &&
          candidate.remoteEntryId == action.remoteEntryId &&
          candidate.value == action.value &&
          candidate.feedUrl == action.feedUrl &&
          candidate.categoryTitle == action.categoryTitle,
    );
    _actions[accountId] = current;
  }
}

Account _buildAccount({
  required String id,
  required AccountType type,
  String? baseUrl,
}) {
  final now = DateTime.utc(2026, 3, 1, 9, 0);
  return Account(
    id: id,
    type: type,
    name: type.name,
    baseUrl: baseUrl,
    createdAt: now,
    updatedAt: now,
  );
}

ArticleActionService _buildArticleActionService({
  required Isar isar,
  required Account account,
  required OutboxStore outbox,
  Dio? dio,
  CredentialStore? credentials,
}) {
  return ArticleActionService(
    account: account,
    articles: ArticleRepository(isar),
    feeds: FeedRepository(isar),
    categories: CategoryRepository(isar),
    dio: dio ?? Dio(),
    credentials: credentials ?? _FakeCredentialStore(apiToken: 'token'),
    outbox: outbox,
  );
}

Dio _rejectingDio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: const SocketException('offline'),
          ),
        );
      },
    ),
  );
  return dio;
}

Dio _minifluxMarkAllReadSuccessDio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method == 'GET' && options.uri.path == '/v1/feeds') {
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              data: [
                {'id': 7, 'feed_url': 'https://example.com/feed.xml'},
              ],
            ),
          );
          return;
        }
        if (options.method == 'PUT' &&
            options.uri.path == '/v1/feeds/7/mark-all-as-read') {
          handler.resolve(Response<Object?>(requestOptions: options));
          return;
        }
        handler.reject(
          DioException(
            requestOptions: options,
            error: 'unexpected request: ${options.method} ${options.uri}',
          ),
        );
      },
    ),
  );
  return dio;
}

Future<void> _seedFeedAndArticle(
  Isar isar, {
  int feedId = 1,
  String feedUrl = 'https://example.com/feed.xml',
  int articleId = 10,
  String remoteId = '123',
  bool isRead = false,
  bool isStarred = false,
  bool isReadLater = false,
}) async {
  final now = DateTime.utc(2026, 3, 1, 9, 0);
  await isar.writeTxn(() async {
    final feed = Feed()
      ..id = feedId
      ..url = feedUrl
      ..title = 'Feed $feedId'
      ..createdAt = now
      ..updatedAt = now;
    await isar.feeds.put(feed);

    final article = Article()
      ..id = articleId
      ..feedId = feedId
      ..categoryId = null
      ..remoteId = remoteId
      ..link = 'https://example.com/posts/$articleId'
      ..title = 'Article $articleId'
      ..publishedAt = now
      ..fetchedAt = now
      ..updatedAt = now
      ..isRead = isRead
      ..isStarred = isStarred
      ..isReadLater = isReadLater;
    await isar.articles.put(article);
  });
}

void main() {
  Isar? isar;
  Directory? tempDir;

  setUpAll(() async {
    await ensureIsarCoreInitialized();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fleur_outbox_action_');
    isar = await Isar.open(
      [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
      directory: tempDir!.path,
      name: 'outbox_action_test',
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

  test('OutboxAction serializes markAllRead with feedUrl', () {
    final ts = DateTime.utc(2026, 2, 9, 12, 0, 0);
    final a = OutboxAction(
      type: OutboxActionType.markAllRead,
      feedUrl: 'https://example.com/rss.xml',
      value: true,
      createdAt: ts,
    );
    final json = a.toJson();
    final decoded = OutboxAction.fromJson(json);

    expect(decoded.type, OutboxActionType.markAllRead);
    expect(decoded.feedUrl, 'https://example.com/rss.xml');
    expect(decoded.categoryTitle, isNull);
    expect(decoded.remoteEntryId, isNull);
    expect(decoded.value, true);
    expect(decoded.createdAt.toIso8601String(), ts.toIso8601String());
  });

  test('OutboxAction.fromJson supports legacy entry-level fields', () {
    final legacy = <String, Object?>{
      'type': 'markRead',
      'remoteEntryId': 42,
      'value': true,
      'createdAt': '2026-02-09T12:00:00.000Z',
    };
    final a = OutboxAction.fromJson(legacy);
    expect(a.type, OutboxActionType.markRead);
    expect(a.remoteEntryId, 42);
    expect(a.value, true);
    expect(a.feedUrl, isNull);
    expect(a.categoryTitle, isNull);
  });

  test(
    'ArticleActionService markRead keeps local state and enqueues outbox on remote failure',
    () async {
      final now = DateTime.utc(2026, 3, 1, 9, 0);
      await isar!.writeTxn(() async {
        final feed = Feed()
          ..id = 1
          ..url = 'https://example.com/feed.xml'
          ..title = 'Feed'
          ..createdAt = now
          ..updatedAt = now;
        await isar!.feeds.put(feed);

        final article = Article()
          ..id = 10
          ..feedId = 1
          ..categoryId = null
          ..remoteId = '123'
          ..link = 'https://example.com/posts/123'
          ..title = 'Article'
          ..publishedAt = now
          ..fetchedAt = now
          ..updatedAt = now
          ..isRead = false;
        await isar!.articles.put(article);
      });

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'PUT' && options.uri.path == '/v1/entries') {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                  error: const SocketException('offline'),
                ),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'unexpected request: ${options.method} ${options.uri}',
              ),
            );
          },
        ),
      );

      const accountId = 'miniflux-account';
      final outbox = _MemoryOutboxStore();
      final service = ArticleActionService(
        account: Account(
          id: accountId,
          type: AccountType.miniflux,
          name: 'Miniflux',
          baseUrl: 'https://miniflux.example.com',
          createdAt: now,
          updatedAt: now,
        ),
        articles: ArticleRepository(isar!),
        feeds: FeedRepository(isar!),
        categories: CategoryRepository(isar!),
        dio: dio,
        credentials: _FakeCredentialStore(apiToken: 'token'),
        outbox: outbox,
      );

      await service.markRead(10, true);

      final updated = await ArticleRepository(isar!).getById(10);
      expect(updated, isNotNull);
      expect(updated!.isRead, isTrue);

      final pending = await outbox.load(accountId);
      expect(pending, hasLength(1));
      expect(pending.single.type, OutboxActionType.markRead);
      expect(pending.single.remoteEntryId, 123);
      expect(pending.single.value, isTrue);
    },
  );

  test(
    'ArticleActionService local account keeps article actions local',
    () async {
      await _seedFeedAndArticle(
        isar!,
        articleId: 10,
        remoteId: '123',
        isRead: false,
        isStarred: false,
      );
      await _seedFeedAndArticle(
        isar!,
        articleId: 11,
        remoteId: '456',
        isRead: false,
      );

      const accountId = 'local-account';
      final outbox = _MemoryOutboxStore();
      final service = _buildArticleActionService(
        isar: isar!,
        account: _buildAccount(id: accountId, type: AccountType.local),
        outbox: outbox,
        dio: _rejectingDio(),
      );

      await service.markRead(10, true);
      await service.toggleStar(10);
      await service.markAllRead(feedId: 1);

      final articles = ArticleRepository(isar!);
      final first = await articles.getById(10);
      final second = await articles.getById(11);
      expect(first, isNotNull);
      expect(first!.isRead, isTrue);
      expect(first.isStarred, isTrue);
      expect(second, isNotNull);
      expect(second!.isRead, isTrue);
      expect(await outbox.load(accountId), isEmpty);
    },
  );

  test(
    'ArticleActionService miniflux toggleStar enqueues bookmark on remote failure',
    () async {
      await _seedFeedAndArticle(isar!, articleId: 10, remoteId: '123');

      const accountId = 'miniflux-star-account';
      final outbox = _MemoryOutboxStore();
      final service = _buildArticleActionService(
        isar: isar!,
        account: _buildAccount(
          id: accountId,
          type: AccountType.miniflux,
          baseUrl: 'https://miniflux.example.com',
        ),
        outbox: outbox,
        dio: _rejectingDio(),
      );

      await service.toggleStar(10);

      final updated = await ArticleRepository(isar!).getById(10);
      expect(updated, isNotNull);
      expect(updated!.isStarred, isTrue);

      final pending = await outbox.load(accountId);
      expect(pending, hasLength(1));
      expect(pending.single.type, OutboxActionType.bookmark);
      expect(pending.single.remoteEntryId, 123);
      expect(pending.single.value, isTrue);
    },
  );

  test(
    'ArticleActionService fever markRead and toggleStar enqueue on remote failure',
    () async {
      await _seedFeedAndArticle(isar!, articleId: 10, remoteId: '123');
      await _seedFeedAndArticle(isar!, articleId: 11, remoteId: '456');

      const accountId = 'fever-account';
      final outbox = _MemoryOutboxStore();
      final service = _buildArticleActionService(
        isar: isar!,
        account: _buildAccount(
          id: accountId,
          type: AccountType.fever,
          baseUrl: 'https://fever.example.com',
        ),
        outbox: outbox,
        dio: _rejectingDio(),
      );

      await service.markRead(10, true);
      await service.toggleStar(11);

      final articles = ArticleRepository(isar!);
      expect((await articles.getById(10))!.isRead, isTrue);
      expect((await articles.getById(11))!.isStarred, isTrue);

      final pending = await outbox.load(accountId);
      expect(pending, hasLength(2));
      expect(
        pending.where((action) => action.type == OutboxActionType.markRead),
        hasLength(1),
      );
      expect(
        pending.where((action) => action.type == OutboxActionType.bookmark),
        hasLength(1),
      );
    },
  );

  test('ArticleActionService remote read later remains local-only', () async {
    await _seedFeedAndArticle(isar!, articleId: 10, remoteId: '123');
    await _seedFeedAndArticle(isar!, articleId: 11, remoteId: '456');

    final outbox = _MemoryOutboxStore();
    final cases = <({String accountId, AccountType type, int articleId})>[
      (
        accountId: 'miniflux-read-later-account',
        type: AccountType.miniflux,
        articleId: 10,
      ),
      (
        accountId: 'fever-read-later-account',
        type: AccountType.fever,
        articleId: 11,
      ),
    ];

    for (final c in cases) {
      final service = _buildArticleActionService(
        isar: isar!,
        account: _buildAccount(
          id: c.accountId,
          type: c.type,
          baseUrl: 'https://${c.type.name}.example.com',
        ),
        outbox: outbox,
        dio: _rejectingDio(),
      );
      await service.toggleReadLater(c.articleId);

      final updated = await ArticleRepository(isar!).getById(c.articleId);
      expect(updated, isNotNull);
      expect(updated!.isReadLater, isTrue);
      expect(await outbox.load(c.accountId), isEmpty);
    }
  });

  test(
    'ArticleActionService markAllRead creates scoped outbox for remote accounts',
    () async {
      await _seedFeedAndArticle(
        isar!,
        feedId: 1,
        feedUrl: 'https://example.com/miniflux.xml',
        articleId: 10,
        remoteId: '123',
      );
      await _seedFeedAndArticle(
        isar!,
        feedId: 2,
        feedUrl: 'https://example.com/fever.xml',
        articleId: 20,
        remoteId: '456',
      );

      final outbox = _MemoryOutboxStore();
      final cases =
          <({String accountId, AccountType type, int feedId, String feedUrl})>[
            (
              accountId: 'miniflux-mark-all-account',
              type: AccountType.miniflux,
              feedId: 1,
              feedUrl: 'https://example.com/miniflux.xml',
            ),
            (
              accountId: 'fever-mark-all-account',
              type: AccountType.fever,
              feedId: 2,
              feedUrl: 'https://example.com/fever.xml',
            ),
          ];

      for (final c in cases) {
        final service = _buildArticleActionService(
          isar: isar!,
          account: _buildAccount(
            id: c.accountId,
            type: c.type,
            baseUrl: 'https://${c.type.name}.example.com',
          ),
          outbox: outbox,
          credentials: _FakeCredentialStore(),
        );

        await service.markAllRead(feedId: c.feedId);

        final pending = await outbox.load(c.accountId);
        expect(pending, hasLength(1));
        expect(pending.single.type, OutboxActionType.markAllRead);
        expect(pending.single.feedUrl, c.feedUrl);
        expect(pending.single.categoryTitle, isNull);
        expect(pending.single.value, isTrue);
      }
    },
  );

  test(
    'ArticleActionService markAllRead removes queued action after remote success',
    () async {
      await _seedFeedAndArticle(
        isar!,
        feedId: 1,
        feedUrl: 'https://example.com/feed.xml',
        articleId: 10,
        remoteId: '123',
      );

      const accountId = 'miniflux-mark-all-success-account';
      final outbox = _MemoryOutboxStore();
      final service = _buildArticleActionService(
        isar: isar!,
        account: _buildAccount(
          id: accountId,
          type: AccountType.miniflux,
          baseUrl: 'https://miniflux.example.com',
        ),
        outbox: outbox,
        dio: _minifluxMarkAllReadSuccessDio(),
      );

      await service.markAllRead(feedId: 1);

      final updated = await ArticleRepository(isar!).getById(10);
      expect(updated, isNotNull);
      expect(updated!.isRead, isTrue);
      expect(await outbox.load(accountId), isEmpty);
    },
  );
}
