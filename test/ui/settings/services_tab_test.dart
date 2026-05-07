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

  testWidgets('Fever hides Miniflux server content fetch mode', (tester) async {
    await pumpTab(
      tester,
      account: buildTestAccount(type: AccountType.fever, name: 'Fever'),
    );

    expect(find.text('Miniflux strategy'), findsNothing);
    expect(find.text('Web page fetching'), findsNothing);
    expect(find.text('Server (Miniflux fetch-content)'), findsNothing);
  });

  testWidgets('Miniflux shows server content fetch mode', (tester) async {
    await pumpTab(
      tester,
      account: buildTestAccount(type: AccountType.miniflux, name: 'Miniflux'),
    );

    expect(find.text('Miniflux strategy'), findsOneWidget);
    expect(find.text('Web page fetching'), findsOneWidget);
    expect(find.text('Client (Readability)'), findsOneWidget);
  });
}
