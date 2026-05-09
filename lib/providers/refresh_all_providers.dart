import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/accounts/account.dart';
import '../services/sync/refresh_all_coordinator.dart';
import '../services/sync/remote_subscription_structure_executor.dart';
import 'account_providers.dart';
import 'repository_providers.dart';
import 'service_providers.dart';

final refreshAllCoordinatorProvider = Provider<RefreshAllCoordinator>(
  (ref) {
    final account = ref.watch(activeAccountProvider);
    RefreshAllUpstreamRefresh? refreshAllRemoteFeeds;
    if (account.type == AccountType.miniflux) {
      final remoteClientFactory = ref.watch(remoteClientFactoryProvider);
      refreshAllRemoteFeeds = () async {
        final client = await remoteClientFactory.miniflux(account);
        await MinifluxRemoteSubscriptionStructureExecutor(
          client,
        ).refreshAllFeeds();
      };
    }

    return RefreshAllCoordinator(
      account: account,
      feeds: ref.watch(feedRepositoryProvider),
      syncService: ref.watch(syncServiceProvider),
      refreshAllRemoteFeeds: refreshAllRemoteFeeds,
    );
  },
  dependencies: [
    activeAccountProvider,
    feedRepositoryProvider,
    syncServiceProvider,
    remoteClientFactoryProvider,
  ],
);
