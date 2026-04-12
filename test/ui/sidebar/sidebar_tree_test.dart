import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/sidebar/sidebar_management_actions.dart';
import 'package:fleur/ui/sidebar/sidebar_selection_actions.dart';
import 'package:fleur/ui/sidebar/sidebar_tree.dart';

class _SidebarHarness extends ConsumerStatefulWidget {
  const _SidebarHarness({
    required this.categories,
    required this.feeds,
    required this.unreadCounts,
  });

  final List<Category> categories;
  final List<Feed> feeds;
  final Map<int?, int> unreadCounts;

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
      tags: const AsyncValue.data(<Tag>[]),
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
      onAddFeed: () async {},
      onAddCategory: () async {},
      onShowCategoryMenu: (_) async {},
      onShowFeedMenu: (_) async {},
    );
  }
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
}
