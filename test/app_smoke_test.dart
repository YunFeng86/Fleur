import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import 'package:fleur/app/app.dart';
import 'package:fleur/app/router.dart';
import 'package:fleur/app/search_routes.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/article.dart';
import 'package:fleur/models/article_scope.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/providers/article_list_controller.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/app_update_providers.dart';
import 'package:fleur/providers/background_sync_providers.dart';
import 'package:fleur/providers/core_providers.dart';
import 'package:fleur/providers/outbox_status_providers.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/providers/reader_providers.dart';
import 'package:fleur/providers/refresh_all_providers.dart';
import 'package:fleur/providers/repository_providers.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/providers/settings_providers.dart';
import 'package:fleur/providers/sync_status_providers.dart';
import 'package:fleur/providers/unread_providers.dart';
import 'package:fleur/repositories/feed_repository.dart';
import 'package:fleur/screens/add_subscription_screen.dart';
import 'package:fleur/screens/home_screen.dart';
import 'package:fleur/screens/saved_screen.dart';
import 'package:fleur/screens/search_screen.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/reader_settings.dart';
import 'package:fleur/services/sync/sync_service.dart';
import 'package:fleur/services/sync/sync_status_reporter.dart';
import 'package:fleur/services/update/app_update_manifest.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/theme/app_typography.dart';
import 'package:fleur/theme/fleur_icons.dart';
import 'package:fleur/theme/fleur_theme_extensions.dart';
import 'package:fleur/ui/app_menu.dart';
import 'package:fleur/ui/app_drawer_scope.dart';
import 'package:fleur/ui/app_shell.dart';
import 'package:fleur/ui/home/home_scene_commands.dart';
import 'package:fleur/ui/home/home_scene_panes.dart';
import 'package:fleur/ui/home/home_scene_shortcuts.dart';
import 'package:fleur/ui/layout.dart';
import 'package:fleur/ui/layout_spec.dart';
import 'package:fleur/ui/shell_chrome_layout.dart';
import 'package:fleur/ui/sidebar_layout.dart';
import 'package:fleur/ui/sidebar/sidebar_selection_actions.dart';
import 'package:fleur/ui/sidebar/sidebar_tree.dart';
import 'package:fleur/ui/workspace_layers.dart';
import 'package:fleur/utils/platform.dart';
import 'package:fleur/utils/desktop_window_options.dart';
import 'package:fleur/widgets/article_list.dart';
import 'package:fleur/widgets/article_list_item.dart';
import 'package:fleur/widgets/app_scrollbar.dart';
import 'package:fleur/widgets/overflow_marquee.dart';
import 'package:fleur/widgets/reader_view.dart';
import 'package:fleur/widgets/sidebar.dart';
import 'package:fleur/widgets/sync_status_capsule.dart';

import 'test_utils/critical_workflow_test_support.dart';

