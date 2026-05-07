import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/accounts/account_store.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/ui/settings/tabs/services_tab.dart';

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

void main() {
  AccountsState accountsState(Account account) {
    return AccountsState(
      version: AccountStore.currentVersion,
      activeAccountId: account.id,
      accounts: [account],
    );
  }

  Future<void> pumpTab(WidgetTester tester, {required Account account}) async {
    await pumpLocalizedTestApp(
      tester,
      home: const Scaffold(body: ServicesTab(showPageTitle: false)),
      overrides: [
        accountStoreProvider.overrideWithValue(
          _FakeAccountStore(accountsState(account)),
        ),
        appSettingsStoreProvider.overrideWithValue(
          FakeAppSettingsStore(AppSettings.defaults()),
        ),
      ],
      size: const Size(900, 1200),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Local keeps refresh-all semantics and hides remote strategy', (
    tester,
  ) async {
    await pumpTab(
      tester,
      account: buildTestAccount(type: AccountType.local, name: 'Local'),
    );

    expect(find.text('Refresh all'), findsWidgets);
    expect(find.text('Account sync'), findsNothing);
    expect(find.text('Remote sync strategy'), findsNothing);
    expect(find.text('Entries per sync'), findsNothing);
  });

  testWidgets('Fever shows account sync and remote entry window', (
    tester,
  ) async {
    await pumpTab(
      tester,
      account: buildTestAccount(type: AccountType.fever, name: 'Fever'),
    );

    expect(find.text('Account sync'), findsOneWidget);
    expect(find.text('Sync account'), findsOneWidget);
    expect(find.text('Remote sync strategy'), findsOneWidget);
    expect(find.text('Entries per sync'), findsOneWidget);
    expect(find.text('Miniflux strategy'), findsNothing);
    expect(find.text('Web page fetching'), findsNothing);
    expect(find.text('Server (Miniflux fetch-content)'), findsNothing);
  });

  testWidgets('Miniflux shows account sync, entry window, and fetch mode', (
    tester,
  ) async {
    await pumpTab(
      tester,
      account: buildTestAccount(type: AccountType.miniflux, name: 'Miniflux'),
    );

    expect(find.text('Account sync'), findsOneWidget);
    expect(find.text('Sync account'), findsOneWidget);
    expect(find.text('Remote sync strategy'), findsOneWidget);
    expect(find.text('Entries per sync'), findsOneWidget);
    expect(find.text('Web page fetching'), findsOneWidget);
    expect(find.text('Client (Readability)'), findsOneWidget);
  });
}
