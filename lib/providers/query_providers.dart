import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';
import '../models/article_scope.dart';
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
    this.scope = ArticleScope.all,
    this.unreadOnly = false,
    this.searchQuery = '',
    this.searchInContentOverride,
  });

  final ArticleScope scope;
  final bool unreadOnly;
  final String searchQuery;
  final bool? searchInContentOverride;

  int? get selectedFeedId => scope.feedId;
  int? get selectedCategoryId => scope.categoryId;
  int? get selectedTagId => scope.tagId;
  bool get starredOnly => scope.starredOnly;
  bool get readLaterOnly => scope.readLaterOnly;

  ArticleListFilter copyWith({
    Object? scope = _unchanged,
    bool? unreadOnly,
    String? searchQuery,
    Object? searchInContentOverride = _unchanged,
  }) {
    return ArticleListFilter(
      scope: identical(scope, _unchanged) ? this.scope : scope as ArticleScope,
      unreadOnly: unreadOnly ?? this.unreadOnly,
      searchQuery: searchQuery ?? this.searchQuery,
      searchInContentOverride: identical(searchInContentOverride, _unchanged)
          ? this.searchInContentOverride
          : searchInContentOverride as bool?,
    );
  }

  ArticleListFilter clearBrowseFilters() {
    return copyWith(searchQuery: '', searchInContentOverride: null);
  }

  ArticleListFilter selectScope(ArticleScope scope) {
    if (scope.isSavedScope) {
      return clearBrowseFilters().copyWith(scope: scope, unreadOnly: false);
    }
    return clearBrowseFilters().copyWith(scope: scope);
  }

  ArticleListFilter selectAll() {
    return selectScope(ArticleScope.all);
  }

  ArticleListFilter selectFeed(int feedId) {
    return selectScope(ArticleScope.feed(feedId));
  }

  ArticleListFilter selectCategory(int categoryId) {
    return selectScope(ArticleScope.category(categoryId));
  }

  ArticleListFilter selectTag(int tagId) {
    return selectScope(ArticleScope.tag(tagId));
  }

  ArticleListFilter selectStarred() {
    return selectScope(ArticleScope.starred);
  }

  ArticleListFilter selectReadLater() {
    return selectScope(ArticleScope.readLater);
  }

  ArticleListFilter enterFeedsSection() {
    return selectAll();
  }

  ArticleListFilter enterSearchSection() {
    return copyWith(
      scope: ArticleScope.all,
      unreadOnly: false,
      searchInContentOverride: true,
    );
  }

  ArticleListFilter savedOnly({required bool starred}) {
    return selectScope(starred ? ArticleScope.starred : ArticleScope.readLater);
  }

  ArticleListFilter toggleUnreadOnly() {
    return copyWith(unreadOnly: !unreadOnly);
  }
}

final articleListFilterProvider = StateProvider<ArticleListFilter>(
  (ref) => const ArticleListFilter(),
);

final activeArticleListSelectionProvider = StateProvider<int?>((ref) => null);

final currentArticleScopeProvider = Provider<ArticleScope>((ref) {
  return ref.watch(articleListFilterProvider.select((filter) => filter.scope));
});

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