GoRouter _buildRouter() {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
      GoRoute(
        path: '/all/article/:id',
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

Widget _buildShellHarness({
  Uri? currentUri,
  Widget? child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      activeAccountProvider.overrideWithValue(buildTestAccount()),
      feedsProvider.overrideWith((ref) => Stream.value(<Feed>[])),
      categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
      tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
      allUnreadCountsProvider.overrideWith(
        (ref) => Stream.value(<int?, int>{}),
      ),
      outboxPendingCountProvider.overrideWith((ref) async => 0),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppShell(
        currentUri: currentUri ?? Uri(path: '/'),
        child:
            child ??
            const ColoredBox(
              key: Key('app_shell_child'),
              color: Colors.transparent,
            ),
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

AppUpdateManifest _buildUpdateManifest() {
  return AppUpdateManifest(
    schemaVersion: 1,
    channel: AppUpdateChannel.stable,
    version: '9.9.9',
    tag: 'v9.9.9',
    publishedAt: DateTime.utc(2026, 1, 1),
    releaseUrl: Uri.parse('https://example.com/releases/v9.9.9'),
    notes: const {'en': 'Test update'},
    assets: const {},
  );
}

void _expectWorkspaceSurfaceAppearance(
  WidgetTester tester,
  Key key, {
  required BorderRadius borderRadius,
  required bool showShadow,
  required WorkspaceLayerEdge leadingEdge,
}) {
  final surface = tester.widget<WorkspaceLayerSurface>(find.byKey(key));
  expect(surface.borderRadius, borderRadius);
  expect(surface.showShadow, showShadow);
  expect(surface.leadingEdge, leadingEdge);
}

void _expectShellIconButtonRadius(WidgetTester tester, Key key) {
  final iconButton = tester.widget<IconButton>(
    find.descendant(of: find.byKey(key), matching: find.byType(IconButton)),
  );
  final shape = iconButton.style?.shape?.resolve(<WidgetState>{});

  expect(shape, isA<RoundedRectangleBorder>());
  expect(
    (shape! as RoundedRectangleBorder).borderRadius,
    BorderRadius.circular(kShellControlSize / 2),
  );
}

class _TestAppUpdateController extends AppUpdateController {
  _TestAppUpdateController(this.initialState);

  final AppUpdateState initialState;

  @override
  AppUpdateState build() => initialState;
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
  Future<HomeRefreshOutcome> refreshAll() async {
    calls.add('refresh');
    return const HomeRefreshOutcome(
      batch: BatchRefreshResult(<FeedRefreshResult>[]),
      successFeedback: HomeRefreshSuccessFeedback.refreshed,
    );
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

class _FakeFeedRepository extends Fake implements FeedRepository {
  _FakeFeedRepository(this.feeds);

  final List<Feed> feeds;

  @override
  Future<List<Feed>> getAll() async => feeds;

  @override
  Future<Feed?> getById(int id) async {
    for (final feed in feeds) {
      if (feed.id == id) return feed;
    }
    return null;
  }
}

class _FakeMinifluxSourceRefresh implements MinifluxSourceRefresh {
  int refreshAllCalls = 0;
  final List<int> refreshedFeedIds = <int>[];

  @override
  Future<void> refreshAll() async {
    refreshAllCalls++;
  }

  @override
  Future<void> refreshFeed(Feed feed) async {
    refreshedFeedIds.add(feed.id);
  }

  @override
  Future<void> refreshFeeds(List<Feed> feeds, {int maxConcurrent = 2}) async {
    refreshedFeedIds.addAll(feeds.map((feed) => feed.id));
  }
}

Future<HomeSceneCommands> _pumpHomeCommandsHarness(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  late HomeSceneCommands commands;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          return Consumer(
            builder: (context, ref, _) {
              commands = HomeSceneCommands(
                context: context,
                ref: ref,
                selectedArticleId: null,
              );
              return const SizedBox(key: ValueKey('home_commands_harness'));
            },
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: overrides,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return commands;
}

Future<void> _settleRailOverlayReveal(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 180));
  await tester.pumpAndSettle();
}

void main() {
  test('collapsed desktop sidebar does not consume content width', () {
    expect(
      effectiveContentWidth(
        1200,
        sidebarPresentationMode: SidebarPresentationMode.collapsed,
      ),
      1200,
    );
    expect(
      effectiveContentWidth(
        1200,
        sidebarPresentationMode: SidebarPresentationMode.expanded,
        sidebarWidth: kDefaultWorkspaceSidebarWidth,
      ),
      1200 - kDefaultWorkspaceSidebarWidth - kSidebarContentDividerWidth,
    );
  });

  test('workspace sidebar width clamps to window and app maximums', () {
    expect(clampWorkspaceSidebarWidth(999, 1200), kMaxWorkspaceSidebarWidth);
    expect(
      clampWorkspaceSidebarWidth(999, 700),
      700 - kMinWorkspaceContentWidth - kSidebarContentDividerWidth,
    );
    expect(clampWorkspaceSidebarWidth(999, 500), kMinWorkspaceSidebarWidth);
  });

  test('reader embedding stays monotonic while desktop width narrows', () {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    LayoutSpec specFor(double width) => LayoutSpec.fromTotalSize(
      totalWidth: width,
      totalHeight: 800,
      sidebarPresentationMode: SidebarPresentationMode.expanded,
      sidebarWidth: kDefaultWorkspaceSidebarWidth,
      listWidth: kDefaultWorkspaceListWidth,
    );

    const widths = <double>[1200, 1078, 1000, 899, 822, 821];

    expect(
      widths
          .map(
            (width) => shouldEmbedReaderForLayout(
              specFor(width),
              listWidth: kHomeListWidth,
            ),
          )
          .toList(),
      <bool>[true, true, true, false, false, false],
    );
    expect(
      widths
          .map(
            (width) => shouldEmbedReaderForLayout(
              specFor(width),
              listWidth: kDesktopListWidth,
            ),
          )
          .toList(),
      <bool>[true, true, true, false, false, false],
    );
    expect(
      widths
          .map(
            (width) => shouldCollapseSidebarForReaderLayout(
              specFor(width),
              preferredListWidth: kHomeListWidth,
            ),
          )
          .toList(),
      <bool>[false, true, true, false, false, false],
    );
    expect(
      canEmbedDesktopReaderForContentWidth(
        822,
        preferredListWidth: kDesktopListWidth,
      ),
      isTrue,
    );
    expect(
      canEmbedDesktopReaderForContentWidth(
        821,
        preferredListWidth: kDesktopListWidth,
      ),
      isFalse,
    );
  });

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

  testWidgets(
    'Desktop chrome shows Fever account sync without hiding feed actions',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.macOS;
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => debugFleurTargetPlatformOverride = null);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/all',
        routes: [
          GoRoute(
            path: '/all',
            builder: (context, state) =>
                const HomeScreen(selectedArticleId: null),
          ),
          GoRoute(
            path: '/all/article/:id',
            builder: (context, state) => Text(state.pathParameters['id'] ?? ''),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routerProvider.overrideWithValue(router),
            activeAccountProvider.overrideWithValue(
              buildTestAccount(type: AccountType.fever),
            ),
            appSettingsStoreProvider.overrideWithValue(
              FakeAppSettingsStore(AppSettings.defaults()),
            ),
            articleListControllerProvider.overrideWith(
              _EmptyArticleListController.new,
            ),
            feedsProvider.overrideWith((ref) => Stream.value(<Feed>[])),
            categoriesProvider.overrideWith(
              (ref) => Stream.value(<Category>[]),
            ),
            tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
            allUnreadCountsProvider.overrideWith(
              (ref) => Stream.value(<int?, int>{null: 0}),
            ),
            outboxPendingCountProvider.overrideWith((ref) async => 0),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Sync account'), findsOneWidget);
      expect(find.byTooltip('Refresh sources'), findsNothing);
      expect(find.byTooltip('Unread only'), findsOneWidget);
      expect(find.byTooltip('Mark all read'), findsOneWidget);
    },
  );

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
      desktopTheme.fleurState.scrollbarIdle,
    );
    expect(
      desktopTheme.scrollbarTheme.thumbColor?.resolve(<WidgetState>{
        WidgetState.hovered,
      }),
      desktopTheme.fleurState.scrollbarHover,
    );
    expect(
      desktopTheme.scrollbarTheme.thumbColor?.resolve(<WidgetState>{
        WidgetState.dragged,
      }),
      desktopTheme.fleurState.scrollbarDrag,
    );

    debugFleurTargetPlatformOverride = TargetPlatform.android;
    final mobileTheme = AppTheme.light();
    expect(
      mobileTheme.scrollbarTheme.thumbVisibility?.resolve(<WidgetState>{}),
      isFalse,
    );
    expect(mobileTheme.scrollbarTheme.thickness?.resolve(<WidgetState>{}), 8);
    expect(desktopTheme.navigationRailTheme.labelType, isNull);
    expect(desktopTheme.navigationBarTheme.height, isNull);
    expect(mobileTheme.navigationBarTheme.height, isNull);
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
    expect(macTheme.fleurReader.metaStyle.fontWeight, FontWeight.w500);
    expect(macTheme.fleurReader.metaStyle.fontSize, 12);
  });

  test('Desktop window options hide native chrome for Flutter titlebars', () {
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    expect(desktopWindowOptions().titleBarStyle, TitleBarStyle.hidden);

    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    expect(desktopWindowOptions().titleBarStyle, TitleBarStyle.hidden);

    debugFleurTargetPlatformOverride = TargetPlatform.linux;
    expect(desktopWindowOptions().titleBarStyle, TitleBarStyle.hidden);
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
    final draggedThumbColor = scrollbarTheme().data.thumbColor?.resolve(
      <WidgetState>{WidgetState.dragged},
    );
    final hoveredThickness = scrollbarTheme().data.thickness?.resolve(
      <WidgetState>{},
    );
    final theme = Theme.of(tester.element(find.byType(AppScrollbar)));

    expect(idleThumbColor, theme.fleurState.scrollbarIdle);
    expect(hoveredThumbColor, isNot(idleThumbColor));
    expect(draggedThumbColor, theme.fleurState.scrollbarDrag);
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

  testWidgets('App shell switches between layered sidebar states', (
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
    final theme = AppTheme.light();

    expect(find.byType(Sidebar), findsOneWidget);
    expect(
      tester.getSize(find.byType(Sidebar)).width,
      kDefaultWorkspaceSidebarWidth,
    );
    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
    expect(find.byKey(const Key('app_shell_rail_overlay')), findsNothing);
    expect(find.byKey(const Key('shell_title_bar')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('shell_title_bar'))).height,
      kWorkspaceHeaderHeight,
    );
    expect(find.byKey(const Key('shell_title_bar_divider')), findsOneWidget);
    expect(find.byKey(const Key('shell_sidebar_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_back_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_forward_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_search_button')), findsOneWidget);
    expect(
      find.byKey(const Key('shell_window_caption_controls')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('shell_window_minimize_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('shell_window_maximize_button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('shell_window_close_button')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('shell_window_caption_controls'))),
      const Size(kShellWindowCaptionControlsWidth, kWorkspaceHeaderHeight),
    );
    expect(
      tester.getSize(find.byKey(const Key('shell_window_minimize_button'))),
      const Size(kShellWindowCaptionButtonWidth, kWorkspaceHeaderHeight),
    );
    expect(
      tester.getSize(find.byKey(const Key('shell_window_maximize_button'))),
      const Size(kShellWindowCaptionButtonWidth, kWorkspaceHeaderHeight),
    );
    expect(
      tester.getSize(find.byKey(const Key('shell_window_close_button'))),
      const Size(kShellWindowCaptionButtonWidth, kWorkspaceHeaderHeight),
    );
    expect(find.byKey(const Key('shell_outbox_button')), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('shell_sidebar_button'))),
      const Size.square(kShellControlSize),
    );
    _expectShellIconButtonRadius(tester, const Key('shell_sidebar_button'));
    final expandedSidebarIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('shell_sidebar_button')),
        matching: find.byType(Icon),
      ),
    );
    expect(expandedSidebarIcon.size, kShellControlIconSize);
    expect(
      tester.getSize(find.byKey(const Key('sidebar_all_button'))),
      const Size.square(kShellControlSize),
    );
    final expandedAllIconSurface = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(const Key('sidebar_all_button')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (expandedAllIconSurface.decoration as BoxDecoration).color,
      theme.fleurState.selectionTint,
    );
    expect(
      find.byKey(const Key('sidebar_collapsed_rail_surface')),
      findsNothing,
    );
    expect(find.byKey(const Key('app_shell_sidebar_divider')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('app_shell_content_layer')),
        matching: find.byKey(const Key('workspace_layer_leading_edge')),
      ),
      findsNothing,
    );
    _expectWorkspaceSurfaceAppearance(
      tester,
      const Key('app_shell_content_layer'),
      borderRadius: kConnectedWorkspaceLayerRadius,
      showShadow: false,
      leadingEdge: WorkspaceLayerEdge.none,
    );
    expect(
      find.byKey(const Key('app_shell_sidebar_split_handle')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('app_shell_sidebar_split_handle')),
        matching: find.byType(ColoredBox),
      ),
      findsNothing,
    );
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('app_shell_child'))).height,
      900 - kWorkspaceHeaderHeight,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dy,
      kWorkspaceHeaderHeight,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
      kDefaultWorkspaceSidebarWidth + kSidebarContentDividerWidth,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('shell_title_bar_divider'))).dx,
      kDefaultWorkspaceSidebarWidth + kSidebarContentDividerWidth,
    );
    final expandedToggleTopLeft = tester.getTopLeft(
      find.byKey(const Key('shell_sidebar_button')),
    );
    final expandedForwardRight = tester
        .getRect(find.byKey(const Key('shell_forward_button')))
        .right;
    final expandedSearchTopLeft = tester.getTopLeft(
      find.byKey(const Key('shell_search_button')),
    );
    expect(expandedSearchTopLeft.dx, 16 + kShellControlSize * 3);
    expect(expandedSearchTopLeft.dy, kShellControlTopInset);
    expect(expandedSearchTopLeft.dx, expandedForwardRight);
    final expandedAllDx = tester
        .getCenter(find.byKey(const Key('sidebar_all_button')))
        .dx;
    final expandedStarredDx = tester
        .getCenter(find.byKey(const Key('sidebar_starred_button')))
        .dx;
    final expandedReadLaterDx = tester
        .getCenter(find.byKey(const Key('sidebar_read_later_button')))
        .dx;
    final expandedAddDx = tester
        .getCenter(find.byKey(const Key('sidebar_add_subscription_button')))
        .dx;
    final expandedAccountCenter = tester.getCenter(
      find.byKey(const Key('sidebar_account_button')),
    );
    final fixedItemDx = kSidebarRailWidth / 2;
    const collapsedFixedItemDx = kTitleBarExpectedSidebarRailWidth / 2;
    expect(expandedAllDx, fixedItemDx);
    expect(expandedStarredDx, fixedItemDx);
    expect(expandedReadLaterDx, fixedItemDx);
    expect(expandedAddDx, fixedItemDx);
    final addTileRect = tester.getRect(
      find
          .ancestor(
            of: find.byKey(const Key('sidebar_add_subscription_button')),
            matching: find.byType(ListTile),
          )
          .first,
    );
    final subscriptionsTitleRect = tester.getRect(find.text('Subscriptions'));
    expect(subscriptionsTitleRect.top - addTileRect.bottom, lessThan(16));
    final newCategoryButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'New category',
    );
    expect(tester.getSize(newCategoryButton), const Size.square(32));

    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app_shell_rail_overlay')), findsNothing);
    expect(find.byType(Sidebar), findsOneWidget);
    expect(find.byKey(const Key('app_shell_connected_rail')), findsOneWidget);
    final connectedRail = find.byKey(const Key('app_shell_connected_rail'));
    expect(
      tester.getSize(connectedRail).width,
      kTitleBarExpectedSidebarRailWidth,
    );
    final collapsedRailSurface = find.descendant(
      of: connectedRail,
      matching: find.byKey(const Key('sidebar_collapsed_rail_surface')),
    );
    expect(collapsedRailSurface, findsNothing);
    expect(
      find.descendant(
        of: connectedRail,
        matching: find.byKey(const Key('sidebar_collapsed_rail_divider')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: collapsedRailSurface,
        matching: find.byKey(const Key('sidebar_account_button')),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
    expect(find.byKey(const Key('shell_sidebar_toggle_capsule')), findsNothing);
    expect(
      find.byKey(const Key('shell_content_controls_capsule')),
      findsNothing,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
      kTitleBarExpectedSidebarRailWidth,
    );
    _expectWorkspaceSurfaceAppearance(
      tester,
      const Key('app_shell_content_layer'),
      borderRadius: kConnectedWorkspaceLayerRadius,
      showShadow: false,
      leadingEdge: WorkspaceLayerEdge.none,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('shell_title_bar_divider'))).dx,
      kTitleBarExpectedSidebarRailWidth,
    );
    expect(find.byKey(const Key('shell_back_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_forward_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_search_button')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('shell_sidebar_button'))).dx,
      12,
    );
    _expectShellIconButtonRadius(tester, const Key('shell_sidebar_button'));
    expect(
      tester.getTopLeft(find.byKey(const Key('shell_sidebar_button'))).dy,
      expandedToggleTopLeft.dy,
    );
    Finder railButton(Key key) =>
        find.descendant(of: connectedRail, matching: find.byKey(key));
    final collapsedAllButton = tester.widget<IconButton>(
      find
          .descendant(
            of: railButton(const Key('sidebar_all_button')),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(
      collapsedAllButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      theme.fleurState.selectionTint,
    );
    expect(
      tester.getCenter(railButton(const Key('sidebar_all_button'))).dx,
      collapsedFixedItemDx,
    );
    expect(
      tester.getCenter(railButton(const Key('sidebar_starred_button'))).dx,
      collapsedFixedItemDx,
    );
    expect(
      tester.getCenter(railButton(const Key('sidebar_read_later_button'))).dx,
      collapsedFixedItemDx,
    );
    expect(
      tester
          .getCenter(railButton(const Key('sidebar_add_subscription_button')))
          .dx,
      collapsedFixedItemDx,
    );
    expect(
      tester.getSize(railButton(const Key('sidebar_account_button'))),
      const Size.square(kShellControlSize),
    );
    expect(
      tester.getCenter(railButton(const Key('sidebar_account_button'))).dx,
      collapsedFixedItemDx,
    );
    expect(
      tester.getCenter(railButton(const Key('sidebar_account_button'))).dy,
      expandedAccountCenter.dy,
    );

    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pump();
    expect(find.byKey(const Key('app_shell_rail_overlay')), findsNothing);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(Sidebar)).width,
      kDefaultWorkspaceSidebarWidth,
    );
    expect(find.byKey(const Key('app_shell_rail_overlay')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
      kDefaultWorkspaceSidebarWidth + kSidebarContentDividerWidth,
    );

    tester.view.physicalSize = const Size(640, 900);
    await tester.pumpWidget(_buildShellHarness());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(Sidebar), findsOneWidget);
    expect(find.byKey(const Key('app_shell_rail_overlay')), findsNothing);
    expect(find.byKey(const Key('app_shell_connected_rail')), findsOneWidget);
    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
    expect(find.byKey(const Key('shell_drawer_controls')), findsNothing);
    expect(find.byKey(const Key('app_shell_sidebar_divider')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
      kTitleBarExpectedSidebarRailWidth,
    );
    expect(
      tester.getSize(find.byKey(const Key('app_shell_child'))).height,
      900 - kWorkspaceHeaderHeight,
    );

    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pump();

    expect(find.byType(Sidebar), findsOneWidget);
    expect(find.byKey(const Key('app_shell_rail_overlay')), findsNothing);
    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
      kDefaultWorkspaceSidebarWidth,
    );
  });

  testWidgets('Windows compact shell uses off-canvas push reveal', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(475, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildShellHarness());
    await tester.pumpAndSettle();

    final contentLayer = find.byKey(const Key('app_shell_content_layer'));
    expect(find.byKey(const Key('shell_title_bar')), findsOneWidget);
    expect(find.byKey(const Key('app_shell_connected_rail')), findsNothing);
    expect(find.byKey(const Key('app_shell_rail_overlay')), findsNothing);
    expect(tester.getTopLeft(contentLayer).dx, 0);
    expect(tester.getSize(contentLayer).width, 475);

    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pumpAndSettle();

    expect(find.byType(Sidebar), findsOneWidget);
    expect(find.byKey(const Key('app_shell_navigation_scrim')), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'shell-temporary-navigation',
    );
    expect(tester.getTopLeft(contentLayer).dx, kTemporaryWorkspaceSidebarWidth);
    expect(tester.getSize(contentLayer).width, 475);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app_shell_navigation_scrim')), findsNothing);
    expect(tester.getTopLeft(contentLayer).dx, 0);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'shell-navigation-toggle',
    );
  });

  testWidgets('Windows shell keeps update and search actions in titlebar', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildShellHarness(
        overrides: [
          appUpdateControllerProvider.overrideWith(
            () => _TestAppUpdateController(
              AppUpdateState(
                status: AppUpdateStatus.updateAvailable,
                manifest: _buildUpdateManifest(),
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell_search_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_update_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_window_close_button')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_update_button')), findsNothing);
    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);

    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pump();

    expect(find.byKey(const Key('shell_search_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_update_button')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_update_button')), findsNothing);
    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
    expect(find.byKey(const Key('app_shell_connected_rail')), findsOneWidget);
    expect(find.byKey(const Key('app_shell_rail_overlay')), findsNothing);
    expect(
      find.byKey(const Key('sidebar_collapsed_rail_surface')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('sidebar_collapsed_rail_divider')),
      findsOneWidget,
    );
  });

  testWidgets('Windows home header actions stay in the content header', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildShellHarness(
        currentUri: Uri(path: '/all'),
        child: const HomeScreen(selectedArticleId: null),
        overrides: [
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(AppSettings.defaults()),
          ),
          articleListControllerProvider.overrideWith(
            _EmptyArticleListController.new,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final titleBar = find.byKey(const Key('shell_title_bar'));
    expect(titleBar, findsOneWidget);
    final header = find.byKey(const Key('home_scope_header'));
    expect(header, findsOneWidget);
    expect(
      find.descendant(of: titleBar, matching: find.text('All Articles')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: titleBar,
        matching: find.byKey(const Key('home_scope_actions')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: header, matching: find.text('All Articles')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: header,
        matching: find.byKey(const Key('home_scope_actions')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: header,
        matching: find.byKey(const Key('scope_refresh_button')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: header,
        matching: find.byKey(const Key('scope_unread_filter_button')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: header,
        matching: find.byKey(const Key('scope_mark_all_read_button')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('macOS narrow expanded sidebar shows update as icon only', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildShellHarness(
        overrides: [
          appUpdateControllerProvider.overrideWith(
            () => _TestAppUpdateController(
              AppUpdateState(
                status: AppUpdateStatus.updateAvailable,
                manifest: _buildUpdateManifest(),
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell_update_button')), findsNothing);
    expect(find.byKey(const Key('sidebar_update_button')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('sidebar_update_button')),
        matching: find.text('Update'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('sidebar_update_button')),
        matching: find.byIcon(FleurIcons.download),
      ),
      findsOneWidget,
    );
  });

  testWidgets('macOS wide expanded sidebar shows update as text', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildShellHarness(
        overrides: [
          workspaceSidebarWidthProvider.overrideWith(
            (ref) => kMaxWorkspaceSidebarWidth,
          ),
          appUpdateControllerProvider.overrideWith(
            () => _TestAppUpdateController(
              AppUpdateState(
                status: AppUpdateStatus.updateAvailable,
                manifest: _buildUpdateManifest(),
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell_update_button')), findsNothing);
    expect(find.byKey(const Key('sidebar_update_button')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('sidebar_update_button')),
        matching: find.text('Update'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Linux shell uses titlebar controls and a plain collapsed rail', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildShellHarness());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell_search_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
    expect(find.byKey(const Key('shell_window_close_button')), findsOneWidget);
    _expectWorkspaceSurfaceAppearance(
      tester,
      const Key('app_shell_content_layer'),
      borderRadius: kConnectedWorkspaceLayerRadius,
      showShadow: false,
      leadingEdge: WorkspaceLayerEdge.none,
    );

    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pump();
    await _settleRailOverlayReveal(tester);

    expect(find.byKey(const Key('shell_search_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
    expect(
      find.byKey(const Key('sidebar_collapsed_rail_surface')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('sidebar_collapsed_rail_divider')),
      findsOneWidget,
    );
    _expectWorkspaceSurfaceAppearance(
      tester,
      const Key('app_shell_content_layer'),
      borderRadius: kConnectedWorkspaceLayerRadius,
      showShadow: false,
      leadingEdge: WorkspaceLayerEdge.none,
    );
  });

  testWidgets('App shell utility routes drive sidebar active states', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    ListTile fixedTile(WidgetTester tester, Key key) {
      return tester.widget<ListTile>(
        find
            .ancestor(of: find.byKey(key), matching: find.byType(ListTile))
            .first,
      );
    }

    await tester.pumpWidget(
      _buildShellHarness(
        currentUri: Uri.parse('/search/article/42?q=claude&scope=all'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('shell_search_button')),
        matching: find.byIcon(FleurIcons.searchSelected),
      ),
      findsOneWidget,
    );
    expect(
      fixedTile(tester, const Key('sidebar_all_button')).selected,
      isFalse,
    );

    await tester.pumpWidget(
      _buildShellHarness(
        currentUri: Uri.parse('/add-subscription?categoryId=7'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      fixedTile(tester, const Key('sidebar_add_subscription_button')).selected,
      isTrue,
    );
    expect(
      fixedTile(tester, const Key('sidebar_all_button')).selected,
      isFalse,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('shell_search_button')),
        matching: find.byIcon(FleurIcons.searchSelected),
      ),
      findsNothing,
    );
  });

  testWidgets('Windows shell titlebar sits above shifted workspace content', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildShellHarness(
        child: const Column(
          children: [
            SizedBox(
              key: Key('home_scope_header'),
              height: kWorkspaceHeaderHeight,
            ),
            Expanded(
              child: ColoredBox(
                key: Key('app_shell_child'),
                color: Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final shellCenter = tester
        .getCenter(find.byKey(const Key('shell_sidebar_button')))
        .dy;
    final shellCenterX = tester
        .getCenter(find.byKey(const Key('shell_sidebar_button')))
        .dx;
    final headerTop = tester
        .getTopLeft(find.byKey(const Key('home_scope_header')))
        .dy;
    final headerCenter = tester
        .getCenter(find.byKey(const Key('home_scope_header')))
        .dy;

    expect(shellCenter, kWorkspaceHeaderHeight / 2);
    expect(shellCenterX, kSidebarRailWidth / 2);
    expect(headerTop, kWorkspaceHeaderHeight);
    expect(headerCenter, kWorkspaceHeaderHeight + kWorkspaceHeaderHeight / 2);
  });

  testWidgets('App shell sidebar split handle resizes the content layer', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildShellHarness());
    await tester.pumpAndSettle();

    final initialContentLeft = tester
        .getTopLeft(find.byKey(const Key('app_shell_content_layer')))
        .dx;
    await tester.dragFrom(
      Offset(kDefaultWorkspaceSidebarWidth, kWorkspaceHeaderHeight / 2),
      const Offset(200, 0),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
      initialContentLeft,
    );

    await tester.drag(
      find.byKey(const Key('app_shell_sidebar_split_handle')),
      const Offset(200, 0),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
      kMaxWorkspaceSidebarWidth + kSidebarContentDividerWidth,
    );
  });

  testWidgets(
    'App shell sidebar split handle preserves max-width overshoot until the pointer returns',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugFleurTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildShellHarness());
      await tester.pumpAndSettle();

      final handle = find.byKey(const Key('app_shell_sidebar_split_handle'));
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveBy(const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
        kMaxWorkspaceSidebarWidth + kSidebarContentDividerWidth,
      );

      await gesture.moveBy(const Offset(-50, 0));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
        kMaxWorkspaceSidebarWidth + kSidebarContentDividerWidth,
      );

      await gesture.moveBy(const Offset(-60, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
        350 + kSidebarContentDividerWidth,
      );
    },
  );

  testWidgets(
    'App shell sidebar split handle clamps at minimum without small-overshoot collapse',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugFleurTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildShellHarness());
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('app_shell_sidebar_split_handle')),
        const Offset(-52, 0),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('app_shell_sidebar_split_handle')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
      expect(find.byKey(const Key('app_shell_rail_overlay')), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
        kMinWorkspaceSidebarWidth + kSidebarContentDividerWidth,
      );

      final element = tester.element(find.byKey(const Key('app_shell_child')));
      final container = ProviderScope.containerOf(element);
      expect(
        container.read(sidebarPresentationModeProvider),
        SidebarPresentationMode.expanded,
      );
      expect(
        container.read(workspaceSidebarWidthProvider),
        kMinWorkspaceSidebarWidth,
      );
    },
  );

  testWidgets(
    'App shell sidebar split handle collapses immediately after minimum-width overshoot',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugFleurTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildShellHarness());
      await tester.pumpAndSettle();

      final handle = find.byKey(const Key('app_shell_sidebar_split_handle'));
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveBy(const Offset(-160, 0));
      await tester.pump();

      expect(handle, findsNothing);
      final element = tester.element(find.byKey(const Key('app_shell_child')));
      final container = ProviderScope.containerOf(element);
      expect(
        container.read(sidebarPresentationModeProvider),
        SidebarPresentationMode.collapsed,
      );
      expect(
        container.read(workspaceSidebarWidthProvider),
        kMinWorkspaceSidebarWidth,
      );

      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
      expect(find.byKey(const Key('app_shell_rail_overlay')), findsNothing);
      expect(find.byKey(const Key('app_shell_connected_rail')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
        kTitleBarExpectedSidebarRailWidth,
      );
    },
  );

  testWidgets(
    'App shell sidebar split handle stays collapsed when overshoot is pulled back',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugFleurTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildShellHarness());
      await tester.pumpAndSettle();

      final handle = find.byKey(const Key('app_shell_sidebar_split_handle'));
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveBy(const Offset(-160, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(30, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(handle, findsNothing);
      expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
      expect(find.byKey(const Key('app_shell_rail_overlay')), findsNothing);
      expect(find.byKey(const Key('app_shell_connected_rail')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
        kTitleBarExpectedSidebarRailWidth,
      );

      final element = tester.element(find.byKey(const Key('app_shell_child')));
      final container = ProviderScope.containerOf(element);
      expect(
        container.read(sidebarPresentationModeProvider),
        SidebarPresentationMode.collapsed,
      );
      expect(
        container.read(workspaceSidebarWidthProvider),
        kMinWorkspaceSidebarWidth,
      );
    },
  );

  testWidgets('Windows connected rail gives content headers their full width', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildShellHarness(
        child: Column(
          children: [
            WorkspaceHeader(
              title: 'All Articles',
              trailingWidth: kShellControlSize,
              trailing: const SizedBox.square(
                dimension: kShellControlSize,
                key: Key('rail_clear_trailing'),
              ),
            ),
            Builder(
              builder: (context) {
                final scope = ShellLayerScope.maybeOf(context);
                return Text(
                  'leading:${scope?.contentLeadingInset}',
                  key: const Key('content_leading_inset_probe'),
                );
              },
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app_shell_rail_overlay')), findsNothing);
    expect(find.byKey(const Key('app_shell_connected_rail')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
      kTitleBarExpectedSidebarRailWidth,
    );
    expect(find.text('leading:0.0'), findsOneWidget);
  });

  testWidgets('App shell keeps macOS traffic lights clear of sidebar items', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildShellHarness());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell_title_bar')), findsNothing);
    expect(find.byKey(const Key('shell_window_close_button')), findsNothing);

    final allButtonTop = tester
        .getTopLeft(find.byKey(const Key('sidebar_all_button')))
        .dy;
    final shellButtonLeft = tester
        .getTopLeft(find.byKey(const Key('shell_sidebar_button')))
        .dx;
    final shellButtonTop = tester
        .getTopLeft(find.byKey(const Key('shell_sidebar_button')))
        .dy;
    final shellButtonCenter = tester
        .getCenter(find.byKey(const Key('shell_sidebar_button')))
        .dy;

    expect(kMacOSTrafficLightTargetCenterY, kWorkspaceHeaderHeight / 2);
    expect(shellButtonLeft, greaterThanOrEqualTo(kMacOSTrafficLightSafeInset));
    expect(shellButtonTop, kMacOSShellControlTopInset);
    expect(shellButtonCenter, kMacOSTrafficLightTargetCenterY);
    expect(
      tester.getSize(find.byKey(const Key('shell_sidebar_button'))),
      const Size.square(kShellControlSize),
    );
    expect(allButtonTop, greaterThanOrEqualTo(kWorkspaceHeaderHeight));
    expect(
      tester.getSize(find.byKey(const Key('app_shell_child'))).height,
      900,
    );
  });

  testWidgets('macOS sidebar collapses with one click after re-expanding', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildShellHarness());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('app_shell_child'))),
    );

    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pumpAndSettle();
    await _settleRailOverlayReveal(tester);
    expect(
      container.read(sidebarPresentationModeProvider),
      SidebarPresentationMode.collapsed,
    );
    expect(find.byKey(const Key('shell_controls_capsule')), findsOneWidget);

    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pumpAndSettle();
    expect(
      container.read(sidebarPresentationModeProvider),
      SidebarPresentationMode.expanded,
    );
    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);

    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pumpAndSettle();
    await _settleRailOverlayReveal(tester);
    expect(
      container.read(sidebarPresentationModeProvider),
      SidebarPresentationMode.collapsed,
    );
    expect(find.byKey(const Key('shell_controls_capsule')), findsOneWidget);
  });

  testWidgets('App shell follows macOS traffic light metrics', (tester) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildShellHarness(
        overrides: [
          macOSWindowChromeMetricsProvider.overrideWith(
            (ref) => const MacOSWindowChromeMetrics(
              trafficLightsVisible: true,
              centerY: 26,
              safeInset: 96,
              isFullScreen: false,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final shellButtonLeft = tester
        .getTopLeft(find.byKey(const Key('shell_sidebar_button')))
        .dx;
    final shellButtonTop = tester
        .getTopLeft(find.byKey(const Key('shell_sidebar_button')))
        .dy;
    final shellButtonCenter = tester
        .getCenter(find.byKey(const Key('shell_sidebar_button')))
        .dy;
    final shellSearchCenter = tester
        .getCenter(find.byKey(const Key('shell_search_button')))
        .dy;

    expect(shellButtonLeft, 96);
    expect(shellButtonTop, 26 - (kShellControlSize / 2));
    expect(shellButtonCenter, 26);
    expect(shellSearchCenter, 26);
  });

  testWidgets(
    'App shell returns inline controls to the leading edge fullscreen',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugFleurTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildShellHarness(
          overrides: [
            macOSWindowChromeMetricsProvider.overrideWith(
              (ref) => const MacOSWindowChromeMetrics(
                trafficLightsVisible: false,
                centerY: kMacOSTrafficLightTargetCenterY,
                safeInset: 0,
                isFullScreen: true,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final shellButtonLeft = tester
          .getTopLeft(find.byKey(const Key('shell_sidebar_button')))
          .dx;
      final shellButtonCenter = tester
          .getCenter(find.byKey(const Key('shell_sidebar_button')))
          .dy;

      expect(shellButtonLeft, 12);
      expect(shellButtonCenter, kMacOSTrafficLightTargetCenterY);
    },
  );

  testWidgets('App shell fullscreen controls respect click-safe top inset', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildShellHarness(
        overrides: [
          macOSWindowChromeMetricsProvider.overrideWith(
            (ref) => const MacOSWindowChromeMetrics(
              trafficLightsVisible: false,
              centerY: kMacOSTrafficLightTargetCenterY,
              safeInset: 0,
              isFullScreen: true,
              clickSafeTopInset: 12,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const Key('shell_sidebar_button'))).dx,
      12,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('shell_sidebar_button'))).dy,
      12,
    );
  });

  testWidgets(
    'App shell returns narrow layered controls to the leading edge fullscreen',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugFleurTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(640, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildShellHarness(
          overrides: [
            macOSWindowChromeMetricsProvider.overrideWith(
              (ref) => const MacOSWindowChromeMetrics(
                trafficLightsVisible: false,
                centerY: kMacOSTrafficLightTargetCenterY,
                safeInset: 0,
                isFullScreen: true,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _settleRailOverlayReveal(tester);

      expect(find.byKey(const Key('shell_drawer_controls')), findsNothing);
      expect(find.byKey(const Key('shell_controls_capsule')), findsOneWidget);
      expect(find.byKey(const Key('app_shell_rail_overlay')), findsOneWidget);
      expect(
        find.byKey(const Key('sidebar_collapsed_rail_surface')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('sidebar_collapsed_rail_divider')),
        findsNothing,
      );
      _expectWorkspaceSurfaceAppearance(
        tester,
        const Key('app_shell_content_layer'),
        borderRadius: kWorkspaceLayerRadius,
        showShadow: true,
        leadingEdge: WorkspaceLayerEdge.level1,
      );

      final shellButtonLeft = tester
          .getTopLeft(find.byKey(const Key('shell_sidebar_button')))
          .dx;

      expect(shellButtonLeft, 12);
    },
  );

  testWidgets('App shell hides capsule controls on dedicated reader pages', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildShellHarness(currentUri: Uri(path: '/all/article/42')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
    expect(find.byKey(const Key('shell_drawer_controls')), findsNothing);
    expect(find.byKey(const Key('shell_sidebar_button')), findsNothing);
    expect(find.byKey(const Key('shell_window_close_button')), findsOneWidget);
    expect(find.byType(Sidebar), findsNothing);
    expect(find.byKey(const Key('app_shell_child')), findsOneWidget);
  });

  testWidgets(
    'App shell temporarily collapses sidebar for middle-width article routes',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugFleurTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1000, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildShellHarness(currentUri: Uri(path: '/all/article/42')),
      );
      await tester.pump();

      expect(find.byKey(const Key('app_shell_secondary_layer')), findsNothing);
      expect(find.byKey(const Key('app_shell_sidebar_divider')), findsNothing);
      expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
      expect(find.byKey(const Key('shell_drawer_controls')), findsNothing);
      expect(find.byKey(const Key('shell_sidebar_button')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
        kTitleBarExpectedSidebarRailWidth,
      );

      final element = tester.element(find.byKey(const Key('app_shell_child')));
      final container = ProviderScope.containerOf(element);
      expect(
        container.read(sidebarPresentationModeProvider),
        SidebarPresentationMode.expanded,
      );
    },
  );

  testWidgets(
    'App shell temporary sidebar uses fixed width with a wide saved sidebar',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugFleurTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1000, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildShellHarness(
          currentUri: Uri(path: '/all/article/42'),
          overrides: [
            workspaceSidebarWidthProvider.overrideWith(
              (ref) => kMaxWorkspaceSidebarWidth,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
        kTitleBarExpectedSidebarRailWidth,
      );

      await tester.tap(find.byKey(const Key('shell_sidebar_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
      expect(
        tester.getSize(find.byType(Sidebar).first).width,
        kTemporaryWorkspaceSidebarWidth,
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
        kTemporaryWorkspaceSidebarWidth,
      );

      final element = tester.element(find.byKey(const Key('app_shell_child')));
      final container = ProviderScope.containerOf(element);
      expect(
        container.read(workspaceSidebarWidthProvider),
        kMaxWorkspaceSidebarWidth,
      );
    },
  );

  testWidgets('sidebar fixed items and account menu navigate to shell routes', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final router = GoRouter(
      initialLocation: '/all',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              AppShell(currentUri: state.uri, child: child),
          routes: [
            GoRoute(
              path: '/all',
              builder: (context, state) => const Text('all page'),
            ),
            GoRoute(
              path: '/starred',
              builder: (context, state) => const Text('starred page'),
            ),
            GoRoute(
              path: '/read-later',
              builder: (context, state) => const Text('read later page'),
            ),
            GoRoute(
              path: '/add-subscription',
              builder: (context, state) => const Text('add page'),
            ),
            GoRoute(
              path: '/search',
              builder: (context, state) => const Text('search page'),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const Text('settings page'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(buildTestAccount()),
          feedsProvider.overrideWith((ref) => Stream.value(<Feed>[])),
          categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
          tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
          allUnreadCountsProvider.overrideWith(
            (ref) => Stream.value(<int?, int>{null: 0}),
          ),
          outboxPendingCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    ListTile fixedTile(Key key) {
      return tester.widget<ListTile>(
        find
            .ancestor(of: find.byKey(key), matching: find.byType(ListTile))
            .first,
      );
    }

    await tester.tap(find.byKey(const Key('shell_search_button')));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/search',
    );
    expect(find.text('search page'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('shell_search_button')),
        matching: find.byIcon(FleurIcons.searchSelected),
      ),
      findsOneWidget,
    );
    expect(fixedTile(const Key('sidebar_all_button')).selected, isFalse);

    await tester.tap(find.byKey(const Key('sidebar_all_button')));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/all');
    expect(fixedTile(const Key('sidebar_all_button')).selected, isTrue);

    await tester.tap(find.byKey(const Key('sidebar_starred_button')));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/starred',
    );
    expect(find.text('starred page'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sidebar_read_later_button')));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/read-later',
    );

    await tester.tap(find.byKey(const Key('sidebar_all_button')));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/all');

    await tester.tap(find.byKey(const Key('sidebar_add_subscription_button')));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/add-subscription',
    );
    expect(
      fixedTile(const Key('sidebar_add_subscription_button')).selected,
      isTrue,
    );
    expect(fixedTile(const Key('sidebar_all_button')).selected, isFalse);

    await tester.tap(find.byKey(const Key('sidebar_account_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar_account_menu_account')));
    await tester.pumpAndSettle();

    expect(find.text('settings page'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sidebar_account_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar_account_menu_settings')));
    await tester.pumpAndSettle();
    expect(find.text('settings page'), findsOneWidget);
  });

  testWidgets('App shell drawer account menu closes before opening services', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/all',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              AppShell(currentUri: state.uri, child: child),
          routes: [
            GoRoute(
              path: '/all',
              builder: (context, state) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Services settings')),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(buildTestAccount()),
          feedsProvider.overrideWith((ref) => Stream.value(<Feed>[])),
          categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
          tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
          allUnreadCountsProvider.overrideWith(
            (ref) => Stream.value(<int?, int>{}),
          ),
          outboxPendingCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final shellChildContext = tester.element(
      find.byKey(const Key('app_shell_content_layer')),
    );
    AppDrawerScope.drawerOpenerOf(shellChildContext)!();
    await tester.pumpAndSettle();

    expect(find.text('Test Account'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sidebar_account_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar_account_menu_account')));
    await tester.pumpAndSettle();

    expect(find.text('Services settings'), findsOneWidget);
    expect(find.text('Test Account'), findsNothing);
  });

  testWidgets('sidebar collapsed mode keeps fixed item order icon-only', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    final category = Category()
      ..id = 7
      ..name = 'Design';
    final feed = _buildFeed(title: 'Dense Pixels')..categoryId = 7;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(buildTestAccount()),
          sidebarPresentationModeProvider.overrideWith(
            (ref) => SidebarPresentationMode.collapsed,
          ),
          feedsProvider.overrideWith((ref) => Stream.value(<Feed>[feed])),
          categoriesProvider.overrideWith(
            (ref) => Stream.value(<Category>[category]),
          ),
          tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
          allUnreadCountsProvider.overrideWith(
            (ref) => Stream.value(<int?, int>{null: 0, 7: 2, 10: 1}),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppMenuHost(
            child: SizedBox(
              width: kSidebarCollapsedWidth,
              child: Sidebar(
                onSelectScope: _noopSelectScope,
                railSurfaceStyle: SidebarRailSurfaceStyle.plain,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('All Articles'), findsNothing);
    expect(find.text('Starred'), findsNothing);
    expect(find.text('Read Later'), findsNothing);
    expect(find.byType(SidebarNavigationTree), findsNothing);
    expect(find.text('Subscriptions'), findsNothing);
    expect(find.text('Design'), findsNothing);
    expect(find.text('Dense Pixels'), findsNothing);
    expect(
      find.byKey(const Key('sidebar_collapsed_rail_surface')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('sidebar_collapsed_rail_divider')),
      findsOneWidget,
    );

    final allY = tester
        .getCenter(find.byKey(const Key('sidebar_all_button')))
        .dy;
    final starredY = tester
        .getCenter(find.byKey(const Key('sidebar_starred_button')))
        .dy;
    final readLaterY = tester
        .getCenter(find.byKey(const Key('sidebar_read_later_button')))
        .dy;
    final accountY = tester
        .getCenter(find.byKey(const Key('sidebar_account_button')))
        .dy;

    expect(allY, lessThan(starredY));
    expect(starredY, lessThan(readLaterY));
    expect(readLaterY, lessThan(accountY));
  });

  testWidgets('Fever sidebar hides add subscription fixed item', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(
            buildTestAccount(type: AccountType.fever),
          ),
          sidebarPresentationModeProvider.overrideWith(
            (ref) => SidebarPresentationMode.expanded,
          ),
          feedsProvider.overrideWith((ref) => Stream.value(<Feed>[])),
          categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
          tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
          allUnreadCountsProvider.overrideWith(
            (ref) => Stream.value(<int?, int>{null: 0}),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppMenuHost(
            child: SizedBox(
              width: kSidebarExpandedWidth,
              child: Sidebar(onSelectScope: _noopSelectScope),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('sidebar_add_subscription_button')),
      findsNothing,
    );
    expect(find.text('Add subscription'), findsNothing);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(
            buildTestAccount(type: AccountType.fever),
          ),
          sidebarPresentationModeProvider.overrideWith(
            (ref) => SidebarPresentationMode.collapsed,
          ),
          feedsProvider.overrideWith((ref) => Stream.value(<Feed>[])),
          categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
          tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
          allUnreadCountsProvider.overrideWith(
            (ref) => Stream.value(<int?, int>{null: 0}),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppMenuHost(
            child: SizedBox(
              width: kSidebarCollapsedWidth,
              child: Sidebar(onSelectScope: _noopSelectScope),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('sidebar_add_subscription_button')),
      findsNothing,
    );
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
      final feed = _buildFeed(id: 10);
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
            path: '/all/article/:id',
            builder: (context, state) => Text(state.pathParameters['id'] ?? ''),
          ),
          GoRoute(
            path: '/feed/:feedId/article/:id',
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
            currentArticleScopeProvider.overrideWith(
              (ref) => const ArticleScope.feed(10),
            ),
            articleListControllerProvider.overrideWith(
              _FixedArticleListController.new,
            ),
            articleActionServiceProvider.overrideWithValue(actionService),
            feedRepositoryProvider.overrideWithValue(
              _FakeFeedRepository([feed]),
            ),
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

      final refreshOutcome = await homeCommands.refreshAll();
      expect(syncService.refreshCalls, [
        [10],
      ]);
      expect(
        refreshOutcome.successFeedback,
        HomeRefreshSuccessFeedback.refreshed,
      );

      await homeCommands.markAllRead();
      expect(actionService.markAllReadCalls, [
        (
          feedId: 10,
          categoryId: null,
          starredOnly: false,
          readLaterOnly: false,
          tagId: null,
        ),
      ]);

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

  testWidgets('Home scene commands mark all read within the current scope', (
    tester,
  ) async {
    final cases =
        <
          ({
            ArticleScope scope,
            ({
              int? feedId,
              int? categoryId,
              bool starredOnly,
              bool readLaterOnly,
              int? tagId,
            })
            expected,
          })
        >[
          (
            scope: ArticleScope.starred,
            expected: (
              feedId: null,
              categoryId: null,
              starredOnly: true,
              readLaterOnly: false,
              tagId: null,
            ),
          ),
          (
            scope: ArticleScope.readLater,
            expected: (
              feedId: null,
              categoryId: null,
              starredOnly: false,
              readLaterOnly: true,
              tagId: null,
            ),
          ),
          (
            scope: const ArticleScope.tag(9),
            expected: (
              feedId: null,
              categoryId: null,
              starredOnly: false,
              readLaterOnly: false,
              tagId: 9,
            ),
          ),
        ];

    for (final c in cases) {
      final actionService = RecordingArticleActionService();
      final homeCommands = await _pumpHomeCommandsHarness(
        tester,
        overrides: [
          currentArticleScopeProvider.overrideWith((ref) => c.scope),
          articleActionServiceProvider.overrideWithValue(actionService),
        ],
      );

      await homeCommands.markAllRead();

      expect(actionService.markAllReadCalls, [c.expected]);
    }
  });

  testWidgets('Home scene commands refresh the selected local category only', (
    tester,
  ) async {
    final syncService = FakeSyncService();
    final feeds = [
      _buildFeed(id: 1)..categoryId = 7,
      _buildFeed(id: 2, url: 'https://example.com/2.xml')..categoryId = 7,
      _buildFeed(id: 3, url: 'https://example.com/3.xml')..categoryId = 9,
    ];

    final homeCommands = await _pumpHomeCommandsHarness(
      tester,
      overrides: [
        activeAccountProvider.overrideWithValue(
          buildTestAccount(type: AccountType.local, name: 'Local'),
        ),
        selectedCategoryIdProvider.overrideWith((ref) => 7),
        feedRepositoryProvider.overrideWithValue(_FakeFeedRepository(feeds)),
        syncServiceProvider.overrideWithValue(syncService),
      ],
    );

    final outcome = await homeCommands.refreshAll();

    expect(syncService.refreshCalls, [
      [1, 2],
    ]);
    expect(outcome.successFeedback, HomeRefreshSuccessFeedback.refreshed);
  });

  testWidgets('Home scene commands fail fast when selected feed is missing', (
    tester,
  ) async {
    final syncService = FakeSyncService();
    final minifluxSourceRefresh = _FakeMinifluxSourceRefresh();

    final homeCommands = await _pumpHomeCommandsHarness(
      tester,
      overrides: [
        activeAccountProvider.overrideWithValue(
          buildTestAccount(type: AccountType.miniflux, name: 'Miniflux'),
        ),
        selectedFeedIdProvider.overrideWith((ref) => 404),
        feedRepositoryProvider.overrideWithValue(_FakeFeedRepository([])),
        minifluxSourceRefreshProvider.overrideWithValue(minifluxSourceRefresh),
        syncServiceProvider.overrideWithValue(syncService),
      ],
    );

    final outcome = await homeCommands.refreshAll();

    expect(outcome.batch.firstError?.feedId, 404);
    expect(outcome.batch.firstError?.error, isA<StateError>());
    expect(minifluxSourceRefresh.refreshedFeedIds, isEmpty);
    expect(syncService.refreshCalls, isEmpty);
  });

  testWidgets(
    'Home scene commands refresh selected Miniflux feed source before sync',
    (tester) async {
      final syncService = FakeSyncService();
      final minifluxSourceRefresh = _FakeMinifluxSourceRefresh();
      final feed = _buildFeed(id: 10)..remoteId = '42';

      final homeCommands = await _pumpHomeCommandsHarness(
        tester,
        overrides: [
          activeAccountProvider.overrideWithValue(
            buildTestAccount(type: AccountType.miniflux, name: 'Miniflux'),
          ),
          selectedFeedIdProvider.overrideWith((ref) => 10),
          feedRepositoryProvider.overrideWithValue(_FakeFeedRepository([feed])),
          minifluxSourceRefreshProvider.overrideWithValue(
            minifluxSourceRefresh,
          ),
          syncServiceProvider.overrideWithValue(syncService),
        ],
      );

      final outcome = await homeCommands.refreshAll();

      expect(minifluxSourceRefresh.refreshedFeedIds, [10]);
      expect(minifluxSourceRefresh.refreshAllCalls, 0);
      expect(syncService.refreshCalls, [
        [10],
      ]);
      expect(outcome.successFeedback, HomeRefreshSuccessFeedback.refreshed);
    },
  );

  testWidgets(
    'Home scene commands refresh selected Miniflux category sources before sync',
    (tester) async {
      final syncService = FakeSyncService();
      final minifluxSourceRefresh = _FakeMinifluxSourceRefresh();
      final feeds = [
        _buildFeed(id: 1)..categoryId = 7,
        _buildFeed(id: 2, url: 'https://example.com/2.xml')..categoryId = 7,
        _buildFeed(id: 3, url: 'https://example.com/3.xml')..categoryId = 9,
      ];

      final homeCommands = await _pumpHomeCommandsHarness(
        tester,
        overrides: [
          activeAccountProvider.overrideWithValue(
            buildTestAccount(type: AccountType.miniflux, name: 'Miniflux'),
          ),
          selectedCategoryIdProvider.overrideWith((ref) => 7),
          feedRepositoryProvider.overrideWithValue(_FakeFeedRepository(feeds)),
          minifluxSourceRefreshProvider.overrideWithValue(
            minifluxSourceRefresh,
          ),
          syncServiceProvider.overrideWithValue(syncService),
        ],
      );

      final outcome = await homeCommands.refreshAll();

      expect(minifluxSourceRefresh.refreshedFeedIds, [1, 2]);
      expect(minifluxSourceRefresh.refreshAllCalls, 0);
      expect(syncService.refreshCalls, [
        [1, 2],
      ]);
      expect(outcome.successFeedback, HomeRefreshSuccessFeedback.refreshed);
    },
  );

  testWidgets(
    'Home scene commands treat empty Miniflux category as refreshed',
    (tester) async {
      final syncService = FakeSyncService();
      final minifluxSourceRefresh = _FakeMinifluxSourceRefresh();

      final homeCommands = await _pumpHomeCommandsHarness(
        tester,
        overrides: [
          activeAccountProvider.overrideWithValue(
            buildTestAccount(type: AccountType.miniflux, name: 'Miniflux'),
          ),
          selectedCategoryIdProvider.overrideWith((ref) => 7),
          feedRepositoryProvider.overrideWithValue(_FakeFeedRepository([])),
          minifluxSourceRefreshProvider.overrideWithValue(
            minifluxSourceRefresh,
          ),
          syncServiceProvider.overrideWithValue(syncService),
        ],
      );

      final outcome = await homeCommands.refreshAll();

      expect(outcome.batch.results, isEmpty);
      expect(outcome.successFeedback, HomeRefreshSuccessFeedback.refreshed);
      expect(minifluxSourceRefresh.refreshedFeedIds, isEmpty);
      expect(syncService.refreshCalls, isEmpty);
    },
  );

  testWidgets(
    'Home scene commands keep Miniflux all-subscriptions refresh global',
    (tester) async {
      final syncService = FakeSyncService();
      final minifluxSourceRefresh = _FakeMinifluxSourceRefresh();
      final feed = _buildFeed(id: 10);

      final homeCommands = await _pumpHomeCommandsHarness(
        tester,
        overrides: [
          activeAccountProvider.overrideWithValue(
            buildTestAccount(type: AccountType.miniflux, name: 'Miniflux'),
          ),
          feedRepositoryProvider.overrideWithValue(_FakeFeedRepository([feed])),
          minifluxSourceRefreshProvider.overrideWithValue(
            minifluxSourceRefresh,
          ),
          syncServiceProvider.overrideWithValue(syncService),
        ],
      );

      final outcome = await homeCommands.refreshAll();

      expect(minifluxSourceRefresh.refreshAllCalls, 1);
      expect(minifluxSourceRefresh.refreshedFeedIds, isEmpty);
      expect(syncService.refreshCalls, [
        [10],
      ]);
      expect(
        outcome.successFeedback,
        HomeRefreshSuccessFeedback.refreshedAndSynced,
      );
    },
  );

  testWidgets('Home scene commands sync unsupported-source remote accounts', (
    tester,
  ) async {
    final syncService = FakeSyncService();
    final feed = Feed()
      ..id = 1
      ..url = 'https://example.com/feed.xml'
      ..title = 'Feed';
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
          feedRepositoryProvider.overrideWithValue(_FakeFeedRepository([feed])),
          syncServiceProvider.overrideWithValue(syncService),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final outcome = await homeCommands.refreshAll();

    expect(syncService.refreshCalls, [
      [1],
    ]);
    expect(outcome.successFeedback, HomeRefreshSuccessFeedback.syncedAccount);
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

    var pumpIndex = 0;

    Future<void> pumpHome(
      AccountType type, {
      List<Override> extraOverrides = const <Override>[],
    }) async {
      pumpIndex++;
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey('home_${type.name}_$pumpIndex'),
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
            ...extraOverrides,
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

    await pumpHome(
      AccountType.local,
      extraOverrides: [
        selectedFeedIdProvider.overrideWith((ref) => 10),
        feedRepositoryProvider.overrideWithValue(
          _FakeFeedRepository([_buildFeed(id: 10)]),
        ),
      ],
    );
    expect(find.byTooltip('Refresh feed'), findsOneWidget);
    expect(find.byTooltip('Sync account'), findsNothing);

    await tester.tap(find.byTooltip('Refresh feed'));
    await tester.pump();
    expect(find.text('Refreshed'), findsOneWidget);
    expect(find.text('Refreshed all'), findsNothing);

    await pumpHome(
      AccountType.local,
      extraOverrides: [selectedCategoryIdProvider.overrideWith((ref) => 7)],
    );
    expect(find.byTooltip('Refresh category'), findsOneWidget);
    expect(find.byTooltip('Refresh sources'), findsNothing);

    await pumpHome(AccountType.local);
    expect(find.byTooltip('Refresh sources'), findsOneWidget);
    expect(find.byTooltip('Sync account'), findsNothing);

    await pumpHome(
      AccountType.miniflux,
      extraOverrides: [selectedFeedIdProvider.overrideWith((ref) => 10)],
    );
    expect(find.byTooltip('Refresh feed and sync'), findsOneWidget);
    expect(find.byTooltip('Refresh sources'), findsNothing);

    await pumpHome(
      AccountType.miniflux,
      extraOverrides: [selectedCategoryIdProvider.overrideWith((ref) => 7)],
    );
    expect(find.byTooltip('Refresh category and sync'), findsOneWidget);
    expect(find.byTooltip('Refresh sources'), findsNothing);

    await pumpHome(AccountType.miniflux);
    expect(find.byTooltip('Refresh sources and sync'), findsOneWidget);
    expect(find.byTooltip('Refresh sources'), findsNothing);

    await pumpHome(AccountType.fever);
    expect(find.byTooltip('Sync account'), findsOneWidget);
    expect(find.byTooltip('Refresh sources'), findsNothing);
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

  testWidgets('Home hides list sync status capsule in compact list layouts', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(buildTestAccount()),
          articleListControllerProvider.overrideWith(
            _EmptyArticleListController.new,
          ),
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(AppSettings.defaults()),
          ),
          outboxPendingCountProvider.overrideWith((ref) async => 0),
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
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    container
        .read(syncStatusReporterProvider)
        .startTask(label: SyncStatusLabel.syncingFeeds, current: 1, total: 3);
    await tester.pump();

    expect(find.byKey(const Key('sync_status_capsule')), findsNothing);
  });

  testWidgets('Home shows list sync status capsule on roomy list layouts', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(buildTestAccount()),
          articleListControllerProvider.overrideWith(
            _EmptyArticleListController.new,
          ),
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(AppSettings.defaults()),
          ),
          outboxPendingCountProvider.overrideWith((ref) async => 0),
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
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    container
        .read(syncStatusReporterProvider)
        .startTask(label: SyncStatusLabel.syncingFeeds, current: 1, total: 3);
    await tester.pump();

    expect(find.byKey(const Key('sync_status_capsule')), findsOneWidget);
    expect(find.text('Syncing feeds（1/3）'), findsOneWidget);
  });

  testWidgets('Sidebar account footer can suppress duplicate sync status', (
    tester,
  ) async {
    Future<void> pumpSidebar({required bool showAccountSyncStatus}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeAccountProvider.overrideWithValue(buildTestAccount()),
            feedsProvider.overrideWith((ref) => Stream.value(<Feed>[])),
            categoriesProvider.overrideWith(
              (ref) => Stream.value(<Category>[]),
            ),
            tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
            allUnreadCountsProvider.overrideWith(
              (ref) => Stream.value(<int?, int>{}),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: SizedBox(
                  width: kDefaultWorkspaceSidebarWidth,
                  child: Sidebar(
                    onSelectScope: (_) {},
                    presentationModeOverride: SidebarPresentationMode.expanded,
                    showAccountSyncStatus: showAccountSyncStatus,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Sidebar)),
      );
      container
          .read(syncStatusReporterProvider)
          .startTask(label: SyncStatusLabel.syncingFeeds, current: 1, total: 3);
      await tester.pump();
    }

    await pumpSidebar(showAccountSyncStatus: true);
    expect(find.text('Syncing feeds（1/3）'), findsOneWidget);

    await pumpSidebar(showAccountSyncStatus: false);
    expect(find.text('Syncing feeds（1/3）'), findsNothing);
  });

  testWidgets(
    'Sync status capsule adapts between centered edge, centered floating, and left floating',
    (tester) async {
      Future<Rect> pumpCapsule(
        double hostWidth, {
        SyncStatusLabel label = SyncStatusLabel.syncing,
        String? detail,
        int? current,
        int? total,
      }) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: hostWidth,
                    height: 240,
                    child: const SyncStatusCapsuleHost(
                      child: SizedBox.expand(),
                    ),
                  ),
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
            .startTask(
              label: label,
              detail: detail,
              current: current,
              total: total,
            );
        await tester.pump();

        final capsule = find.byKey(const Key('sync_status_capsule'));
        return tester.getRect(capsule);
      }

      const horizontalPadding = 20.0;
      const narrowWidth = 380.0;
      const middleWidth = 480.0;
      const wideWidth = 760.0;

      final narrowEdge = await pumpCapsule(
        narrowWidth,
        label: SyncStatusLabel.syncingSubscriptions,
        detail:
            'Miniflux2 subscription metadata sync with a very long detail label',
        current: 405,
        total: 555,
      );
      expect(narrowEdge.center.dx, moreOrLessEquals(narrowWidth / 2));
      expect(narrowEdge.width, narrowWidth - horizontalPadding * 2);

      final middleShort = await pumpCapsule(middleWidth);
      expect(middleShort.center.dx, moreOrLessEquals(middleWidth / 2));
      expect(middleShort.width, lessThan(kSyncStatusCapsuleMaxWidth));

      final middleLong = await pumpCapsule(
        middleWidth,
        label: SyncStatusLabel.syncingSubscriptions,
        detail:
            'Miniflux2 subscription metadata sync with a very long detail label',
        current: 405,
        total: 555,
      );
      expect(middleLong.center.dx, moreOrLessEquals(middleWidth / 2));
      expect(middleLong.width, kSyncStatusCapsuleMaxWidth);

      final wideShort = await pumpCapsule(wideWidth);
      expect(wideShort.left, horizontalPadding);
      expect(wideShort.width, lessThan(kSyncStatusCapsuleMaxWidth));

      final wideContent = await pumpCapsule(
        wideWidth,
        label: SyncStatusLabel.syncingSubscriptions,
        detail: 'Miniflux2 sync',
        current: 405,
        total: 555,
      );
      expect(wideContent.left, horizontalPadding);
      expect(wideContent.width, greaterThan(kSyncStatusCapsuleMaxWidth));
      expect(wideContent.width, lessThan(wideWidth - horizontalPadding * 2));

      final wideLong = await pumpCapsule(
        wideWidth,
        label: SyncStatusLabel.syncingSubscriptions,
        detail:
            'Miniflux2 subscription metadata sync with a very long detail label',
        current: 405,
        total: 555,
      );
      expect(wideLong.left, horizontalPadding);
      expect(wideLong.width, wideWidth - horizontalPadding * 2);
    },
  );

  testWidgets(
    'Sidebar selection actions share feed, category, tag, and clear-selection flows',
    (tester) async {
      late SidebarSelectionActions actions;
      int closeCount = 0;
      ArticleScope? selectedScopeCallback;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            articleListFilterProvider.overrideWith(
              (ref) => const ArticleListFilter(
                scope: ArticleScope.readLater,
                searchQuery: 'needle',
              ),
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                actions = SidebarSelectionActions(
                  ref: ref,
                  onSelectScope: (scope) => selectedScopeCallback = scope,
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
      expect(selectedScopeCallback, const ArticleScope.feed(12));
      expect(closeCount, 1);

      actions.selectFeed(12);
      expect(container.read(selectedFeedIdProvider), isNull);
      expect(container.read(selectedCategoryIdProvider), isNull);
      expect(container.read(selectedTagIdProvider), isNull);
      expect(selectedScopeCallback, ArticleScope.all);
      expect(closeCount, 2);

      container
          .read(articleListFilterProvider.notifier)
          .update(
            (filter) => filter.copyWith(
              scope: ArticleScope.readLater,
              searchQuery: 'category',
            ),
          );
      actions.selectCategory(34);
      expect(container.read(selectedFeedIdProvider), isNull);
      expect(container.read(selectedCategoryIdProvider), 34);
      expect(container.read(selectedTagIdProvider), isNull);
      expect(container.read(starredOnlyProvider), isFalse);
      expect(container.read(readLaterOnlyProvider), isFalse);
      expect(container.read(articleSearchQueryProvider), '');
      expect(selectedScopeCallback, const ArticleScope.category(34));
      expect(closeCount, 3);

      container
          .read(articleListFilterProvider.notifier)
          .update(
            (filter) => filter.copyWith(
              scope: ArticleScope.starred,
              searchQuery: 'tag',
            ),
          );
      actions.selectTag(56);
      expect(container.read(selectedFeedIdProvider), isNull);
      expect(container.read(selectedCategoryIdProvider), isNull);
      expect(container.read(selectedTagIdProvider), 56);
      expect(container.read(starredOnlyProvider), isFalse);
      expect(container.read(readLaterOnlyProvider), isFalse);
      expect(container.read(articleSearchQueryProvider), '');
      expect(selectedScopeCallback, const ArticleScope.tag(56));
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
                child: AppMenuHost(
                  child: Sidebar(onSelectScope: _noopSelectScope),
                ),
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
            feedRepositoryProvider.overrideWithValue(
              _FakeFeedRepository([feed]),
            ),
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
                child: AppMenuHost(
                  child: Sidebar(onSelectScope: _noopSelectScope),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(find.text('Fleur Feed')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(FleurIcons.moreVertical));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh').last);
      await tester.pumpAndSettle();
      await mouse.removePointer();

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
            feedRepositoryProvider.overrideWithValue(
              _FakeFeedRepository([feed]),
            ),
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
                child: AppMenuHost(
                  child: Sidebar(onSelectScope: _noopSelectScope),
                ),
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
                child: AppMenuHost(
                  child: Sidebar(onSelectScope: _noopSelectScope),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final newCategoryButton = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'New category',
      );
      final addSubscriptionButton = find.byKey(
        const Key('sidebar_add_subscription_button'),
      );

      expect(addSubscriptionButton, findsOneWidget);
      expect(find.text('Add subscription'), findsOneWidget);
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

      expect(find.text('Fleur Feed'), findsOneWidget);
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
      final article = _buildArticle(isRead: false, isStarred: true)
        ..contentHtml =
            '<p>Hello world</p><img src="https://example.com/thumb.jpg">';

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
              body: SizedBox(
                width: 700,
                child: ArticleListItem(article: article, selected: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final theme = AppTheme.light();
      final cardDecoration =
          tester
                  .widget<Container>(find.byKey(const Key('article_item_card')))
                  .decoration
              as BoxDecoration;
      final title = tester.widget<Text>(find.text('Selected Article'));
      final feedLabel = tester.widget<Text>(
        find.byKey(const Key('article_item_feed_label')),
      );
      final timestamp = tester.widget<Text>(
        find.byKey(const Key('article_item_timestamp')),
      );

      expect(cardDecoration.color, theme.fleurSurface.cardSelected);
      expect(
        cardDecoration.borderRadius,
        const BorderRadius.all(Radius.circular(8)),
      );
      expect(cardDecoration.boxShadow, isNull);
      expect(title.style?.fontWeight, FontWeight.w600);
      expect(title.style?.letterSpacing, 0);
      expect(title.style?.height, 1.2);
      expect(feedLabel.style?.fontSize, 11);
      expect(feedLabel.style?.fontWeight, FontWeight.w500);
      expect(feedLabel.style?.letterSpacing, 0);
      expect(timestamp.style?.fontSize, 10);
      expect(timestamp.style?.fontWeight, FontWeight.w500);
      expect(timestamp.style?.letterSpacing, 0);
      expect(timestamp.style?.height, 1.1);
      expect(find.text('Hello world'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('article_item_preview_text')))
            .maxLines,
        4,
      );
      expect(
        tester.getSize(find.byKey(const Key('article_item_thumbnail'))),
        const Size(156, 108),
      );
      expect(
        tester.getSize(find.byKey(const Key('article_item_feed_icon'))),
        const Size(32, 32),
      );
      expect(find.byKey(const Key('article_item_hover_actions')), findsNothing);
    },
  );

  testWidgets('Article list item shows hover actions and calls services', (
    tester,
  ) async {
    final feed = _buildFeed();
    final article = _buildArticle(id: 42, isRead: false, isStarred: false);
    final actions = RecordingArticleActionService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedsProvider.overrideWith((ref) => Stream.value([feed])),
          articleActionServiceProvider.overrideWithValue(actions),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 700,
              child: ArticleListItem(article: article, selected: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('article_item_timestamp')), findsOneWidget);
    expect(find.byKey(const Key('article_item_hover_actions')), findsNothing);
    final initialCardHeight = tester
        .getSize(find.byKey(const Key('article_item_card')))
        .height;

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer();
    await gesture.moveTo(
      tester.getCenter(find.byKey(const Key('article_item_card'))),
    );
    await tester.pump();

    expect(find.byKey(const Key('article_item_timestamp')), findsNothing);
    expect(find.byKey(const Key('article_item_hover_actions')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('article_item_card'))).height,
      initialCardHeight,
    );
    final hoverDecoration =
        tester
                .widget<Container>(find.byKey(const Key('article_item_card')))
                .decoration
            as BoxDecoration;
    expect(hoverDecoration.color, Colors.transparent);
    expect(hoverDecoration.boxShadow, isNull);

    await tester.tap(find.byKey(const Key('article_item_read_later_button')));
    await tester.tap(find.byKey(const Key('article_item_star_button')));
    await tester.tap(find.byKey(const Key('article_item_read_button')));
    await tester.pump();

    expect(actions.toggleReadLaterCalls, [42]);
    expect(actions.toggleStarCalls, [42]);
    expect(actions.markReadCalls, [(articleId: 42, isRead: true)]);
  });

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

  testWidgets('Article list item omits empty preview without overflow', (
    tester,
  ) async {
    final feed = _buildFeed();
    final article = _buildArticle(isRead: true, isStarred: false)
      ..contentHash = 'image-only-preview'
      ..contentHtml =
          '<img src="https://example.com/icon.png" width="32" height="32">';

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
            body: SizedBox(
              width: 260,
              child: ArticleListItem(article: article, selected: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('article_item_preview_text')), findsNothing);
    expect(find.byKey(const Key('article_item_thumbnail')), findsNothing);
    expect(tester.takeException(), isNull);
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
      expect(find.text(l10n.unreadEmptySubtitle), findsOneWidget);
      expect(container.color, theme.fleurSurface.list);
    },
  );

  testWidgets('Home workspace omits reader pane until article is selected', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final article = _buildArticle(id: 42);
    _FixedArticleListController.items = <Article>[article];
    addTearDown(() => _FixedArticleListController.items = <Article>[]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(buildTestAccount()),
          articleListControllerProvider.overrideWith(
            _FixedArticleListController.new,
          ),
          articleProvider(42).overrideWith((ref) => Stream.value(article)),
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(AppSettings.defaults()),
          ),
          feedsProvider.overrideWith(
            (ref) => Stream.value([_buildFeed(id: article.feedId)]),
          ),
          categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
          tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
          allUnreadCountsProvider.overrideWith(
            (ref) => Stream.value(<int?, int>{null: 0}),
          ),
          outboxPendingCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(selectedArticleId: null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(HomeScreen));
    final l10n = AppLocalizations.of(element)!;
    final container = ProviderScope.containerOf(element);

    expect(tester.getSize(find.byType(ArticleList)).width, 1200);
    expect(
      tester.getSize(find.byKey(const Key('article_item_card'))).width,
      lessThanOrEqualTo(kMaxReadingWidth),
    );
    expect(find.byKey(const Key('home_scope_header')), findsOneWidget);
    expect(find.byKey(const Key('home_scope_actions')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('home_scope_actions'))).height,
      kShellControlSize,
    );
    expect(
      tester.getCenter(find.byKey(const Key('home_scope_actions'))).dy,
      kMacOSTrafficLightTargetCenterY,
    );
    expect(find.byKey(const Key('scope_refresh_button')), findsOneWidget);
    expect(find.byKey(const Key('scope_unread_filter_button')), findsOneWidget);
    final scopeHeader = find.byKey(const Key('home_scope_header'));
    final headerFade = find.descendant(
      of: scopeHeader,
      matching: find.byKey(const ValueKey('article-list-top-fade')),
    );
    expect(headerFade, findsOneWidget);
    expect(tester.getSize(headerFade).height, kWorkspaceHeaderHeight);
    expect(
      find.descendant(of: headerFade, matching: find.byType(BackdropFilter)),
      findsOneWidget,
    );
    expect(find.byType(HomeReaderPane), findsNothing);
    expect(find.byType(ReadingPaneSurface), findsNothing);
    expect(find.byType(ReaderView), findsNothing);
    expect(find.text(l10n.selectAnArticle), findsNothing);
    expect(find.text(l10n.readerEmptySubtitle), findsNothing);
    expect(container.read(unreadOnlyProvider), isFalse);

    await tester.tap(find.byKey(const Key('scope_unread_filter_button')));
    await tester.pumpAndSettle();
    expect(container.read(unreadOnlyProvider), isTrue);
  });

  testWidgets('Home workspace keeps list width while showing reader surface', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final article = _buildArticle(id: 42);
    _FixedArticleListController.items = <Article>[article];
    addTearDown(() => _FixedArticleListController.items = <Article>[]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(buildTestAccount()),
          articleListControllerProvider.overrideWith(
            _FixedArticleListController.new,
          ),
          articleProvider(42).overrideWith((ref) => Stream.value(article)),
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(AppSettings.defaults()),
          ),
          readerSettingsStoreProvider.overrideWithValue(
            FakeReaderSettingsStore(const ReaderSettings()),
          ),
          readerProgressStoreProvider.overrideWithValue(
            InMemoryReaderProgressStore(),
          ),
          imageMetaStoreProvider.overrideWithValue(InMemoryImageMetaStore()),
          articleActionServiceProvider.overrideWithValue(
            RecordingArticleActionService(),
          ),
          feedsProvider.overrideWith(
            (ref) => Stream.value([_buildFeed(id: article.feedId)]),
          ),
          categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
          tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
          allUnreadCountsProvider.overrideWith(
            (ref) => Stream.value(<int?, int>{null: 0}),
          ),
          outboxPendingCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(selectedArticleId: 42),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 240));

    final surface = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(const Key('reading_pane_surface')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = surface.decoration as BoxDecoration;
    final radius = decoration.borderRadius! as BorderRadius;
    final shadows = decoration.boxShadow!;

    expect(tester.getSize(find.byType(ArticleList)).width, kDesktopListWidth);
    expect(
      find.byKey(const Key('workspace_list_split_handle')),
      findsOneWidget,
    );
    final initialArticleListWidth = tester
        .getSize(find.byType(ArticleList))
        .width;
    final listSplitCenter = tester.getCenter(
      find.byKey(const Key('workspace_list_split_handle')),
    );
    await tester.dragFrom(
      Offset(listSplitCenter.dx, kWorkspaceHeaderHeight / 2),
      const Offset(400, 0),
    );
    await tester.pump();
    expect(
      tester.getSize(find.byType(ArticleList)).width,
      initialArticleListWidth,
    );

    await tester.drag(
      find.byKey(const Key('workspace_list_split_handle')),
      const Offset(400, 0),
    );
    await tester.pump();
    final maxListWidthForHarness =
        1200 - kWorkspaceSplitHandleHitWidth - kMinReadingWidth;
    final expectedReaderWidthForHarness = 1200 - maxListWidthForHarness;
    expect(
      tester.getSize(find.byType(ArticleList)).width,
      maxListWidthForHarness,
    );
    expect(
      tester.getSize(find.byType(HomeReaderPane)).width,
      expectedReaderWidthForHarness,
    );
    expect(
      tester.getSize(find.byType(HomeReaderPane)).width,
      greaterThanOrEqualTo(kMinReadingWidth),
    );
    expect(find.byType(HomeReaderPane), findsOneWidget);
    expect(find.byType(ReaderView), findsOneWidget);
    expect(tester.getSize(find.byType(ReadingPaneSurface)).height, 800);
    expect(radius.topLeft.x, greaterThan(0));
    expect(radius.bottomLeft.x, greaterThan(0));
    expect(radius.topRight.x, 0);
    expect(shadows, isNotEmpty);
    expect(shadows.first.blurRadius, greaterThan(0));
    expect(
      find.descendant(
        of: find.byKey(const Key('reading_pane_surface')),
        matching: find.byKey(const Key('workspace_layer_leading_edge')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Home workspace preserves article list scroll state on open', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final selectedArticle = _buildArticle(id: 1);
    final articles = List<Article>.generate(
      30,
      (index) => _buildArticle(id: index + 1, title: 'Article ${index + 1}'),
    );
    _FixedArticleListController.items = articles;
    addTearDown(() => _FixedArticleListController.items = <Article>[]);

    final selected = ValueNotifier<int?>(null);
    addTearDown(selected.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(buildTestAccount()),
          articleListControllerProvider.overrideWith(
            _FixedArticleListController.new,
          ),
          for (final article in articles)
            articleProvider(
              article.id,
            ).overrideWith((ref) => Stream.value(article)),
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(AppSettings.defaults()),
          ),
          readerSettingsStoreProvider.overrideWithValue(
            FakeReaderSettingsStore(const ReaderSettings()),
          ),
          readerProgressStoreProvider.overrideWithValue(
            InMemoryReaderProgressStore(),
          ),
          imageMetaStoreProvider.overrideWithValue(InMemoryImageMetaStore()),
          articleActionServiceProvider.overrideWithValue(
            RecordingArticleActionService(),
          ),
          feedsProvider.overrideWith(
            (ref) => Stream.value([_buildFeed(id: selectedArticle.feedId)]),
          ),
          categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
          tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
          allUnreadCountsProvider.overrideWith(
            (ref) => Stream.value(<int?, int>{null: 0}),
          ),
          outboxPendingCountProvider.overrideWith((ref) async => 0),
        ],
        child: ValueListenableBuilder<int?>(
          valueListenable: selected,
          builder: (context, selectedArticleId, _) {
            return MaterialApp(
              theme: AppTheme.light(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: HomeScreen(selectedArticleId: selectedArticleId),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((state) => state.position.axis == Axis.vertical);
    before.position.jumpTo(180);
    await tester.pump();
    final pixelsBefore = before.position.pixels;

    selected.value = selectedArticle.id;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    final after = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((state) => state.position.axis == Axis.vertical);
    expect(identical(before, after), isTrue);
    expect(after.position.pixels, pixelsBefore);
    expect(find.byType(ReaderView), findsOneWidget);
  });

  testWidgets('Add subscription screen starts as a task page', (tester) async {
    final router = GoRouter(
      initialLocation: '/add-subscription',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        GoRoute(
          path: '/add-subscription',
          builder: (context, state) => const AddSubscriptionScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    final now = DateTime.fromMillisecondsSinceEpoch(0);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(
            Account(
              id: 'local-test',
              type: AccountType.local,
              name: 'Local',
              isPrimary: true,
              createdAt: now,
              updatedAt: now,
            ),
          ),
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(AppSettings.defaults()),
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

    expect(find.byKey(const Key('add_subscription_url_field')), findsOneWidget);
    expect(
      find.byKey(const Key('add_subscription_discover_button')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Search screen starts as a task page and shows results after input',
    (tester) async {
      const searchSectionKey = ValueKey<String>('search-section-test');
      final router = GoRouter(
        initialLocation: '/search',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const SizedBox()),
          GoRoute(
            path: '/search',
            pageBuilder: (context, state) => NoTransitionPage(
              key: searchSectionKey,
              child: SearchScreen(
                selectedArticleId: null,
                routeState: searchStateFromUri(state.uri),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsStoreProvider.overrideWithValue(
              FakeAppSettingsStore(AppSettings.defaults()),
            ),
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

      final element = tester.element(find.byType(SearchScreen));
      final l10n = AppLocalizations.of(element)!;

      expect(find.byKey(const Key('search_task_field_large')), findsOneWidget);
      expect(find.byType(ArticleList), findsNothing);
      expect(find.byType(ReaderView), findsNothing);
      expect(find.text(l10n.searchStartTitle), findsNothing);
      expect(find.text(l10n.searchReaderEmptyTitle), findsNothing);
      expect(find.text(l10n.searchReaderEmptySubtitle), findsNothing);

      final stageRect = tester.getRect(
        find.byKey(const Key('search_task_empty_stage')),
      );
      final largeFieldRect = tester.getRect(
        find.byKey(const Key('search_task_field_large')),
      );
      final searchBar = tester.widget<SearchBar>(
        find.byKey(const Key('search_task_field')),
      );
      final defaultStates = <WidgetState>{};
      final fieldSide = searchBar.side!.resolve(defaultStates)!;

      expect(
        (largeFieldRect.center.dx - stageRect.center.dx).abs(),
        lessThan(1),
      );
      expect(
        (largeFieldRect.center.dy - stageRect.center.dy).abs(),
        lessThan(1),
      );
      expect(largeFieldRect.height, 46);
      expect(searchBar.shape!.resolve(defaultStates), isA<StadiumBorder>());
      expect(searchBar.elevation!.resolve(defaultStates), 0);
      expect(fieldSide.width, 1);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('search_task_field')),
          matching: find.byType(EditableText),
        ),
        'claude',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/search?q=claude',
      );
      expect(find.byKey(const Key('search_task_field_top')), findsOneWidget);
      expect(find.byKey(const Key('search_advanced_filters')), findsOneWidget);
      expect(find.byType(ArticleList), findsOneWidget);
      expect(find.byType(ReaderView), findsNothing);
      expect(find.text(l10n.notFound), findsOneWidget);
      expect(find.text(l10n.searchNoResultsSubtitle('claude')), findsOneWidget);
      expect(find.text(l10n.clearSearch), findsOneWidget);

      await tester.tap(find.text(l10n.clearSearch));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/search',
      );
      expect(find.byKey(const Key('search_task_field_large')), findsOneWidget);
      expect(find.byType(ArticleList), findsNothing);
      expect(find.text(l10n.searchStartTitle), findsNothing);
    },
  );

  testWidgets('Search task field centers within shell content', (tester) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(2048, 1008);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              AppShell(currentUri: state.uri, child: child),
          routes: [
            GoRoute(
              path: '/search',
              pageBuilder: (context, state) => NoTransitionPage(
                child: SearchScreen(
                  selectedArticleId: null,
                  routeState: searchStateFromUri(state.uri),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(buildTestAccount()),
          sidebarPresentationModeProvider.overrideWith(
            (ref) => SidebarPresentationMode.collapsed,
          ),
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(AppSettings.defaults()),
          ),
          articleListControllerProvider.overrideWith(
            _EmptyArticleListController.new,
          ),
          feedsProvider.overrideWith((ref) => Stream.value(<Feed>[])),
          categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
          tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
          allUnreadCountsProvider.overrideWith(
            (ref) => Stream.value(<int?, int>{null: 0}),
          ),
          outboxPendingCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final screenRect = tester.getRect(find.byType(SearchScreen));
    final fieldRect = tester.getRect(
      find.byKey(const Key('search_task_field_large')),
    );

    expect((fieldRect.center.dx - screenRect.center.dx).abs(), lessThan(1));
    expect((fieldRect.center.dy - screenRect.center.dy).abs(), lessThan(1));
    expect(fieldRect.width, 720);
    expect(fieldRect.height, 46);
    expect(fieldRect.left, greaterThan(screenRect.left));
    expect(fieldRect.right, lessThan(screenRect.right));
  });

  testWidgets(
    'Search result click preserves query when opening article route',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugFleurTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final article = _buildArticle(id: 42, title: 'Claude Result');
      final feed = _buildFeed(id: article.feedId);
      _FixedArticleListController.items = <Article>[article];
      addTearDown(() => _FixedArticleListController.items = <Article>[]);

      final router = GoRouter(
        initialLocation: '/search?q=claude&scope=starred',
        routes: [
          GoRoute(
            path: '/search',
            pageBuilder: (context, state) => NoTransitionPage(
              child: SearchScreen(
                selectedArticleId: null,
                routeState: searchStateFromUri(state.uri),
              ),
            ),
          ),
          GoRoute(
            path: '/search/article/:id',
            builder: (context, state) =>
                Text('search article ${state.pathParameters['id']}'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            articleListControllerProvider.overrideWith(
              _FixedArticleListController.new,
            ),
            appSettingsStoreProvider.overrideWithValue(
              FakeAppSettingsStore(AppSettings.defaults()),
            ),
            feedsProvider.overrideWith((ref) => Stream.value([feed])),
            categoriesProvider.overrideWith(
              (ref) => Stream.value(<Category>[]),
            ),
            tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ArticleList), findsOneWidget);
      expect(find.byType(ReaderView), findsNothing);

      await tester.tap(find.text('Claude Result'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/search/article/42?q=claude&scope=starred',
      );
      expect(find.text('search article 42'), findsOneWidget);
    },
  );

  testWidgets('Search reader route uses the sliding workspace layout', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final article = _buildArticle(id: 42, title: 'Claude Result');
    final feed = _buildFeed(id: article.feedId);
    _FixedArticleListController.items = <Article>[article];
    addTearDown(() => _FixedArticleListController.items = <Article>[]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          articleListControllerProvider.overrideWith(
            _FixedArticleListController.new,
          ),
          articleProvider(42).overrideWith((ref) => Stream.value(article)),
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(AppSettings.defaults()),
          ),
          readerSettingsStoreProvider.overrideWithValue(
            FakeReaderSettingsStore(const ReaderSettings()),
          ),
          readerProgressStoreProvider.overrideWithValue(
            InMemoryReaderProgressStore(),
          ),
          imageMetaStoreProvider.overrideWithValue(InMemoryImageMetaStore()),
          articleActionServiceProvider.overrideWithValue(
            RecordingArticleActionService(),
          ),
          feedsProvider.overrideWith((ref) => Stream.value([feed])),
          categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
          tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SearchScreen(
            selectedArticleId: 42,
            routeState: SearchRouteState(query: 'claude'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(
      find.byKey(const Key('article_reader_workspace_layout')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reading_pane_surface')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('reading_pane_surface')),
        matching: find.byKey(const Key('workspace_layer_leading_edge')),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(ArticleList)).width, kDesktopListWidth);
    expect(find.byType(ReaderView), findsOneWidget);
  });

  testWidgets('Saved reader route uses the sliding workspace layout', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final article = _buildArticle(
      id: 42,
      title: 'Starred Result',
      isStarred: true,
    );
    final feed = _buildFeed(id: article.feedId);
    _FixedArticleListController.items = <Article>[article];
    addTearDown(() => _FixedArticleListController.items = <Article>[]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          articleListControllerProvider.overrideWith(
            _FixedArticleListController.new,
          ),
          articleProvider(42).overrideWith((ref) => Stream.value(article)),
          appSettingsStoreProvider.overrideWithValue(
            FakeAppSettingsStore(AppSettings.defaults()),
          ),
          readerSettingsStoreProvider.overrideWithValue(
            FakeReaderSettingsStore(const ReaderSettings()),
          ),
          readerProgressStoreProvider.overrideWithValue(
            InMemoryReaderProgressStore(),
          ),
          imageMetaStoreProvider.overrideWithValue(InMemoryImageMetaStore()),
          articleActionServiceProvider.overrideWithValue(
            RecordingArticleActionService(),
          ),
          feedsProvider.overrideWith((ref) => Stream.value([feed])),
          categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
          tagsProvider.overrideWith((ref) => Stream.value(<Tag>[])),
          starredCountProvider.overrideWith((ref) => Stream.value(1)),
          readLaterCountProvider.overrideWith((ref) => Stream.value(0)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SavedScreen(selectedArticleId: 42),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(
      find.byKey(const Key('article_reader_workspace_layout')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reading_pane_surface')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('reading_pane_surface')),
        matching: find.byKey(const Key('workspace_layer_leading_edge')),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(ArticleList)).width, kDesktopListWidth);
    expect(find.byType(ReaderView), findsOneWidget);
  });
}

void _noopSelectScope(ArticleScope _) {}
