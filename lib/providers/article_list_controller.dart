import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';
import 'repository_providers.dart';
import 'query_providers.dart';
import 'unread_providers.dart';
import 'app_settings_providers.dart';
import '../services/settings/app_settings.dart';

class ArticleListState {
  const ArticleListState({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  final List<Article> items;
  final bool hasMore;
  final bool isLoadingMore;

  ArticleListState copyWith({
    List<Article>? items,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return ArticleListState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class ArticleListController extends AutoDisposeAsyncNotifier<ArticleListState> {
  static const _pageSize = 50;

  StreamSubscription<void>? _sub;
  int? _feedId;
  int? _categoryId;
  int? _tagId;
  bool _unreadOnly = false;
  bool _starredOnly = false;
  bool _readLaterOnly = false;
  String _searchQuery = '';
  bool _sortAscending = false;
  bool _searchInContent = true;

  @override
  Future<ArticleListState> build() async {
    _feedId = ref.watch(selectedFeedIdProvider);
    _categoryId = ref.watch(selectedCategoryIdProvider);
    _tagId = ref.watch(selectedTagIdProvider);
    _unreadOnly = ref.watch(unreadOnlyProvider);
    _starredOnly = ref.watch(starredOnlyProvider);
    _readLaterOnly = ref.watch(readLaterOnlyProvider);
    _searchQuery = ref.watch(articleSearchQueryProvider);
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    _sortAscending =
        (settings?.articleSortOrder ?? ArticleSortOrder.newestFirst) ==
        ArticleSortOrder.oldestFirst;
    _searchInContent = settings?.searchInContent ?? true;

    // 查询结果变化时刷新列表（新增/过滤）。
    // 读/星标通过单条流更新，避免全量刷新。
    _sub?.cancel();
    final repo = ref.watch(articleRepositoryProvider);
    // Watch only the current query to avoid collection-wide refreshes.
    _sub = repo
        .watchQueryChanges(
          feedId: _feedId,
          categoryId: _categoryId,
          tagId: _tagId,
          unreadOnly: _unreadOnly,
          starredOnly: _starredOnly,
          readLaterOnly: _readLaterOnly,
          searchQuery: _searchQuery,
          sortAscending: _sortAscending,
          searchInContent: _searchInContent,
        )
        .listen((_) {
          unawaited(refresh());
        });
    ref.onDispose(() => _sub?.cancel());

    final items = await repo.fetchPage(
      offset: 0,
      limit: _pageSize,
      feedId: _feedId,
      categoryId: _categoryId,
      tagId: _tagId,
      unreadOnly: _unreadOnly,
      starredOnly: _starredOnly,
      readLaterOnly: _readLaterOnly,
      searchQuery: _searchQuery,
      sortAscending: _sortAscending,
      searchInContent: _searchInContent,
    );
    return ArticleListState(items: items, hasMore: items.length == _pageSize);
  }

  Future<void> refresh() async {
    final repo = ref.read(articleRepositoryProvider);
    final items = await repo.fetchPage(
      offset: 0,
      limit: _pageSize,
      feedId: _feedId,
      categoryId: _categoryId,
      tagId: _tagId,
      unreadOnly: _unreadOnly,
      starredOnly: _starredOnly,
      readLaterOnly: _readLaterOnly,
      searchQuery: _searchQuery,
      sortAscending: _sortAscending,
      searchInContent: _searchInContent,
    );
    final current = state.valueOrNull;
    if (current == null) {
      state = AsyncValue.data(
        ArticleListState(items: items, hasMore: items.length == _pageSize),
      );
      return;
    }
    state = AsyncValue.data(
      current.copyWith(items: items, hasMore: items.length == _pageSize),
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final repo = ref.read(articleRepositoryProvider);
      final more = await repo.fetchPage(
        offset: current.items.length,
        limit: _pageSize,
        feedId: _feedId,
        categoryId: _categoryId,
        tagId: _tagId,
        unreadOnly: _unreadOnly,
        starredOnly: _starredOnly,
        readLaterOnly: _readLaterOnly,
        searchQuery: _searchQuery,
        sortAscending: _sortAscending,
        searchInContent: _searchInContent,
      );
      state = AsyncValue.data(
        current.copyWith(
          items: [...current.items, ...more],
          hasMore: more.length == _pageSize,
          isLoadingMore: false,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final articleListControllerProvider =
    AutoDisposeAsyncNotifierProvider<ArticleListController, ArticleListState>(
      ArticleListController.new,
    );
