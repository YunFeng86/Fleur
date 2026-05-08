import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/providers/subscription_settings_provider.dart';
import 'package:fleur/ui/settings/subscriptions/subscription_tree_view.dart';
import 'package:fleur/ui/settings/widgets/section_header.dart';
import 'package:fleur/widgets/app_scrollbar.dart';
import 'package:fleur/widgets/tree_disclosure_button.dart';

void main() {
  testWidgets('SubscriptionTreeView starts expanded when category is selected', (
    tester,
  ) async {
    final category = Category()
      ..id = 1
      ..name = 'Tech';

    final feed = Feed()
      ..id = 101
      ..url = 'http://tech.com/rss'
      ..title = 'Tech News'
      ..categoryId = 1;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value([category])),
          feedsProvider.overrideWith((ref) => Stream.value([feed])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              // Simulate "already drilled down" state by initialising the provider state
              // We can't easily mock the notifier logic directly unless we override the provider.
              // We can just act on it in build or use a microtask.
              unawaited(
                Future.microtask(() {
                  ref
                      .read(subscriptionSelectionProvider.notifier)
                      .selectCategory(1);
                }),
              );
              return const Scaffold(body: SubscriptionTreeView());
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Category is present
    expect(find.text('Tech'), findsOneWidget);

    // Verify Feed is visible (implies expansion)
    expect(find.text('Tech News'), findsOneWidget);
  });

  testWidgets(
    'SubscriptionTreeView starts collapsed when category is NOT selected',
    (tester) async {
      final category = Category()
        ..id = 1
        ..name = 'Tech';

      final feed = Feed()
        ..id = 101
        ..url = 'http://tech.com/rss'
        ..title = 'Tech News'
        ..categoryId = 1;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) => Stream.value([category])),
            feedsProvider.overrideWith((ref) => Stream.value([feed])),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SubscriptionTreeView()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Category is present
      expect(find.text('Tech'), findsOneWidget);

      // Verify Feed is NOT visible (collapsed)
      expect(find.text('Tech News'), findsNothing);
    },
  );

  testWidgets('SubscriptionTreeView feed rows use shared settings primitives', (
    tester,
  ) async {
    final category = Category()
      ..id = 1
      ..name = 'Tech';

    final feed = Feed()
      ..id = 101
      ..url = 'http://tech.com/rss'
      ..title = 'Tech News'
      ..categoryId = 1;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value([category])),
          feedsProvider.overrideWith((ref) => Stream.value([feed])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              unawaited(
                Future.microtask(() {
                  ref
                      .read(subscriptionSelectionProvider.notifier)
                      .selectCategory(1);
                }),
              );
              return const Scaffold(body: SubscriptionTreeView());
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(SettingsTile), findsWidgets);
    expect(find.byType(SettingsLeadingAvatar), findsAtLeastNWidgets(1));
  });

  testWidgets('SubscriptionTreeView uses AppScrollbar for the tree pane', (
    tester,
  ) async {
    final category = Category()
      ..id = 1
      ..name = 'Tech';
    final feed = Feed()
      ..id = 101
      ..url = 'http://tech.com/rss'
      ..title = 'Tech News'
      ..categoryId = 1;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value([category])),
          feedsProvider.overrideWith((ref) => Stream.value([feed])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SubscriptionTreeView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppScrollbar), findsOneWidget);
  });

  testWidgets('expand button only expands tree and body tap changes scope', (
    tester,
  ) async {
    final category = Category()
      ..id = 1
      ..name = 'Tech';

    final feed = Feed()
      ..id = 101
      ..url = 'http://tech.com/rss'
      ..title = 'Tech News'
      ..categoryId = 1;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value([category])),
          feedsProvider.overrideWith((ref) => Stream.value([feed])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SubscriptionTreeView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SubscriptionTreeView)),
    );

    expect(find.byIcon(Icons.folder_outlined), findsNothing);
    expect(
      tester.getCenter(find.byIcon(Icons.chevron_right)).dx,
      lessThan(tester.getCenter(find.text('Tech')).dx),
    );

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Tech News'), findsOneWidget);
    expect(
      container.read(subscriptionSelectionProvider).activeCategoryId,
      isNull,
    );

    await tester.tap(find.text('Tech'));
    await tester.pumpAndSettle();

    expect(container.read(subscriptionSelectionProvider).activeCategoryId, 1);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
  });

  testWidgets(
    'uncategorized feeds are flattened to the root level at the bottom of the folder list',
    (tester) async {
      final category = Category()
        ..id = 1
        ..name = 'Tech';

      final uncategorizedFeed = Feed()
        ..id = 7
        ..url = 'https://example.com/root.xml'
        ..title = 'Root Feed';

      final categorizedFeed = Feed()
        ..id = 101
        ..url = 'http://tech.com/rss'
        ..title = 'Tech News'
        ..categoryId = 1;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) => Stream.value([category])),
            feedsProvider.overrideWith(
              (ref) => Stream.value([uncategorizedFeed, categorizedFeed]),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SubscriptionTreeView()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('All subscriptions'), findsNothing);
      expect(find.text('Uncategorized'), findsNothing);
      expect(find.text('Root Feed'), findsOneWidget);
      expect(find.text('Tech'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Root Feed')).dy,
        greaterThan(tester.getTopLeft(find.text('Tech')).dy),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SubscriptionTreeView)),
      );

      await tester.tap(find.text('Root Feed'));
      await tester.pumpAndSettle();

      final selection = container.read(subscriptionSelectionProvider);
      expect(selection.selectedFeedId, 7);
      expect(selection.activeCategoryId, isNull);
      expect(selection.categoryScope, isA<SubscriptionCategoryAll>());
    },
  );

  testWidgets('selected expanded category can be collapsed again', (
    tester,
  ) async {
    final category = Category()
      ..id = 1
      ..name = 'Tech';

    final feed = Feed()
      ..id = 101
      ..url = 'http://tech.com/rss'
      ..title = 'Tech News'
      ..categoryId = 1;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value([category])),
          feedsProvider.overrideWith((ref) => Stream.value([feed])),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              unawaited(
                Future.microtask(() {
                  ref
                      .read(subscriptionSelectionProvider.notifier)
                      .selectCategory(1);
                }),
              );
              return const Scaffold(body: SubscriptionTreeView());
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tech News'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();

    expect(find.text('Tech News'), findsNothing);
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
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value(categories)),
          feedsProvider.overrideWith((ref) => Stream.value(feeds)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SizedBox(height: 280, child: SubscriptionTreeView()),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final scrollable = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((state) => state.position.maxScrollExtent > 0);
    scrollable.position.jumpTo(250);
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
}
