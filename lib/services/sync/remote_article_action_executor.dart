import 'fever/fever_client.dart';
import 'google_reader/google_reader_client.dart';
import 'miniflux/miniflux_client.dart';
import 'outbox/outbox_store.dart';

abstract class RemoteArticleActionExecutor {
  Future<bool> apply(OutboxAction action);
}

class MinifluxRemoteArticleActionExecutor
    implements RemoteArticleActionExecutor {
  MinifluxRemoteArticleActionExecutor(this._client);

  final MinifluxClient _client;

  Map<String, int>? _feedUrlToRemoteId;
  Map<String, int>? _categoryTitleToRemoteId;

  @override
  Future<bool> apply(OutboxAction action) async {
    switch (action.type) {
      case OutboxActionType.markRead:
        final entryId = _remoteEntryInt(action);
        final value = action.value;
        if (entryId == null || value == null) return false;
        await _client.setEntriesStatus([
          entryId,
        ], status: value ? 'read' : 'unread');
        return true;
      case OutboxActionType.bookmark:
        final entryId = _remoteEntryInt(action);
        final value = action.value;
        if (entryId == null || value == null) return false;
        await _client.setBookmarkState(entryId, value);
        return true;
      case OutboxActionType.markAllRead:
        await _markAllRead(action);
        return true;
    }
  }

  Future<void> _markAllRead(OutboxAction action) async {
    final feedUrl = action.feedUrl == null
        ? null
        : _normalizeFeedUrl(action.feedUrl!);
    final categoryTitle = action.categoryTitle?.trim();

    if (feedUrl != null && feedUrl.isNotEmpty) {
      final map = await _getFeedUrlMap();
      final remoteFeedId = map[feedUrl];
      if (remoteFeedId == null) {
        throw StateError('Remote feed not found for url: $feedUrl');
      }
      await _client.markFeedAllAsRead(remoteFeedId);
      return;
    }

    if (categoryTitle != null && categoryTitle.isNotEmpty) {
      final map = await _getCategoryTitleMap();
      final remoteCategoryId = map[categoryTitle];
      if (remoteCategoryId == null) {
        throw StateError('Remote category not found for title: $categoryTitle');
      }
      await _client.markCategoryAllAsRead(remoteCategoryId);
      return;
    }

    final feeds = await _client.getFeeds();
    for (final feed in feeds) {
      final id = feed['id'];
      if (id is! int) continue;
      await _client.markFeedAllAsRead(id);
    }
  }

  Future<Map<String, int>> _getFeedUrlMap() async {
    final cached = _feedUrlToRemoteId;
    if (cached != null) return cached;

    final feeds = await _client.getFeeds();
    final map = <String, int>{};
    for (final feed in feeds) {
      final id = feed['id'];
      final feedUrl = feed['feed_url'];
      if (id is! int || feedUrl is! String) continue;
      final key = _normalizeFeedUrl(feedUrl);
      if (key.isEmpty) continue;
      map[key] = id;
    }
    _feedUrlToRemoteId = map;
    return map;
  }

  Future<Map<String, int>> _getCategoryTitleMap() async {
    final cached = _categoryTitleToRemoteId;
    if (cached != null) return cached;

    final categories = await _client.getCategories();
    final map = <String, int>{};
    for (final category in categories) {
      final id = category['id'];
      final title = category['title'];
      if (id is! int || title is! String) continue;
      final key = title.trim();
      if (key.isEmpty) continue;
      map[key] = id;
    }
    _categoryTitleToRemoteId = map;
    return map;
  }
}

class FeverRemoteArticleActionExecutor implements RemoteArticleActionExecutor {
  FeverRemoteArticleActionExecutor(this._client);

  final FeverClient _client;

  Map<String, int>? _feedUrlToRemoteId;
  Map<String, int>? _groupTitleToRemoteId;

  @override
  Future<bool> apply(OutboxAction action) async {
    switch (action.type) {
      case OutboxActionType.markRead:
        final entryId = _remoteEntryInt(action);
        final value = action.value;
        if (entryId == null || value == null) return false;
        await _client.markItemRead(entryId, read: value);
        return true;
      case OutboxActionType.bookmark:
        final entryId = _remoteEntryInt(action);
        final value = action.value;
        if (entryId == null || value == null) return false;
        await _client.markItemSaved(entryId, saved: value);
        return true;
      case OutboxActionType.markAllRead:
        await _markAllRead(action);
        return true;
    }
  }

