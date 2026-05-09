import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sync/refresh_all_coordinator.dart';
import '../services/sync/remote_subscription_structure_executor.dart';
import 'account_providers.dart';
import 'backend_capabilities_provider.dart';
import 'repository_providers.dart';
import 'service_providers.dart';

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
    final account = ref.watch(activeAccountProvider);
    final capabilities = ref.watch(backendCapabilitiesProvider);
    RefreshSourcesUpstreamRefresh? refreshAllRemoteFeeds;
    if (capabilities.refreshesRemoteSourcesUpstream) {
      final remoteClientFactory = ref.watch(remoteClientFactoryProvider);
      refreshAllRemoteFeeds = () async {
        final client = await remoteClientFactory.miniflux(account);
        await MinifluxRemoteSubscriptionStructureExecutor(
          client,
        ).refreshAllFeeds();
      };
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
    remoteClientFactoryProvider,
  ],
);
