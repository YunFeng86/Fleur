import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/features/subscriptions/subscriptions.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/app_menu.dart';
import 'package:fleur/ui/settings/subscriptions/category_list_component.dart';
import 'package:fleur/utils/platform.dart';
import 'package:fleur/widgets/app_scrollbar.dart';

import '../../../test_utils/critical_workflow_test_support.dart';

Future<void> _openContextMenuOnText(WidgetTester tester, String text) async {
  await _openContextMenu(tester, find.text(text).first);
}

Future<void> _openContextMenu(WidgetTester tester, Finder finder) async {
  await tester.tapAt(tester.getCenter(finder), buttons: kSecondaryMouseButton);
  await tester.pumpAndSettle();
}

Finder _popupMenuText(String text) {
  return find.descendant(
    of: find.byType(MenuItemButton),
    matching: find.text(text),
  );
}

void main() {
  testWidgets('CategoryListComponent uses AppScrollbar for the category pane', (
    tester,
  ) async {
    final category = Category()
      ..id = 1
      ..name = 'Tech';
    final feed = Feed()
      ..id = 101
      ..url = 'https://example.com/feed.xml'
      ..title = 'Tech Feed'
      ..categoryId = 1;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value([category])),
          feedsProvider.overrideWith((ref) => Stream.value([feed])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppMenuHost(
            child: Scaffold(body: CategoryListComponent()),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tech'), findsOneWidget);
    expect(find.byType(AppScrollbar), findsOneWidget);
  });

  testWidgets(
    'CategoryListComponent context menu covers categories and root feeds',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugFleurTargetPlatformOverride = null);

      final category = Category()
        ..id = 1
        ..name = 'Tech';
      final categorizedFeed = Feed()
        ..id = 101
        ..url = 'https://example.com/feed.xml'
        ..title = 'Tech Feed'
        ..categoryId = 1;
      final rootFeed = Feed()
        ..id = 102
        ..url = 'https://example.com/root.xml'
        ..title = 'Root Feed';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeAccountProvider.overrideWithValue(buildTestAccount()),
            categoriesProvider.overrideWith((ref) => Stream.value([category])),
            feedsProvider.overrideWith(
              (ref) => Stream.value([categorizedFeed, rootFeed]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AppMenuHost(
              child: Scaffold(body: CategoryListComponent()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await _openContextMenuOnText(tester, 'Tech');

      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete category'), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await _openContextMenuOnText(tester, 'Root Feed');

      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Make available offline'), findsOneWidget);
      expect(find.text('Move to category'), findsOneWidget);
      expect(find.text('Delete subscription'), findsOneWidget);
    },
  );

  testWidgets(
    'CategoryListComponent context menu covers header, folders, and global defaults',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugFleurTargetPlatformOverride = null);

      final category = Category()
        ..id = 1
        ..name = 'Tech';
      final feed = Feed()
        ..id = 101
        ..url = 'https://example.com/feed.xml'
        ..title = 'Tech Feed'
        ..categoryId = 1;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeAccountProvider.overrideWithValue(buildTestAccount()),
            categoriesProvider.overrideWith((ref) => Stream.value([category])),
            feedsProvider.overrideWith((ref) => Stream.value([feed])),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AppMenuHost(
              child: Scaffold(body: CategoryListComponent()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CategoryListComponent)),
      );

      await tester.tap(find.text('Tech'));
      await tester.pumpAndSettle();
      expect(container.read(subscriptionSelectionProvider).activeCategoryId, 1);
      expect(
        container.read(subscriptionSelectionProvider).isGlobalDefaults,
        isFalse,
      );

      await _openContextMenuOnText(tester, 'Global defaults');

      expect(_popupMenuText('Global defaults'), findsOneWidget);
      expect(
        container.read(subscriptionSelectionProvider).isGlobalDefaults,
        isFalse,
      );

      await tester.tap(_popupMenuText('Global defaults'));
      await tester.pumpAndSettle();

      expect(
        container.read(subscriptionSelectionProvider).isGlobalDefaults,
        isTrue,
      );
      expect(container.read(subscriptionSelectionProvider).activeCategoryId, 1);

      await _openContextMenuOnText(tester, 'Subscriptions');

      expect(_popupMenuText('Refresh sources'), findsOneWidget);
      expect(_popupMenuText('Add subscription'), findsOneWidget);
      expect(_popupMenuText('New category'), findsOneWidget);
      expect(_popupMenuText('Import OPML'), findsOneWidget);
      expect(_popupMenuText('Export OPML'), findsOneWidget);
      expect(_popupMenuText('Settings'), findsNothing);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await _openContextMenu(tester, find.text('Subscriptions').last);

      expect(_popupMenuText('Refresh sources'), findsOneWidget);
      expect(_popupMenuText('Add subscription'), findsOneWidget);
      expect(_popupMenuText('New category'), findsOneWidget);
      expect(_popupMenuText('Import OPML'), findsOneWidget);
      expect(_popupMenuText('Export OPML'), findsOneWidget);
      expect(_popupMenuText('Settings'), findsNothing);
    },
  );

  testWidgets('CategoryListComponent Miniflux menu keeps remote feed actions', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final rootFeed = Feed()
      ..id = 102
      ..url = 'https://example.com/root.xml'
      ..title = 'Root Feed';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeAccountProvider.overrideWithValue(
            buildTestAccount(type: AccountType.miniflux),
          ),
          categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
          feedsProvider.overrideWith((ref) => Stream.value([rootFeed])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppMenuHost(
            child: Scaffold(body: CategoryListComponent()),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _openContextMenu(tester, find.text('Subscriptions').last);

    expect(_popupMenuText('Refresh sources'), findsOneWidget);
    expect(_popupMenuText('Add subscription'), findsOneWidget);
    expect(_popupMenuText('New category'), findsOneWidget);
    expect(_popupMenuText('Export OPML'), findsOneWidget);
    expect(_popupMenuText('Import OPML'), findsNothing);
    expect(_popupMenuText('Sync account'), findsNothing);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await _openContextMenuOnText(tester, 'Root Feed');

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Make available offline'), findsOneWidget);
    expect(find.text('Move to category'), findsOneWidget);
    expect(find.text('Delete subscription'), findsOneWidget);
  });
}
