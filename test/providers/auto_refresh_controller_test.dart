import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/models/feed.dart';
import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/auto_refresh_providers.dart';
import 'package:fleur/providers/repository_providers.dart';
import 'package:fleur/providers/refresh_all_providers.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/repositories/feed_repository.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/sync/backend_capabilities.dart';
import 'package:fleur/services/sync/refresh_all_coordinator.dart';
import 'package:fleur/services/sync/sync_service.dart';

import '../test_utils/critical_workflow_test_support.dart';

class _FakeFeedRepository extends Fake implements FeedRepository {
  @override
  Future<List<Feed>> getAll() async {
    return [
      Feed()
        ..id = 1
        ..url = 'https://example.com/feed.xml'
        ..title = 'Feed',
    ];
  }
}

class _FakeMinifluxSourceRefresh implements MinifluxSourceRefresh {
  _FakeMinifluxSourceRefresh(this.events);

  final List<String> events;

  @override
  Future<void> refreshAll() async {
    events.add('upstream');
  }

  @override
  Future<void> refreshFeed(Feed feed) async {}

  @override
  Future<void> refreshFeeds(List<Feed> feeds, {int maxConcurrent = 2}) async {}
}

class _AutoRefreshHost extends ConsumerWidget {
  const _AutoRefreshHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autoRefreshControllerProvider);
    return const SizedBox.shrink();
  }
}

void main() {
  Future<List<String>> pumpController(
    WidgetTester tester, {
    required AccountType accountType,
    required int? sourceRefreshMinutes,
    bool syncEnabled = true,
  }) async {
    final events = <String>[];
    final account = buildTestAccount(type: accountType);
    final accountSyncService = FakeSyncService(
      onRefresh: (feedIds) async {
        events.add('sync');
        return const BatchRefreshResult(<FeedRefreshResult>[]);
      },
    );
    final sourceRefreshService = FakeSyncService(
      onRefresh: (feedIds) async {
        events.add('source');
        return const BatchRefreshResult(<FeedRefreshResult>[]);
      },
    );
    final accountSyncCoordinator = AccountSyncCoordinator(
      capabilities: BackendCapabilities.forAccountType(account.type),
      feeds: _FakeFeedRepository(),
      syncService: accountSyncService,
    );
    final refreshSourcesCoordinator = RefreshSourcesCoordinator(
      capabilities: BackendCapabilities.forAccountType(account.type),
      feeds: _FakeFeedRepository(),
      syncService: sourceRefreshService,
      refreshAllRemoteFeeds: () async {
        events.add('upstream');
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(account),
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(
              AppSettings.defaults().copyWith(
                sourceRefreshMinutes: sourceRefreshMinutes,
                syncEnabled: syncEnabled,
              ),
            ),
          ),
          accountSyncCoordinatorProvider.overrideWithValue(
            accountSyncCoordinator,
          ),
          refreshSourcesCoordinatorProvider.overrideWithValue(
            refreshSourcesCoordinator,
          ),
        ],
        child: const _AutoRefreshHost(),
      ),
    );
    await tester.pump();
    await tester.pump();
    return events;
  }

  Future<void> disposeController(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
  }

  testWidgets('remote account polling syncs account without source refresh', (
    tester,
  ) async {
    final events = await pumpController(
      tester,
      accountType: AccountType.miniflux,
      sourceRefreshMinutes: null,
    );

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();

    expect(events, ['sync']);

    await disposeController(tester);
  });

  testWidgets('source refresh due skips duplicate account sync', (
    tester,
  ) async {
    final events = await pumpController(
      tester,
      accountType: AccountType.miniflux,
      sourceRefreshMinutes: 15,
    );

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));
    await tester.pump();

    expect(events, ['sync', 'sync', 'upstream', 'source']);

    await disposeController(tester);
  });

  testWidgets('local account only refreshes sources when configured', (
    tester,
  ) async {
    final events = await pumpController(
      tester,
      accountType: AccountType.local,
      sourceRefreshMinutes: 15,
    );

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    expect(events, isEmpty);

    await tester.pump(const Duration(minutes: 10));
    await tester.pump();
    expect(events, ['source']);

    await disposeController(tester);
  });

  testWidgets('auto scheduler stays idle when sync is disabled', (
    tester,
  ) async {
    final events = await pumpController(
      tester,
      accountType: AccountType.miniflux,
      sourceRefreshMinutes: 15,
      syncEnabled: false,
    );

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();

    expect(events, isEmpty);

    await disposeController(tester);
  });

  testWidgets('auto scheduler reads refresh dependencies from nested scope', (
    tester,
  ) async {
    final events = <String>[];
    final account = buildTestAccount(type: AccountType.miniflux);
    final syncService = FakeSyncService(
      onRefresh: (feedIds) async {
        events.add('sync:${feedIds.join(',')}');
        return const BatchRefreshResult(<FeedRefreshResult>[]);
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(account),
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(
              AppSettings.defaults().copyWith(sourceRefreshMinutes: 15),
            ),
          ),
        ],
        child: ProviderScope(
          overrides: [
            feedRepositoryProvider.overrideWithValue(_FakeFeedRepository()),
            syncServiceProvider.overrideWithValue(syncService),
            minifluxSourceRefreshProvider.overrideWithValue(
              _FakeMinifluxSourceRefresh(events),
            ),
          ],
          child: const _AutoRefreshHost(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));
    await tester.pump();

    expect(events, ['sync:1', 'sync:1', 'upstream', 'sync:1']);
    expect(tester.takeException(), isNull);

    await disposeController(tester);
  });
}
