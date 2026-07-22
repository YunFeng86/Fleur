import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/subscriptions/subscriptions.dart';
import '../../models/category.dart';
import '../../models/feed.dart';
import '../../providers/query_providers.dart';
import '../../providers/service_providers.dart';
import 'sidebar_selection_actions.dart';

typedef SidebarDialogPresenter =
    Future<T?> Function<T>({required WidgetBuilder builder});

class SidebarManagementActions {
  const SidebarManagementActions({
    required BuildContext context,
    required WidgetRef ref,
    required SidebarSelectionActions selectionActions,
    required NavigatorState navigator,
    required SidebarDialogPresenter showDialogRoute,
    GoRouter? router,
  }) : _context = context,
       _ref = ref,
       _selectionActions = selectionActions,
       _navigator = navigator,
       _showDialogRoute = showDialogRoute,
       _router = router;

  final BuildContext _context;
  final WidgetRef _ref;
  final SidebarSelectionActions _selectionActions;
  final NavigatorState _navigator;
  final SidebarDialogPresenter _showDialogRoute;
  final GoRouter? _router;

  Future<T?> _showDialog<T>({required WidgetBuilder builder}) {
    return _showDialogRoute<T>(builder: builder);
  }

  Future<void> openSettings() async {
    final target = _router ?? GoRouter.maybeOf(_context);
    if (target == null) return;
    await target.push('/settings');
  }

  Future<int?> addFeed({int? initialCategoryId}) async {
    final id = await SubscriptionActions.addFeed(
      _context,
      _ref,
      navigator: _navigator,
      initialCategoryId: initialCategoryId,
    );
    if (id == null) return null;
    _selectionActions.selectFeed(id);
    return id;
  }

  Future<int?> addCategory() {
    return SubscriptionActions.addCategory(
      _context,
      _ref,
      dialogPresenter: _showDialog,
    );
  }

  Future<void> renameCategory(Category category) async {
    await SubscriptionActions.renameCategory(
      _context,
      _ref,
      categoryId: category.id,
      currentName: category.name,
      dialogPresenter: _showDialog,
    );
  }

  Future<void> deleteCategory(Category category) async {
    final deleted = await SubscriptionActions.deleteCategory(
      _context,
      _ref,
      categoryId: category.id,
      dialogPresenter: _showDialog,
    );
    if (!deleted || !_context.mounted) return;
    if (_ref.read(selectedCategoryIdProvider) == category.id) {
      _selectionActions.selectAll();
    }
  }

  Future<void> editFeedTitle(Feed feed) async {
    await SubscriptionActions.editFeedTitle(
      _context,
      _ref,
      feedId: feed.id,
      currentTitle: feed.userTitle,
      dialogPresenter: _showDialog,
    );
  }

  Future<void> refreshFeed(Feed feed) {
    return SubscriptionActions.refreshFeed(_context, _ref, feed.id);
  }

  Future<void> cacheFeedOffline(Feed feed) {
    return SubscriptionActions.cacheFeedOffline(_context, _ref, feed.id);
  }

  Future<void> moveFeedToCategory(Feed feed) async {
    await SubscriptionActions.moveFeedToCategory(
      _context,
      _ref,
      feedId: feed.id,
      dialogPresenter: _showDialog,
    );
  }

  Future<void> deleteFeed(Feed feed) async {
    final deleted = await SubscriptionActions.deleteFeed(
      _context,
      _ref,
      feedId: feed.id,
      dialogPresenter: _showDialog,
    );
    if (!deleted || !_context.mounted) return;
    if (_ref.read(selectedFeedIdProvider) == feed.id) {
      _selectionActions.selectAll();
    }
  }

  Future<void> refreshAll() {
    return SubscriptionActions.refreshAll(_context, _ref);
  }

  Future<void> markAllRead({int? feedId, int? categoryId}) {
    return _ref
        .read(articleActionServiceProvider)
        .markAllRead(
          feedId: feedId,
          categoryId: feedId == null ? categoryId : null,
        );
  }

  Future<void> importOpml() {
    return SubscriptionOpmlActions.importOpml(_context, _ref);
  }

  Future<void> exportOpml() {
    return SubscriptionOpmlActions.exportOpml(_context, _ref);
  }
}
