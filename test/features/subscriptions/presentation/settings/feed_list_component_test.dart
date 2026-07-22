import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/app_menu.dart';
import 'package:fleur/features/subscriptions/presentation/settings/feed_list_component.dart';
import 'package:fleur/utils/platform.dart';

import '../../../../test_utils/critical_workflow_test_support.dart';

Future<void> _openContextMenuOnText(WidgetTester tester, String text) async {
  await tester.tapAt(
    tester.getCenter(find.text(text)),
    buttons: kSecondaryMouseButton,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpFeedList(
  WidgetTester tester, {
  required AccountType accountType,
}) async {
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
        activeAccountProvider.overrideWithValue(
          buildTestAccount(type: accountType),
        ),
        categoriesProvider.overrideWith((ref) => Stream.value([category])),
        feedsProvider.overrideWith((ref) => Stream.value([feed])),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppMenuHost(child: Scaffold(body: FeedListComponent())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('FeedListComponent context menu shows feed actions', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    await _pumpFeedList(tester, accountType: AccountType.local);
    await _openContextMenuOnText(tester, 'Tech Feed');

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Make available offline'), findsOneWidget);
    expect(find.text('Move to category'), findsOneWidget);
    expect(find.text('Delete subscription'), findsOneWidget);
  });

  testWidgets('FeedListComponent Fever context menu hides structure actions', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    await _pumpFeedList(tester, accountType: AccountType.fever);
    await _openContextMenuOnText(tester, 'Tech Feed');

    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Make available offline'), findsOneWidget);
    expect(find.text('Refresh'), findsNothing);
    expect(find.text('Move to category'), findsNothing);
    expect(find.text('Delete subscription'), findsNothing);
  });
}
