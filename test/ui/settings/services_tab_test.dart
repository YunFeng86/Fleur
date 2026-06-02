import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/models/feed.dart';
import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/refresh_all_providers.dart';
import 'package:fleur/repositories/feed_repository.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/accounts/account_store.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/sync/backend_capabilities.dart';
import 'package:fleur/services/sync/refresh_all_coordinator.dart';
import 'package:fleur/services/sync/sync_service.dart';
import 'package:fleur/ui/settings/settings_targets.dart';
import 'package:fleur/ui/settings/tabs/services_tab.dart';
import 'package:fleur/ui/settings/widgets/section_header.dart';

import '../../test_utils/critical_workflow_test_support.dart';

class _FakeAccountStore extends AccountStore {
  _FakeAccountStore(this.state);

  AccountsState state;

  @override
  Future<AccountsState> loadOrCreate() async => state;

  @override
  Future<void> save(AccountsState next) async {
    state = next;
  }
}

class _FakeFeedRepository extends Fake implements FeedRepository {
  _FakeFeedRepository(this.feeds);

  final List<Feed> feeds;

  @override
  Future<List<Feed>> getAll() async => feeds;
}

Feed _feed(int id) {
  return Feed()
    ..id = id
    ..url = 'https://example.com/$id.xml'
    ..title = 'Feed $id';
}

