import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/article_scope.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/sync/backend_capabilities.dart';
import 'package:fleur/services/sync/backend_sync_semantics.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/theme/fleur_icons.dart';
import 'package:fleur/ui/app_menu.dart';
import 'package:fleur/ui/sidebar_layout.dart';
import 'package:fleur/ui/sidebar/sidebar_management_actions.dart';
import 'package:fleur/ui/sidebar/sidebar_selection_actions.dart';
import 'package:fleur/ui/sidebar/sidebar_tree.dart';
import 'package:fleur/utils/platform.dart';
import 'package:fleur/widgets/favicon_circle.dart';
import 'package:fleur/widgets/tree_disclosure_button.dart';

import '../../test_utils/critical_workflow_test_support.dart';

class _SidebarHarness extends ConsumerStatefulWidget {
  const _SidebarHarness({
    required this.categories,
    required this.feeds,
    required this.unreadCounts,
    this.accountType = AccountType.local,
    this.onAddFeed,
    this.onAddCategory,
  });

  final List<Category> categories;
  final List<Feed> feeds;
  final Map<int?, int> unreadCounts;
  final AccountType accountType;
  final Future<void> Function()? onAddFeed;
  final Future<void> Function()? onAddCategory;

  @override
  ConsumerState<_SidebarHarness> createState() => _SidebarHarnessState();
}

class _SidebarHarnessState extends ConsumerState<_SidebarHarness> {
  final ScrollController _scrollController = ScrollController();
  int? _expandedCategoryId;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectionActions = SidebarSelectionActions(
      ref: ref,
      onSelectScope: (ArticleScope _) {},
      closeSidebar: () {},
    );
    final managementActions = SidebarManagementActions(
      context: context,
      ref: ref,
      selectionActions: selectionActions,
      navigator: Navigator.of(context),
      showDialogRoute: <T>({required builder}) async => null,
    );

    return AppMenuHost(
      child: SidebarNavigationTree(
        presentationMode: SidebarPresentationMode.expanded,
        scrollController: _scrollController,
        feeds: AsyncValue.data(widget.feeds),
        categories: AsyncValue.data(widget.categories),
        allUnreadCounts: AsyncValue.data(widget.unreadCounts),
        selectedFeedId: ref.watch(selectedFeedIdProvider),
        selectedCategoryId: ref.watch(selectedCategoryIdProvider),
        starredOnly: ref.watch(starredOnlyProvider),
        readLaterOnly: ref.watch(readLaterOnlyProvider),
        expandedCategoryId: _expandedCategoryId,
        onExpandedCategoryChanged: (categoryId) {
          setState(() => _expandedCategoryId = categoryId);
        },
        selectionActions: selectionActions,
        managementActions: managementActions,
        capabilities: BackendCapabilities.forAccountType(widget.accountType),
        syncSemantics: BackendSyncSemantics.forAccountType(widget.accountType),
        onAddFeed: widget.onAddFeed ?? () async {},
        onAddCategory: widget.onAddCategory ?? () async {},
        onShowCategoryMenu: (_) async {},
        onShowFeedMenu: (_) async {},
      ),
    );
  }
}

Future<void> _openContextMenuOnText(WidgetTester tester, String text) async {
  await tester.tapAt(
    tester.getCenter(find.text(text).first),
    buttons: kSecondaryMouseButton,
  );
  await tester.pumpAndSettle();
}

Finder _popupMenuText(String text) {
  return find.descendant(
    of: find.byType(MenuItemButton),
    matching: find.text(text),
  );
}

Future<TestGesture> _hoverText(WidgetTester tester, String text) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer();
  await gesture.moveTo(tester.getCenter(find.text(text).first));
  await tester.pumpAndSettle();
  return gesture;
}

