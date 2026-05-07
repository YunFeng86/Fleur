import 'miniflux/miniflux_client.dart';

abstract class RemoteSubscriptionStructureExecutor {
  Future<List<Map<String, Object?>>> listFeeds();

  Future<List<Map<String, Object?>>> listCategories();

  Future<Map<String, Object?>> createCategory(String title);

  Future<Map<String, Object?>> createFeed({
    required String feedUrl,
    required int categoryId,
  });

  Future<Map<String, Object?>> renameCategoryByTitle({
    required String currentTitle,
    required String title,
  });

  Future<void> deleteCategoryByTitle(String title);

  Future<void> deleteFeedByUrl(String feedUrl);

  Future<void> refreshFeedByUrl(String feedUrl);

  Future<void> refreshAllFeeds();

  Future<Map<String, Object?>> moveFeedToCategory({
    required String feedUrl,
    required String categoryTitle,
  });

  Future<int> resolveFeedIdByUrl(String feedUrl);

  Future<({int remoteId, String title})> resolveCategoryByTitle(String title);
}

class MinifluxRemoteSubscriptionStructureExecutor
    implements RemoteSubscriptionStructureExecutor {
  MinifluxRemoteSubscriptionStructureExecutor(this._client);

  final MinifluxClient _client;

  @override
  Future<List<Map<String, Object?>>> listFeeds() {
    return _client.getFeeds();
  }

  @override
  Future<List<Map<String, Object?>>> listCategories() {
    return _client.getCategories();
  }

  @override
  Future<Map<String, Object?>> createCategory(String title) {
    return _client.createCategory(title);
  }

  @override
  Future<Map<String, Object?>> createFeed({
    required String feedUrl,
    required int categoryId,
  }) {
    return _client.createFeed(feedUrl: feedUrl, categoryId: categoryId);
  }

  @override
  Future<Map<String, Object?>> renameCategoryByTitle({
    required String currentTitle,
    required String title,
  }) async {
    final remote = await resolveCategoryByTitle(currentTitle);
    return _client.updateCategory(categoryId: remote.remoteId, title: title);
  }

  @override
  Future<void> deleteCategoryByTitle(String title) async {
    final remote = await resolveCategoryByTitle(title);
    await _client.deleteCategory(remote.remoteId);
  }

  @override
  Future<void> deleteFeedByUrl(String feedUrl) async {
    final remoteFeedId = await resolveFeedIdByUrl(feedUrl);
    await _client.deleteFeed(remoteFeedId);
  }

  @override
  Future<void> refreshFeedByUrl(String feedUrl) async {
    final remoteFeedId = await resolveFeedIdByUrl(feedUrl);
    await _client.refreshFeed(remoteFeedId);
  }

  @override
  Future<void> refreshAllFeeds() {
    return _client.refreshAllFeeds();
  }

  @override
  Future<Map<String, Object?>> moveFeedToCategory({
    required String feedUrl,
    required String categoryTitle,
  }) async {
    final remoteFeedId = await resolveFeedIdByUrl(feedUrl);
    final remoteCategory = await resolveCategoryByTitle(categoryTitle);
    return _client.updateFeed(
      feedId: remoteFeedId,
      categoryId: remoteCategory.remoteId,
    );
  }

  @override
  Future<int> resolveFeedIdByUrl(String feedUrl) async {
    final target = _normalizeFeedUrl(feedUrl);
    if (target.isEmpty) {
      throw StateError('Feed url is empty');
    }

    final remoteFeeds = await _client.getFeeds();
    for (final remote in remoteFeeds) {
      final remoteId = remote['id'];
      final remoteUrl = remote['feed_url'];
      if (remoteId is! int || remoteUrl is! String) continue;
      if (_normalizeFeedUrl(remoteUrl) == target) return remoteId;
    }

    throw StateError('Remote feed not found for url: $feedUrl');
  }

  @override
  Future<({int remoteId, String title})> resolveCategoryByTitle(
    String title,
  ) async {
    final target = title.trim();
    if (target.isEmpty) {
      throw StateError('Category title is empty');
    }

    final remoteCategories = await _client.getCategories();
    for (final remote in remoteCategories) {
      final remoteId = remote['id'];
      final remoteTitle = remote['title'];
      if (remoteId is! int || remoteTitle is! String) continue;
      if (remoteTitle.trim() == target) {
        return (remoteId: remoteId, title: remoteTitle.trim());
      }
    }

    throw StateError('Remote category not found for title: $target');
  }
}

String _normalizeFeedUrl(String url) {
  return url.trim().replaceAll(RegExp(r'/+$'), '');
}
