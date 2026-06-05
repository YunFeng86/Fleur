import 'package:dio/dio.dart';
import 'package:isar_community/isar.dart';

import '../../repositories/category_repository.dart';
import '../../repositories/article_repository.dart';
import '../../repositories/feed_repository.dart';
import '../accounts/account.dart';
import '../accounts/credential_store.dart';
import '../sync/backend_capabilities.dart';
import '../sync/outbox/outbox_store.dart';
import '../sync/remote_client_factory.dart';
import '../sync/remote_article_action_executor.dart';

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
       _clientFactory = RemoteClientFactory(dio: dio, credentials: credentials),
       _outbox = outbox;

  final Account _account;
  final BackendCapabilities _capabilities;
  final ArticleRepository _articles;
  final FeedRepository _feeds;
  final CategoryRepository _categories;
  final RemoteClientFactory _clientFactory;
  final OutboxStore _outbox;

  Future<void> markRead(int articleId, bool isRead) async {
    final ok = await _runLocalVoid(() => _articles.markRead(articleId, isRead));
    if (!ok) return;
    if (!_shouldProjectRemote(BackendFeature.articleReadState)) return;

    switch (_account.type) {
      case AccountType.miniflux:
        final entryId = await _resolveRemoteEntryId(articleId);
        if (entryId == null) return;
        final client = await _clientFactory.minifluxOrNull(_account);
        if (client == null) return;
        try {
          await MinifluxRemoteArticleActionExecutor(client).apply(
            OutboxAction(
              type: OutboxActionType.markRead,
              remoteEntryId: entryId,
              value: isRead,
              createdAt: DateTime.now(),
            ),
          );
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
        final entryId = await _resolveRemoteEntryId(articleId);
        if (entryId == null) return;
        final client = await _clientFactory.feverOrNull(_account);
        if (client == null) return;
        try {
          await FeverRemoteArticleActionExecutor(client).apply(
            OutboxAction(
              type: OutboxActionType.markRead,
              remoteEntryId: entryId,
              value: isRead,
              createdAt: DateTime.now(),
            ),
          );
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
      case AccountType.googleReader:
        final itemId = await _resolveRemoteEntryKey(articleId);
        if (itemId == null) return;
        final client = await _clientFactory.googleReaderOrNull(_account);
        if (client == null) return;
        final action = OutboxAction(
          type: OutboxActionType.markRead,
          remoteEntryKey: itemId,
          value: isRead,
          createdAt: DateTime.now(),
        );
        try {
          await GoogleReaderRemoteArticleActionExecutor(client).apply(action);
        } catch (_) {
          await _outbox.enqueue(_account.id, action);
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

    switch (_account.type) {
      case AccountType.miniflux:
        final rid = int.tryParse((a?.remoteId ?? '').trim());
        if (rid == null) return;
        final client = await _clientFactory.minifluxOrNull(_account);
        if (client == null) return;
        try {
          await MinifluxRemoteArticleActionExecutor(client).apply(
            OutboxAction(
              type: OutboxActionType.bookmark,
              remoteEntryId: rid,
              value: a?.isStarred == true,
              createdAt: DateTime.now(),
            ),
          );
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
        final rid = int.tryParse((a?.remoteId ?? '').trim());
        if (rid == null) return;
        final client = await _clientFactory.feverOrNull(_account);
        if (client == null) return;
        final target = a?.isStarred == true;
        try {
          await FeverRemoteArticleActionExecutor(client).apply(
            OutboxAction(
              type: OutboxActionType.bookmark,
              remoteEntryId: rid,
              value: target,
              createdAt: DateTime.now(),
            ),
          );
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
      case AccountType.googleReader:
        final itemId = (a?.remoteId ?? '').trim();
        if (itemId.isEmpty) return;
        final client = await _clientFactory.googleReaderOrNull(_account);
        if (client == null) return;
        final target = a?.isStarred == true;
        final action = OutboxAction(
          type: OutboxActionType.bookmark,
          remoteEntryKey: itemId,
          value: target,
          createdAt: DateTime.now(),
        );
        try {
          await GoogleReaderRemoteArticleActionExecutor(client).apply(action);
        } catch (_) {
          await _outbox.enqueue(_account.id, action);
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

  Future<void> markAllRead({
    int? feedId,
    int? categoryId,
    bool starredOnly = false,
    bool readLaterOnly = false,
    int? tagId,
  }) async {
    final effectiveCategoryId = feedId == null ? categoryId : null;
    final localOnlyScope = starredOnly || readLaterOnly || tagId != null;
    final ok = await _runLocalInt(
      () => _articles.markAllRead(
        feedId: feedId,
        categoryId: effectiveCategoryId,
        starredOnly: starredOnly,
        readLaterOnly: readLaterOnly,
        tagId: tagId,
      ),
    );
    if (ok == null) return;
    if (localOnlyScope) return;

    if (!_shouldProjectRemote(BackendFeature.articleReadState)) return;

    final action = await _buildMarkAllReadAction(
      feedId: feedId,
      categoryId: effectiveCategoryId,
    );
    // Safety guard: if user targeted a specific scope but we can't resolve the
    // identifier needed for remote replay, do NOT fall back to "all".
    if (feedId != null && !_hasFeedScopeIdentifier(action)) {
      return;
    }
    if (effectiveCategoryId != null && !_hasCategoryScopeIdentifier(action)) {
      return;
    }
    // "Action as fact": persist intent first, then try to apply remotely.
    await _outbox.enqueue(_account.id, action);

    switch (_account.type) {
      case AccountType.miniflux:
        final client = await _clientFactory.minifluxOrNull(_account);
        if (client == null) return;
        try {
          if (await MinifluxRemoteArticleActionExecutor(client).apply(action)) {
            await _outbox.remove(_account.id, action);
          }
        } catch (_) {
          // Keep in outbox; will be flushed on next sync.
        }
        return;
      case AccountType.fever:
        final client = await _clientFactory.feverOrNull(_account);
        if (client == null) return;
        try {
          if (await FeverRemoteArticleActionExecutor(client).apply(action)) {
            await _outbox.remove(_account.id, action);
          }
        } catch (_) {
          // Keep in outbox; will be flushed on next sync.
        }
        return;
      case AccountType.googleReader:
        final client = await _clientFactory.googleReaderOrNull(_account);
        if (client == null) return;
        try {
          if (await GoogleReaderRemoteArticleActionExecutor(
            client,
          ).apply(action)) {
            await _outbox.remove(_account.id, action);
          }
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
    String? streamId;
    if (feedId != null) {
      final f = await _feeds.getById(feedId);
      feedUrl = f?.url;
      streamId = _googleReaderStreamId(f?.remoteId);
    } else if (categoryId != null) {
      final c = await _categories.getById(categoryId);
      categoryTitle = c?.name;
      streamId = _googleReaderStreamId(c?.remoteId);
    }
    return OutboxAction(
      type: OutboxActionType.markAllRead,
      feedUrl: feedUrl,
      categoryTitle: categoryTitle,
      streamId: streamId,
      value: true,
      createdAt: DateTime.now(),
    );
  }

  bool _hasFeedScopeIdentifier(OutboxAction action) {
    final feedUrl = action.feedUrl?.trim();
    if (feedUrl != null && feedUrl.isNotEmpty) return true;
    final streamId = action.streamId?.trim();
    return _account.type == AccountType.googleReader &&
        streamId != null &&
        streamId.isNotEmpty;
  }

  bool _hasCategoryScopeIdentifier(OutboxAction action) {
    final categoryTitle = action.categoryTitle?.trim();
    if (categoryTitle != null && categoryTitle.isNotEmpty) return true;
    final streamId = action.streamId?.trim();
    return _account.type == AccountType.googleReader &&
        streamId != null &&
        streamId.isNotEmpty;
  }

  String? _googleReaderStreamId(String? remoteId) {
    if (_account.type != AccountType.googleReader) return null;
    final value = remoteId?.trim();
    return value == null || value.isEmpty ? null : value;
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

  Future<String?> _resolveRemoteEntryKey(int articleId) async {
    final a = await _articles.getById(articleId);
    final raw = a?.remoteId?.trim() ?? '';
    return raw.isEmpty ? null : raw;
  }
}
