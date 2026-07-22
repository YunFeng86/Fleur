import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/article.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/home/article_list/article_list_item.dart';

import '../../../test_utils/critical_workflow_test_support.dart';

Article _article() {
  return Article()
    ..id = 42
    ..feedId = 10
    ..link = 'https://example.com/article'
    ..title = 'Accessible article'
    ..contentHtml = '<p>Article summary</p>'
    ..publishedAt = DateTime.utc(2026, 1, 2)
    ..updatedAt = DateTime.utc(2026, 1, 2);
}

Feed _feed() {
  return Feed()
    ..id = 10
    ..url = 'https://example.com/feed.xml'
    ..title = 'Example Feed'
    ..siteUrl = 'https://example.com';
}

Future<RecordingArticleActionService> _pumpItem(
  WidgetTester tester, {
  required FocusHighlightStrategy interactionStrategy,
}) async {
  final focusManager = FocusManager.instance;
  final previousStrategy = focusManager.highlightStrategy;
  focusManager.highlightStrategy = interactionStrategy;
  addTearDown(() => focusManager.highlightStrategy = previousStrategy);

  final actions = RecordingArticleActionService();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        feedMapProvider.overrideWithValue({10: _feed()}),
        imageMetaStoreProvider.overrideWithValue(InMemoryImageMetaStore()),
        articleActionServiceProvider.overrideWithValue(actions),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 420,
            child: ArticleListItem(
              article: _article(),
              selected: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return actions;
}

void main() {
  testWidgets('touch mode keeps timestamp and exposes 48dp quick actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final actions = await _pumpItem(
        tester,
        interactionStrategy: FocusHighlightStrategy.alwaysTouch,
      );

      expect(find.byKey(const Key('article_item_timestamp')), findsOneWidget);
      expect(
        find.byKey(const Key('article_item_hover_actions')),
        findsOneWidget,
      );

      for (final key in const [
        Key('article_item_read_later_button'),
        Key('article_item_star_button'),
        Key('article_item_read_button'),
      ]) {
        expect(tester.getSize(find.byKey(key)), const Size.square(48));
      }
      expect(find.bySemanticsLabel('Read Later'), findsOneWidget);
      expect(find.bySemanticsLabel('Star'), findsOneWidget);
      expect(find.bySemanticsLabel('Mark read'), findsOneWidget);

      await tester.tap(find.byKey(const Key('article_item_star_button')));
      await tester.pump();
      expect(actions.toggleStarCalls, [42]);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'keyboard focus reveals actions and keeps them during traversal',
    (tester) async {
      await _pumpItem(
        tester,
        interactionStrategy: FocusHighlightStrategy.alwaysTraditional,
      );

      expect(find.byKey(const Key('article_item_hover_actions')), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        find.byKey(const Key('article_item_hover_actions')),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        find.byKey(const Key('article_item_hover_actions')),
        findsOneWidget,
      );
      expect(
        Focus.of(
          tester.element(
            find.byKey(const Key('article_item_read_later_button')),
          ),
        ).hasFocus,
        isTrue,
      );
    },
  );
}
