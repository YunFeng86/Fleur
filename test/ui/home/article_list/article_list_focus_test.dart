import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/models/article.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/article_list_controller.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/ui/home/article_list/article_list.dart';

import '../../../test_utils/critical_workflow_test_support.dart';

class _MutableArticleListController extends ArticleListController {
  static late ArticleListState initialState;

  @override
  Future<ArticleListState> build() async => initialState;

  void replaceState(ArticleListState next) {
    state = AsyncValue.data(next);
  }
}

Feed _buildFeed() {
  return Feed()
    ..id = 10
    ..url = 'https://example.com/feed.xml'
    ..title = 'Example Feed';
}

Article _buildArticle(int id) {
  return Article()
    ..id = id
    ..feedId = 10
    ..link = 'https://example.com/article/$id'
    ..title = 'Article $id'
    ..contentHtml = '<p>Content $id</p>'
    ..publishedAt = DateTime.utc(2026, 1, id)
    ..updatedAt = DateTime.utc(2026, 1, id);
}

void main() {
  late ValueNotifier<int?> selectedArticleId;
  late FocusNode readerFocusNode;

  setUp(() {
    selectedArticleId = ValueNotifier<int?>(2);
    readerFocusNode = FocusNode(debugLabel: 'reader-probe');
  });

  tearDown(() {
    selectedArticleId.dispose();
    readerFocusNode.dispose();
  });

  Future<ProviderContainer> pumpList(
    WidgetTester tester, {
    required List<Article> articles,
  }) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
    });
    _MutableArticleListController.initialState = ArticleListState(
      items: articles,
      hasMore: false,
      nextOffset: articles.length,
    );

    await pumpLocalizedTestApp(
      tester,
      size: const Size(420, 600),
      overrides: [
        appSettingsStoreProvider.overrideWithValue(
          FakeAppSettingsStore(AppSettings.defaults()),
        ),
        articleListControllerProvider.overrideWith(
          _MutableArticleListController.new,
        ),
        feedsProvider.overrideWith((ref) => Stream.value([_buildFeed()])),
        for (final article in articles)
          articleProvider(
            article.id,
          ).overrideWith((ref) => Stream.value(article)),
      ],
      home: Scaffold(
        body: Stack(
          children: [
            ValueListenableBuilder<int?>(
              valueListenable: selectedArticleId,
              builder: (context, selected, _) =>
                  ArticleList(selectedArticleId: selected),
            ),
            Focus(focusNode: readerFocusNode, child: const SizedBox.shrink()),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(ArticleList)));
  }

  testWidgets('closing reader restores the selected article focus', (
    tester,
  ) async {
    await pumpList(tester, articles: [_buildArticle(1), _buildArticle(2)]);
    readerFocusNode.requestFocus();
    await tester.pump();

    selectedArticleId.value = null;
    await tester.pump();
    await tester.pump();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'article-list-article-anchor',
    );
  });

  testWidgets('closing reader falls back to the list when article is gone', (
    tester,
  ) async {
    final articles = [_buildArticle(1), _buildArticle(2)];
    final container = await pumpList(tester, articles: articles);
    readerFocusNode.requestFocus();
    await tester.pump();

    final controller =
        container.read(articleListControllerProvider.notifier)
            as _MutableArticleListController;
    controller.replaceState(
      ArticleListState(items: [articles.first], hasMore: false, nextOffset: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('Article 2'), findsNothing);
    selectedArticleId.value = null;
    await tester.pump();
    await tester.pump();

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'article-list-fallback',
    );
  });

  testWidgets('switching articles does not steal reader focus', (tester) async {
    await pumpList(tester, articles: [_buildArticle(1), _buildArticle(2)]);
    readerFocusNode.requestFocus();
    await tester.pump();

    selectedArticleId.value = 1;
    await tester.pump();
    await tester.pump();

    expect(readerFocusNode.hasFocus, isTrue);
  });
}
