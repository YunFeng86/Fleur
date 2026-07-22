import '../../models/feed.dart';
import '../../repositories/feed_repository.dart';
import 'package:fleur/features/accounts/accounts.dart';
import 'backend_capabilities.dart';
import 'sync_service.dart';

enum AccountSyncTrigger { manual, foregroundAuto, background }

enum RefreshSourcesTrigger { manual, foregroundAuto, background }

typedef RefreshSourcesUpstreamRefresh = Future<void> Function();
typedef RefreshScopedRemoteFeeds =
    Future<void> Function(List<Feed> feeds, {int maxConcurrent});

sealed class RefreshScope {
  const RefreshScope();
}

final class FeedRefreshScope extends RefreshScope {
  const FeedRefreshScope(this.feedId);

  final int feedId;
}

final class CategoryRefreshScope extends RefreshScope {
  const CategoryRefreshScope(this.categoryId);

  final int categoryId;
}

final class AllRefreshScope extends RefreshScope {
  const AllRefreshScope();
}

class RefreshSourcesUnsupportedException implements Exception {
  const RefreshSourcesUnsupportedException(this.diagnosticAccountType);

  final String diagnosticAccountType;

  @override
  String toString() {
    return 'Refresh sources is not supported for $diagnosticAccountType accounts';
  }
}

class RefreshAllResult {
  const RefreshAllResult({required this.batch, this.error, this.stackTrace});

  factory RefreshAllResult.failure(Object error, StackTrace stackTrace) {
    return RefreshAllResult(
      batch: BatchRefreshResult([
        FeedRefreshResult(
          feedId: -1,
          incomingCount: 0,
          newCount: 0,
          error: error,
        ),
      ]),
      error: error,
      stackTrace: stackTrace,
    );
  }

  final BatchRefreshResult batch;
  final Object? error;
  final StackTrace? stackTrace;

  Object? get firstError => error ?? batch.firstError?.error;
  bool get ok => firstError == null;
}

class AccountSyncCoordinator {
  const AccountSyncCoordinator({
    required BackendCapabilities capabilities,
    required FeedRepository feeds,
    required SyncServiceBase syncService,
  }) : _capabilities = capabilities,
       _feeds = feeds,
       _syncService = syncService;

  final BackendCapabilities _capabilities;
  final FeedRepository _feeds;
  final SyncServiceBase _syncService;

  Future<RefreshAllResult> syncAccount({
    required AccountSyncTrigger trigger,
    int maxConcurrent = 2,
    void Function(int current, int total)? onProgress,
    bool notify = true,
    List<Feed>? feedsOverride,
  }) async {
    final feeds = feedsOverride ?? await _feeds.getAll();

    if (feeds.isEmpty && !_capabilities.isRemoteBacked) {
      return const RefreshAllResult(batch: BatchRefreshResult([]));
    }

    final batch = await _syncService.syncAccountSafe(
      maxConcurrent: maxConcurrent,
      onProgress: onProgress,
      notify: notify,
      feedIds: _accountSyncFeedIds(_capabilities, feeds),
    );
    return RefreshAllResult(batch: batch);
  }
}

class RefreshSourcesCoordinator {
  const RefreshSourcesCoordinator({
    required BackendCapabilities capabilities,
    required FeedRepository feeds,
    required SyncServiceBase syncService,
    RefreshSourcesUpstreamRefresh? refreshAllRemoteFeeds,
  }) : _capabilities = capabilities,
       _feeds = feeds,
       _syncService = syncService,
       _refreshAllRemoteFeeds = refreshAllRemoteFeeds;

  final BackendCapabilities _capabilities;
  final FeedRepository _feeds;
  final SyncServiceBase _syncService;
  final RefreshSourcesUpstreamRefresh? _refreshAllRemoteFeeds;