void main() {
  AccountsState accountsState({
    required List<Account> accounts,
    String? activeAccountId,
  }) {
    return AccountsState(
      version: AccountStore.currentVersion,
      activeAccountId: activeAccountId ?? accounts.first.id,
      accounts: accounts,
    );
  }

  Future<({FakeAppSettingsStore appStore, _FakeAccountStore accountStore})>
  pumpTabWithStores(
    WidgetTester tester, {
    Account? account,
    List<Account>? accounts,
    String? activeAccountId,
    AppSettings? appSettings,
    List<Override> overrides = const <Override>[],
  }) async {
    final appStore = FakeAppSettingsStore(
      appSettings ?? AppSettings.defaults(),
    );
    final resolvedAccounts = accounts ?? [account!];
    final accountStore = _FakeAccountStore(
      accountsState(
        accounts: resolvedAccounts,
        activeAccountId: activeAccountId,
      ),
    );
    await pumpLocalizedTestApp(
      tester,
      home: Scaffold(
        body: ServicesTab(
          showPageTitle: false,
          targetController: SettingsTargetController(),
        ),
      ),
      overrides: [
        accountStoreProvider.overrideWithValue(accountStore),
        appSettingsStoreProvider.overrideWithValue(appStore),
        ...overrides,
      ],
      size: const Size(900, 1200),
    );
    await tester.pumpAndSettle();
    return (appStore: appStore, accountStore: accountStore);
  }

  Future<FakeAppSettingsStore> pumpTab(
    WidgetTester tester, {
    required Account account,
    AppSettings? appSettings,
  }) async {
    final stores = await pumpTabWithStores(
      tester,
      account: account,
      appSettings: appSettings,
    );
    return stores.appStore;
  }

  testWidgets('Local keeps refresh-all semantics and hides remote strategy', (
    tester,
  ) async {
    await pumpTab(
      tester,
      account: buildTestAccount(type: AccountType.local, name: 'Local'),
    );

    expect(find.text('Refresh sources'), findsWidgets);
    expect(find.text('Account sync'), findsNothing);
    expect(find.text('Refresh Concurrency'), findsOneWidget);
    expect(find.text('Remote sync strategy'), findsNothing);
    expect(find.text('Entries per sync'), findsNothing);
    expect(find.text('Remote fetch concurrency'), findsNothing);
  });

  testWidgets('Fever hides source refresh and shows remote entry window', (
    tester,
  ) async {
    await pumpTab(
      tester,
      account: buildTestAccount(type: AccountType.fever, name: 'Fever'),
    );

    expect(find.text('Account sync'), findsNothing);
    expect(find.text('Sync account'), findsNothing);
    expect(find.text('Refresh sources'), findsNothing);
    expect(find.text('Refresh Concurrency'), findsNothing);
    expect(find.text('Remote sync strategy'), findsOneWidget);
    expect(find.textContaining('Fever syncs unread'), findsOneWidget);
    expect(find.text('Entries per sync'), findsOneWidget);
    expect(find.text('Remote fetch concurrency'), findsOneWidget);
    expect(find.text('Miniflux strategy'), findsNothing);
    expect(find.text('Web page fetching'), findsNothing);
    expect(find.text('Server (Miniflux fetch-content)'), findsNothing);
  });

  testWidgets('Miniflux shows source refresh, entry window, and fetch mode', (
    tester,
  ) async {
    await pumpTab(
      tester,
      account: buildTestAccount(type: AccountType.miniflux, name: 'Miniflux'),
    );

    expect(find.text('Refresh sources'), findsWidgets);
    expect(find.text('Account sync'), findsNothing);
    expect(find.text('Sync account'), findsNothing);
    expect(find.text('Refresh Concurrency'), findsNothing);
    expect(find.text('Remote sync strategy'), findsOneWidget);
    expect(
      find.textContaining('Miniflux can page through remote entries'),
      findsOneWidget,
    );
    expect(find.text('Entries per sync'), findsOneWidget);
    expect(find.text('Remote fetch concurrency'), findsOneWidget);
    expect(find.text('Web page fetching'), findsOneWidget);
    expect(find.text('Client (Readability)'), findsOneWidget);
  });

  testWidgets('source refresh button uses inline loading while refreshing', (
    tester,
  ) async {
    final finishRefresh = Completer<void>();
    final syncService = FakeSyncService(
      onRefresh: (feedIds) async {
        await finishRefresh.future;
        return const BatchRefreshResult(<FeedRefreshResult>[]);
      },
    );
    final account = buildTestAccount(type: AccountType.local, name: 'Local');
    final coordinator = RefreshSourcesCoordinator(
      capabilities: BackendCapabilities.forAccountType(account.type),
      feeds: _FakeFeedRepository([_feed(1)]),
      syncService: syncService,
    );

    await pumpTabWithStores(
      tester,
      account: account,
      overrides: [
        refreshSourcesCoordinatorProvider.overrideWithValue(coordinator),
      ],
    );

    final buttonFinder = find.byKey(
      const Key('services_refresh_sources_button'),
    );
    expect(buttonFinder, findsOneWidget);
    expect(
      tester.widget<SettingsActionButton>(buttonFinder).onPressed,
      isNotNull,
    );

    await tester.tap(buttonFinder);
    await tester.pump();

    expect(syncService.refreshCalls, [
      [1],
    ]);
    expect(tester.widget<SettingsActionButton>(buttonFinder).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Refreshing 0/0...'), findsNothing);

    await tester.tap(buttonFinder);
    await tester.pump();
    expect(syncService.refreshCalls, [
      [1],
    ]);

    finishRefresh.complete();
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<SettingsActionButton>(buttonFinder).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'account section renders expanded list with active account first',
    (tester) async {
      final local = buildTestAccount(
        id: 'local',
        type: AccountType.local,
        name: 'Local',
        isPrimary: true,
      );
      final miniflux = buildTestAccount(
        id: 'miniflux',
        type: AccountType.miniflux,
        name: 'Miniflux',
        baseUrl: 'https://rss.example.com',
      );

      await pumpTabWithStores(
        tester,
        accounts: [local, miniflux],
        activeAccountId: miniflux.id,
      );

      expect(
        find.byKey(const Key('services_account_tile_miniflux')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('services_account_tile_local')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('services_account_selected_miniflux')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('services_account_selected_local')),
        findsNothing,
      );

      final activeTop = tester
          .getTopLeft(find.byKey(const Key('services_account_tile_miniflux')))
          .dy;
      final localTop = tester
          .getTopLeft(find.byKey(const Key('services_account_tile_local')))
          .dy;
      expect(activeTop, lessThan(localTop));
    },
  );

  testWidgets('tapping an account switches the active account', (tester) async {
    final local = buildTestAccount(
      id: 'local',
      type: AccountType.local,
      name: 'Local',
      isPrimary: true,
    );
    final fever = buildTestAccount(
      id: 'fever',
      type: AccountType.fever,
      name: 'Fever',
      baseUrl: 'https://fever.example.com',
    );
    final stores = await pumpTabWithStores(
      tester,
      accounts: [local, fever],
      activeAccountId: fever.id,
    );

    await tester.tap(find.byKey(const Key('services_account_tile_local')));
    await tester.pumpAndSettle();

    expect(stores.accountStore.state.activeAccountId, local.id);
    expect(
      find.byKey(const Key('services_account_selected_local')),
      findsOneWidget,
    );
  });

  testWidgets('account menu keeps delete disabled for primary account', (
    tester,
  ) async {
    final local = buildTestAccount(
      id: 'local',
      type: AccountType.local,
      name: 'Local',
      isPrimary: true,
    );

    await pumpTabWithStores(tester, accounts: [local]);
    await tester.tap(find.byKey(const Key('services_account_menu_local')));
    await tester.pumpAndSettle();

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    final deleteItem = tester.widget<MenuItemButton>(
      find.byKey(const Key('services_account_delete_local')),
    );
    expect(deleteItem.onPressed, isNull);
  });

  testWidgets('add or register account opens account type picker', (
    tester,
  ) async {
    await pumpTab(
      tester,
      account: buildTestAccount(type: AccountType.local, name: 'Local'),
    );

    await tester.tap(find.byKey(const Key('services_add_account')));
    await tester.pumpAndSettle();

    expect(find.text('Add Local'), findsOneWidget);
    expect(find.text('Add Miniflux'), findsOneWidget);
    expect(find.text('Add Fever'), findsOneWidget);
  });

  testWidgets(
    'source refresh interval persists and explains background limits',
    (tester) async {
      final appStore = await pumpTab(
        tester,
        account: buildTestAccount(type: AccountType.local, name: 'Local'),
      );

      expect(find.textContaining('Mobile background refresh'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('services_source_refresh_interval_select')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Every 5 min'), findsNothing);
      expect(find.text('Every 15 min').last, findsOneWidget);
      expect(find.text('Every 30 min').last, findsOneWidget);
      expect(find.text('Every 60 min').last, findsOneWidget);

      await tester.tap(find.text('Every 15 min').last);
      await tester.pumpAndSettle();

      expect(appStore.settings.sourceRefreshMinutes, 15);
    },
  );

  testWidgets('remote entry window updates the shared setting', (tester) async {
    final appStore = await pumpTab(
      tester,
      account: buildTestAccount(type: AccountType.fever, name: 'Fever'),
    );

    await tester.tap(
      find.byKey(const Key('services_remote_entries_limit_select')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('800').last);
    await tester.pumpAndSettle();

    expect(appStore.settings.remoteEntriesLimit, 800);
    expect(appStore.settings.minifluxEntriesLimit, 800);
  });

  testWidgets('remote fetch concurrency updates the shared setting', (
    tester,
  ) async {
    final appStore = await pumpTab(
      tester,
      account: buildTestAccount(type: AccountType.fever, name: 'Fever'),
    );

    await tester.tap(
      find.byKey(const Key('services_remote_fetch_concurrency_select')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('4').last);
    await tester.pumpAndSettle();

    expect(appStore.settings.remoteFetchConcurrency, 4);
  });
}
