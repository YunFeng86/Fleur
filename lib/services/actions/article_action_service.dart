import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:isar/isar.dart';
import 'package:crypto/crypto.dart';

import '../../repositories/category_repository.dart';
import '../../repositories/article_repository.dart';
import '../../repositories/feed_repository.dart';
import '../accounts/account.dart';
import '../accounts/credential_store.dart';
import '../sync/backend_capabilities.dart';
import '../sync/miniflux/miniflux_client.dart';
import '../sync/fever/fever_client.dart';
import '../sync/outbox/outbox_store.dart';

class ArticleActionService {
  ArticleActionService({
    required Account account,
    required ArticleRepository articles,
    required FeedRepository feeds,
    required CategoryRepository categories,
    required Dio dio,
    required CredentialStore credentials,
    required OutboxStore outbox,
  }) : _account = account,
       _capabilities = BackendCapabilities.forAccountType(account.type),
       _articles = articles,
       _feeds = feeds,
       _categories = categories,
       _dio = dio,
       _credentials = credentials,
       _outbox = outbox;

  final Account _account;
  final BackendCapabilities _capabilities;
  final ArticleRepository _articles;
  final FeedRepository _feeds;
  final CategoryRepository _categories;
  final Dio _dio;
  final CredentialStore _credentials;
  final OutboxStore _outbox;

  Future<void> markRead(int articleId, bool isRead) async {
    final ok = await _runLocalVoid(() => _articles.markRead(articleId, isRead));
    if (!ok) return;
    if (!_shouldProjectRemote(BackendFeature.articleReadState)) return;

    final entryId = await _resolveRemoteEntryId(articleId);
    if (entryId == null) return;

    switch (_account.type) {
      case AccountType.miniflux:
        final client = await _minifluxClientOrNull();
        if (client == null) return;
        try {
          await client.setEntriesStatus([
            entryId,
          ], status: isRead ? 'read' : 'unread');
        } catch (_) {
          await _outbox.enqueue(
            _account.id,
            OutboxAction(
              type: OutboxActionType.markRead,
              remoteEntryId: entryId,
              value: isRead,
              createdAt: DateTime.now(),
            ),
          );
        }
        return;
      case AccountType.fever:
        final client = await _feverClientOrNull();
        if (client == null) return;
        try {
          await client.markItemRead(entryId, read: isRead);
        } catch (_) {
          await _outbox.enqueue(
            _account.id,
            OutboxAction(
              type: OutboxActionType.markRead,
              remoteEntryId: entryId,
              value: isRead,
              createdAt: DateTime.now(),
            ),
          );
        }
        return;
      case AccountType.local:
        return;
    }
  }

  Future<void> toggleStar(int articleId) async {
    final ok = await _runLocalVoid(() => _articles.toggleStar(articleId));
    if (!ok) return;
    if (!_shouldProjectRemote(BackendFeature.articleStarState)) return;

    final a = await _articles.getById(articleId);
    final rid = int.tryParse((a?.remoteId ?? '').trim());
    if (rid == null) return;

    switch (_account.type) {
      case AccountType.miniflux:
        final client = await _minifluxClientOrNull();
        if (client == null) return;
        try {
          await client.setBookmarkState(rid, a?.isStarred == true);
        } catch (_) {
          await _outbox.enqueue(
            _account.id,
            OutboxAction(
              type: OutboxActionType.bookmark,
              remoteEntryId: rid,
              value: a?.isStarred == true,
              createdAt: DateTime.now(),
            ),
          );
        }
        return;
      case AccountType.fever:
        final client = await _feverClientOrNull();
        if (client == null) return;
        final target = a?.isStarred == true;
        try {
          await client.markItemSaved(rid, saved: target);
        } catch (_) {
          await _outbox.enqueue(
            _account.id,
            OutboxAction(
              type: OutboxActionType.bookmark,
              remoteEntryId: rid,
              value: target,
              createdAt: DateTime.now(),
            ),
          );
        }
        return;
      case AccountType.local:
        return;
    }
  }

  Future<void> toggleReadLater(int articleId) async {
    // Read-later is currently local-only.
    final ok = await _runLocalVoid(() => _articles.toggleReadLater(articleId));
    if (!ok) return;
    if (!_shouldProjectRemote(BackendFeature.articleReadLater)) return;
  }

