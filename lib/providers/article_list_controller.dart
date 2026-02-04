import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/article.dart';
import '../repositories/article_repository.dart';
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
  int? _feedId;
  int? _categoryId;
  int? _tagId;
  bool _unreadOnly = false;
  bool _starredOnly = false;
  bool _readLaterOnly = false;
  String _searchQuery = '';
  bool _sortAscending = false;
  bool _searchInContent = true;

  ArticleQuery _currentQuery() {
    return ArticleQuery(
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
  }

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
    await _sub?.cancel();
    final repo = ref.watch(articleRepositoryProvider);
    // 仅监听当前查询，避免全表刷新。
    final query = _currentQuery();
    _sub = repo.watchQueryChanges(query).listen((_) {
      unawaited(refresh());
    });
    ref.onDispose(() => _sub?.cancel());

    final items = await repo.fetchPage(query, offset: 0, limit: _pageSize);
    return ArticleListState(
      items: items,
      hasMore: items.length == _pageSize,
      nextOffset: items.length,
    );
  }

  Future<void> refresh() async {
    final repo = ref.read(articleRepositoryProvider);
    final query = _currentQuery();
    final items = await repo.fetchPage(query, offset: 0, limit: _pageSize);
    final current = state.valueOrNull;
    if (current == null) {
      state = AsyncValue.data(
        ArticleListState(
          items: items,
          hasMore: items.length == _pageSize,
          nextOffset: items.length,
        ),
      );
      return;
    }
    state = AsyncValue.data(
      current.copyWith(
        items: items,
        hasMore: items.length == _pageSize,
        startOffset: 0,
        nextOffset: items.length,
      ),
    );
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
      state = AsyncValue.error(e, st);
    }
  }
}

final articleListControllerProvider =
    AutoDisposeAsyncNotifierProvider<ArticleListController, ArticleListState>(
      ArticleListController.new,
    );
