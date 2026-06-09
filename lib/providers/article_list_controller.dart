import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article_scope.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../services/logging/app_logger.dart';
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
    this.startOffset = 0,
    required this.nextOffset,
  });

  final List<Article> items;
  final bool hasMore;
  final bool isLoadingMore;
  final int startOffset;
  final int nextOffset;

  ArticleListState copyWith({
    List<Article>? items,
    bool? hasMore,
    bool? isLoadingMore,
    int? startOffset,
    int? nextOffset,
  }) {
    return ArticleListState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      startOffset: startOffset ?? this.startOffset,
      nextOffset: nextOffset ?? this.nextOffset,
    );
  }
}

class ArticleListController extends AutoDisposeAsyncNotifier<ArticleListState> {
  // Number of articles loaded per page (balances UX responsiveness and data transfer)
  static const _pageSize = 50;
  // Maximum articles kept in memory (prevents memory overflow on infinite scroll)
  static const _maxItems = 500;

  StreamSubscription<void>? _sub;
  ArticleScope _scope = ArticleScope.all;
  bool _unreadOnly = false;
  String _searchQuery = '';
  bool? _searchInContentOverride;
  bool _sortAscending = false;
  bool _searchInContent = true;
  bool _isMounted = false;

  ArticleQuery _currentQuery() {
    return ArticleQuery(
      feedId: _scope.feedId,
      categoryId: _scope.categoryId,
      tagId: _scope.tagId,
      unreadOnly: _unreadOnly,
      starredOnly: _scope.starredOnly,
      readLaterOnly: _scope.readLaterOnly,
      searchQuery: _searchQuery,
      sortAscending: _sortAscending,
      searchInContent: _searchInContent,
    );
  }

  @override
  Future<ArticleListState> build() async {
    _isMounted = true;
    _scope = ref.watch(currentArticleScopeProvider);
    _unreadOnly = ref.watch(unreadOnlyProvider);
    _searchQuery = ref.watch(articleSearchQueryProvider);
    _searchInContentOverride = ref.watch(
      articleListFilterProvider.select(
        (filter) => filter.searchInContentOverride,
      ),
    );
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    _sortAscending =
        (settings?.articleSortOrder ?? ArticleSortOrder.newestFirst) ==
        ArticleSortOrder.oldestFirst;
    _searchInContent =
        _searchInContentOverride ?? settings?.searchInContent ?? true;

    // 查询结果变化时刷新列表（新增/过滤）。
    // 读/星标通过单条流更新，避免全量刷新。
    await _sub?.cancel();
    final repo = ref.watch(articleRepositoryProvider);
    // 仅监听当前查询，避免全表刷新。
    final query = _currentQuery();
    _sub = repo.watchQueryChanges(query).listen((_) {
      if (!_isMounted) return;
      unawaited(refresh());
    });
    ref.onDispose(() {
      _isMounted = false;
      final sub = _sub;
      if (sub != null) {
        unawaited(sub.cancel());
      }
    });

    final items = await repo.fetchPage(query, offset: 0, limit: _pageSize);
    return ArticleListState(
      items: items,
      hasMore: items.length == _pageSize,
      nextOffset: items.length,
    );
  }

  Future<void> refresh() async {
    if (!_isMounted) return;
    final repo = ref.read(articleRepositoryProvider);
    final selectedArticleId = ref.read(activeArticleListSelectionProvider);
    final query = _currentQuery();
    final current = state.valueOrNull;
    if (current == null) {
      final ids = await repo.fetchPageIds(query, offset: 0, limit: _pageSize);
      if (!_isMounted) return;
      final hasMore = ids.length == _pageSize;
      final items = await repo.fetchPage(query, offset: 0, limit: _pageSize);
      if (!_isMounted) return;
      state = AsyncValue.data(
        ArticleListState(
          items: items,
          hasMore: hasMore,
          nextOffset: items.length,
        ),
      );
      return;
    }

    var offset = current.startOffset;
    var limit = current.nextOffset - current.startOffset;
    if (limit <= 0) {
      limit = current.items.isEmpty ? _pageSize : current.items.length;
    }
    var ids = await repo.fetchPageIds(query, offset: offset, limit: limit + 1);
    if (!_isMounted) return;
    var hasMore = ids.length > limit;
    var windowIds = hasMore ? ids.sublist(0, limit) : ids;

    if (offset > 0 && windowIds.isEmpty) {
      offset = 0;
      limit = _pageSize;
      ids = await repo.fetchPageIds(query, offset: offset, limit: limit + 1);
      if (!_isMounted) return;
      hasMore = ids.length > limit;
      windowIds = hasMore ? ids.sublist(0, limit) : ids;
    }

    final retainedWindow = _retainSelectedArticleInUnreadWindow(
      query: query,
      currentItems: current.items,
      windowIds: windowIds,
      selectedArticleId: selectedArticleId,
    );
    final displayIds = retainedWindow.ids;
    final nextOffset = offset + windowIds.length;
    if (_sameIds(current.items, displayIds)) {
      if (current.hasMore == hasMore &&
          current.nextOffset == nextOffset &&
          current.startOffset == offset &&
          !current.isLoadingMore) {
        return;
      }
      if (!_isMounted) return;
      state = AsyncValue.data(
        current.copyWith(
          hasMore: hasMore,
          isLoadingMore: false,
          startOffset: offset,
          nextOffset: nextOffset,
        ),
      );
      return;
    }
    final queryItems = windowIds.isEmpty
        ? const <Article>[]
        : await repo.fetchPage(query, offset: offset, limit: windowIds.length);
    if (!_isMounted) return;
    final items = retainedWindow.apply(queryItems);
    state = AsyncValue.data(
      current.copyWith(
        items: items,
        hasMore: hasMore,
        isLoadingMore: false,
        startOffset: offset,
        nextOffset: nextOffset,
      ),
    );
  }