void main() {
  testWidgets(
    'sidebar categories use left disclosure and preserve selection semantics',
    (tester) async {
      final category = Category()
        ..id = 1
        ..name = 'Tech';
      final feed = Feed()
        ..id = 101
        ..url = 'https://example.com/feed.xml'
        ..title = 'Tech News'
        ..categoryId = 1;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: _SidebarHarness(
                categories: [category],
                feeds: [feed],
                unreadCounts: const {null: 1, 101: 1},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(FleurIcons.category), findsNothing);
      expect(find.text('Tech News'), findsNothing);
      expect(
        tester.getSize(find.byType(TreeDisclosureButton).first),
        const Size(40, 48),
      );
      expect(
        tester.getCenter(find.byIcon(FleurIcons.expand)).dx,
        closeTo(kSidebarRailWidth / 2, 0.1),
      );
      expect(
        tester.getCenter(find.byIcon(FleurIcons.expand)).dx,
        lessThan(tester.getCenter(find.text('Tech')).dx),
      );
      final categoryTitle = tester.widget<Text>(find.text('Tech'));
      expect(categoryTitle.maxLines, 1);
      expect(categoryTitle.overflow, TextOverflow.ellipsis);
      final tileFinder = find.ancestor(
        of: find.text('Tech'),
        matching: find.byType(ListTile),
      );
      final semanticsFinder = find.ancestor(
        of: tileFinder,
        matching: find.byType(Semantics),
      );
      final collapsedSemantics = tester.widget<Semantics>(
        semanticsFinder.first,
      );
      expect(collapsedSemantics.properties.expanded, isFalse);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SidebarNavigationTree)),
      );

      await tester.tap(find.byIcon(FleurIcons.expand));
      await tester.pumpAndSettle();

      expect(find.text('Tech News'), findsOneWidget);
      expect(
        tester.getCenter(find.byType(FaviconCircle).first).dx,
        closeTo(kSidebarRailWidth / 2 + 16, 0.1),
      );
      expect(container.read(selectedCategoryIdProvider), isNull);
      final expandedSemantics = tester.widget<Semantics>(semanticsFinder.first);
      expect(expandedSemantics.properties.expanded, isTrue);

      await tester.tap(find.text('Tech'));
      await tester.pumpAndSettle();

      expect(container.read(selectedCategoryIdProvider), 1);
      expect(find.byIcon(FleurIcons.collapse), findsOneWidget);
    },
  );

  testWidgets('sidebar reveal actions replace capped unread counts by scope', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final actionService = RecordingArticleActionService();
    final category = Category()
      ..id = 1
      ..name = 'Tech';
    final feed = Feed()
      ..id = 101
      ..url = 'https://example.com/feed.xml'
      ..title = 'Tech News'
      ..categoryId = 1;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          articleActionServiceProvider.overrideWithValue(actionService),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _SidebarHarness(
              categories: [category],
              feeds: [feed],
              unreadCounts: const {101: 240},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('99+'), findsOneWidget);
    expect(find.text('240'), findsNothing);
    final unreadText = tester.widget<Text>(find.text('99+'));
    final unreadContext = tester.element(find.text('99+'));
    expect(unreadText.textAlign, TextAlign.right);
    expect(
      unreadText.style?.color,
      Theme.of(unreadContext).colorScheme.onSurfaceVariant,
    );
    expect(
      find.ancestor(
        of: find.text('99+').first,
        matching: find.byWidgetPredicate((widget) {
          if (widget is! Padding) return false;
          final padding = widget.padding.resolve(TextDirection.ltr);
          return padding.left == 0 &&
              padding.top == 0 &&
              padding.right == 8 &&
              padding.bottom == 0;
        }),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Mark all read'), findsNothing);
    expect(find.byTooltip('Add subscription'), findsNothing);

    final categoryHover = await _hoverText(tester, 'Tech');
    expect(find.byTooltip('More'), findsOneWidget);
    expect(find.byTooltip('Add subscription'), findsOneWidget);
    expect(find.byTooltip('Mark all read'), findsOneWidget);
    await categoryHover.removePointer();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tech'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('More'), findsNothing);
    expect(find.byTooltip('Add subscription'), findsNothing);
    expect(find.byTooltip('Mark all read'), findsNothing);

    final selectedCategoryHover = await _hoverText(tester, 'Tech');
    expect(find.byTooltip('More'), findsOneWidget);
    expect(find.byTooltip('Add subscription'), findsOneWidget);
    expect(find.byTooltip('Mark all read'), findsOneWidget);

    await tester.tap(find.byTooltip('Mark all read'));
    await tester.pumpAndSettle();
    await selectedCategoryHover.removePointer();
    await tester.pumpAndSettle();

    expect(actionService.markAllReadCalls, [
      (
        feedId: null,
        categoryId: 1,
        starredOnly: false,
        readLaterOnly: false,
        tagId: null,
      ),
    ]);

    await tester.tap(find.byIcon(FleurIcons.expand));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tech News'));
    await tester.pumpAndSettle();

    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(SidebarNavigationTree)),
      ).read(selectedCategoryIdProvider),
      isNull,
    );
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(SidebarNavigationTree)),
      ).read(selectedFeedIdProvider),
      101,
    );
    expect(find.byTooltip('More'), findsNothing);
    expect(find.byTooltip('Mark all read'), findsNothing);

    final feedHover = await _hoverText(tester, 'Tech News');
    expect(find.byTooltip('More'), findsOneWidget);
    expect(find.byTooltip('Mark all read'), findsOneWidget);

    await tester.tap(find.byTooltip('Mark all read'));
    await tester.pumpAndSettle();
    await feedHover.removePointer();
    await tester.pumpAndSettle();

    expect(actionService.markAllReadCalls, [
      (
        feedId: null,
        categoryId: 1,
        starredOnly: false,
        readLaterOnly: false,
        tagId: null,
      ),
      (
        feedId: 101,
        categoryId: null,
        starredOnly: false,
        readLaterOnly: false,
        tagId: null,
      ),
    ]);
  });

  testWidgets('sidebar more menu remains interactive after hover leaves row', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final category = Category()
      ..id = 1
      ..name = 'Tech';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _SidebarHarness(
              categories: [category],
              feeds: const <Feed>[],
              unreadCounts: const {null: 1},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SidebarNavigationTree)),
    );

    final hover = await _hoverText(tester, 'Tech');
    expect(container.read(selectedCategoryIdProvider), isNull);
    expect(find.byTooltip('More'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete category'), findsOneWidget);

    await hover.removePointer();
    await tester.pumpAndSettle();

    expect(container.read(selectedCategoryIdProvider), isNull);
    expect(find.byTooltip('More'), findsNothing);
    expect(find.text('Rename'), findsOneWidget);

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(find.text('Rename'), findsNothing);
  });

  testWidgets('sidebar feed rows show one-line title with padded unread edge', (
    tester,
  ) async {
    final category = Category()
      ..id = 1
      ..name = 'Tech';
    final titledFeed = Feed()
      ..id = 101
      ..url = 'https://example.com/feed.xml'
      ..title = 'Tech News'
      ..categoryId = 1;
    final urlOnlyFeed = Feed()
      ..id = 102
      ..url = 'https://fallback.example/rss'
      ..categoryId = 1;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _SidebarHarness(
              categories: [category],
              feeds: [titledFeed, urlOnlyFeed],
              unreadCounts: const {101: 240, 102: 1},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(FleurIcons.expand));
    await tester.pumpAndSettle();

    expect(find.text('Tech News'), findsOneWidget);
    expect(find.text('https://example.com/feed.xml'), findsNothing);
    expect(find.text('https://fallback.example/rss'), findsOneWidget);

    final titledText = tester.widget<Text>(find.text('Tech News'));
    expect(titledText.maxLines, 1);
    expect(titledText.overflow, TextOverflow.ellipsis);

    final urlText = tester.widget<Text>(
      find.text('https://fallback.example/rss'),
    );
    expect(urlText.maxLines, 1);
    expect(urlText.overflow, TextOverflow.ellipsis);

    final feedTile = tester.widget<ListTile>(
      find
          .ancestor(of: find.text('Tech News'), matching: find.byType(ListTile))
          .first,
    );
    final contentPadding = feedTile.contentPadding!.resolve(TextDirection.ltr);
    expect(contentPadding.right, 16);
    expect(find.text('99+'), findsAtLeastNWidgets(1));
  });

  testWidgets('Fever sidebar hides structure actions and OPML import', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final category = Category()
      ..id = 1
      ..name = 'Tech';
    final feed = Feed()
      ..id = 101
      ..url = 'https://example.com/feed.xml'
      ..title = 'Tech News'
      ..categoryId = 1;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _SidebarHarness(
              categories: [category],
              feeds: [feed],
              unreadCounts: const {null: 1, 101: 1},
              accountType: AccountType.fever,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('New category'), findsNothing);
    expect(find.byTooltip('Read-only remote groups'), findsOneWidget);
    expect(find.text('Tech'), findsOneWidget);

    await _openContextMenuOnText(tester, 'Subscriptions');
    await tester.pumpAndSettle();

    expect(find.text('Import OPML'), findsNothing);
    expect(find.text('Export OPML'), findsOneWidget);
    expect(find.text('Sync account'), findsOneWidget);
    expect(find.text('Refresh sources'), findsNothing);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(FleurIcons.expand));
    await tester.pumpAndSettle();

    expect(find.text('Tech News'), findsOneWidget);
    await tester.tap(find.text('Tech News'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('More'), findsNothing);
    final feverFeedHover = await _hoverText(tester, 'Tech News');
    expect(find.byTooltip('More'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await feverFeedHover.removePointer();
    await tester.pumpAndSettle();

    expect(find.text('Move to category'), findsNothing);
    expect(find.text('Delete subscription'), findsNothing);
    expect(find.text('Refresh'), findsNothing);
    expect(find.text('Rename'), findsOneWidget);
  });

  testWidgets('Miniflux sidebar uses source refresh wording for root refresh', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final category = Category()
      ..id = 1
      ..name = 'Tech';
    final feed = Feed()
      ..id = 101
      ..url = 'https://example.com/feed.xml'
      ..title = 'Tech News'
      ..categoryId = 1;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _SidebarHarness(
              categories: [category],
              feeds: [feed],
              unreadCounts: const {null: 1, 101: 1},
              accountType: AccountType.miniflux,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Read-only remote groups'), findsNothing);
    await tester.tap(find.text('Tech'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('More'), findsNothing);
    final categoryHover = await _hoverText(tester, 'Tech');
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await categoryHover.removePointer();
    await tester.pumpAndSettle();

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete category'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await _openContextMenuOnText(tester, 'Subscriptions');
    await tester.pumpAndSettle();

    expect(find.text('Refresh sources'), findsOneWidget);
    expect(find.text('Sync account'), findsNothing);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await _openContextMenuOnText(tester, 'Subscriptions');

    expect(_popupMenuText('Refresh sources'), findsOneWidget);
    expect(_popupMenuText('Add subscription'), findsOneWidget);
    expect(_popupMenuText('New category'), findsOneWidget);
    expect(_popupMenuText('Export OPML'), findsOneWidget);
    expect(_popupMenuText('Import OPML'), findsNothing);
    expect(_popupMenuText('Sync account'), findsNothing);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(FleurIcons.expand));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tech News'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('More'), findsNothing);
    final feedHover = await _hoverText(tester, 'Tech News');
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await feedHover.removePointer();
    await tester.pumpAndSettle();

    expect(find.text('Refresh'), findsOneWidget);
  });

  testWidgets('desktop context menu shows category and feed actions', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final category = Category()
      ..id = 1
      ..name = 'Tech';
    final feed = Feed()
      ..id = 101
      ..url = 'https://example.com/feed.xml'
      ..title = 'Tech News'
      ..categoryId = 1;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _SidebarHarness(
              categories: [category],
              feeds: [feed],
              unreadCounts: const {null: 1, 101: 1},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SidebarNavigationTree)),
    );

    await _openContextMenuOnText(tester, 'Tech');

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete category'), findsOneWidget);
    expect(container.read(selectedCategoryIdProvider), isNull);
    expect(container.read(selectedFeedIdProvider), isNull);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(FleurIcons.expand));
    await tester.pumpAndSettle();

    await _openContextMenuOnText(tester, 'Tech News');

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Make available offline'), findsOneWidget);
    expect(find.text('Move to category'), findsOneWidget);
    expect(find.text('Delete subscription'), findsOneWidget);
    expect(container.read(selectedCategoryIdProvider), isNull);
    expect(container.read(selectedFeedIdProvider), isNull);
  });

  testWidgets('desktop context menu shows subscription header actions', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final category = Category()
      ..id = 1
      ..name = 'Tech';
    final feed = Feed()
      ..id = 101
      ..url = 'https://example.com/feed.xml'
      ..title = 'Tech News'
      ..categoryId = 1;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _SidebarHarness(
              categories: [category],
              feeds: [feed],
              unreadCounts: const {null: 1, 101: 1},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SidebarNavigationTree)),
    );

    await tester.tap(find.text('Tech'));
    await tester.pumpAndSettle();
    expect(container.read(selectedCategoryIdProvider), 1);

    await _openContextMenuOnText(tester, 'Subscriptions');

    expect(_popupMenuText('Show all'), findsNothing);
    expect(_popupMenuText('Refresh sources'), findsOneWidget);
    expect(_popupMenuText('Add subscription'), findsOneWidget);
    expect(_popupMenuText('New category'), findsOneWidget);
    expect(_popupMenuText('Import OPML'), findsOneWidget);
    expect(_popupMenuText('Export OPML'), findsOneWidget);
    expect(_popupMenuText('Settings'), findsOneWidget);
    expect(container.read(selectedCategoryIdProvider), 1);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
  });

  testWidgets('sidebar header keeps only folder action visible', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    var addCategoryCount = 0;
    final category = Category()
      ..id = 1
      ..name = 'Tech';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _SidebarHarness(
              categories: [category],
              feeds: const <Feed>[],
              unreadCounts: const {null: 1},
              onAddFeed: () async {},
              onAddCategory: () async => addCategoryCount++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Add subscription'), findsNothing);
    expect(find.byTooltip('New category'), findsOneWidget);

    await _openContextMenuOnText(tester, 'Subscriptions');

    expect(_popupMenuText('Settings'), findsOneWidget);
    expect(_popupMenuText('Refresh sources'), findsOneWidget);
    expect(_popupMenuText('Import OPML'), findsOneWidget);
    expect(_popupMenuText('Export OPML'), findsOneWidget);
    expect(_popupMenuText('Add subscription'), findsOneWidget);
    expect(_popupMenuText('New category'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New category'));
    await tester.pumpAndSettle();

    expect(addCategoryCount, 1);

    await tester.tapAt(
      tester.getCenter(find.byTooltip('New category')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(_popupMenuText('Refresh sources'), findsNothing);
    expect(_popupMenuText('Settings'), findsNothing);
  });

  testWidgets('sidebar header context menu is desktop only', (tester) async {
    debugFleurTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: _SidebarHarness(
              categories: <Category>[],
              feeds: <Feed>[],
              unreadCounts: {null: 1},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openContextMenuOnText(tester, 'Subscriptions');
    expect(_popupMenuText('Refresh sources'), findsNothing);
    expect(_popupMenuText('Add subscription'), findsNothing);
  });

  testWidgets('Fever desktop context menu keeps only local feed actions', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final category = Category()
      ..id = 1
      ..name = 'Tech';
    final feed = Feed()
      ..id = 101
      ..url = 'https://example.com/feed.xml'
      ..title = 'Tech News'
      ..categoryId = 1;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _SidebarHarness(
              categories: [category],
              feeds: [feed],
              unreadCounts: const {null: 1, 101: 1},
              accountType: AccountType.fever,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openContextMenuOnText(tester, 'Tech');

    expect(find.text('Rename'), findsNothing);
    expect(find.text('Delete category'), findsNothing);

    await tester.tap(find.byIcon(FleurIcons.expand));
    await tester.pumpAndSettle();
    await _openContextMenuOnText(tester, 'Tech News');

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Make available offline'), findsOneWidget);
    expect(find.text('Refresh'), findsNothing);
    expect(find.text('Move to category'), findsNothing);
    expect(find.text('Delete subscription'), findsNothing);
  });

  testWidgets('expanding a category above the viewport preserves visible row', (
    tester,
  ) async {
    final categories = List<Category>.generate(
      8,
      (index) => Category()
        ..id = index + 1
        ..name = 'Category ${index + 1}',
    );
    final feeds = <Feed>[
      for (final category in categories)
        for (var i = 0; i < 4; i++)
          Feed()
            ..id = category.id * 100 + i
            ..url = 'https://example.com/${category.id}/feed-$i.xml'
            ..title = 'Feed ${category.id}-$i'
            ..categoryId = category.id,
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              height: 260,
              child: _SidebarHarness(
                categories: categories,
                feeds: feeds,
                unreadCounts: const {null: 1},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((state) => state.position.maxScrollExtent > 0);
    scrollable.position.jumpTo(220);
    await tester.pump();

    final viewportTop = tester.getTopLeft(find.byType(ListView)).dy;
    Finder categoryRow(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.expanded != null,
      ),
    );
    final anchorRowFinder =
        List<Finder>.generate(
          7,
          (index) => categoryRow('Category ${index + 2}'),
        ).firstWhere(
          (finder) =>
              finder.evaluate().isNotEmpty &&
              tester.getTopLeft(finder).dy >= viewportTop,
        );
    expect(anchorRowFinder, findsOneWidget);
    final beforeTop = tester.getTopLeft(anchorRowFinder).dy;
    final beforePixels = scrollable.position.pixels;
    final beforeMaxExtent = scrollable.position.maxScrollExtent;
    final beforeViewportDimension = scrollable.position.viewportDimension;

    final firstDisclosure = tester
        .widgetList<TreeDisclosureButton>(find.byType(TreeDisclosureButton))
        .first;
    firstDisclosure.onPressed();
    await tester.pump();

    expect(scrollable.position.maxScrollExtent, greaterThan(beforeMaxExtent));
    expect(scrollable.position.viewportDimension, beforeViewportDimension);
    await tester.pump();

    expect(scrollable.position.pixels, greaterThan(beforePixels));
    expect(tester.getTopLeft(anchorRowFinder).dy, closeTo(beforeTop, 1));
    await tester.pumpAndSettle();

    expect(scrollable.position.maxScrollExtent, greaterThan(beforeMaxExtent));
    expect(scrollable.position.viewportDimension, beforeViewportDimension);
    expect(tester.getTopLeft(anchorRowFinder).dy, closeTo(beforeTop, 1));
  });

  testWidgets(
    'desktop expanded large category with hidden actions keeps maxScrollExtent stable while scrolling',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugFleurTargetPlatformOverride = null);

      final bigCategory = Category()
        ..id = 1
        ..name = 'Large category';
      final followingCategories = List<Category>.generate(
        24,
        (index) => Category()
          ..id = index + 2
          ..name = 'Following ${index + 1}',
      );
      final feeds = List<Feed>.generate(
        80,
        (index) => Feed()
          ..id = 1000 + index
          ..url = 'https://example.com/large/feed-$index.xml'
          ..title = 'Large Feed $index'
          ..categoryId = bigCategory.id,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                height: 320,
                child: _SidebarHarness(
                  categories: [bigCategory, ...followingCategories],
                  feeds: feeds,
                  unreadCounts: const {null: 1},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .widget<TreeDisclosureButton>(find.byType(TreeDisclosureButton).first)
          .onPressed();
      await tester.pumpAndSettle();
      expect(find.byType(MenuAnchor), findsOneWidget);

      final scrollable = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .firstWhere((state) => state.position.maxScrollExtent > 0);
      final samples = <double>[scrollable.position.maxScrollExtent];
      for (final offset in <double>[800, 2400, 4800, 6200, 7200]) {
        scrollable.position.jumpTo(
          offset.clamp(0.0, scrollable.position.maxScrollExtent).toDouble(),
        );
        await tester.pump();
        samples.add(scrollable.position.maxScrollExtent);
      }

      final smallest = samples.reduce((a, b) => a < b ? a : b);
      final largest = samples.reduce((a, b) => a > b ? a : b);
      expect(largest / smallest, lessThan(1.15));
      expect(tester.takeException(), isNull);
    },
  );
}
