import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/app/settings_routes.dart';
import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/screens/settings_screen.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/accounts/account_store.dart';
import 'package:fleur/services/settings/app_settings.dart';

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

void main() {
  Account settingsAccount() {
    return buildTestAccount(
      id: 'settings-account',
      name: 'Settings Account',
      isPrimary: true,
    );
  }

  List<Override> servicesOverrides() {
    final account = settingsAccount();
    return [
      accountStoreProvider.overrideWithValue(
        _FakeAccountStore(
          AccountsState(
            version: AccountStore.currentVersion,
            activeAccountId: account.id,
            accounts: [account],
          ),
        ),
      ),
      appSettingsStoreProvider.overrideWithValue(
        FakeAppSettingsStore(AppSettings.defaults()),
      ),
    ];
  }

  // Helper to pump the Settings Screen with a specific width
  Future<void> pumpSettingsScreen(
    WidgetTester tester,
    double width, {
    SettingsTab? initialTab,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(initialTab: initialTab),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Settings Screen starts with List in Narrow Mode', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 400); // Narrow

    // Should see "Settings" title
    expect(find.text('Settings'), findsOneWidget);
    // Should find App Preferences in the list
    expect(find.text('App Preferences'), findsOneWidget);
    // Should NOT see detail content (e.g. "System Language" dropdown from App Preferences)
    // Note: App Preferences tab has "Language" header.
    expect(find.text('System Language'), findsNothing);
  });

  testWidgets('Settings Screen navigates to Detail in Narrow Mode', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 400);

    // Tap App Preferences
    await tester.tap(find.text('App Preferences'));
    await tester.pumpAndSettle();

    // Should now see Detail Content
    expect(find.text('System language'), findsOneWidget);

    // Verify Back Button works
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Back to list
    expect(find.text('System Language'), findsNothing);
    expect(find.text('App Preferences'), findsOneWidget);
  });

  testWidgets('App Preferences detail shows a single title in narrow mode', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 400);

    await tester.tap(find.text('App Preferences'));
    await tester.pumpAndSettle();

    expect(find.text('App Preferences'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('Subscriptions detail shows a single title in narrow mode', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 400);

    await tester.tap(find.text('Subscriptions'));
    await tester.pumpAndSettle();

    expect(find.text('Subscriptions'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('Settings Screen restores state when resizing Narrow -> Wide', (
    tester,
  ) async {
    // Start Narrow
    await pumpSettingsScreen(tester, 400);

    // Select App Preferences
    await tester.tap(find.text('App Preferences'));
    await tester.pumpAndSettle();
    expect(find.text('System language'), findsOneWidget);

    // Resize to Wide
    tester.view.physicalSize = const Size(1000, 800);
    await tester.pumpAndSettle();

    // Should see Split View
    // Sidebar item should be selected (visual check hard in test, but we check content presence)
    // Content should be visible
    expect(find.text('System language'), findsOneWidget);

    // Check if Sidebar is also visible (Wide mode has both)
    // Sidebar list item "App Preferences" should exist
    expect(
      find.text('App Preferences'),
      findsAny,
    ); // Might find 2 (sidebar + header?) or just 1
  });

  testWidgets('Settings Screen defaults to first item in Wide Mode', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 1000); // Wide

    // Uses default selection (index 0 -> App Preferences)
    expect(find.text('System language'), findsOneWidget);
    expect(find.text('App Preferences'), findsAtLeastNWidgets(2));
  });

  testWidgets(
    'Settings Screen opens Services detail from initial tab in narrow mode',
    (tester) async {
      await pumpSettingsScreen(
        tester,
        400,
        initialTab: SettingsTab.services,
        overrides: servicesOverrides(),
      );

      expect(find.text('Services'), findsOneWidget);
      expect(
        find.byKey(const Key('services_account_tile_settings-account')),
        findsOneWidget,
      );
      expect(find.text('System language'), findsNothing);
    },
  );

  testWidgets(
    'Settings Screen selects Services from initial tab in wide mode',
    (tester) async {
      await pumpSettingsScreen(
        tester,
        1000,
        initialTab: SettingsTab.services,
        overrides: servicesOverrides(),
      );

      expect(
        find.byKey(const Key('services_account_tile_settings-account')),
        findsOneWidget,
      );
      expect(find.text('System language'), findsNothing);
    },
  );

  testWidgets('AppLocalizations uses strict pathNotFound message in English', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            expect(
              l10n.pathNotFound('/tmp/example'),
              'Path does not exist: /tmp/example',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('AppLocalizations uses strict pathNotFound message in Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            expect(l10n.pathNotFound('/tmp/example'), '路径不存在：/tmp/example');
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets(
    'AppLocalizations uses strict pathNotFound message in Chinese Traditional',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              expect(l10n.pathNotFound('/tmp/example'), '路徑不存在：/tmp/example');
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    },
  );

  testWidgets('AppLocalizations uses strict openFailedGeneral in English', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            expect(
              l10n.openFailedGeneral,
              'Couldn\'t open this location. Check permissions and try again.',
            );
            expect(
              l10n.macosMenuLanguageRestartHint,
              'Menu bar language may require restarting the app to fully apply.',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('AppLocalizations uses strict openFailedGeneral in Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            expect(l10n.openFailedGeneral, '无法打开该位置，请检查权限或稍后重试。');
            expect(l10n.macosMenuLanguageRestartHint, '菜单栏语言可能需要重启应用才能完全生效。');
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets(
    'AppLocalizations uses strict openFailedGeneral in Chinese Traditional',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              expect(l10n.openFailedGeneral, '無法打開該位置，請檢查權限或稍後重試。');
              expect(
                l10n.macosMenuLanguageRestartHint,
                '選單列語言可能需要重新啟動應用程式才能完全生效。',
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    },
  );
}
