import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/accounts/account.dart';
import '../services/sync/refresh_all_coordinator.dart';
import '../services/sync/remote_subscription_structure_executor.dart';
import 'account_providers.dart';
import 'repository_providers.dart';
import 'service_providers.dart';

final accountSyncCoordinatorProvider = Provider<AccountSyncCoordinator>(
  (ref) {
    final account = ref.watch(activeAccountProvider);
    return AccountSyncCoordinator(
      account: account,
      feeds: ref.watch(feedRepositoryProvider),
      syncService: ref.watch(syncServiceProvider),
    );
  },
  dependencies: [
    activeAccountProvider,
    feedRepositoryProvider,
    syncServiceProvider,
  ],
);

final refreshSourcesCoordinatorProvider = Provider<RefreshSourcesCoordinator>(
  (ref) {
    final account = ref.watch(activeAccountProvider);
    RefreshSourcesUpstreamRefresh? refreshAllRemoteFeeds;
    if (account.type == AccountType.miniflux) {
      final remoteClientFactory = ref.watch(remoteClientFactoryProvider);
      refreshAllRemoteFeeds = () async {
        final client = await remoteClientFactory.miniflux(account);
        await MinifluxRemoteSubscriptionStructureExecutor(
          client,
        ).refreshAllFeeds();
      };
    }

    return RefreshSourcesCoordinator(
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
