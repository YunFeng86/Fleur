import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/article_scope.dart';
import '../../providers/query_providers.dart';

typedef SidebarScopeSelectionCallback = void Function(ArticleScope scope);

class SidebarSelectionActions {
  const SidebarSelectionActions({
    required WidgetRef ref,
    required SidebarScopeSelectionCallback onSelectScope,
    required VoidCallback closeSidebar,
  }) : _ref = ref,
       _onSelectScope = onSelectScope,
       _closeSidebar = closeSidebar;

  final WidgetRef _ref;
  final SidebarScopeSelectionCallback _onSelectScope;
  final VoidCallback _closeSidebar;

  void _updateFilter(ArticleListFilter Function(ArticleListFilter) update) {
    _ref.read(articleListFilterProvider.notifier).update(update);
  }

  void _selectScope(ArticleScope scope) {
    final next = _ref.read(currentArticleScopeProvider) == scope
        ? ArticleScope.all
        : scope;
    _updateFilter((filter) => filter.selectScope(next));
    _onSelectScope(next);
    _closeSidebar();
  }

  void selectFeed(int feedId) {
    _selectScope(ArticleScope.feed(feedId));
  }

  void selectAll() {
    _updateFilter((filter) => filter.selectAll());
    _onSelectScope(ArticleScope.all);
    _closeSidebar();
  }

  void selectStarred() {
    _selectScope(ArticleScope.starred);
  }

  void selectReadLater() {
    _selectScope(ArticleScope.readLater);
  }

  void selectCategory(int categoryId) {
    _selectScope(ArticleScope.category(categoryId));
  }

  void selectTag(int tagId) {
    _selectScope(ArticleScope.tag(tagId));
  }
}
