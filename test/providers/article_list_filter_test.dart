import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/models/article_scope.dart';
import 'package:fleur/providers/query_providers.dart';

void main() {
  test('selecting browse targets clears saved filters and search', () {
    const filter = ArticleListFilter(
      scope: ArticleScope.starred,
      unreadOnly: true,
      searchQuery: 'needle',
    );

    final selectedFeed = filter.selectFeed(12);
    expect(selectedFeed.scope, const ArticleScope.feed(12));
    expect(selectedFeed.selectedFeedId, 12);
    expect(selectedFeed.selectedCategoryId, isNull);
    expect(selectedFeed.selectedTagId, isNull);
    expect(selectedFeed.unreadOnly, isTrue);
    expect(selectedFeed.starredOnly, isFalse);
    expect(selectedFeed.readLaterOnly, isFalse);
    expect(selectedFeed.searchQuery, '');

    final selectedCategory = filter.selectCategory(34);
    expect(selectedCategory.scope, const ArticleScope.category(34));
    expect(selectedCategory.selectedFeedId, isNull);
    expect(selectedCategory.selectedCategoryId, 34);
    expect(selectedCategory.selectedTagId, isNull);
    expect(selectedCategory.unreadOnly, isTrue);
    expect(selectedCategory.starredOnly, isFalse);
    expect(selectedCategory.readLaterOnly, isFalse);
    expect(selectedCategory.searchQuery, '');
  });

  test('top-level sections keep their previous filter semantics', () {
    const filter = ArticleListFilter(
      scope: ArticleScope.tag(3),
      unreadOnly: true,
      searchQuery: 'needle',
    );

    final feeds = filter.enterFeedsSection();
    expect(feeds.scope, ArticleScope.all);
    expect(feeds.selectedFeedId, isNull);
    expect(feeds.selectedCategoryId, isNull);
    expect(feeds.selectedTagId, isNull);
    expect(feeds.unreadOnly, isTrue);
    expect(feeds.starredOnly, isFalse);
    expect(feeds.readLaterOnly, isFalse);
    expect(feeds.searchQuery, '');

    final search = filter.enterSearchSection();
    expect(search.selectedFeedId, isNull);
    expect(search.selectedCategoryId, isNull);
    expect(search.selectedTagId, isNull);
    expect(search.unreadOnly, isFalse);
    expect(search.starredOnly, isFalse);
    expect(search.readLaterOnly, isFalse);
    expect(search.searchQuery, 'needle');

    final saved = filter.selectReadLater();
    expect(saved.scope, ArticleScope.readLater);
    expect(saved.selectedFeedId, isNull);
    expect(saved.selectedCategoryId, isNull);
    expect(saved.selectedTagId, isNull);
    expect(saved.unreadOnly, isFalse);
    expect(saved.starredOnly, isFalse);
    expect(saved.readLaterOnly, isTrue);
    expect(saved.searchQuery, '');
  });

  test('saved scopes reset unread while browse scopes preserve it', () {
    const filter = ArticleListFilter(
      scope: ArticleScope.all,
      unreadOnly: true,
      searchQuery: 'needle',
    );

    final starred = filter.selectStarred();
    expect(starred.scope, ArticleScope.starred);
    expect(starred.unreadOnly, isFalse);
    expect(starred.searchQuery, '');

    final feed = filter.selectFeed(7);
    expect(feed.scope, const ArticleScope.feed(7));
    expect(feed.unreadOnly, isTrue);
    expect(feed.searchQuery, '');
  });

  test('section selection clears search content override', () {
    const filter = ArticleListFilter(
      scope: ArticleScope.starred,
      unreadOnly: true,
      searchQuery: 'needle',
      searchInContentOverride: false,
    );

    final next = filter.selectFeed(7);

    expect(next.scope, const ArticleScope.feed(7));
    expect(next.searchQuery, '');
    expect(next.searchInContentOverride, isNull);

    final saved = filter.selectReadLater();

    expect(saved.scope, ArticleScope.readLater);
    expect(saved.unreadOnly, isFalse);
    expect(saved.searchQuery, '');
    expect(saved.searchInContentOverride, isNull);
  });

  test(
    'search section preserves query and sets a page-local content override',
    () {
      const filter = ArticleListFilter(
        scope: ArticleScope.feed(7),
        unreadOnly: true,
        searchQuery: 'needle',
        searchInContentOverride: false,
      );

      final next = filter.enterSearchSection();

      expect(next.scope, ArticleScope.all);
      expect(next.unreadOnly, isFalse);
      expect(next.searchQuery, 'needle');
      expect(next.searchInContentOverride, isTrue);
    },
  );

  test('copyWith can clear search content override explicitly', () {
    const filter = ArticleListFilter(searchInContentOverride: false);

    final next = filter.copyWith(searchInContentOverride: null);

    expect(next.searchInContentOverride, isNull);
  });
}