  Future<void> markAllRead({int? feedId, int? categoryId}) async {
    final effectiveCategoryId = feedId == null ? categoryId : null;
    final ok = await _runLocalInt(
      () => _articles.markAllRead(
        feedId: feedId,
        categoryId: effectiveCategoryId,
      ),
    );
    if (ok == null) return;

    if (!_shouldProjectRemote(BackendFeature.articleReadState)) return;

    final action = await _buildMarkAllReadAction(
      feedId: feedId,
      categoryId: effectiveCategoryId,
    );
    // Safety guard: if user targeted a specific scope but we can't resolve the
    // identifier needed for remote replay, do NOT fall back to "all".
    if (feedId != null &&
        (action.feedUrl == null || action.feedUrl!.trim().isEmpty)) {
      return;
    }
    if (effectiveCategoryId != null &&
        (action.categoryTitle == null ||
            action.categoryTitle!.trim().isEmpty)) {
      return;
    }
    // "Action as fact": persist intent first, then try to apply remotely.
    await _outbox.enqueue(_account.id, action);

    switch (_account.type) {
      case AccountType.miniflux:
        final client = await _minifluxClientOrNull();
        if (client == null) return;
        try {
          await _applyMarkAllRead(client, action);
          await _outbox.remove(_account.id, action);
        } catch (_) {
          // Keep in outbox; will be flushed on next sync.
        }
        return;
      case AccountType.fever:
        final client = await _feverClientOrNull();
        if (client == null) return;
        try {
          await _applyMarkAllReadFever(client, action);
          await _outbox.remove(_account.id, action);
        } catch (_) {
          // Keep in outbox; will be flushed on next sync.
        }
        return;
      case AccountType.local:
        return;
    }
  }

  Future<OutboxAction> _buildMarkAllReadAction({
    required int? feedId,
    required int? categoryId,
  }) async {
    String? feedUrl;
    String? categoryTitle;
    if (feedId != null) {
      final f = await _feeds.getById(feedId);
      feedUrl = f?.url;
    } else if (categoryId != null) {
      final c = await _categories.getById(categoryId);
      categoryTitle = c?.name;
    }
    return OutboxAction(
      type: OutboxActionType.markAllRead,
      feedUrl: feedUrl,
      categoryTitle: categoryTitle,
      value: true,
      createdAt: DateTime.now(),
    );
  }

  bool _shouldProjectRemote(BackendFeature feature) {
    return switch (_capabilities.availability(feature)) {
      FeatureAvailability.deferredRemote ||
      FeatureAvailability.onlineRequired => true,
      FeatureAvailability.local ||
      FeatureAvailability.localOnly ||
      FeatureAvailability.hidden => false,
    };
  }

  Future<void> _applyMarkAllRead(
    MinifluxClient client,
    OutboxAction action,
  ) async {
    String normalizeFeedUrl(String url) {
      return url.trim().replaceAll(RegExp(r'/+$'), '');
    }

    final feedUrl = action.feedUrl == null
        ? null
        : normalizeFeedUrl(action.feedUrl!);
    final catTitle = action.categoryTitle?.trim();
    if (feedUrl != null && feedUrl.isNotEmpty) {
      final feeds = await client.getFeeds();
      final remote = feeds
          .where((f) => f['id'] is int && f['feed_url'] is String)
          .map(
            (f) => (
              id: f['id'] as int,
              url: normalizeFeedUrl(f['feed_url'] as String),
            ),
          )
          .firstWhere((x) => x.url == feedUrl, orElse: () => (id: -1, url: ''));
      if (remote.id <= 0) {
        throw StateError('Remote feed not found for url: $feedUrl');
      }
      await client.markFeedAllAsRead(remote.id);
      return;
    }
    if (catTitle != null && catTitle.isNotEmpty) {
      final cats = await client.getCategories();
      final remote = cats
          .where((c) => c['id'] is int && c['title'] is String)
          .map(
            (c) => (id: c['id'] as int, title: (c['title'] as String).trim()),
          )
          .firstWhere(
            (x) => x.title == catTitle,
            orElse: () => (id: -1, title: ''),
          );
      if (remote.id <= 0) {
        throw StateError('Remote category not found for title: $catTitle');
      }
      await client.markCategoryAllAsRead(remote.id);
      return;
    }

    // Fallback: apply to all feeds.
    final feeds = await client.getFeeds();
    for (final f in feeds) {
      final id = f['id'];
      if (id is! int) continue;
      await client.markFeedAllAsRead(id);
    }
  }

