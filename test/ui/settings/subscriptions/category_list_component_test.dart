import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/settings/subscriptions/category_list_component.dart';
import 'package:fleur/widgets/app_scrollbar.dart';

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
          home: const Scaffold(body: CategoryListComponent()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tech'), findsOneWidget);
    expect(find.byType(AppScrollbar), findsOneWidget);
  });
}