  _RetainedArticleWindow _retainSelectedArticleInUnreadWindow({
    required ArticleQuery query,
    required List<Article> currentItems,
    required List<int> windowIds,
    required int? selectedArticleId,
  }) {
    if (!query.unreadOnly ||
        selectedArticleId == null ||
        windowIds.contains(selectedArticleId)) {
      return _RetainedArticleWindow(windowIds);
    }

    final previousIndex = currentItems.indexWhere(
      (article) => article.id == selectedArticleId,
    );
    if (previousIndex < 0) return _RetainedArticleWindow(windowIds);

    final ids = windowIds.toList();
    final insertIndex = previousIndex.clamp(0, ids.length).toInt();
    ids.insert(insertIndex, selectedArticleId);
    return _RetainedArticleWindow(
      ids,
      retainedArticle: currentItems[previousIndex],
      retainedIndex: insertIndex,
    );
  }

  bool _sameIds(List<Article> items, List<int> ids) {
    if (items.length != ids.length) return false;
    for (var i = 0; i < ids.length; i++) {
      if (items[i].id != ids[i]) return false;
    }
    return true;
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final repo = ref.read(articleRepositoryProvider);
      final query = _currentQuery();
      final more = await repo.fetchPage(
        query,
        offset: current.nextOffset,
        limit: _pageSize,
      );
      final nextOffset = current.nextOffset + more.length;
      var merged = [...current.items, ...more];
      var startOffset = current.startOffset;
      if (merged.length > _maxItems) {
        final drop = merged.length - _maxItems;
        // 只保留最近加载的窗口，避免列表无限增长占内存。
        merged = merged.sublist(drop);
        startOffset += drop;
      }
      state = AsyncValue.data(
        current.copyWith(
          items: merged,
          hasMore: more.length == _pageSize,
          isLoadingMore: false,
          startOffset: startOffset,
          nextOffset: nextOffset,
        ),
      );
    } catch (e, st) {
      AppLogger.w(
        'Article list load more failed',
        tag: 'article_list',
        error: e,
        stackTrace: st,
        context: <String, Object?>{
          'operation': 'loadMore',
          'scope': _scope.toString(),
          'unreadOnly': _unreadOnly,
          'sortAscending': _sortAscending,
          'searchInContent': _searchInContent,
          'offset': current.nextOffset,
          'limit': _pageSize,
          'searchQueryLength': _searchQuery.length,
        },
      );
      state = AsyncValue.error(e, st);
    }
  }
}

final articleListControllerProvider =
    AutoDisposeAsyncNotifierProvider<ArticleListController, ArticleListState>(
      ArticleListController.new,
      dependencies: [articleRepositoryProvider],
    );

class _RetainedArticleWindow {
  const _RetainedArticleWindow(
    this.ids, {
    this.retainedArticle,
    this.retainedIndex,
  });

  final List<int> ids;
  final Article? retainedArticle;
  final int? retainedIndex;

  List<Article> apply(List<Article> queryItems) {
    final article = retainedArticle;
    final index = retainedIndex;
    if (article == null || index == null) return queryItems;
    if (queryItems.any((item) => item.id == article.id)) return queryItems;
    final items = queryItems.toList();
    items.insert(index.clamp(0, items.length).toInt(), article);
    return items;
  }
}