  Future<void> _applyMarkAllReadFever(
    FeverClient client,
    OutboxAction action,
  ) async {
    String normalizeFeedUrl(String url) {
      return url.trim().replaceAll(RegExp(r'/+$'), '');
    }

    final beforeSeconds =
        action.createdAt.toUtc().millisecondsSinceEpoch ~/ 1000;

    final feedUrl = action.feedUrl == null
        ? null
        : normalizeFeedUrl(action.feedUrl!);
    final groupTitle = action.categoryTitle?.trim();

    if (feedUrl != null && feedUrl.isNotEmpty) {
      final feeds = await client.getFeeds();
      final remote = feeds
          .where((f) => f['id'] is int && f['url'] is String)
          .map(
            (f) =>
                (id: f['id'] as int, url: normalizeFeedUrl(f['url'] as String)),
          )
          .firstWhere((x) => x.url == feedUrl, orElse: () => (id: -1, url: ''));
      if (remote.id <= 0) {
        throw StateError('Remote feed not found for url: $feedUrl');
      }
      await client.markFeedRead(remote.id, beforeSeconds: beforeSeconds);
      return;
    }

    if (groupTitle != null && groupTitle.isNotEmpty) {
      final groups = await client.getGroups();
      final remote = groups
          .where((g) => g['id'] is int && g['title'] is String)
          .map(
            (g) => (id: g['id'] as int, title: (g['title'] as String).trim()),
          )
          .firstWhere(
            (x) => x.title == groupTitle,
            orElse: () => (id: -1, title: ''),
          );
      if (remote.id <= 0) {
        throw StateError('Remote group not found for title: $groupTitle');
      }
      await client.markGroupRead(remote.id, beforeSeconds: beforeSeconds);
      return;
    }

    // Fallback: apply to all feeds.
    final feeds = await client.getFeeds();
    for (final f in feeds) {
      final id = f['id'];
      if (id is! int) continue;
      await client.markFeedRead(id, beforeSeconds: beforeSeconds);
    }
  }

  Future<bool> _runLocalVoid(Future<void> Function() op) async {
    try {
      await op();
      return true;
    } on IsarError catch (e) {
      // Account switching can close Isar while UI still has pending unawaited
      // tasks. Treat this as a benign race and ignore.
      if (_isClosedError(e)) return false;
      rethrow;
    }
  }

  Future<int?> _runLocalInt(Future<int> Function() op) async {
    try {
      return await op();
    } on IsarError catch (e) {
      if (_isClosedError(e)) return null;
      rethrow;
    }
  }

  static bool _isClosedError(IsarError e) {
    // Isar throws IsarError('Isar instance has already been closed')
    // when operations are executed after close().
    return e.message.toLowerCase().contains('already been closed');
  }

  Future<int?> _resolveRemoteEntryId(int articleId) async {
    final a = await _articles.getById(articleId);
    if (a == null) return null;
    final raw = a.remoteId?.trim() ?? '';
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<MinifluxClient?> _minifluxClientOrNull() async {
    final baseUrl = (_account.baseUrl ?? '').trim();
    if (baseUrl.isEmpty) return null;
    final token = await _credentials.getApiToken(
      _account.id,
      AccountType.miniflux,
    );
    if (token != null && token.trim().isNotEmpty) {
      return MinifluxClient(dio: _dio, baseUrl: baseUrl, apiToken: token);
    }

    final basic = await _credentials.getBasicAuth(
      _account.id,
      AccountType.miniflux,
    );
    if (basic == null) return null;
    return MinifluxClient(
      dio: _dio,
      baseUrl: baseUrl,
      username: basic.username,
      password: basic.password,
    );
  }

  Future<FeverClient?> _feverClientOrNull() async {
    final baseUrl = (_account.baseUrl ?? '').trim();
    if (baseUrl.isEmpty) return null;

    final token = await _credentials.getApiToken(
      _account.id,
      AccountType.fever,
    );
    if (token != null && token.trim().isNotEmpty) {
      return FeverClient(dio: _dio, baseUrl: baseUrl, apiKey: token.trim());
    }

    final basic = await _credentials.getBasicAuth(
      _account.id,
      AccountType.fever,
    );
    if (basic == null) return null;
    final apiKey = md5
        .convert(utf8.encode('${basic.username}:${basic.password}'))
        .toString();
    return FeverClient(dio: _dio, baseUrl: baseUrl, apiKey: apiKey);
  }
}
