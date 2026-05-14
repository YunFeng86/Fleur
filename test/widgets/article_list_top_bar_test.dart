import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/models/article.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/providers/article_list_controller.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/widgets/article_list.dart';

import '../test_utils/critical_workflow_test_support.dart';

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

Feed _buildFeed() {
  return Feed()
    ..id = 10
    ..url = 'https://example.com/feed.xml'
    ..title = 'Example Feed'
    ..siteUrl = 'https://example.com';
}

Article _buildArticle(int id) {
  return Article()
    ..id = id
    ..feedId = 10
    ..link = 'https://example.com/article/$id'
    ..title = 'Top Bar Article $id'
    ..contentHtml = '<p>Hello world</p>'
    ..publishedAt = DateTime.utc(2026, 1, id.clamp(1, 28))
    ..updatedAt = DateTime.utc(2026, 1, id.clamp(1, 28));
}

Finder _topBar() => find.byKey(const ValueKey('article-list-top-bar'));
Finder _topFade() => find.byKey(const ValueKey('article-list-top-fade'));

Future<void> _pumpArticleList(WidgetTester tester) async {
  final articles = [for (var i = 1; i <= 30; i++) _buildArticle(i)];
  _FixedArticleListController.items = articles;
  addTearDown(() => _FixedArticleListController.items = <Article>[]);

  await pumpLocalizedTestApp(
    tester,
    size: const Size(420, 360),
    overrides: [
      appSettingsStoreProvider.overrideWithValue(
        FakeAppSettingsStore(AppSettings.defaults()),
      ),
      articleListControllerProvider.overrideWith(
        _FixedArticleListController.new,
      ),
      feedsProvider.overrideWith((ref) => Stream.value([_buildFeed()])),
      for (final article in articles)
        articleProvider(
          article.id,
        ).overrideWith((ref) => Stream.value(article)),
    ],
    home: Scaffold(
      body: ArticleList(
        selectedArticleId: null,
        topBar: Container(
          height: 44,
          alignment: Alignment.centerLeft,
          child: const Text('Scoped Toolbar'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'optional top bar stays fixed while list scrolls under top fade',
    (tester) async {
      await _pumpArticleList(tester);

      expect(find.text('Scoped Toolbar'), findsOneWidget);
      expect(tester.getSize(_topBar()).height, greaterThan(0));
      expect(_topFade(), findsOneWidget);
      expect(tester.getSize(_topFade()).height, 20);
      expect(
        find.descendant(of: _topFade(), matching: find.byType(ClipRect)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _topFade(), matching: find.byType(BackdropFilter)),
        findsOneWidget,
      );
      final fadeDecoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: _topFade(),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      final gradient = fadeDecoration.gradient as LinearGradient;
      expect(gradient.colors.first.a, lessThan(1));
      expect(gradient.colors.last.a, 0);

      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.text('Scoped Toolbar'), findsOneWidget);
      expect(tester.getSize(_topBar()).height, greaterThan(0));
      expect(_topFade(), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(tester.getSize(_topBar()).height, greaterThan(0));
    },
  );

  testWidgets('optional top bar stays visible for pointer scroll events', (
    tester,
  ) async {
    await _pumpArticleList(tester);
    final position = tester.getCenter(find.byType(ListView));

    await tester.sendEventToBinding(
      PointerScrollEvent(position: position, scrollDelta: const Offset(0, 500)),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(_topBar()).height, greaterThan(0));

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: position,
        scrollDelta: const Offset(0, -200),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(_topBar()).height, greaterThan(0));
    expect(_topFade(), findsOneWidget);
  });
}
