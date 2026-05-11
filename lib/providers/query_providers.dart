import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';
import '../models/category.dart';
import '../models/feed.dart';
import '../models/tag.dart';
import 'repository_providers.dart';

final feedsProvider = StreamProvider<List<Feed>>((ref) {
  return ref.watch(feedRepositoryProvider).watchAll();
}, dependencies: [feedRepositoryProvider]);

final feedProvider = StreamProvider.family<Feed?, int>((ref, id) {
  return ref.watch(feedRepositoryProvider).watchById(id);
}, dependencies: [feedRepositoryProvider]);

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAll();
}, dependencies: [categoryRepositoryProvider]);

final categoryProvider = StreamProvider.family<Category?, int>((ref, id) {
  return ref.watch(categoryRepositoryProvider).watchById(id);
}, dependencies: [categoryRepositoryProvider]);

final tagsProvider = StreamProvider<List<Tag>>((ref) {
  return ref.watch(tagRepositoryProvider).watchAll();
}, dependencies: [tagRepositoryProvider]);

const _unchanged = Object();

class ArticleListFilter {
  const ArticleListFilter({
    this.selectedFeedId,
    this.selectedCategoryId,
    this.selectedTagId,
    this.unreadOnly = false,
    this.starredOnly = false,
    this.readLaterOnly = false,
    this.searchQuery = '',
  });

  final int? selectedFeedId;
  final int? selectedCategoryId;
  final int? selectedTagId;
  final bool unreadOnly;
  final bool starredOnly;
  final bool readLaterOnly;
  final String searchQuery;

  ArticleListFilter copyWith({
    Object? selectedFeedId = _unchanged,
    Object? selectedCategoryId = _unchanged,
    Object? selectedTagId = _unchanged,
    bool? unreadOnly,
    bool? starredOnly,
    bool? readLaterOnly,
    String? searchQuery,
  }) {
    return ArticleListFilter(
      selectedFeedId: identical(selectedFeedId, _unchanged)
          ? this.selectedFeedId
          : selectedFeedId as int?,
      selectedCategoryId: identical(selectedCategoryId, _unchanged)
          ? this.selectedCategoryId
          : selectedCategoryId as int?,
      selectedTagId: identical(selectedTagId, _unchanged)
          ? this.selectedTagId
          : selectedTagId as int?,
      unreadOnly: unreadOnly ?? this.unreadOnly,
      starredOnly: starredOnly ?? this.starredOnly,
      readLaterOnly: readLaterOnly ?? this.readLaterOnly,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  ArticleListFilter clearBrowseFilters() {
    return copyWith(starredOnly: false, readLaterOnly: false, searchQuery: '');
  }

  ArticleListFilter selectAll() {
    return clearBrowseFilters().copyWith(
      selectedFeedId: null,
      selectedCategoryId: null,
      selectedTagId: null,
    );
  }

  ArticleListFilter selectFeed(int feedId) {
    return clearBrowseFilters().copyWith(
      selectedFeedId: feedId,
      selectedCategoryId: null,
      selectedTagId: null,
    );
  }

  ArticleListFilter selectCategory(int categoryId) {
    return clearBrowseFilters().copyWith(
      selectedFeedId: null,
      selectedCategoryId: categoryId,
      selectedTagId: null,
    );
  }

  ArticleListFilter selectTag(int tagId) {
    return clearBrowseFilters().copyWith(
      selectedFeedId: null,
      selectedCategoryId: null,
      selectedTagId: tagId,
    );
  }

  ArticleListFilter enterFeedsSection() {
    return clearBrowseFilters();
  }

  ArticleListFilter enterSearchSection() {
    return copyWith(
      selectedFeedId: null,
      selectedCategoryId: null,
      selectedTagId: null,
      unreadOnly: false,
      starredOnly: false,
      readLaterOnly: false,
    );
  }

  ArticleListFilter savedOnly({required bool starred}) {
    return copyWith(
      selectedFeedId: null,
      selectedCategoryId: null,
      selectedTagId: null,
      unreadOnly: false,
      starredOnly: starred,
      readLaterOnly: !starred,
      searchQuery: '',
    );
  }

  ArticleListFilter toggleUnreadOnly() {
    return copyWith(unreadOnly: !unreadOnly);
  }
}

final articleListFilterProvider = StateProvider<ArticleListFilter>(
  (ref) => const ArticleListFilter(),
);

final selectedFeedIdProvider = Provider<int?>((ref) {
  return ref.watch(
    articleListFilterProvider.select((filter) => filter.selectedFeedId),
  );
});

final selectedCategoryIdProvider = Provider<int?>((ref) {
  return ref.watch(
    articleListFilterProvider.select((filter) => filter.selectedCategoryId),
  );
});

final selectedTagIdProvider = Provider<int?>((ref) {
  return ref.watch(
    articleListFilterProvider.select((filter) => filter.selectedTagId),
  );
});

final starredOnlyProvider = Provider<bool>((ref) {
  return ref.watch(
    articleListFilterProvider.select((filter) => filter.starredOnly),
  );
});

final readLaterOnlyProvider = Provider<bool>((ref) {
  return ref.watch(
    articleListFilterProvider.select((filter) => filter.readLaterOnly),
  );
});

final articleSearchQueryProvider = Provider<String>((ref) {
  return ref.watch(
    articleListFilterProvider.select((filter) => filter.searchQuery),
  );
});

final articlesProvider = StreamProvider.family<List<Article>, int?>((
  ref,
  feedId,
) {
  return ref.watch(articleRepositoryProvider).watchLatest(feedId: feedId);
}, dependencies: [articleRepositoryProvider]);

final articleProvider = StreamProvider.family<Article?, int>((ref, id) {
  return ref.watch(articleRepositoryProvider).watchById(id);
}, dependencies: [articleRepositoryProvider]);

/// Watches the tags linked to an article, loading IsarLinks asynchronously.
///
/// Note: `watchObject` does not automatically load links, so the UI should use
/// this provider instead of calling `loadSync()` in the widget tree.
final articleTagsProvider = StreamProvider.autoDispose.family<List<Tag>, int>((
  ref,
  articleId,
) {
  var disposed = false;
  ref.onDispose(() => disposed = true);

  final repo = ref.watch(articleRepositoryProvider);
  return repo.watchById(articleId).asyncMap((a) async {
    if (a == null) return const <Tag>[];
    if (!a.tags.isLoaded) {
      try {
        await a.tags.load();
      } catch (_) {
        if (disposed) return const <Tag>[];
        rethrow;
      }
    }
    if (disposed) return const <Tag>[];
    return a.tags.toList(growable: false);
  });
}, dependencies: [articleRepositoryProvider]);

final feedMapProvider = Provider<Map<int, Feed>>((ref) {
  final feeds = ref.watch(feedsProvider).valueOrNull ?? [];
  return {for (final feed in feeds) feed.id: feed};
}, dependencies: [feedsProvider]);
