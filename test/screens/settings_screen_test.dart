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
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/theme/seed_color_presets.dart';
import 'package:fleur/utils/platform.dart';

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

  FakeAppSettingsStore appSettingsStore([
    AppSettings settings = const AppSettings(),
  ]) {
    return FakeAppSettingsStore(settings);
  }

  List<Override> servicesOverrides({FakeAppSettingsStore? settingsStore}) {
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
        settingsStore ?? appSettingsStore(AppSettings.defaults()),
      ),
    ];
  }

  // Helper to pump the Settings Screen with a specific width
  Future<void> pumpSettingsScreen(
    WidgetTester tester,
    double width, {
    SettingsTab? initialTab,
    bool showBack = false,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(initialTab: initialTab, showBack: showBack),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Settings Screen starts with List in Narrow Mode', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 400); // Narrow

    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(const Key('settings_paper_surface')), findsOneWidget);
    expect(
      find.byKey(const Key('settings_search_placeholder')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings_search_inside_paper')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings_search_outside_paper')),
      findsNothing,
    );
    expect(find.byKey(const Key('settings_sidebar_button')), findsOneWidget);
    expect(find.byKey(const Key('settings_sidebar')), findsNothing);
    expect(find.text('App Preferences'), findsOneWidget);
    expect(
      find.byKey(const Key('settings_list_nav_app-preferences')),
      findsOneWidget,
    );
    expect(find.text('System language'), findsNothing);
  });

  testWidgets('Settings Screen navigates to Detail in Narrow Mode', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 400);

    await tester.tap(find.text('App Preferences'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('app_preferences_language_select')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('settings_back_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings_back_button')));
    await tester.pumpAndSettle();

    expect(find.text('System language'), findsNothing);
    expect(find.text('App Preferences'), findsOneWidget);
  });

  testWidgets('App Preferences detail shows a single title in narrow mode', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 400);

    await tester.tap(find.text('App Preferences'));
    await tester.pumpAndSettle();

    expect(find.text('App Preferences'), findsOneWidget);
    expect(find.byKey(const Key('settings_back_button')), findsOneWidget);
  });

  testWidgets('Subscriptions detail shows a single title in narrow mode', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 400);

    await tester.tap(find.text('Subscriptions'));
    await tester.pumpAndSettle();

    expect(find.text('Subscriptions'), findsOneWidget);
    expect(find.byKey(const Key('settings_back_button')), findsOneWidget);
  });

  testWidgets('Settings Screen expands temporary sidebar in narrow mode', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 900, overrides: servicesOverrides());

    final paperBefore = tester.getTopLeft(
      find.byKey(const Key('settings_paper_surface')),
    );
    expect(
      tester.getCenter(find.byKey(const Key('settings_search_placeholder'))).dx,
      closeTo(
        tester.getCenter(find.byKey(const Key('settings_paper_surface'))).dx,
        1,
      ),
    );
    expect(find.byKey(const Key('settings_sidebar')), findsNothing);

    await tester.tap(find.byKey(const Key('settings_sidebar_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings_sidebar')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('settings_paper_surface'))).dx,
      greaterThan(paperBefore.dx),
    );

    await tester.tap(find.byKey(const Key('settings_nav_services')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings_sidebar')), findsNothing);
    expect(find.text('Services'), findsOneWidget);
    expect(
      find.byKey(const Key('services_account_tile_settings-account')),
      findsOneWidget,
    );
  });

  testWidgets('Settings Screen restores state when resizing Narrow -> Wide', (
    tester,
  ) async {
    // Start Narrow
    await pumpSettingsScreen(tester, 400);

    // Select App Preferences
    await tester.tap(find.text('App Preferences'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('app_preferences_language_select')),
      findsOneWidget,
    );

    // Resize to Wide
    tester.view.physicalSize = const Size(1000, 800);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('app_preferences_language_select')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('settings_sidebar')), findsOneWidget);
    expect(find.byKey(const Key('settings_sidebar_button')), findsNothing);
    expect(find.byKey(const Key('settings_back_button')), findsNothing);
    expect(
      find.byKey(const Key('settings_search_outside_paper')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('settings_search_inside_paper')), findsNothing);
    expect(find.text('App Preferences'), findsNWidgets(2));
  });

  testWidgets('Settings Screen defaults to first item in Wide Mode', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 1500); // Wide

    expect(find.byKey(const Key('settings_sidebar')), findsOneWidget);
    expect(find.byKey(const Key('settings_sidebar_button')), findsNothing);
    expect(find.byKey(const Key('settings_back_button')), findsNothing);
    expect(find.byKey(const Key('settings_paper_surface')), findsOneWidget);
    expect(
      find.byKey(const Key('settings_search_placeholder')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings_search_outside_paper')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('settings_search_inside_paper')), findsNothing);
    expect(
      find.byKey(const Key('settings_nav_app-preferences')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('app_preferences_language_select')),
      findsOneWidget,
    );
    expect(find.text('App Preferences'), findsNWidgets(2));

    final paperSize = tester.getSize(
      find.byKey(const Key('settings_paper_surface')),
    );
    final searchSize = tester.getSize(
      find.byKey(const Key('settings_search_placeholder')),
    );
    expect(paperSize.width, closeTo(960, 1));
    expect(searchSize.width, greaterThan(900));
    final searchDockBottom = tester
        .getBottomLeft(find.byKey(const Key('settings_search_outside_paper')))
        .dy;
    final paperTop = tester
        .getTopLeft(find.byKey(const Key('settings_paper_surface')))
        .dy;
    expect(paperTop - searchDockBottom, closeTo(8, 1));
    expect(
      tester.getCenter(find.byKey(const Key('settings_search_placeholder'))).dx,
      closeTo(
        tester.getCenter(find.byKey(const Key('settings_paper_surface'))).dx,
        1,
      ),
    );
  });

  testWidgets('Settings Screen shows close back button in wide route mode', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 1000, showBack: true);

    expect(find.byKey(const Key('settings_sidebar')), findsOneWidget);
    expect(find.byKey(const Key('settings_sidebar_button')), findsNothing);
    expect(find.byKey(const Key('settings_back_button')), findsOneWidget);
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

  testWidgets('App Preferences theme controls persist mode and seed color', (
    tester,
  ) async {
    final store = appSettingsStore(AppSettings.defaults());
    await pumpSettingsScreen(
      tester,
      1000,
      overrides: servicesOverrides(settingsStore: store),
    );

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(store.settings.themeMode, ThemeMode.dark);

    await tester.tap(
      find.byKey(const Key('app_preferences_seed_color_pink_card')),
    );
    await tester.pumpAndSettle();

    expect(store.settings.useDynamicColor, isFalse);
    expect(store.settings.seedColorPreset, SeedColorPreset.pink);
  });

  testWidgets('App Preferences shows dynamic color card only on Android', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    await pumpSettingsScreen(tester, 1000, overrides: servicesOverrides());

    expect(
      find.byKey(const Key('app_preferences_dynamic_color_card')),
      findsOneWidget,
    );

    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpSettingsScreen(tester, 1000, overrides: servicesOverrides());

    expect(
      find.byKey(const Key('app_preferences_dynamic_color_card')),
      findsNothing,
    );
  });

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
