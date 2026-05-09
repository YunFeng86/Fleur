import '../../models/feed.dart';
import '../../repositories/feed_repository.dart';
import '../accounts/account.dart';
import 'sync_service.dart';

enum AccountSyncTrigger { manual, foregroundAuto, background }

enum RefreshSourcesTrigger { manual, foregroundAuto, background }

typedef RefreshSourcesUpstreamRefresh = Future<void> Function();

class RefreshSourcesUnsupportedException implements Exception {
  const RefreshSourcesUnsupportedException(this.accountType);

  final AccountType accountType;

  @override
  String toString() {
    return 'Refresh sources is not supported for ${accountType.wire} accounts';
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
    required Account account,
    required FeedRepository feeds,
    required SyncServiceBase syncService,
  }) : _account = account,
       _feeds = feeds,
       _syncService = syncService;

  final Account _account;
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

class RefreshSourcesCoordinator {
  const RefreshSourcesCoordinator({
    required Account account,
    required FeedRepository feeds,
    required SyncServiceBase syncService,
    RefreshSourcesUpstreamRefresh? refreshAllRemoteFeeds,
  }) : _account = account,
       _feeds = feeds,
       _syncService = syncService,
       _refreshAllRemoteFeeds = refreshAllRemoteFeeds;

  final Account _account;
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
    if (_account.type == AccountType.fever) {
      return RefreshAllResult.failure(
        RefreshSourcesUnsupportedException(_account.type),
        StackTrace.current,
      );
    }

    final feeds = feedsOverride ?? await _feeds.getAll();

    if (_account.type == AccountType.miniflux) {
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
