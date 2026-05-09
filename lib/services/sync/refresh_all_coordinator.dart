import '../../models/feed.dart';
import '../../repositories/feed_repository.dart';
import '../accounts/account.dart';
import 'sync_service.dart';

enum RefreshAllTrigger { manual, foregroundAuto, background }

typedef RefreshAllUpstreamRefresh = Future<void> Function();

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

class RefreshAllCoordinator {
  const RefreshAllCoordinator({
    required Account account,
    required FeedRepository feeds,
    required SyncServiceBase syncService,
    RefreshAllUpstreamRefresh? refreshAllRemoteFeeds,
  }) : _account = account,
       _feeds = feeds,
       _syncService = syncService,
       _refreshAllRemoteFeeds = refreshAllRemoteFeeds;

  final Account _account;
  final FeedRepository _feeds;
  final SyncServiceBase _syncService;
  final RefreshAllUpstreamRefresh? _refreshAllRemoteFeeds;

  Future<RefreshAllResult> refreshAll({
    required RefreshAllTrigger trigger,
    int maxConcurrent = 2,
    void Function(int current, int total)? onProgress,
    bool notify = true,
    List<Feed>? feedsOverride,
  }) async {
    final feeds = feedsOverride ?? await _feeds.getAll();

    if (_account.type == AccountType.miniflux) {
      final refreshAllRemoteFeeds = _refreshAllRemoteFeeds;
      if (refreshAllRemoteFeeds != null) {
        try {
          await refreshAllRemoteFeeds();
        } catch (error, stackTrace) {
          return RefreshAllResult.failure(error, stackTrace);
        }
      }
    }

    if (feeds.isEmpty && _account.type == AccountType.local) {
      return const RefreshAllResult(batch: BatchRefreshResult([]));
    }

    final batch = await _syncService.refreshFeedsSafe(
      feeds.map((feed) => feed.id),
      maxConcurrent: maxConcurrent,
      onProgress: onProgress,
      notify: notify,
    );
    return RefreshAllResult(batch: batch);
  }
}
