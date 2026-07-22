import 'package:dio/dio.dart';
import 'package:isar_community/isar.dart';

import '../../repositories/category_repository.dart';
import '../../repositories/article_repository.dart';
import '../../repositories/feed_repository.dart';
import '../accounts/account.dart';
import '../accounts/credential_store.dart';
import '../sync/backend_capabilities.dart';
import '../sync/outbox/outbox_delivery.dart';
import '../sync/outbox/outbox_store.dart';
import '../sync/remote_client_factory.dart';
import '../sync/remote_article_action_executor.dart';
import '../sync/sync_mutex.dart';

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
       _capabilities = BackendCapabilities.forAccount(account),
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
    final shouldFlush = await _serializeIntent(() async {
      final ok = await _runLocalVoid(
        () => _articles.markRead(articleId, isRead),
      );
      if (!ok) return false;
      if (!_shouldProjectRemote(BackendFeature.articleReadState)) return false;

      final action = await _buildEntryAction(
        articleId: articleId,
        type: OutboxActionType.markRead,
        value: isRead,
      );
      return _persistRemoteAction(action);
    });
    if (shouldFlush) await _flushRemoteActions();
  }

  Future<void> toggleStar(int articleId) async {
    final shouldFlush = await _serializeIntent(() async {
      final ok = await _runLocalVoid(() => _articles.toggleStar(articleId));
      if (!ok) return false;
      if (!_shouldProjectRemote(BackendFeature.articleStarState)) return false;

      final a = await _articles.getById(articleId);
      final action = _entryActionForRemoteId(
        remoteId: a?.remoteId,
        type: OutboxActionType.bookmark,
        value: a?.isStarred == true,
      );
      return _persistRemoteAction(action);
    });
    if (shouldFlush) await _flushRemoteActions();
  }

  Future<void> toggleReadLater(int articleId) async {
    await _serializeIntent(() async {
      // Read-later is currently local-only.
      final ok = await _runLocalVoid(
        () => _articles.toggleReadLater(articleId),
      );
      if (!ok) return;
      if (!_shouldProjectRemote(BackendFeature.articleReadLater)) return;
    });
  }

  Future<void> markAllRead({
    int? feedId,
    int? categoryId,
    bool starredOnly = false,
    bool readLaterOnly = false,
    int? tagId,
  }) async {
    final shouldFlush = await _serializeIntent(() async {
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
      if (ok == null || localOnlyScope) return false;
      if (!_shouldProjectRemote(BackendFeature.articleReadState)) return false;

      final action = await _buildMarkAllReadAction(
        feedId: feedId,
        categoryId: effectiveCategoryId,
      );
      // Safety guard: if user targeted a specific scope but we can't resolve
      // the identifier needed for remote replay, do not fall back to "all".
      if (feedId != null && !_hasFeedScopeIdentifier(action)) return false;
      if (effectiveCategoryId != null && !_hasCategoryScopeIdentifier(action)) {
        return false;
      }
      return _persistRemoteAction(action);
    });
    if (shouldFlush) await _flushRemoteActions();
  }

  Future<OutboxAction?> _buildEntryAction({
    required int articleId,
    required OutboxActionType type,
    required bool value,
  }) async {
    final article = await _articles.getById(articleId);
    return _entryActionForRemoteId(
      remoteId: article?.remoteId,
      type: type,
      value: value,
    );
  }

  OutboxAction? _entryActionForRemoteId({
    required String? remoteId,
    required OutboxActionType type,
    required bool value,
  }) {
    final key = remoteId?.trim() ?? '';
    if (key.isEmpty) return null;

    return switch (_account.type) {
      AccountType.miniflux || AccountType.fever => switch (int.tryParse(key)) {
        final id? => OutboxAction(
          type: type,
          remoteEntryId: id,
          value: value,
          createdAt: DateTime.now(),
        ),
        null => null,
      },
      AccountType.googleReader => OutboxAction(
        type: type,
        remoteEntryKey: key,
        value: value,
        createdAt: DateTime.now(),
      ),
      AccountType.local => null,
    };
  }

  Future<bool> _persistRemoteAction(OutboxAction? action) async {
    if (action == null) return false;
    await _outbox.enqueue(_account.id, action);
    return true;
  }

  Future<void> _flushRemoteActions() async {
    final executor = await _remoteActionExecutor();
    if (executor == null) return;
    await OutboxDelivery(
      _outbox,
    ).flush(accountId: _account.id, apply: executor.apply);
  }

  Future<T> _serializeIntent<T>(Future<T> Function() operation) {
    return SyncMutex.instance.run('article-action:${_account.id}', operation);
  }

  Future<RemoteArticleActionExecutor?> _remoteActionExecutor() async {
    switch (_account.type) {
      case AccountType.miniflux:
        final client = await _clientFactory.minifluxOrNull(_account);
        return client == null
            ? null
            : MinifluxRemoteArticleActionExecutor(client);
      case AccountType.fever:
        final client = await _clientFactory.feverOrNull(_account);
        return client == null ? null : FeverRemoteArticleActionExecutor(client);
      case AccountType.googleReader:
        final client = await _clientFactory.googleReaderOrNull(_account);
        return client == null
            ? null
            : GoogleReaderRemoteArticleActionExecutor(client);
      case AccountType.local:
        return null;
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
}
