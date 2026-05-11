import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/query_providers.dart';

typedef SidebarFeedSelectionCallback = void Function(int? feedId);

class SidebarSelectionActions {
  const SidebarSelectionActions({
    required WidgetRef ref,
    required SidebarFeedSelectionCallback onSelectFeed,
    required VoidCallback closeSidebar,
  }) : _ref = ref,
       _onSelectFeed = onSelectFeed,
       _closeSidebar = closeSidebar;

  final WidgetRef _ref;
  final SidebarFeedSelectionCallback _onSelectFeed;
  final VoidCallback _closeSidebar;

  void _updateFilter(ArticleListFilter Function(ArticleListFilter) update) {
    _ref.read(articleListFilterProvider.notifier).update(update);
  }

  void selectFeed(int feedId) {
    if (_ref.read(selectedFeedIdProvider) == feedId) {
      selectAll();
      return;
    }

    _updateFilter((filter) => filter.selectFeed(feedId));
    _onSelectFeed(feedId);
    _closeSidebar();
  }

  void selectAll() {
    _updateFilter((filter) => filter.selectAll());
    _onSelectFeed(null);
    _closeSidebar();
  }

  void selectCategory(int categoryId) {
    if (_ref.read(selectedCategoryIdProvider) == categoryId) {
      selectAll();
      return;
    }

    _updateFilter((filter) => filter.selectCategory(categoryId));
    _onSelectFeed(null);
    _closeSidebar();
  }

  void selectTag(int tagId) {
    if (_ref.read(selectedTagIdProvider) == tagId) {
      selectAll();
      return;
    }

    _updateFilter((filter) => filter.selectTag(tagId));
    _onSelectFeed(null);
    _closeSidebar();
  }
}
