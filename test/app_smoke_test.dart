import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fleur/app/app.dart';
import 'package:fleur/app/router.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/providers/article_list_controller.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/background_sync_providers.dart';
import 'package:fleur/providers/outbox_status_providers.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/providers/sync_status_providers.dart';
import 'package:fleur/providers/unread_providers.dart';
import 'package:fleur/screens/home_screen.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/screens/saved_screen.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/sync/sync_service.dart';
import 'package:fleur/services/sync/sync_status_reporter.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/theme/app_typography.dart';
import 'package:fleur/theme/fleur_theme_extensions.dart';
import 'package:fleur/ui/app_shell.dart';
import 'package:fleur/ui/home/home_scene_commands.dart';
import 'package:fleur/ui/home/home_scene_shortcuts.dart';
import 'package:fleur/ui/sidebar/sidebar_selection_actions.dart';
import 'package:fleur/utils/platform.dart';
import 'package:fleur/widgets/article_list.dart';
import 'package:fleur/widgets/article_list_item.dart';
import 'package:fleur/widgets/app_scrollbar.dart';
import 'package:fleur/widgets/global_nav_bar.dart';
import 'package:fleur/widgets/global_nav_rail.dart';
import 'package:fleur/widgets/overflow_marquee.dart';
import 'package:fleur/widgets/sidebar.dart';
import 'package:fleur/widgets/sync_status_capsule.dart';

import 'test_utils/critical_workflow_test_support.dart';

GoRouter _buildRouter() {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
      GoRoute(
        path: '/article/:id',
        builder: (context, state) => Text(state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );
}

Widget _buildRuntimeHostHarness({
  required Key scopeKey,
  required GoRouter router,
  required FakeNotificationService notificationService,
  required FakeAppSettingsStore appSettingsStore,
  required Future<void> Function(String? localeTag) preferredLanguageApplier,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      routerProvider.overrideWithValue(router),
      appSettingsStoreProvider.overrideWithValue(appSettingsStore),
      notificationServiceProvider.overrideWithValue(notificationService),
      preferredLanguageApplierProvider.overrideWithValue(
        preferredLanguageApplier,
      ),
    ],
    child: AppRuntimeHost(
      child: ProviderScope(
        key: scopeKey,
        overrides: [
          notificationServiceProvider.overrideWithValue(notificationService),
        ],
        child: child,
      ),
    ),
  );
}

Widget _buildShellHarness() {
  return ProviderScope(
    overrides: [activeAccountProvider.overrideWithValue(buildTestAccount())],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppShell(
        currentUri: Uri(path: '/'),
        child: ColoredBox(color: Colors.transparent),
      ),
    ),
  );
}

Feed _buildFeed({
  int id = 10,
  String title = 'Fleur Feed',
  String url = 'https://example.com/feed.xml',
}) {
  return Feed()
    ..id = id
    ..url = url
    ..title = title
    ..siteUrl = 'https://example.com';
}

Article _buildArticle({
  int id = 42,
  int feedId = 10,
  String title = 'Selected Article',
  bool isRead = false,
  bool isStarred = false,
}) {
  return Article()
    ..id = id
    ..feedId = feedId
    ..link = 'https://example.com/article/$id'
    ..title = title
    ..contentHtml = '<p>Hello world</p>'
    ..publishedAt = DateTime.utc(2026, 1, 2)
    ..updatedAt = DateTime.utc(2026, 1, 2)
    ..isRead = isRead
    ..isStarred = isStarred;
}

class _EmptyArticleListController extends ArticleListController {
  @override
  Future<ArticleListState> build() async {
    return const ArticleListState(items: [], hasMore: false, nextOffset: 0);
  }
}

class _FixedArticleListController extends ArticleListController {
  static List<Article> items = <Article>[];

  @override
  Future<ArticleListState> build() async {
    return ArticleListState(
      items: items,
      hasMore: false,
      nextOffset: items.length,
    );
  }
}

class _RecordingHomeSceneCommands extends HomeSceneCommands {
  _RecordingHomeSceneCommands({required super.context, required super.ref})
    : super(selectedArticleId: null);

