import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/sync/backend_capabilities.dart';
import 'package:fleur/services/sync/backend_sync_semantics.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/sidebar/sidebar_management_actions.dart';
import 'package:fleur/ui/sidebar/sidebar_selection_actions.dart';
import 'package:fleur/ui/sidebar/sidebar_tree.dart';
import 'package:fleur/utils/platform.dart';
import 'package:fleur/widgets/tree_disclosure_button.dart';

class _SidebarHarness extends ConsumerStatefulWidget {
  const _SidebarHarness({
    required this.categories,
    required this.feeds,
    required this.unreadCounts,
    this.tags = const <Tag>[],
    this.accountType = AccountType.local,
    this.onAddFeed,
    this.onAddCategory,
  });

  final List<Category> categories;
  final List<Feed> feeds;
  final List<Tag> tags;
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
      onSelectFeed: (_) {},
      closeSidebar: () {},
    );
    final managementActions = SidebarManagementActions(
      context: context,
      ref: ref,
      selectionActions: selectionActions,
      navigator: Navigator.of(context),
      showDialogRoute: <T>({required builder}) async => null,
    );

    return SidebarNavigationTree(
      scrollController: _scrollController,
      searchText: '',
      feeds: AsyncValue.data(widget.feeds),
      categories: AsyncValue.data(widget.categories),
      tags: AsyncValue.data(widget.tags),
      allUnreadCounts: AsyncValue.data(widget.unreadCounts),
      selectedFeedId: ref.watch(selectedFeedIdProvider),
      selectedCategoryId: ref.watch(selectedCategoryIdProvider),
      selectedTagId: ref.watch(selectedTagIdProvider),
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
    of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
    matching: find.text(text),
  );
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

      expect(find.byIcon(Icons.folder_outlined), findsNothing);
      expect(find.text('Tech News'), findsNothing);
      expect(
        tester.getCenter(find.byIcon(Icons.chevron_right)).dx,
        lessThan(tester.getCenter(find.text('Tech')).dx),
      );
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

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(find.text('Tech News'), findsOneWidget);
      expect(container.read(selectedCategoryIdProvider), isNull);
      final expandedSemantics = tester.widget<Semantics>(semanticsFinder.first);
      expect(expandedSemantics.properties.expanded, isTrue);

      await tester.tap(find.text('Tech'));
      await tester.pumpAndSettle();

      expect(container.read(selectedCategoryIdProvider), 1);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    },
  );

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

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Import OPML'), findsNothing);
    expect(find.text('Export OPML'), findsOneWidget);
    expect(find.text('Sync account'), findsNothing);
    expect(find.text('Refresh sources'), findsNothing);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await _openContextMenuOnText(tester, 'All Articles');

    expect(_popupMenuText('Sync account'), findsNothing);
    expect(_popupMenuText('Export OPML'), findsOneWidget);
    expect(_popupMenuText('Add subscription'), findsNothing);
    expect(_popupMenuText('New category'), findsNothing);
    expect(_popupMenuText('Import OPML'), findsNothing);
    expect(_popupMenuText('Refresh sources'), findsNothing);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Tech News'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert).last);
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
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete category'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz));
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

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).last);
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
    await tester.tap(find.byIcon(Icons.chevron_right));
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

  testWidgets('desktop context menu shows root and header actions', (
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

    await _openContextMenuOnText(tester, 'All Articles');

    expect(_popupMenuText('Show all'), findsOneWidget);
    expect(_popupMenuText('Refresh sources'), findsOneWidget);
    expect(_popupMenuText('Add subscription'), findsOneWidget);
    expect(_popupMenuText('New category'), findsOneWidget);
    expect(_popupMenuText('Import OPML'), findsOneWidget);
    expect(_popupMenuText('Export OPML'), findsOneWidget);
    expect(_popupMenuText('Settings'), findsOneWidget);
    expect(container.read(selectedCategoryIdProvider), 1);
    expect(container.read(selectedFeedIdProvider), isNull);

    await tester.tapAt(const Offset(5, 5));
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

    await _openContextMenuOnText(tester, 'All Articles');
    await tester.tap(_popupMenuText('Show all'));
    await tester.pumpAndSettle();
    expect(container.read(selectedCategoryIdProvider), isNull);
  });

  testWidgets(
    'sidebar header overflow and explicit action buttons stay scoped',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugFleurTargetPlatformOverride = null);

      var addFeedCount = 0;
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
                onAddFeed: () async => addFeedCount++,
                onAddCategory: () async => addCategoryCount++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Refresh sources'), findsOneWidget);
      expect(find.text('Import OPML'), findsOneWidget);
      expect(find.text('Export OPML'), findsOneWidget);
      expect(find.text('Add subscription'), findsNothing);
      expect(find.text('New category'), findsNothing);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add subscription'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New category'));
      await tester.pumpAndSettle();

      expect(addFeedCount, 1);
      expect(addCategoryCount, 1);

      await tester.tapAt(
        tester.getCenter(find.byTooltip('Add subscription')),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      expect(_popupMenuText('Refresh sources'), findsNothing);
      expect(_popupMenuText('Settings'), findsNothing);

      await tester.tapAt(
        tester.getCenter(find.byTooltip('New category')),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      expect(_popupMenuText('Refresh sources'), findsNothing);
      expect(_popupMenuText('Settings'), findsNothing);
    },
  );

  testWidgets('sidebar root and header context menus are desktop only', (
    tester,
  ) async {
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

    await _openContextMenuOnText(tester, 'All Articles');
    expect(_popupMenuText('Show all'), findsNothing);
    expect(_popupMenuText('Refresh sources'), findsNothing);

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

    await tester.tap(find.byIcon(Icons.chevron_right));
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
    Finder categoryRow(String label) => find
        .ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.expanded != null,
          ),
        )
        .first;
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

  testWidgets('expanding tags above the viewport preserves visible row', (
    tester,
  ) async {
    final tags = List<Tag>.generate(
      5,
      (index) => Tag()
        ..id = index + 1
        ..name = 'Tag ${index + 1}',
    );
    final categories = List<Category>.generate(
      8,
      (index) => Category()
        ..id = index + 1
        ..name = 'Category ${index + 1}',
    );

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
                feeds: const <Feed>[],
                tags: tags,
                unreadCounts: const {null: 1},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tagSectionFinder = find
        .ancestor(
          of: find.text('Tags'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.expanded != null,
          ),
        )
        .first;
    final tagDisclosure = tester.widget<TreeDisclosureButton>(
      find.descendant(
        of: tagSectionFinder,
        matching: find.byType(TreeDisclosureButton),
      ),
    );
    final scrollable = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((state) => state.position.maxScrollExtent > 0);
    scrollable.position.jumpTo(100);
    await tester.pump();

    final viewportTop = tester.getTopLeft(find.byType(ListView)).dy;
    Finder categoryRow(String label) => find
        .ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.expanded != null,
          ),
        )
        .first;
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

    tagDisclosure.onPressed();
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

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SidebarNavigationTree)),
    );
    expect(container.read(selectedTagIdProvider), isNull);
  });

  testWidgets(
    'desktop expanded large category with menus keeps maxScrollExtent stable while scrolling',
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
      expect(find.byType(MenuAnchor), findsWidgets);

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
