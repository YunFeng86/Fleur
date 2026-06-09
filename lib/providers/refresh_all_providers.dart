import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pool/pool.dart';

import '../models/feed.dart';
import '../services/sync/refresh_all_coordinator.dart';
import '../services/sync/remote_subscription_structure_executor.dart';
import 'account_providers.dart';
import 'backend_capabilities_provider.dart';
import 'repository_providers.dart';
import 'service_providers.dart';

abstract class MinifluxSourceRefresh {
  Future<void> refreshAll();

  Future<void> refreshFeed(Feed feed);

  Future<void> refreshFeeds(List<Feed> feeds, {int maxConcurrent = 2});
}

class RemoteMinifluxSourceRefresh implements MinifluxSourceRefresh {
  const RemoteMinifluxSourceRefresh({required this.buildExecutor});

  final Future<RemoteSubscriptionStructureExecutor> Function() buildExecutor;

  @override
  Future<void> refreshAll() async {
    final executor = await buildExecutor();
    await executor.refreshAllFeeds();
  }

  @override
  Future<void> refreshFeed(Feed feed) async {
    final executor = await buildExecutor();
    final remoteId = _remoteIdAsInt(feed.remoteId);
    if (remoteId == null) {
      await executor.refreshFeedByUrl(feed.url);
      return;
    }
    await executor.refreshFeedById(remoteId);
  }

  @override
  Future<void> refreshFeeds(List<Feed> feeds, {int maxConcurrent = 2}) async {
    if (feeds.isEmpty) return;
    final pool = Pool(maxConcurrent < 1 ? 1 : maxConcurrent);
    try {
      await Future.wait([
        for (final feed in feeds) pool.withResource(() => refreshFeed(feed)),
      ]);
    } finally {
      await pool.close();
    }
  }

  static int? _remoteIdAsInt(String? remoteId) {
    final trimmed = remoteId?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final value = int.tryParse(trimmed);
    return value != null && value > 0 ? value : null;
  }
}

final minifluxSourceRefreshProvider = Provider<MinifluxSourceRefresh>((ref) {
  final account = ref.watch(activeAccountProvider);
  final remoteClientFactory = ref.watch(remoteClientFactoryProvider);
  return RemoteMinifluxSourceRefresh(
    buildExecutor: () async {
      final client = await remoteClientFactory.miniflux(account);
      return MinifluxRemoteSubscriptionStructureExecutor(client);
    },
  );
}, dependencies: [activeAccountProvider, remoteClientFactoryProvider]);

final accountSyncCoordinatorProvider = Provider<AccountSyncCoordinator>(
  (ref) {
    final capabilities = ref.watch(backendCapabilitiesProvider);
    return AccountSyncCoordinator(
      capabilities: capabilities,
      feeds: ref.watch(feedRepositoryProvider),
      syncService: ref.watch(syncServiceProvider),
    );
  },
  dependencies: [
    activeAccountProvider,
    backendCapabilitiesProvider,
    feedRepositoryProvider,
    syncServiceProvider,
  ],
);

final refreshSourcesCoordinatorProvider = Provider<RefreshSourcesCoordinator>(
  (ref) {
    final capabilities = ref.watch(backendCapabilitiesProvider);
    RefreshSourcesUpstreamRefresh? refreshAllRemoteFeeds;
    if (capabilities.refreshesRemoteSourcesUpstream) {
      final minifluxSourceRefresh = ref.watch(minifluxSourceRefreshProvider);
      refreshAllRemoteFeeds = minifluxSourceRefresh.refreshAll;
    }

    return RefreshSourcesCoordinator(
      capabilities: capabilities,
      feeds: ref.watch(feedRepositoryProvider),
      syncService: ref.watch(syncServiceProvider),
      refreshAllRemoteFeeds: refreshAllRemoteFeeds,
    );
  },
  dependencies: [
    activeAccountProvider,
    backendCapabilitiesProvider,
    feedRepositoryProvider,
    syncServiceProvider,
    minifluxSourceRefreshProvider,
  ],
);

final scopedRefreshCoordinatorProvider = Provider<ScopedRefreshCoordinator>(
  (ref) {
    final capabilities = ref.watch(backendCapabilitiesProvider);
    RefreshScopedRemoteFeeds? refreshRemoteFeeds;
    if (capabilities.refreshesRemoteSourcesUpstream) {
      final minifluxSourceRefresh = ref.watch(minifluxSourceRefreshProvider);
      refreshRemoteFeeds = minifluxSourceRefresh.refreshFeeds;
    }

    return ScopedRefreshCoordinator(
      capabilities: capabilities,
      feeds: ref.watch(feedRepositoryProvider),
      syncService: ref.watch(syncServiceProvider),
      refreshSources: ref.watch(refreshSourcesCoordinatorProvider),
      refreshRemoteFeeds: refreshRemoteFeeds,
    );
  },
  dependencies: [
    activeAccountProvider,
    backendCapabilitiesProvider,
    feedRepositoryProvider,
    syncServiceProvider,
    refreshSourcesCoordinatorProvider,
    minifluxSourceRefreshProvider,
  ],
);