  final List<String> calls = <String>[];

  @override
  Future<BatchRefreshResult> refreshAll() async {
    calls.add('refresh');
    return const BatchRefreshResult(<FeedRefreshResult>[]);
  }

  @override
  void toggleUnreadOnly() {
    calls.add('toggleUnread');
  }

  @override
  Future<void> toggleSelectedArticleRead() async {
    calls.add('toggleRead');
  }

  @override
  Future<void> toggleSelectedArticleStar() async {
    calls.add('toggleStar');
  }

  @override
  void goToSearch() {
    calls.add('search');
  }

  @override
  void goToNextArticle() {
    calls.add('next');
  }

  @override
  void goToPreviousArticle() {
    calls.add('previous');
  }
}

void main() {
  testWidgets('App builds', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final router = _buildRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [routerProvider.overrideWithValue(router)],
        child: const App(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(App), findsOneWidget);
  });

  test('App theme exposes Fleur semantic tokens for desktop and mobile', () {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final desktopTheme = AppTheme.light();
    expect(desktopTheme.fleurSurface.nav, isNotNull);
    expect(desktopTheme.fleurState.selectionTint, isNotNull);
    expect(desktopTheme.fleurReader.maxWidth, greaterThan(0));
    expect(
      desktopTheme.scrollbarTheme.thumbVisibility?.resolve(<WidgetState>{}),
      isTrue,
    );
    expect(desktopTheme.scrollbarTheme.thickness?.resolve(<WidgetState>{}), 6);
    expect(
      desktopTheme.scrollbarTheme.thickness?.resolve(<WidgetState>{
        WidgetState.hovered,
      }),
      6,
    );
    expect(
      desktopTheme.scrollbarTheme.thickness?.resolve(<WidgetState>{
        WidgetState.dragged,
      }),
      6,
    );
    expect(
      desktopTheme.iconButtonTheme.style?.shape?.resolve(<WidgetState>{}),
      isNull,
    );
    expect(
      desktopTheme.scrollbarTheme.thumbColor?.resolve(<WidgetState>{}),
      isNot(
        desktopTheme.scrollbarTheme.thumbColor?.resolve(<WidgetState>{
          WidgetState.hovered,
        }),
      ),
    );

    debugFleurTargetPlatformOverride = TargetPlatform.android;
    final mobileTheme = AppTheme.light();
    expect(
      mobileTheme.scrollbarTheme.thumbVisibility?.resolve(<WidgetState>{}),
      isFalse,
    );
    expect(mobileTheme.scrollbarTheme.thickness?.resolve(<WidgetState>{}), 8);
    expect(
      mobileTheme.navigationBarTheme.height,
      greaterThan(desktopTheme.navigationBarTheme.height ?? 0),
    );
  });

  test('Windows typography uses lighter emphasis than macOS', () {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final windowsTheme = AppTheme.light();
    expect(AppTypography.fontFamily(), 'Segoe UI');
    expect(AppTypography.fontFallback().first, 'DengXian');
    expect(AppTypography.fontFallback()[2], 'Microsoft YaHei UI');
    expect(windowsTheme.textTheme.titleLarge?.fontWeight, FontWeight.w600);
    expect(windowsTheme.textTheme.titleMedium?.fontWeight, FontWeight.w500);
    expect(windowsTheme.fleurReader.titleStyle.fontWeight, FontWeight.w600);
    expect(windowsTheme.fleurReader.metaStyle.fontWeight, FontWeight.w500);

    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    final macTheme = AppTheme.light();
    expect(AppTypography.fontFamily(), isNull);
    expect(macTheme.textTheme.titleLarge?.fontWeight, FontWeight.w700);
    expect(macTheme.textTheme.titleMedium?.fontWeight, FontWeight.w600);
    expect(macTheme.fleurReader.titleStyle.fontWeight, FontWeight.w700);
    expect(macTheme.fleurReader.metaStyle.fontWeight, FontWeight.w600);
  });

  test('Reader title scale stays above body text and caps growth', () {
    final theme = AppTheme.light();
    final defaultTitle = theme.fleurReader.titleStyleForBodyFontSize(16);
    final largeTitle = theme.fleurReader.titleStyleForBodyFontSize(28);

    expect(defaultTitle.fontSize, greaterThan(16));
    expect(largeTitle.fontSize, greaterThan(28));
    expect(largeTitle.fontSize, lessThanOrEqualTo(40));
    expect(largeTitle.height, greaterThanOrEqualTo(defaultTitle.height ?? 0));
  });

  testWidgets('AppScrollbar darkens when hovering the scrollable region', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 240,
            child: AppScrollbar(
              controller: controller,
              thumbVisibility: true,
              interactive: true,
              child: ListView.builder(
                controller: controller,
                itemCount: 50,
                itemBuilder: (context, index) =>
                    SizedBox(height: 40, child: Text('Item $index')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Scrollbar), findsOneWidget);
    ScrollbarTheme scrollbarTheme() =>
        tester.widget<ScrollbarTheme>(find.byType(ScrollbarTheme).first);

    final idleThumbColor = scrollbarTheme().data.thumbColor?.resolve(
      <WidgetState>{},
    );
    final idleThickness = scrollbarTheme().data.thickness?.resolve(
      <WidgetState>{},
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(tester.getCenter(find.byType(AppScrollbar)));
    await tester.pumpAndSettle();

    final hoveredThumbColor = scrollbarTheme().data.thumbColor?.resolve(
      <WidgetState>{},
    );
    final hoveredThickness = scrollbarTheme().data.thickness?.resolve(
      <WidgetState>{},
    );

    expect(hoveredThumbColor, isNot(idleThumbColor));
    expect(hoveredThickness, idleThickness);
  });

  testWidgets(
    'AppScrollbar defers interactive behavior to Flutter by default',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugFleurTargetPlatformOverride = null);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 240,
              child: AppScrollbar(
                child: ListView.builder(
                  itemCount: 20,
                  itemBuilder: (context, index) =>
                      SizedBox(height: 40, child: Text('Item $index')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scrollbar), findsOneWidget);
      final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar).first);
      expect(scrollbar.controller, isNotNull);
      expect(scrollbar.interactive, isNull);
    },
  );

  testWidgets(
    'AppScrollbar safely falls back when the child scroll view opts out of primary binding',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugFleurTargetPlatformOverride = null);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 240,
              child: AppScrollbar(
                child: ListView.builder(
                  primary: false,
                  itemCount: 20,
                  itemBuilder: (context, index) =>
                      SizedBox(height: 40, child: Text('Item $index')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scrollbar), findsOneWidget);
      final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar).first);
      expect(scrollbar.controller, isNull);
      expect(scrollbar.thumbVisibility, isFalse);
      expect(scrollbar.interactive, isFalse);
    },
  );

  testWidgets('App shell switches between rail and bottom navigation', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_buildShellHarness());
    await tester.pumpAndSettle();

    expect(find.byType(GlobalNavRail), findsOneWidget);
    expect(find.byType(GlobalNavBar), findsNothing);

    tester.view.physicalSize = const Size(640, 900);
    await tester.pumpWidget(_buildShellHarness());
    await tester.pumpAndSettle();

    expect(find.byType(GlobalNavBar), findsOneWidget);
    expect(find.byType(GlobalNavRail), findsNothing);
  });

  testWidgets(
    'App runtime host does not repeat startup side effects on rebuild',
    (tester) async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final router = _buildRouter();
      final notificationService = FakeNotificationService();
      final appSettingsStore = FakeAppSettingsStore(
        AppSettings.defaults().copyWith(localeTag: 'en'),
      );
      final localeTags = <String?>[];
      final scheduler = FakeBackgroundSyncScheduler();
      final container = ProviderContainer(
        overrides: [
          routerProvider.overrideWithValue(router),
          activeAccountProvider.overrideWithValue(buildTestAccount()),
          appSettingsStoreProvider.overrideWithValue(appSettingsStore),
          notificationServiceProvider.overrideWithValue(notificationService),
          outboxPendingCountProvider.overrideWith((ref) async => 0),
          backgroundSyncSchedulerProvider.overrideWithValue(scheduler),
          preferredLanguageApplierProvider.overrideWithValue((localeTag) async {
            localeTags.add(localeTag);
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(appSettingsProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AppRuntimeHost(child: App()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(notificationService.actualInitCalls, 1);
      expect(notificationService.actualPermissionCalls, 1);
      expect(notificationService.bindTapHandlerCalls, 1);
      expect(localeTags, ['en']);

      await container
          .read(appSettingsProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await tester.pump();

      expect(notificationService.actualInitCalls, 1);
      expect(notificationService.actualPermissionCalls, 1);
      expect(notificationService.bindTapHandlerCalls, 1);

      await container
          .read(appSettingsProvider.notifier)
          .setLocaleTag('zh_Hant');
      await tester.pump();

      expect(localeTags, ['en', 'zh-Hant']);
    },
  );

  testWidgets(
    'Global runtime host does not replay app-level side effects across account scope rebuilds',
    (tester) async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final router = _buildRouter();
      final notificationService = FakeNotificationService();
      final appSettingsStore = FakeAppSettingsStore(
        AppSettings.defaults().copyWith(localeTag: 'en'),
      );
      final localeTags = <String?>[];

      Future<void> preferredLanguageApplier(String? localeTag) async {
        localeTags.add(localeTag);
      }

      await tester.pumpWidget(
        _buildRuntimeHostHarness(
          scopeKey: const ValueKey<String>('account-a'),
          router: router,
          notificationService: notificationService,
          appSettingsStore: appSettingsStore,
          preferredLanguageApplier: preferredLanguageApplier,
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pump();

      expect(notificationService.actualInitCalls, 1);
      expect(notificationService.actualPermissionCalls, 1);
      expect(notificationService.bindTapHandlerCalls, 1);
      expect(localeTags, ['en']);

      await tester.pumpWidget(
        _buildRuntimeHostHarness(
          scopeKey: const ValueKey<String>('account-b'),
          router: router,
          notificationService: notificationService,
          appSettingsStore: appSettingsStore,
          preferredLanguageApplier: preferredLanguageApplier,
          child: const SizedBox.shrink(),
        ),
      );
      await tester.pump();

      expect(notificationService.actualInitCalls, 1);
      expect(notificationService.actualPermissionCalls, 1);
      expect(notificationService.bindTapHandlerCalls, 1);
      expect(localeTags, ['en']);
    },
  );

  testWidgets(
    'Home scene commands centralize refresh, unread toggle, and article navigation',
    (tester) async {
      final syncService = FakeSyncService();
      final actionService = RecordingArticleActionService();
      late HomeSceneCommands homeCommands;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) {
              return Consumer(
                builder: (context, ref, _) {
                  homeCommands = HomeSceneCommands(
                    context: context,
                    ref: ref,
                    selectedArticleId: 2,
                  );
                  return const SizedBox(key: ValueKey('home_commands_host'));
                },
              );
            },
          ),
          GoRoute(
            path: '/article/:id',
            builder: (context, state) => Text(state.pathParameters['id'] ?? ''),
          ),
        ],
      );
      addTearDown(router.dispose);

      _FixedArticleListController.items = <Article>[
        _buildArticle(id: 1, title: 'Article 1'),
        _buildArticle(id: 2, title: 'Article 2'),
        _buildArticle(id: 3, title: 'Article 3'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedFeedIdProvider.overrideWith((ref) => 10),
            articleListControllerProvider.overrideWith(
              _FixedArticleListController.new,
            ),
            articleActionServiceProvider.overrideWithValue(actionService),
            syncServiceProvider.overrideWithValue(syncService),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('home_commands_host'))),
      );
      await container.read(articleListControllerProvider.future);

      await homeCommands.refreshAll();
      expect(syncService.refreshCalls, [
        [10],
      ]);

      await homeCommands.markAllRead();
      expect(actionService.markAllReadCalls, [(feedId: 10, categoryId: null)]);

      expect(container.read(unreadOnlyProvider), isFalse);
      homeCommands.toggleUnreadOnly();
      expect(container.read(unreadOnlyProvider), isTrue);

      homeCommands.goToPreviousArticle();
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);

      router.go('/');
      await tester.pumpAndSettle();
      final refreshedContainer = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('home_commands_host'))),
      );
      await refreshedContainer.read(articleListControllerProvider.future);

      homeCommands.goToNextArticle();
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
    },
  );

  testWidgets('Home scene commands sync account-wide for remote accounts', (
    tester,
  ) async {
    final syncService = FakeSyncService();
    late HomeSceneCommands homeCommands;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            return Consumer(
              builder: (context, ref, _) {
                homeCommands = HomeSceneCommands(
                  context: context,
                  ref: ref,
                  selectedArticleId: null,
                );
                return const SizedBox(key: ValueKey('remote_commands_host'));
              },
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(
            buildTestAccount(type: AccountType.fever, name: 'Fever'),
          ),
          selectedFeedIdProvider.overrideWith((ref) => 10),
          selectedCategoryIdProvider.overrideWith((ref) => 1),
          syncServiceProvider.overrideWithValue(syncService),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await homeCommands.refreshAll();

    expect(syncService.refreshCalls, [<int>[]]);
  });

  testWidgets('Home refresh tooltip follows backend refresh scope', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpHome(AccountType type) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeAccountProvider.overrideWithValue(
              buildTestAccount(type: type),
            ),
            articleListControllerProvider.overrideWith(
              _EmptyArticleListController.new,
            ),
            appSettingsStoreProvider.overrideWithValue(
              FakeAppSettingsStore(AppSettings.defaults()),
            ),
            outboxPendingCountProvider.overrideWith((ref) async => 0),
            syncServiceProvider.overrideWithValue(FakeSyncService()),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomeScreen(selectedArticleId: null),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpHome(AccountType.local);
    expect(find.byTooltip('Refresh all'), findsOneWidget);
    expect(find.byTooltip('Sync account'), findsNothing);

    await pumpHome(AccountType.fever);
    expect(find.byTooltip('Sync account'), findsOneWidget);
    expect(find.byTooltip('Refresh all'), findsNothing);
  });

  testWidgets('Home scene shortcuts reuse the shared action wiring', (
    tester,
  ) async {
    late _RecordingHomeSceneCommands commands;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              commands = _RecordingHomeSceneCommands(
                context: context,
                ref: ref,
              );
              return Scaffold(
                body: HomeSceneShortcuts(
                  commands: commands,
                  child: const SizedBox(key: ValueKey('home_shortcuts_host')),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(commands.calls, [
      'next',
      'previous',
      'refresh',
      'toggleUnread',
      'toggleRead',
      'toggleStar',
      'search',
    ]);
  });

  testWidgets('Sync status capsule honors reduced-motion preferences', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
              body: SyncStatusCapsuleHost(child: SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SyncStatusCapsuleHost)),
    );
    container
        .read(syncStatusReporterProvider)
        .startTask(label: SyncStatusLabel.syncingFeeds, current: 1, total: 3);
    await tester.pump();

    final capsuleFinder = find.byType(SyncStatusCapsuleHost);
    expect(
      tester
          .widget<AnimatedSlide>(
            find.descendant(
              of: capsuleFinder,
              matching: find.byType(AnimatedSlide),
            ),
          )
          .duration,
      Duration.zero,
    );
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: capsuleFinder,
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .duration,
      Duration.zero,
    );
    expect(
      tester
          .widget<AnimatedSwitcher>(
            find.descendant(
              of: capsuleFinder,
              matching: find.byType(AnimatedSwitcher),
            ),
          )
          .duration,
      Duration.zero,
    );
  });

  testWidgets(
    'Sidebar selection actions share feed, category, tag, and clear-selection flows',
    (tester) async {
      late SidebarSelectionActions actions;
      int closeCount = 0;
      int? selectedFeedCallback;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedFeedIdProvider.overrideWith((ref) => null),
            selectedCategoryIdProvider.overrideWith((ref) => null),
            selectedTagIdProvider.overrideWith((ref) => null),
            starredOnlyProvider.overrideWith((ref) => true),
            readLaterOnlyProvider.overrideWith((ref) => true),
            articleSearchQueryProvider.overrideWith((ref) => 'needle'),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                actions = SidebarSelectionActions(
                  ref: ref,
                  onSelectFeed: (feedId) => selectedFeedCallback = feedId,
                  closeSidebar: () => closeCount++,
                );
                return const SizedBox(key: ValueKey('sidebar_actions_host'));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const ValueKey('sidebar_actions_host'))),
      );

      actions.selectFeed(12);
      expect(container.read(selectedFeedIdProvider), 12);
      expect(container.read(selectedCategoryIdProvider), isNull);
      expect(container.read(selectedTagIdProvider), isNull);
      expect(container.read(starredOnlyProvider), isFalse);
      expect(container.read(readLaterOnlyProvider), isFalse);
      expect(container.read(articleSearchQueryProvider), '');
      expect(selectedFeedCallback, 12);
      expect(closeCount, 1);

      actions.selectFeed(12);
      expect(container.read(selectedFeedIdProvider), isNull);
      expect(container.read(selectedCategoryIdProvider), isNull);
      expect(container.read(selectedTagIdProvider), isNull);
      expect(selectedFeedCallback, isNull);
      expect(closeCount, 2);

      container.read(starredOnlyProvider.notifier).state = true;
      container.read(readLaterOnlyProvider.notifier).state = true;
      container.read(articleSearchQueryProvider.notifier).state = 'category';
      actions.selectCategory(34);
      expect(container.read(selectedFeedIdProvider), isNull);
      expect(container.read(selectedCategoryIdProvider), 34);
      expect(container.read(selectedTagIdProvider), isNull);
      expect(container.read(starredOnlyProvider), isFalse);
      expect(container.read(readLaterOnlyProvider), isFalse);
      expect(container.read(articleSearchQueryProvider), '');
      expect(selectedFeedCallback, isNull);
      expect(closeCount, 3);

      container.read(starredOnlyProvider.notifier).state = true;
      container.read(readLaterOnlyProvider.notifier).state = true;
      container.read(articleSearchQueryProvider.notifier).state = 'tag';
      actions.selectTag(56);
      expect(container.read(selectedFeedIdProvider), isNull);
      expect(container.read(selectedCategoryIdProvider), isNull);
      expect(container.read(selectedTagIdProvider), 56);
      expect(container.read(starredOnlyProvider), isFalse);
      expect(container.read(readLaterOnlyProvider), isFalse);
      expect(container.read(articleSearchQueryProvider), '');
      expect(selectedFeedCallback, isNull);
      expect(closeCount, 4);
    },
  );

  testWidgets(
    'Sidebar shows selected feed state and unread badges through shared tokens',
    (tester) async {
      final feed = _buildFeed();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeAccountProvider.overrideWithValue(buildTestAccount()),
            feedsProvider.overrideWith((ref) => Stream.value([feed])),
            categoriesProvider.overrideWith(
              (ref) => Stream.value(<Category>[]),
            ),
            tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
            selectedFeedIdProvider.overrideWith((ref) => feed.id),
            allUnreadCountsProvider.overrideWith(
              (ref) => Stream.value(<int?, int>{null: 5, feed.id: 3}),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SizedBox(
                width: 1200,
                child: Sidebar(onSelectFeed: _noopSelectFeed),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fleur Feed'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      final tileFinder = find.ancestor(
        of: find.text('Fleur Feed'),
        matching: find.byType(ListTile),
      );
      expect(tester.widget<ListTile>(tileFinder).selected, isTrue);
    },
  );

  testWidgets(
    'Sidebar desktop feed menu reuses the shared refresh action path',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugFleurTargetPlatformOverride = null);

      final feed = _buildFeed();
      final syncService = FakeSyncService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeAccountProvider.overrideWithValue(buildTestAccount()),
            syncServiceProvider.overrideWithValue(syncService),
            feedsProvider.overrideWith((ref) => Stream.value([feed])),
            categoriesProvider.overrideWith(
              (ref) => Stream.value(<Category>[]),
            ),
            tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
            allUnreadCountsProvider.overrideWith(
              (ref) => Stream.value(<int?, int>{null: 0, feed.id: 0}),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SizedBox(
                width: 1200,
                child: Sidebar(onSelectFeed: _noopSelectFeed),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh').last);
      await tester.pumpAndSettle();

      expect(syncService.refreshCalls, [
        [feed.id],
      ]);
    },
  );

  testWidgets(
    'Sidebar mobile long-press menu reuses the shared refresh action path',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugFleurTargetPlatformOverride = null);

      final feed = _buildFeed();
      final syncService = FakeSyncService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeAccountProvider.overrideWithValue(buildTestAccount()),
            syncServiceProvider.overrideWithValue(syncService),
            feedsProvider.overrideWith((ref) => Stream.value([feed])),
            categoriesProvider.overrideWith(
              (ref) => Stream.value(<Category>[]),
            ),
            tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
            allUnreadCountsProvider.overrideWith(
              (ref) => Stream.value(<int?, int>{null: 0, feed.id: 0}),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SizedBox(
                width: 400,
                child: Sidebar(onSelectFeed: _noopSelectFeed),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Fleur Feed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh').last);
      await tester.pumpAndSettle();

      expect(syncService.refreshCalls, [
        [feed.id],
      ]);
    },
  );

  testWidgets(
    'Sidebar mobile exposes explicit item menus and keeps header actions touch-friendly',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugFleurTargetPlatformOverride = null);

      final feed = _buildFeed()..categoryId = 1;
      final category = Category()
        ..id = 1
        ..name = 'News';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeAccountProvider.overrideWithValue(buildTestAccount()),
            feedsProvider.overrideWith((ref) => Stream.value([feed])),
            categoriesProvider.overrideWith((ref) => Stream.value([category])),
            tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
            allUnreadCountsProvider.overrideWith(
              (ref) => Stream.value(<int?, int>{null: 0, category.id: 1}),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SizedBox(
                width: 400,
                child: Sidebar(onSelectFeed: _noopSelectFeed),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addSubscriptionButton = find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == 'Add subscription',
      );
      final newCategoryButton = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'New category',
      );

      expect(
        tester.getSize(addSubscriptionButton).width,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(addSubscriptionButton).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.getSize(newCategoryButton).width, greaterThanOrEqualTo(48));
      expect(
        tester.getSize(newCategoryButton).height,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Expand',
        ),
      );
      await tester.pumpAndSettle();

      final moreButtonFinder = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'More',
      );
      final categoryTile = find.ancestor(
        of: find.text('News'),
        matching: find.byType(ListTile),
      );
      final categoryMoreButton = find.descendant(
        of: categoryTile,
        matching: moreButtonFinder,
      );
      expect(categoryMoreButton, findsOneWidget);

      await tester.tap(categoryMoreButton);
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsOneWidget);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      final feedTile = find.ancestor(
        of: find.text('Fleur Feed'),
        matching: find.byType(ListTile),
      );
      final feedMoreButton = find.descendant(
        of: feedTile,
        matching: moreButtonFinder,
      );
      expect(feedMoreButton, findsOneWidget);

      await tester.tap(feedMoreButton);
      await tester.pumpAndSettle();
      expect(find.text('Refresh'), findsOneWidget);
    },
  );

  testWidgets('OverflowMarquee respects reduced motion accessibility signals', (
    tester,
  ) async {
    const text = 'This is a long reader title that should normally animate.';

    Future<void> pumpReducedMotion(MediaQueryData mediaQuery) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: mediaQuery,
            child: const Scaffold(
              body: SizedBox(width: 120, child: OverflowMarquee(text: text)),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    for (final mediaQuery in <MediaQueryData>[
      const MediaQueryData(disableAnimations: true),
      const MediaQueryData(accessibleNavigation: true),
    ]) {
      await pumpReducedMotion(mediaQuery);

      expect(
        find.descendant(
          of: find.byType(OverflowMarquee),
          matching: find.byType(AnimatedBuilder),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(OverflowMarquee),
          matching: find.text(text),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byType(OverflowMarquee),
                matching: find.byType(Text),
              ),
            )
            .overflow,
        TextOverflow.ellipsis,
      );
    }
  });

  testWidgets(
    'OverflowMarquee resumes after reduced motion is turned back off',
    (tester) async {
      const text = 'This is a long reader title that should normally animate.';
      final mediaQuery = ValueNotifier(const MediaQueryData());
      addTearDown(mediaQuery.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<MediaQueryData>(
            valueListenable: mediaQuery,
            builder: (context, data, _) {
              return MediaQuery(
                data: data,
                child: const Scaffold(
                  body: SizedBox(
                    width: 120,
                    child: OverflowMarquee(
                      key: ValueKey('overflow_marquee'),
                      text: text,
                      pause: Duration(milliseconds: 1),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      double currentDx() {
        final transform = tester.widget<Transform>(
          find.descendant(
            of: find.byKey(const ValueKey('overflow_marquee')),
            matching: find.byType(Transform),
          ),
        );
        return transform.transform.storage[12];
      }

      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 200));
      expect(currentDx(), lessThan(0));

      mediaQuery.value = const MediaQueryData(disableAnimations: true);
      await tester.pump();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('overflow_marquee')),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );

      mediaQuery.value = const MediaQueryData();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 200));

      expect(currentDx(), lessThan(0));
    },
  );

  testWidgets(
    'Article list item reflects selected, unread, and starred states',
    (tester) async {
      final feed = _buildFeed();
      final article = _buildArticle(isRead: false, isStarred: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedsProvider.overrideWith((ref) => Stream.value([feed])),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ArticleListItem(article: article, selected: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final theme = AppTheme.light();
      final card = tester.widget<Card>(find.byType(Card));
      final title = tester.widget<Text>(find.text('Selected Article'));

      expect(card.color, theme.fleurSurface.cardSelected);
      expect(title.style?.fontWeight, FontWeight.w700);
      expect(find.byIcon(Icons.star), findsOneWidget);
    },
  );

  testWidgets('Article list item softens title weight on Windows', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final feed = _buildFeed();
    final article = _buildArticle(isRead: false, isStarred: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedsProvider.overrideWith((ref) => Stream.value([feed])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ArticleListItem(article: article, selected: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('Selected Article'));
    expect(title.style?.fontWeight, FontWeight.w600);
  });

  testWidgets(
    'Article list empty state keeps list surface and unread empty feedback',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsStoreProvider.overrideWithValue(
              FakeAppSettingsStore(AppSettings.defaults()),
            ),
            unreadOnlyProvider.overrideWith((ref) => true),
            articleListControllerProvider.overrideWith(
              _EmptyArticleListController.new,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: ArticleList(selectedArticleId: null)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(ArticleList));
      final l10n = AppLocalizations.of(element)!;
      final theme = Theme.of(element);
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text(l10n.noUnreadArticles),
              matching: find.byType(Container),
            )
            .first,
      );

      expect(find.text(l10n.noUnreadArticles), findsOneWidget);
      expect(container.color, theme.fleurSurface.list);
    },
  );

  testWidgets('Saved screen shows mode-specific empty feedback', (
    tester,
  ) async {
    const savedSectionKey = ValueKey<String>('saved-section-test');
    final router = GoRouter(
      initialLocation: '/saved',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        GoRoute(
          path: '/saved',
          pageBuilder: (context, state) => const NoTransitionPage(
            key: savedSectionKey,
            child: SavedScreen(selectedArticleId: null),
          ),
        ),
        GoRoute(path: '/search', builder: (context, state) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(AppSettings.defaults()),
          ),
          starredCountProvider.overrideWith((ref) => Stream.value(0)),
          readLaterCountProvider.overrideWith((ref) => Stream.value(0)),
          articleListControllerProvider.overrideWith(
            _EmptyArticleListController.new,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(SavedScreen));
    final l10n = AppLocalizations.of(element)!;

    expect(find.text(l10n.noStarredArticles), findsOneWidget);
    expect(find.text(l10n.noReadLaterArticles), findsNothing);

    await tester.tap(find.text('${l10n.readLater} (0)'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.noReadLaterArticles), findsOneWidget);
    expect(find.text(l10n.noStarredArticles), findsNothing);
  });
}

void _noopSelectFeed(int? _) {}
