import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/accounts/account_store.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/theme/fleur_theme_extensions.dart';
import 'package:fleur/widgets/account_manager_dialog.dart';

import '../test_utils/critical_workflow_test_support.dart';

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

Future<void> _pumpAccountManagerDialog(WidgetTester tester) async {
  final local = buildTestAccount(id: 'local', name: 'Local', isPrimary: true);
  final miniflux = buildTestAccount(
    id: 'miniflux',
    type: AccountType.miniflux,
    name: 'Miniflux',
    baseUrl: 'https://rss.example.com',
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountStoreProvider.overrideWithValue(
          _FakeAccountStore(
            AccountsState(
              version: AccountStore.currentVersion,
              activeAccountId: local.id,
              accounts: [local, miniflux],
            ),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: AccountManagerDialog()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AccountManagerDialog uses Fleur tokens for list surfaces', (
    tester,
  ) async {
    await _pumpAccountManagerDialog(tester);

    final theme = Theme.of(tester.element(find.byType(AccountManagerDialog)));
    final surfaces = theme.fleurSurface;
    final states = theme.fleurState;

    final listSurface = tester.widget<DecoratedBox>(
      find.byKey(const Key('account_manager_list_surface')),
    );
    final listDecoration = listSurface.decoration as BoxDecoration;
    expect(listDecoration.color, surfaces.card);
    expect(listDecoration.border?.top.color, surfaces.subtleDivider);

    final activeRow = tester.widget<AnimatedContainer>(
      find.byKey(const Key('account_manager_account_local')),
    );
    final activeDecoration = activeRow.decoration as BoxDecoration;
    expect(activeDecoration.color, surfaces.cardSelected);
    expect(activeDecoration.border?.top.color, states.focusRing);

    final inactiveRow = tester.widget<AnimatedContainer>(
      find.byKey(const Key('account_manager_account_miniflux')),
    );
    final inactiveDecoration = inactiveRow.decoration as BoxDecoration;
    expect(inactiveDecoration.color, surfaces.card);
    expect(inactiveDecoration.border?.top.color, surfaces.subtleDivider);
  });

  testWidgets('Account type cards use Fleur card and divider tokens', (
    tester,
  ) async {
    await _pumpAccountManagerDialog(tester);

    await tester.tap(find.byKey(const Key('account_manager_add_button')));
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(AlertDialog)));
    final surfaces = theme.fleurSurface;
    final cards = tester.widgetList<Card>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Card),
      ),
    );

    expect(cards, hasLength(4));
    expect(find.text('Add Google Reader API'), findsOneWidget);
    for (final card in cards) {
      final shape = card.shape! as RoundedRectangleBorder;
      expect(card.color, surfaces.card);
      expect(shape.side.color, surfaces.subtleDivider);
    }
  });
}
