import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/app/settings_routes.dart';
import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/core_providers.dart';
import 'package:fleur/providers/settings_providers.dart';
import 'package:fleur/screens/settings_screen.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/reader_settings.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/theme/fleur_theme_extensions.dart';
import 'package:fleur/theme/seed_color_presets.dart';
import 'package:fleur/ui/app_shell.dart';
import 'package:fleur/ui/shell_chrome_layout.dart';
import 'package:fleur/ui/settings/widgets/settings_controls.dart';
import 'package:fleur/ui/sidebar_layout.dart';
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
    double height = 800,
    SettingsTab? initialTab,
    String? initialSettingId,
    bool showBack = false,
    bool dynamicColorAvailable = false,
    FakeReaderSettingsStore? readerSettingsStore,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readerSettingsStoreProvider.overrideWithValue(
            readerSettingsStore ??
                FakeReaderSettingsStore(const ReaderSettings()),
          ),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.light(dynamicColorAvailable: dynamicColorAvailable),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(
            initialTab: initialTab,
            initialSettingId: initialSettingId,
            showBack: showBack,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> pumpSettingsShell(
    WidgetTester tester,
    double width, {
    double height = 800,
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readerSettingsStoreProvider.overrideWithValue(
            FakeReaderSettingsStore(const ReaderSettings()),
          ),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppShell(
            currentUri: Uri(path: '/settings'),
            child: const SettingsScreen(showBack: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
  }

  Finder settingsSwitchControl(Key tileKey) {
    return find.descendant(
      of: find.byKey(tileKey),
      matching: find.byType(SettingsCompactSwitch),
    );
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
    expect(find.text('Appearance'), findsOneWidget);
    expect(
      find.byKey(const Key('settings_list_nav_app-preferences')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings_list_nav_appearance')),
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

  testWidgets('Appearance detail shows theme and reader display controls', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 400);

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('App appearance'), findsOneWidget);
    expect(find.text('Reader appearance'), findsWidgets);
    expect(find.text('Code appearance'), findsNothing);
    expect(find.text('Theme mode'), findsOneWidget);
    expect(find.text('Accent color'), findsOneWidget);
    expect(
      find.byKey(const Key('appearance_reader_font_family_options')),
      findsOneWidget,
    );
    expect(find.text('Font size'), findsOneWidget);
    expect(find.text('Line height'), findsOneWidget);
    expect(find.text('Reading width'), findsOneWidget);
    expect(find.text('Reading texture'), findsOneWidget);
    expect(
      find.byKey(const Key('appearance_advanced_fonts_tile')),
      findsOneWidget,
    );
    expect(find.text('Advanced font settings'), findsOneWidget);
    expect(find.text('Wrap code lines'), findsOneWidget);
    expect(
      find.byKey(const Key('appearance_reader_font_stack_input')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('appearance_code_font_size_slider')),
      findsNothing,
    );
    expect(find.byKey(const Key('settings_back_button')), findsOneWidget);
  });

  testWidgets('Appearance fonts detail back returns to Appearance first', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 400, overrides: servicesOverrides());

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('appearance_advanced_fonts_tile')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearance_advanced_fonts_tile')));
    await tester.pumpAndSettle();

    expect(find.text('Advanced font settings'), findsOneWidget);
    expect(
      find.byKey(const Key('appearance_standard_font_stack_input')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('settings_back_button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('appearance_standard_font_stack_input')),
      findsNothing,
    );
    expect(find.text('App appearance'), findsOneWidget);
    expect(
      find.byKey(const Key('appearance_advanced_fonts_tile')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('settings_back_button')));
    await tester.pumpAndSettle();

    expect(find.text('App appearance'), findsNothing);
    expect(
      find.byKey(const Key('settings_list_nav_appearance')),
      findsOneWidget,
    );
  });

  testWidgets('Settings Screen expands temporary sidebar in off-canvas mode', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 650, overrides: servicesOverrides());

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

  testWidgets('Settings Screen uses a navigation rail at medium width', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 800);

    expect(find.byKey(const Key('settings_sidebar')), findsNothing);
    expect(find.byKey(const Key('settings_navigation_rail')), findsOneWidget);
    expect(find.byKey(const Key('settings_sidebar_button')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('settings_content_layer'))).dx,
      kSidebarRailWidth,
    );
    expect(
      find.byKey(const Key('settings_search_outside_paper')),
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
    expect(find.byKey(const Key('settings_sidebar_button')), findsOneWidget);
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
    expect(find.byKey(const Key('settings_sidebar_button')), findsOneWidget);
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
    expect(find.byKey(const Key('settings_nav_appearance')), findsOneWidget);
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
    expect(searchSize.width, closeTo(720, 1));
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

  testWidgets('Settings navigation keeps selection feedback synchronized', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 1500);

    TextButton button(String tab) {
      return tester.widget<TextButton>(
        find.descendant(
          of: find.byKey(Key('settings_nav_button_$tab')),
          matching: find.byType(TextButton),
        ),
      );
    }

    final theme = Theme.of(tester.element(find.byType(SettingsScreen)));
    final selectedColor = theme.fleurSurface.cardSelected;
    expect(
      button('app-preferences').style?.backgroundColor?.resolve({}),
      selectedColor,
    );
    expect(
      button('appearance').style?.backgroundColor?.resolve({}),
      Colors.transparent,
    );

    final appPreferencesLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('settings_nav_app-preferences')),
        matching: find.text('App Preferences'),
      ),
    );
    expect(appPreferencesLabel.style?.fontWeight, FontWeight.w500);

    await tester.tap(find.byKey(const Key('settings_nav_appearance')));
    await tester.pump();

    expect(
      button('app-preferences').style?.backgroundColor?.resolve({}),
      Colors.transparent,
    );
    expect(
      button('appearance').style?.backgroundColor?.resolve({}),
      selectedColor,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('settings_content_layer')),
        matching: find.byType(AnimatedSwitcher),
      ),
      findsNothing,
    );
  });

  testWidgets('Settings Screen shows close back button in wide route mode', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 1000, showBack: true);

    expect(find.byKey(const Key('settings_sidebar')), findsOneWidget);
    expect(find.byKey(const Key('settings_sidebar_button')), findsOneWidget);
    expect(find.byKey(const Key('settings_back_button')), findsOneWidget);
  });

  testWidgets('Settings Screen does not own native window chrome', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    await pumpSettingsScreen(tester, 1000, showBack: true);

    expect(find.byKey(const Key('shell_title_bar')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('settings_content_layer'))).dy,
      0,
    );
    final paperDecoration =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const Key('settings_paper_surface')),
                )
                .decoration
            as BoxDecoration;
    expect(
      paperDecoration.borderRadius,
      const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
    );
  });

  testWidgets('Windows AppShell owns one title bar above settings', (
    tester,
  ) async {
    final focusManager = FocusManager.instance;
    final previousStrategy = focusManager.highlightStrategy;
    focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => focusManager.highlightStrategy = previousStrategy);
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    await pumpSettingsShell(tester, 1000);

    expect(find.byKey(const Key('shell_title_bar')), findsOneWidget);
    expect(find.byKey(const Key('shell_sidebar_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_back_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_forward_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_search_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_window_close_button')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('settings_content_layer'))).dy,
      kWorkspaceHeaderHeight,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('shell_title_bar_divider'))).dx,
      kDefaultWorkspaceSidebarWidth + kSidebarContentDividerWidth,
    );
    expect(
      tester.getCenter(find.byKey(const Key('shell_sidebar_button'))).dx,
      kTitleBarExpectedSidebarRailWidth / 2,
    );
    expect(
      tester
          .getCenter(
            find.descendant(
              of: find.byKey(const Key('settings_nav_button_app-preferences')),
              matching: find.byType(Icon),
            ),
          )
          .dx,
      kTitleBarExpectedSidebarRailWidth / 2,
    );
  });

  testWidgets('Settings title-bar toggle keeps feed preference independent', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final container = await pumpSettingsShell(
      tester,
      800,
      overrides: [
        sidebarPresentationModeProvider.overrideWith(
          (ref) => SidebarPresentationMode.collapsed,
        ),
      ],
    );

    expect(find.byKey(const Key('settings_navigation_rail')), findsOneWidget);
    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pumpAndSettle();

    expect(container.read(settingsTemporaryNavigationOpenProvider), isTrue);
    expect(
      container.read(sidebarPresentationModeProvider),
      SidebarPresentationMode.collapsed,
    );
  });

  testWidgets('Settings temporary navigation traps and restores focus', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    await pumpSettingsShell(tester, 650);
    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pumpAndSettle();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'shell-temporary-navigation',
    );
    for (var index = 0; index < 12; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focusContext = FocusManager.instance.primaryFocus?.context;
      expect(focusContext, isNotNull);
      expect(
        find.ancestor(
          of: find.byElementPredicate(
            (element) => identical(element, focusContext),
          ),
          matching: find.byKey(const Key('settings_sidebar')),
        ),
        findsOneWidget,
      );
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings_sidebar')), findsNothing);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'shell-navigation-toggle',
    );
  });

  testWidgets('Settings title-bar toggle collapses after inline re-expansion', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final container = await pumpSettingsShell(tester, 1000);

    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pumpAndSettle();
    expect(
      container.read(settingsSidebarPresentationModeProvider),
      SidebarPresentationMode.collapsed,
    );
    expect(find.byKey(const Key('settings_navigation_rail')), findsOneWidget);

    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pumpAndSettle();
    expect(
      container.read(settingsSidebarPresentationModeProvider),
      SidebarPresentationMode.expanded,
    );
    expect(container.read(settingsTemporaryNavigationOpenProvider), isFalse);
    expect(find.byKey(const Key('settings_sidebar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pumpAndSettle();
    expect(
      container.read(settingsSidebarPresentationModeProvider),
      SidebarPresentationMode.collapsed,
    );
    expect(find.byKey(const Key('settings_navigation_rail')), findsOneWidget);
  });

  testWidgets('Content-only settings header owns adaptive navigation toggle', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final container = await pumpSettingsShell(tester, 1200);

    expect(find.byKey(const Key('shell_title_bar')), findsNothing);
    expect(find.byKey(const Key('shell_window_close_button')), findsNothing);
    expect(find.byKey(const Key('settings_sidebar')), findsOneWidget);
    expect(find.byKey(const Key('settings_sidebar_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings_sidebar_button')));
    await tester.pumpAndSettle();

    expect(
      container.read(settingsSidebarPresentationModeProvider),
      SidebarPresentationMode.collapsed,
    );
    expect(find.byKey(const Key('settings_navigation_rail')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('settings_content_layer'))).dx,
      kSidebarRailWidth,
    );
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

  testWidgets(
    'Settings Screen selects Appearance from initial tab in wide mode',
    (tester) async {
      await pumpSettingsScreen(
        tester,
        1000,
        initialTab: SettingsTab.appearance,
      );

      expect(find.text('Theme mode'), findsOneWidget);
      expect(find.text('Font size'), findsOneWidget);
      expect(
        find.byKey(const Key('appearance_reader_theme_options')),
        findsOneWidget,
      );
      expect(find.text('Reader appearance'), findsWidgets);
      expect(find.text('System language'), findsNothing);
    },
  );

  testWidgets('App Preferences does not show appearance controls', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 1000, overrides: servicesOverrides());

    expect(
      find.byKey(const Key('app_preferences_language_select')),
      findsOneWidget,
    );
    expect(find.text('Theme mode'), findsNothing);
    expect(find.text('Accent color'), findsNothing);
    expect(find.text('Font size'), findsNothing);
    expect(find.text('Reader appearance'), findsNothing);
    expect(find.text('Code appearance'), findsNothing);
    expect(find.text('Fonts and code'), findsNothing);
    expect(
      find.byKey(const Key('appearance_seed_color_pink_card')),
      findsNothing,
    );
  });

  testWidgets('App Preferences language menu uses canonical native order', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 1000, overrides: servicesOverrides());

    await tester.tap(find.byKey(const Key('app_preferences_language_select')));
    await tester.pumpAndSettle();

    const expectedLabels = [
      'System language',
      '简体中文',
      '繁體中文',
      'English',
      'Deutsch (Beta)',
      'Español (Beta)',
      'Français (Beta)',
      '日本語 (Beta)',
      '한국어 (Beta)',
      'Português (Brasil) (Beta)',
    ];

    double menuLabelTop(String label) {
      return tester.getTopLeft(find.text(label).last).dy;
    }

    for (final label in expectedLabels) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Chinese (Simplified)'), findsNothing);
    expect(find.text('Chinese (Traditional)'), findsNothing);

    for (var i = 1; i < expectedLabels.length; i++) {
      expect(
        menuLabelTop(expectedLabels[i]),
        greaterThan(menuLabelTop(expectedLabels[i - 1])),
      );
    }
  });

  testWidgets(
    'App Preferences displays legacy zh setting as Simplified Chinese',
    (tester) async {
      await pumpSettingsScreen(
        tester,
        1000,
        overrides: servicesOverrides(
          settingsStore: appSettingsStore(const AppSettings(localeTag: 'zh')),
        ),
      );

      expect(find.text('简体中文'), findsOneWidget);
      expect(find.text('zh'), findsNothing);
    },
  );

  testWidgets('Appearance theme controls persist mode and seed color', (
    tester,
  ) async {
    final store = appSettingsStore(AppSettings.defaults());
    await pumpSettingsScreen(
      tester,
      1000,
      initialTab: SettingsTab.appearance,
      overrides: servicesOverrides(settingsStore: store),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('appearance_theme_mode_segmented')),
        matching: find.text('Dark'),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.settings.themeMode, ThemeMode.dark);

    await tester.tap(find.byKey(const Key('appearance_seed_color_pink_card')));
    await tester.pumpAndSettle();

    expect(store.settings.useDynamicColor, isFalse);
    expect(store.settings.seedColorPreset, SeedColorPreset.pink);
  });

  testWidgets('Appearance theme swatch repaints during selection animation', (
    tester,
  ) async {
    await pumpSettingsScreen(
      tester,
      1000,
      initialTab: SettingsTab.appearance,
      overrides: servicesOverrides(),
    );

    final pinkCard = find.byKey(const Key('appearance_seed_color_pink_card'));
    final pinkPaint = find.descendant(
      of: pinkCard,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.size == const Size.square(54) &&
            widget.painter != null,
      ),
    );
    final before = tester.widget<CustomPaint>(pinkPaint).painter!;

    await tester.tap(pinkCard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));

    final during = tester.widget<CustomPaint>(pinkPaint).painter!;
    expect(during.shouldRepaint(before), isTrue);
  });

  testWidgets('Appearance reader controls persist reader appearance', (
    tester,
  ) async {
    final store = FakeReaderSettingsStore(const ReaderSettings());
    await pumpSettingsScreen(
      tester,
      1000,
      height: 1200,
      initialTab: SettingsTab.appearance,
      readerSettingsStore: store,
      overrides: servicesOverrides(),
    );

    await tester.tap(
      find.byKey(const Key('appearance_reader_font_family_serif_option')),
    );
    await tester.pumpAndSettle();
    expect(store.settings.fontFamily, ReaderFontFamily.serif);

    await tester.tap(
      find.byKey(const Key('appearance_reader_font_size_large_option')),
    );
    await tester.pumpAndSettle();
    expect(store.settings.fontSize, 20);

    await tester.tap(
      find.byKey(const Key('appearance_reader_line_height_relaxed_option')),
    );
    await tester.pumpAndSettle();
    expect(store.settings.lineHeight, 1.85);

    await tester.tap(
      find.byKey(const Key('appearance_reader_width_wide_option')),
    );
    await tester.pumpAndSettle();
    expect(store.settings.contentWidthPreset, ReaderContentWidthPreset.wide);

    await tester.tap(
      find.byKey(const Key('appearance_reader_theme_sepia_option')),
    );
    await tester.pumpAndSettle();
    expect(store.settings.readerTheme, ReaderThemePreset.sepia);

    await tester.ensureVisible(
      find.byKey(const Key('appearance_code_soft_wrap_switch')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      settingsSwitchControl(const Key('appearance_code_soft_wrap_switch')),
    );
    await tester.pumpAndSettle();
    expect(store.settings.codeSoftWrap, isTrue);

    await tester.ensureVisible(
      find.byKey(const Key('appearance_advanced_fonts_tile')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearance_advanced_fonts_tile')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('appearance_standard_font_stack_input')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('appearance_standard_font_stack_input')),
      '"PingFang SC", system-ui, sans-serif',
    );
    await tester.pumpAndSettle();
    expect(
      store.settings.standardFontStack,
      '"PingFang SC", system-ui, sans-serif',
    );

    final minimumFontSizeSlider = tester.widget<Slider>(
      find.descendant(
        of: find.byKey(const Key('appearance_minimum_font_size_slider')),
        matching: find.byType(Slider),
      ),
    );
    minimumFontSizeSlider.onChanged!(13);
    await tester.pumpAndSettle();
    expect(store.settings.minimumFontSize, 13);

    await tester.tap(find.byKey(const Key('appearance_fonts_back_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearance_reader_reset_button')));
    await tester.pumpAndSettle();
    expect(store.settings.fontFamily, ReaderFontFamily.serif);
    expect(store.settings.readerFontStack, isEmpty);
    expect(store.settings.standardFontStack, isEmpty);
    expect(
      store.settings.minimumFontSize,
      ReaderSettings.defaultMinimumFontSize,
    );
    expect(
      store.settings.contentWidthPreset,
      ReaderContentWidthPreset.standard,
    );
    expect(store.settings.readerTheme, ReaderThemePreset.defaultLightAware);
    expect(store.settings.codeSoftWrap, isFalse);
  });

  testWidgets('Appearance reader previews keep stable card geometry', (
    tester,
  ) async {
    await pumpSettingsScreen(
      tester,
      1200,
      height: 1200,
      initialTab: SettingsTab.appearance,
      readerSettingsStore: FakeReaderSettingsStore(const ReaderSettings()),
      overrides: servicesOverrides(),
    );

    final mediumOption = find.byKey(
      const Key('appearance_reader_font_size_medium_option'),
    );
    final selectedIcon = find.descendant(
      of: mediumOption,
      matching: find.byType(Icon),
    );
    final optionRect = tester.getRect(mediumOption);
    final iconRect = tester.getRect(selectedIcon);
    expect(optionRect.right - iconRect.right, closeTo(5, 0.5));
    expect(iconRect.top - optionRect.top, closeTo(5, 0.5));

    final fontOptionRects = <Rect>[];
    final fontPreviewCenters = <Offset>[];
    for (final preset in ReaderFontSizePreset.values) {
      final option = find.byKey(
        Key('appearance_reader_font_size_${preset.name}_option'),
      );
      final preview = find.descendant(of: option, matching: find.text('Aa'));
      fontOptionRects.add(tester.getRect(option));
      fontPreviewCenters.add(tester.getCenter(preview));
    }
    expect(fontOptionRects.map((rect) => rect.height).toSet(), hasLength(1));
    for (var index = 0; index < fontPreviewCenters.length; index++) {
      expect(
        fontPreviewCenters[index].dx,
        closeTo(fontOptionRects[index].center.dx, 0.5),
      );
      expect(
        fontPreviewCenters[index].dy,
        closeTo(fontPreviewCenters.first.dy, 0.5),
      );
    }

    final measureWidths = <double>[];
    for (final preset in ReaderContentWidthPreset.values) {
      final option = find.byKey(
        Key('appearance_reader_width_${preset.name}_option'),
      );
      final measure = find.byKey(
        Key('appearance_reader_width_${preset.name}_measure'),
      );
      final optionRect = tester.getRect(option);
      final measureRect = tester.getRect(measure);
      measureWidths.add(measureRect.width);
      expect(measureRect.center.dx, closeTo(optionRect.center.dx, 0.5));
    }
    expect(measureWidths[0], lessThan(measureWidths[1]));
    expect(measureWidths[1], lessThan(measureWidths[2]));
  });

  testWidgets('Appearance advanced font controls persist code typography', (
    tester,
  ) async {
    final store = FakeReaderSettingsStore(const ReaderSettings());
    await pumpSettingsScreen(
      tester,
      1000,
      height: 1400,
      initialTab: SettingsTab.appearance,
      readerSettingsStore: store,
      overrides: servicesOverrides(),
    );

    await tester.ensureVisible(
      find.byKey(const Key('appearance_advanced_fonts_tile')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearance_advanced_fonts_tile')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('appearance_mono_font_stack_input')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('appearance_mono_font_stack_input')),
      '"JetBrains Mono", "SF Mono", monospace',
    );
    await tester.pumpAndSettle();
    expect(
      store.settings.monoFontStack,
      '"JetBrains Mono", "SF Mono", monospace',
    );

    await tester.enterText(
      find.byKey(const Key('appearance_math_font_stack_input')),
      '"STIX Two Math", serif',
    );
    await tester.pumpAndSettle();
    expect(store.settings.mathFontStack, '"STIX Two Math", serif');

    await tester.tap(
      find.byKey(const Key('appearance_code_font_size_mode_custom_option')),
    );
    await tester.pumpAndSettle();
    expect(store.settings.codeFontSizeMode, CodeFontSizeMode.custom);
    expect(
      find.byKey(const Key('appearance_code_font_size_slider')),
      findsOneWidget,
    );

    final fontSizeSlider = tester.widget<Slider>(
      find.descendant(
        of: find.byKey(const Key('appearance_code_font_size_slider')),
        matching: find.byType(Slider),
      ),
    );
    fontSizeSlider.onChanged!(18);
    await tester.pumpAndSettle();
    expect(store.settings.codeFontSize, 18);

    final lineHeightSlider = tester.widget<Slider>(
      find.descendant(
        of: find.byKey(const Key('appearance_code_line_height_slider')),
        matching: find.byType(Slider),
      ),
    );
    lineHeightSlider.onChanged!(1.7);
    await tester.pumpAndSettle();
    expect(store.settings.codeLineHeight, 1.7);

    await tester.tap(find.byKey(const Key('appearance_fonts_back_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearance_reader_reset_button')));
    await tester.pumpAndSettle();
    expect(store.settings.codeFontFamily, CodeFontFamilyPreset.systemMono);
    expect(store.settings.codeFontStack, isEmpty);
    expect(store.settings.monoFontStack, isEmpty);
    expect(store.settings.mathFontStack, isEmpty);
    expect(store.settings.codeFontSizeMode, CodeFontSizeMode.oneStepDown);
    expect(store.settings.codeFontSize, ReaderSettings.defaultCodeFontSize);
    expect(store.settings.codeLineHeight, ReaderSettings.defaultCodeLineHeight);
    expect(store.settings.codeSoftWrap, isFalse);
  });

  testWidgets('Appearance shows dynamic color switch only when available', (
    tester,
  ) async {
    await pumpSettingsScreen(
      tester,
      1000,
      initialTab: SettingsTab.appearance,
      overrides: servicesOverrides(),
    );

    expect(
      find.byKey(const Key('appearance_dynamic_color_switch')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('appearance_seed_color_pink_card')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpSettingsScreen(
      tester,
      1000,
      initialTab: SettingsTab.appearance,
      dynamicColorAvailable: true,
      overrides: servicesOverrides(),
    );

    expect(
      find.byKey(const Key('appearance_dynamic_color_switch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('appearance_seed_color_pink_card')),
      findsNothing,
    );
  });

  testWidgets('Appearance dynamic color switch reveals manual theme colors', (
    tester,
  ) async {
    final store = appSettingsStore(AppSettings.defaults());
    await pumpSettingsScreen(
      tester,
      1000,
      initialTab: SettingsTab.appearance,
      dynamicColorAvailable: true,
      overrides: servicesOverrides(settingsStore: store),
    );

    expect(store.settings.useDynamicColor, isTrue);
    expect(
      find.byKey(const Key('appearance_dynamic_color_switch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('appearance_seed_color_pink_card')),
      findsNothing,
    );

    await tester.tap(
      settingsSwitchControl(const Key('appearance_dynamic_color_switch')),
    );
    await tester.pumpAndSettle();

    expect(store.settings.useDynamicColor, isFalse);
    expect(
      find.byKey(const Key('appearance_seed_color_pink_card')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('appearance_seed_color_pink_card')));
    await tester.pumpAndSettle();

    expect(store.settings.useDynamicColor, isFalse);
    expect(store.settings.seedColorPreset, SeedColorPreset.pink);
  });

  testWidgets('Settings search opens font size in Appearance', (tester) async {
    await pumpSettingsScreen(tester, 1000, overrides: servicesOverrides());

    await tester.tap(find.byKey(const Key('settings_search_placeholder')));
    await tester.enterText(find.byType(TextField), 'font');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('settings_search_results_panel')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('settings_search_results_body')),
      findsOneWidget,
    );
    expect(find.text('Appearance / Reader appearance'), findsWidgets);

    await tester.tap(
      find.byKey(
        const Key('settings_search_result_appearance.reader.font_size'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings_search_results_body')), findsNothing);
    expect(find.text('Appearance'), findsWidgets);
    expect(find.text('Font size'), findsOneWidget);
    expect(
      find.byKey(const Key('settings_target_appearance.reader.font_size')),
      findsOneWidget,
    );
  });

  testWidgets('Settings search opens reading width in Appearance', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 1000, overrides: servicesOverrides());

    await tester.tap(find.byKey(const Key('settings_search_placeholder')));
    await tester.enterText(find.byType(TextField), 'width');
    await tester.pumpAndSettle();

    expect(find.text('Appearance / Reader appearance'), findsWidgets);

    await tester.tap(
      find.byKey(const Key('settings_search_result_appearance.reader.width')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings_search_results_body')), findsNothing);
    expect(find.text('Reading width'), findsOneWidget);
    expect(
      find.byKey(const Key('settings_target_appearance.reader.width')),
      findsOneWidget,
    );
  });

  testWidgets('Settings search opens language in App Preferences', (
    tester,
  ) async {
    await pumpSettingsScreen(
      tester,
      1000,
      initialTab: SettingsTab.appearance,
      overrides: servicesOverrides(),
    );

    await tester.tap(find.byKey(const Key('settings_search_placeholder')));
    await tester.enterText(find.byType(TextField), 'language');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('settings_search_results_body')),
      findsOneWidget,
    );
    expect(find.text('App Preferences / Language'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const Key('settings_search_result_app_preferences.language.system'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings_search_results_body')), findsNothing);
    expect(
      find.byKey(const Key('app_preferences_language_select')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('settings_target_app_preferences.language.system')),
      findsOneWidget,
    );
  });

  testWidgets('Settings search shows empty state for no results', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 1000, overrides: servicesOverrides());

    await tester.tap(find.byKey(const Key('settings_search_placeholder')));
    await tester.enterText(find.byType(TextField), 'zzzz-not-a-setting');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('settings_search_results_panel')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('settings_search_results_body')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('settings_search_no_results')), findsOneWidget);
    expect(find.text('No settings match this search.'), findsOneWidget);
  });

  testWidgets('Settings search focus ring is on the field surface', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 1000, overrides: servicesOverrides());

    AnimatedContainer fieldSurface() {
      return tester.widget<AnimatedContainer>(
        find.byKey(const Key('settings_search_field_surface')),
      );
    }

    final initialDecoration = fieldSurface().decoration! as BoxDecoration;
    final initialBorder = initialDecoration.border! as Border;
    expect(initialBorder.top.width, 1);

    await tester.tap(find.byKey(const Key('settings_search_placeholder')));
    await tester.pumpAndSettle();

    final focusedDecoration = fieldSurface().decoration! as BoxDecoration;
    final focusedBorder = focusedDecoration.border! as Border;
    expect(focusedBorder.top.width, 2);

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.decoration?.border, InputBorder.none);
  });

  testWidgets('Settings search clears back to the selected tab', (
    tester,
  ) async {
    await pumpSettingsScreen(
      tester,
      1000,
      initialTab: SettingsTab.appearance,
      overrides: servicesOverrides(),
    );

    await tester.tap(find.byKey(const Key('settings_search_placeholder')));
    await tester.enterText(find.byType(TextField), 'font');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('settings_search_results_body')),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings_search_results_body')), findsNothing);
    expect(find.text('Theme mode'), findsOneWidget);
    expect(find.text('Font size'), findsOneWidget);
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