  Future<RefreshAllResult> refreshSources({
    required RefreshSourcesTrigger trigger,
    int maxConcurrent = 2,
    void Function(int current, int total)? onProgress,
    bool notify = true,
    List<Feed>? feedsOverride,
  }) async {
    if (!_capabilities.isVisible(BackendFeature.refreshAllSources)) {
      return RefreshAllResult.failure(
        RefreshSourcesUnsupportedException(_capabilities.diagnosticAccountType),
        StackTrace.current,
      );
    }

    final feeds = feedsOverride ?? await _feeds.getAll();

    if (_capabilities.refreshesRemoteSourcesUpstream) {
      final refreshAllRemoteFeeds = _refreshAllRemoteFeeds;
      if (refreshAllRemoteFeeds == null) {
        return RefreshAllResult.failure(
          StateError('Miniflux source refresh requires an upstream refresher'),
          StackTrace.current,
        );
      }
      try {
        await refreshAllRemoteFeeds();
      } catch (error, stackTrace) {
        return RefreshAllResult.failure(error, stackTrace);
      }
    }

    if (feeds.isEmpty && !_capabilities.isRemoteBacked) {
      return const RefreshAllResult(batch: BatchRefreshResult([]));
    }

    final ids = feeds.map((feed) => feed.id);
    final batch = _capabilities.isRemoteBacked
        ? await _syncService.syncAccountSafe(
            maxConcurrent: maxConcurrent,
            onProgress: onProgress,
            notify: notify,
            feedIds: ids,
          )
        : await _syncService.refreshFeedsSafe(
            ids,
            maxConcurrent: maxConcurrent,
            onProgress: onProgress,
            notify: notify,
          );
    return RefreshAllResult(batch: batch);
  }
}

class ScopedRefreshCoordinator {
  const ScopedRefreshCoordinator({
    required BackendCapabilities capabilities,
    required FeedRepository feeds,
    required SyncServiceBase syncService,
    required RefreshSourcesCoordinator refreshSources,
    RefreshScopedRemoteFeeds? refreshRemoteFeeds,
  }) : _capabilities = capabilities,
       _feeds = feeds,
       _syncService = syncService,
       _refreshSources = refreshSources,
       _refreshRemoteFeeds = refreshRemoteFeeds;

  final BackendCapabilities _capabilities;
  final FeedRepository _feeds;
  final SyncServiceBase _syncService;
  final RefreshSourcesCoordinator _refreshSources;
  final RefreshScopedRemoteFeeds? _refreshRemoteFeeds;

  Future<RefreshAllResult> refreshScope({
    required RefreshScope scope,
    int maxConcurrent = 2,
    void Function(int current, int total)? onProgress,
    bool notify = true,
  }) async {
    return switch (scope) {
      FeedRefreshScope(:final feedId) => _refreshFeed(
        feedId,
        maxConcurrent: maxConcurrent,
        onProgress: onProgress,
        notify: notify,
      ),
      CategoryRefreshScope(:final categoryId) => _refreshCategory(
        categoryId,
        maxConcurrent: maxConcurrent,
        onProgress: onProgress,
        notify: notify,
      ),
      AllRefreshScope() => _refreshAll(
        maxConcurrent: maxConcurrent,
        onProgress: onProgress,
        notify: notify,
      ),
    };
  }

  Future<RefreshAllResult> _refreshAll({
    required int maxConcurrent,
    void Function(int current, int total)? onProgress,
    required bool notify,
  }) async {
    if (_capabilities.isVisible(BackendFeature.refreshAllSources)) {
      return _refreshSources.refreshSources(
        trigger: RefreshSourcesTrigger.manual,
        maxConcurrent: maxConcurrent,
        onProgress: onProgress,
        notify: notify,
      );
    }

    if (!_capabilities.isVisible(BackendFeature.syncNow)) {
      return RefreshAllResult.failure(
        RefreshSourcesUnsupportedException(_capabilities.diagnosticAccountType),
        StackTrace.current,
      );
    }

    final feeds = await _feeds.getAll();
    if (feeds.isEmpty && !_capabilities.isRemoteBacked) {
      return const RefreshAllResult(batch: BatchRefreshResult([]));
    }

    final batch = await _syncService.syncAccountSafe(
      maxConcurrent: maxConcurrent,
      onProgress: onProgress,
      notify: notify,
      feedIds: _accountSyncFeedIds(_capabilities, feeds),
    );
    return RefreshAllResult(batch: batch);
  }

