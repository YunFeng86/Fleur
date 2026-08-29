import 'fever/fever_client.dart';
import 'google_reader/google_reader_client.dart';
import 'miniflux/miniflux_client.dart';
import 'outbox/outbox_store.dart';

/// Indicates that an outbox action targets a remote scope that no longer
/// exists. This is safe to acknowledge; transport and response-shape failures
/// must continue to propagate so the action can be retried.
class RemoteScopeNotFoundException implements Exception {
  const RemoteScopeNotFoundException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Outcome of applying an outbox action on the remote backend.
enum RemoteActionDisposition {
  /// The remote backend accepted the action.
  delivered,

  /// The action can never be applied (missing remote identifiers, deleted
  /// feed/category scope, malformed legacy payload); the queue should drop
  /// it instead of retrying forever.
  rejected,

  /// Not applied now but may succeed later (e.g. eventual-consistency
  /// verification failure); the queue should keep it.
  transient,
}

abstract class RemoteArticleActionExecutor {
  Future<RemoteActionDisposition> apply(OutboxAction action);
}

class MinifluxRemoteArticleActionExecutor
    implements RemoteArticleActionExecutor {
  MinifluxRemoteArticleActionExecutor(this._client);

  final MinifluxClient _client;

  Map<String, int>? _feedUrlToRemoteId;
  Map<String, int>? _categoryTitleToRemoteId;

  @override
  Future<RemoteActionDisposition> apply(OutboxAction action) async {
    switch (action.type) {
      case OutboxActionType.markRead:
        final entryId = _remoteEntryInt(action);
        final value = action.value;
        if (entryId == null || value == null) {
          return RemoteActionDisposition.rejected;
        }
        await _client.setEntriesStatus([
          entryId,
        ], status: value ? 'read' : 'unread');
        return RemoteActionDisposition.delivered;
      case OutboxActionType.bookmark:
        final entryId = _remoteEntryInt(action);
        final value = action.value;
        if (entryId == null || value == null) {
          return RemoteActionDisposition.rejected;
        }
        await _client.setBookmarkState(entryId, value);
        return RemoteActionDisposition.delivered;
      case OutboxActionType.markAllRead:
        try {
          await _markAllRead(action);
        } on RemoteScopeNotFoundException {
          // The remote feed/category backing this scope no longer exists.
          return RemoteActionDisposition.rejected;
        }
        return RemoteActionDisposition.delivered;
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
        throw RemoteScopeNotFoundException(
          'Remote feed not found for url: $feedUrl',
        );
      }
      await _client.markFeedAllAsRead(remoteFeedId);
      return;
    }

    if (categoryTitle != null && categoryTitle.isNotEmpty) {
      final map = await _getCategoryTitleMap();
      final remoteCategoryId = map[categoryTitle];
      if (remoteCategoryId == null) {
        throw RemoteScopeNotFoundException(
          'Remote category not found for title: $categoryTitle',
        );
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
  Future<RemoteActionDisposition> apply(OutboxAction action) async {
    switch (action.type) {
      case OutboxActionType.markRead:
        final entryId = _remoteEntryInt(action);
        final value = action.value;
        if (entryId == null || value == null) {
          return RemoteActionDisposition.rejected;
        }
        await _client.markItemRead(entryId, read: value);
        return RemoteActionDisposition.delivered;
      case OutboxActionType.bookmark:
        final entryId = _remoteEntryInt(action);
        final value = action.value;
        if (entryId == null || value == null) {
          return RemoteActionDisposition.rejected;
        }
        await _client.markItemSaved(entryId, saved: value);
        return RemoteActionDisposition.delivered;
      case OutboxActionType.markAllRead:
        try {
          await _markAllRead(action);
        } on RemoteScopeNotFoundException {
          // The remote feed/group backing this scope no longer exists.
          return RemoteActionDisposition.rejected;
        }
        return RemoteActionDisposition.delivered;
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
        throw RemoteScopeNotFoundException(
          'Remote feed not found for url: $feedUrl',
        );
      }
      await _client.markFeedRead(remoteFeedId, beforeSeconds: beforeSeconds);
      return;
    }

    if (groupTitle != null && groupTitle.isNotEmpty) {
      final map = await _getGroupTitleMap();
      final remoteGroupId = map[groupTitle];
      if (remoteGroupId == null) {
        throw RemoteScopeNotFoundException(
          'Remote group not found for title: $groupTitle',
        );
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
  Future<RemoteActionDisposition> apply(OutboxAction action) async {
    switch (action.type) {
      case OutboxActionType.markRead:
        final itemId = action.remoteEntryKey;
        final value = action.value;
        if (itemId == null || value == null) {
          return RemoteActionDisposition.rejected;
        }
        await _client.editTag(
          itemId: itemId,
          add: value ? const [readState] : const [],
          remove: value ? const [] : const [readState],
        );
        return RemoteActionDisposition.delivered;
      case OutboxActionType.bookmark:
        final itemId = action.remoteEntryKey;
        final value = action.value;
        if (itemId == null || value == null) {
          return RemoteActionDisposition.rejected;
        }
        await _client.editTag(
          itemId: itemId,
          add: value ? const [starredState] : const [],
          remove: value ? const [] : const [starredState],
        );
        return RemoteActionDisposition.delivered;
      case OutboxActionType.markAllRead:
        return _markAllRead(action);
    }
  }

  Future<RemoteActionDisposition> applyBatch(
    Iterable<OutboxAction> actions,
  ) async {
    final list = actions.toList(growable: false);
    if (list.isEmpty) return RemoteActionDisposition.delivered;
    final first = list.first;
    if (!isBatchable(first)) return RemoteActionDisposition.rejected;
    final value = first.value;
    final ids = <String>[];
    for (final action in list) {
      if (!isBatchable(action) ||
          action.type != first.type ||
          action.value != value) {
        return RemoteActionDisposition.rejected;
      }
      final itemId = action.remoteEntryKey?.trim();
      if (itemId == null || itemId.isEmpty) {
        return RemoteActionDisposition.rejected;
      }
      ids.add(itemId);
    }
    final state = first.type == OutboxActionType.markRead
        ? readState
        : starredState;
    await _client.editTags(
      itemIds: ids,
      add: value == true ? [state] : const [],
      remove: value == true ? const [] : [state],
    );
    return RemoteActionDisposition.delivered;
  }

  Future<RemoteActionDisposition> _markAllRead(OutboxAction action) async {
    final streamId = _streamIdForMarkAllRead(action);
    if (streamId == null || streamId.isEmpty) {
      return RemoteActionDisposition.rejected;
    }
    await _client.markAllAsRead(streamId: streamId, before: action.createdAt);
    if (!_client.profile.verifyMarkAllAsRead) {
      return RemoteActionDisposition.delivered;
    }
    final unread = await _client.streamItemIds(
      streamId: streamId,
      count: 1,
      excludeState: readState,
    );
    // Verification may fail due to eventual consistency; retry later.
    return unread.itemIds.isEmpty
        ? RemoteActionDisposition.delivered
        : RemoteActionDisposition.transient;
  }

  static bool isBatchable(OutboxAction action) {
    return switch (action.type) {
      OutboxActionType.markRead || OutboxActionType.bookmark =>
        (action.remoteEntryKey ?? '').trim().isNotEmpty && action.value != null,
      OutboxActionType.markAllRead => false,
    };
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
