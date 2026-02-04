import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';
import 'package:flutter_reader/models/category.dart';
import 'package:flutter_reader/models/feed.dart';
import 'package:flutter_reader/providers/query_providers.dart';
import 'package:flutter_reader/providers/subscription_settings_provider.dart';
import 'package:flutter_reader/ui/settings/subscriptions/subscription_tree_view.dart';

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
}