  Future<RefreshAllResult> _refreshFeed(
    int feedId, {
    required int maxConcurrent,
    void Function(int current, int total)? onProgress,
    required bool notify,
  }) async {
    if (!_capabilities.isVisible(BackendFeature.refreshSubscriptionSource) &&
        _capabilities.isVisible(BackendFeature.syncNow)) {
      return _refreshAll(
        maxConcurrent: maxConcurrent,
        onProgress: onProgress,
        notify: notify,
      );
    }

    if (!_capabilities.refreshesRemoteSourcesUpstream) {
      final result = await _syncService.refreshFeedSafe(feedId, notify: notify);
      onProgress?.call(1, 1);
      return RefreshAllResult(batch: BatchRefreshResult([result]));
    }

    final feed = await _feeds.getById(feedId);
    if (feed == null) {
      final error = StateError('Feed $feedId not found');
      return RefreshAllResult(
        batch: BatchRefreshResult([
          FeedRefreshResult(
            feedId: feedId,
            incomingCount: 0,
            newCount: 0,
            error: error,
          ),
        ]),
        error: error,
        stackTrace: StackTrace.current,
      );
    }

    final refreshFailure = await _refreshRemoteSourcesIfNeeded([
      feed,
    ], maxConcurrent: maxConcurrent);
    if (refreshFailure != null) return refreshFailure;

    final result = await _syncService.refreshFeedSafe(feed.id, notify: notify);
    onProgress?.call(1, 1);
    return RefreshAllResult(batch: BatchRefreshResult([result]));
  }

  Future<RefreshAllResult> _refreshCategory(
    int categoryId, {
    required int maxConcurrent,
    void Function(int current, int total)? onProgress,
    required bool notify,
  }) async {
    if (!_capabilities.isVisible(BackendFeature.refreshSubscriptionSource) &&
        _capabilities.isVisible(BackendFeature.syncNow)) {
      return _refreshAll(
        maxConcurrent: maxConcurrent,
        onProgress: onProgress,
        notify: notify,
      );
    }

    final feeds = await _feeds.getAll();
    final filtered = feeds
        .where((feed) => feed.categoryId == categoryId)
        .toList(growable: false);
    if (filtered.isEmpty) {
      onProgress?.call(0, 0);
      return const RefreshAllResult(batch: BatchRefreshResult([]));
    }

    final refreshFailure = await _refreshRemoteSourcesIfNeeded(
      filtered,
      maxConcurrent: maxConcurrent,
    );
    if (refreshFailure != null) return refreshFailure;

    final batch = await _syncService.refreshFeedsSafe(
      filtered.map((feed) => feed.id),
      maxConcurrent: maxConcurrent,
      onProgress: onProgress,
      notify: notify,
    );
    return RefreshAllResult(batch: batch);
  }

  Future<RefreshAllResult?> _refreshRemoteSourcesIfNeeded(
    List<Feed> feeds, {
    required int maxConcurrent,
  }) async {
    if (!_capabilities.refreshesRemoteSourcesUpstream) return null;
    final refreshRemoteFeeds = _refreshRemoteFeeds;
    if (refreshRemoteFeeds == null) {
      return RefreshAllResult.failure(
        StateError(
          'Miniflux scoped source refresh requires an upstream refresher',
        ),
        StackTrace.current,
      );
    }
    try {
      await refreshRemoteFeeds(feeds, maxConcurrent: maxConcurrent);
      return null;
    } catch (error, stackTrace) {
      return RefreshAllResult.failure(error, stackTrace);
    }
  }
}

Iterable<int>? _accountSyncFeedIds(
  BackendCapabilities capabilities,
  List<Feed> feeds,
) {
  if (capabilities.accountType == AccountType.googleReader) return null;
  return feeds.map((feed) => feed.id);
}