  Future<void> _markAllRead(OutboxAction action) async {
    final beforeSeconds =
        action.createdAt.toUtc().millisecondsSinceEpoch ~/ 1000;
    final feedUrl = action.feedUrl == null
        ? null
        : _normalizeFeedUrl(action.feedUrl!);
    final groupTitle = action.categoryTitle?.trim();

    if (feedUrl != null && feedUrl.isNotEmpty) {
      final map = await _getFeedUrlMap();
      final remoteFeedId = map[feedUrl];
      if (remoteFeedId == null) {
        throw StateError('Remote feed not found for url: $feedUrl');
      }
      await _client.markFeedRead(remoteFeedId, beforeSeconds: beforeSeconds);
      return;
    }

    if (groupTitle != null && groupTitle.isNotEmpty) {
      final map = await _getGroupTitleMap();
      final remoteGroupId = map[groupTitle];
      if (remoteGroupId == null) {
        throw StateError('Remote group not found for title: $groupTitle');
      }
      await _client.markGroupRead(remoteGroupId, beforeSeconds: beforeSeconds);
      return;
    }

    final feeds = await _client.getFeeds();
    for (final feed in feeds) {
      final remoteFeedId = _asInt(feed['id']);
      if (remoteFeedId == null) continue;
      if (remoteFeedId <= 0) continue;
      await _client.markFeedRead(remoteFeedId, beforeSeconds: beforeSeconds);
    }
  }

  Future<Map<String, int>> _getFeedUrlMap() async {
    final cached = _feedUrlToRemoteId;
    if (cached != null) return cached;

    final feeds = await _client.getFeeds();
    final map = <String, int>{};
    for (final feed in feeds) {
      final id = _asInt(feed['id']);
      final url = feed['url'];
      if (id == null || url is! String) continue;
      final key = _normalizeFeedUrl(url);
      if (key.isEmpty) continue;
      map[key] = id;
    }
    _feedUrlToRemoteId = map;
    return map;
  }

  Future<Map<String, int>> _getGroupTitleMap() async {
    final cached = _groupTitleToRemoteId;
    if (cached != null) return cached;

    final groups = await _client.getGroups();
    final map = <String, int>{};
    for (final group in groups) {
      final id = _asInt(group['id']);
      final title = group['title'];
      if (id == null || title is! String) continue;
      final key = title.trim();
      if (key.isEmpty) continue;
      map[key] = id;
    }
    _groupTitleToRemoteId = map;
    return map;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.isFinite ? value.toInt() : null;
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

class GoogleReaderRemoteArticleActionExecutor
    implements RemoteArticleActionExecutor {
  GoogleReaderRemoteArticleActionExecutor(this._client);

  static const readState = 'user/-/state/com.google/read';
  static const starredState = 'user/-/state/com.google/starred';
  static const readingListState = 'user/-/state/com.google/reading-list';

  final GoogleReaderClient _client;

  @override
  Future<bool> apply(OutboxAction action) async {
    switch (action.type) {
      case OutboxActionType.markRead:
        final itemId = action.remoteEntryKey;
        final value = action.value;
        if (itemId == null || value == null) return false;
        await _client.editTag(
          itemId: itemId,
          add: value ? const [readState] : const [],
          remove: value ? const [] : const [readState],
        );
        return true;
      case OutboxActionType.bookmark:
        final itemId = action.remoteEntryKey;
        final value = action.value;
        if (itemId == null || value == null) return false;
        await _client.editTag(
          itemId: itemId,
          add: value ? const [starredState] : const [],
          remove: value ? const [] : const [starredState],
        );
        return true;
      case OutboxActionType.markAllRead:
        await _markAllRead(action);
        return true;
    }
  }

  Future<void> _markAllRead(OutboxAction action) async {
    final streamId = _streamIdForMarkAllRead(action);
    if (streamId == null || streamId.isEmpty) return;
    await _client.markAllAsRead(streamId: streamId, before: action.createdAt);
  }

  static String? _streamIdForMarkAllRead(OutboxAction action) {
    final explicit = action.streamId?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final feedUrl = action.feedUrl?.trim();
    if (feedUrl != null && feedUrl.isNotEmpty) {
      return feedUrl.startsWith('feed/') ? feedUrl : 'feed/$feedUrl';
    }

    final categoryTitle = action.categoryTitle?.trim();
    if (categoryTitle != null && categoryTitle.isNotEmpty) {
      return categoryTitle.startsWith('user/-/')
          ? categoryTitle
          : 'user/-/label/$categoryTitle';
    }

    return readingListState;
  }
}

String _normalizeFeedUrl(String url) {
  return url.trim().replaceAll(RegExp(r'/+$'), '');
}

int? _remoteEntryInt(OutboxAction action) {
  final legacy = action.remoteEntryId;
  if (legacy != null) return legacy;
  final key = action.remoteEntryKey?.trim();
  if (key == null || key.isEmpty) return null;
  return int.tryParse(key);
}
