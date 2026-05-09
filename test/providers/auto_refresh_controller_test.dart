import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/models/feed.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/auto_refresh_providers.dart';
import 'package:fleur/providers/refresh_all_providers.dart';
import 'package:fleur/repositories/feed_repository.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/sync/refresh_all_coordinator.dart';

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

class _AutoRefreshHost extends ConsumerWidget {
  const _AutoRefreshHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autoRefreshControllerProvider);
    return const SizedBox.shrink();
  }
}

void main() {
  Future<FakeSyncService> pumpController(
    WidgetTester tester, {
    required int? autoRefreshMinutes,
    bool syncEnabled = true,
  }) async {
    final syncService = FakeSyncService();
    final coordinator = RefreshAllCoordinator(
      account: buildTestAccount(type: AccountType.local),
      feeds: _FakeFeedRepository(),
      syncService: syncService,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(
              AppSettings.defaults().copyWith(
                autoRefreshMinutes: autoRefreshMinutes,
                syncEnabled: syncEnabled,
              ),
            ),
          ),
          refreshAllCoordinatorProvider.overrideWithValue(coordinator),
        ],
        child: const _AutoRefreshHost(),
      ),
    );
    await tester.pump();
    await tester.pump();
    return syncService;
  }

  Future<void> disposeController(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
  }

  testWidgets('auto refresh timer triggers the shared refresh coordinator', (
    tester,
  ) async {
    final syncService = await pumpController(tester, autoRefreshMinutes: 5);

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();

    expect(syncService.refreshCalls, [
      [1],
    ]);

    await disposeController(tester);
  });

  testWidgets('auto refresh timer stays idle when disabled', (tester) async {
    final syncService = await pumpController(tester, autoRefreshMinutes: null);

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();

    expect(syncService.refreshCalls, isEmpty);

    await disposeController(tester);
  });

  testWidgets('auto refresh timer stays idle when sync is disabled', (
    tester,
  ) async {
    final syncService = await pumpController(
      tester,
      autoRefreshMinutes: 5,
      syncEnabled: false,
    );

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();

    expect(syncService.refreshCalls, isEmpty);

    await disposeController(tester);
  });
}
