import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/providers/query_providers.dart';

void main() {
  test('selecting browse targets clears saved filters and search', () {
    const filter = ArticleListFilter(
      unreadOnly: true,
      starredOnly: true,
      readLaterOnly: true,
      searchQuery: 'needle',
    );

    final selectedFeed = filter.selectFeed(12);
    expect(selectedFeed.selectedFeedId, 12);
    expect(selectedFeed.selectedCategoryId, isNull);
    expect(selectedFeed.selectedTagId, isNull);
    expect(selectedFeed.unreadOnly, isTrue);
    expect(selectedFeed.starredOnly, isFalse);
    expect(selectedFeed.readLaterOnly, isFalse);
    expect(selectedFeed.searchQuery, '');

    final selectedCategory = filter.selectCategory(34);
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
      selectedFeedId: 1,
      selectedCategoryId: 2,
      selectedTagId: 3,
      unreadOnly: true,
      starredOnly: true,
      readLaterOnly: true,
      searchQuery: 'needle',
    );

    final feeds = filter.enterFeedsSection();
    expect(feeds.selectedFeedId, 1);
    expect(feeds.selectedCategoryId, 2);
    expect(feeds.selectedTagId, 3);
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

    final saved = filter.savedOnly(starred: false);
    expect(saved.selectedFeedId, isNull);
    expect(saved.selectedCategoryId, isNull);
    expect(saved.selectedTagId, isNull);
    expect(saved.unreadOnly, isFalse);
    expect(saved.starredOnly, isFalse);
    expect(saved.readLaterOnly, isTrue);
    expect(saved.searchQuery, '');
  });
}
