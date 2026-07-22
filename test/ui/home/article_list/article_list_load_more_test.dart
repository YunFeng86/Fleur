import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/models/article.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/providers/article_list_controller.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/ui/home/article_list/article_list.dart';

import '../../../test_utils/critical_workflow_test_support.dart';

class _MutableArticleListController extends ArticleListController {
  static ArticleListState currentState = const ArticleListState(
    items: <Article>[],
    hasMore: false,
    nextOffset: 0,
  );
  static int loadMoreCalls = 0;

  @override
  Future<ArticleListState> build() async => currentState;

  @override
  Future<void> loadMore() async {
    loadMoreCalls++;
    final current = state.valueOrNull;
    if (current == null) return;
    replaceState(current.copyWith(isLoadingMore: true));
  }

  void replaceState(ArticleListState next) {
    currentState = next;
    state = AsyncValue.data(next);
  }

  static void reset() {
    currentState = const ArticleListState(
      items: <Article>[],
      hasMore: false,
      nextOffset: 0,
    );
    loadMoreCalls = 0;
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
    ..title = 'Load More Article $id'
    ..contentHtml = '<p>Hello world</p>'
    ..publishedAt = DateTime.utc(2026, 1, id.clamp(1, 28))
    ..updatedAt = DateTime.utc(2026, 1, id.clamp(1, 28));
}

List<Article> _articles(int start, int count) {
  return List<Article>.generate(count, (index) => _buildArticle(start + index));
}

Future<void> _pumpArticleList(
  WidgetTester tester,
  ArticleListState state, {
  Size size = const Size(420, 360),
}) async {
  _MutableArticleListController.currentState = state;
  final articles = state.items;

  await pumpLocalizedTestApp(
    tester,
    size: size,
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
    home: const Scaffold(body: ArticleList(selectedArticleId: null)),
  );
  await tester.pump();
}

ScrollableState _articleListScrollable(WidgetTester tester) {
  return tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .firstWhere((state) => state.position.axis == Axis.vertical);
}

void main() {
  tearDown(_MutableArticleListController.reset);

  testWidgets('idle load-more state renders no sentinel text or spinner', (
    tester,
  ) async {
    final state = ArticleListState(
      items: _articles(1, 8),
      hasMore: true,
      nextOffset: 8,
    );

    await _pumpArticleList(tester, state);

    final l10n = AppLocalizations.of(tester.element(find.byType(ArticleList)))!;
    expect(find.text(l10n.scrollToLoadMore), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('loading-more state renders only a compact spinner', (
    tester,
  ) async {
    final state = ArticleListState(
      items: _articles(1, 1),
      hasMore: true,
      isLoadingMore: true,
      nextOffset: 1,
    );

    await _pumpArticleList(tester, state);

    final l10n = AppLocalizations.of(tester.element(find.byType(ArticleList)))!;
    expect(find.text(l10n.scrollToLoadMore), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.getSize(find.byType(CircularProgressIndicator)),
      const Size(20, 20),
    );
  });

  testWidgets('scrolling into the preload zone triggers one loadMore call', (
    tester,
  ) async {
    final state = ArticleListState(
      items: _articles(1, 30),
      hasMore: true,
      nextOffset: 30,
    );

    await _pumpArticleList(tester, state);
    expect(_MutableArticleListController.loadMoreCalls, 0);

    final scrollable = _articleListScrollable(tester);
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent - 500);
    await tester.pump();
    await tester.pump();

    expect(_MutableArticleListController.loadMoreCalls, 1);

    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    await tester.pump();

    expect(_MutableArticleListController.loadMoreCalls, 1);
  });

  testWidgets('loadMore is not triggered without more pages or while loading', (
    tester,
  ) async {
    final state = ArticleListState(
      items: _articles(1, 30),
      hasMore: false,
      nextOffset: 30,
    );

    await _pumpArticleList(tester, state);

    final scrollable = _articleListScrollable(tester);
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    await tester.pump();
    expect(_MutableArticleListController.loadMoreCalls, 0);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ArticleList)),
    );
    final controller =
        container.read(articleListControllerProvider.notifier)
            as _MutableArticleListController;
    controller.replaceState(
      ArticleListState(
        items: state.items,
        hasMore: true,
        isLoadingMore: true,
        nextOffset: 30,
      ),
    );
    await tester.pump();

    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    await tester.pump();
    expect(_MutableArticleListController.loadMoreCalls, 0);
  });

  testWidgets('front-trimmed windows compensate scroll offset', (tester) async {
    final state = ArticleListState(
      items: _articles(1, 30),
      hasMore: true,
      nextOffset: 30,
    );

    await _pumpArticleList(tester, state, size: const Size(420, 320));

    final scrollable = _articleListScrollable(tester);
    scrollable.position.jumpTo(900);
    await tester.pump();
    await tester.pump();
    final beforeTrim = scrollable.position.pixels;

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ArticleList)),
    );
    final controller =
        container.read(articleListControllerProvider.notifier)
            as _MutableArticleListController;
    controller.replaceState(
      ArticleListState(
        items: _articles(6, 25),
        hasMore: true,
        startOffset: 5,
        nextOffset: 30,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(scrollable.position.pixels, lessThan(beforeTrim));
    expect(scrollable.position.pixels, greaterThan(0));
  });
}
