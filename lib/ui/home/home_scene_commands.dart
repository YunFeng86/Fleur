import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/article_list_controller.dart';
import '../../providers/backend_capabilities_provider.dart';
import '../../providers/backend_sync_semantics_provider.dart';
import '../../providers/query_providers.dart';
import '../../providers/refresh_all_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/service_providers.dart';
import '../../services/sync/backend_capabilities.dart';
import '../../services/sync/refresh_all_coordinator.dart';
import '../../services/sync/sync_service.dart';
import '../actions/root_sync_action.dart';

class HomeSceneCommands {
  const HomeSceneCommands({
    required BuildContext context,
    required WidgetRef ref,
    required this.selectedArticleId,
  }) : _context = context,
       _ref = ref;

  final BuildContext _context;
  final WidgetRef _ref;
  final int? selectedArticleId;

  Future<BatchRefreshResult> refreshAll() async {
    final syncSemantics = _ref.read(backendSyncSemanticsProvider);
    final capabilities = _ref.read(backendCapabilitiesProvider);
    if (syncSemantics.isAccountWideRefresh) {
      final mode = resolveSubscriptionRootSyncMode(capabilities);
      switch (mode) {
        case SubscriptionRootSyncMode.refreshSources:
          final result = await _ref
              .read(refreshSourcesCoordinatorProvider)
              .refreshSources(trigger: RefreshSourcesTrigger.manual);
          return result.batch;
        case SubscriptionRootSyncMode.syncAccount:
          final result = await _ref
              .read(accountSyncCoordinatorProvider)
              .syncAccount(trigger: AccountSyncTrigger.manual);
          return result.batch;
        case null:
          return const BatchRefreshResult([]);
      }
    }

    final feedId = _ref.read(selectedFeedIdProvider);
    final categoryId = _ref.read(selectedCategoryIdProvider);
    if (feedId != null &&
        capabilities.isVisible(BackendFeature.refreshSubscriptionSource)) {
      final result = await _ref
          .read(syncServiceProvider)
          .refreshFeedSafe(feedId);
      return BatchRefreshResult([result]);
    }
    if (feedId != null) {
      return _ref.read(syncServiceProvider).refreshFeedsSafe([feedId]);
    }

    if (categoryId == null) {
      final result = await _ref
          .read(refreshSourcesCoordinatorProvider)
          .refreshSources(trigger: RefreshSourcesTrigger.manual);
      return result.batch;
    }

    final feeds = await _ref.read(feedRepositoryProvider).getAll();
    final filtered = feeds.where((feed) => feed.categoryId == categoryId);
    return _ref
        .read(syncServiceProvider)
        .refreshFeedsSafe(filtered.map((feed) => feed.id));
  }

  Future<void> markAllRead() async {
    final selectedFeedId = _ref.read(selectedFeedIdProvider);
    final selectedCategoryId = _ref.read(selectedCategoryIdProvider);
    await _ref
        .read(articleActionServiceProvider)
        .markAllRead(
          feedId: selectedFeedId,
          categoryId: selectedFeedId == null ? selectedCategoryId : null,
        );
  }

  void toggleUnreadOnly() {
    _ref
        .read(articleListFilterProvider.notifier)
        .update((filter) => filter.toggleUnreadOnly());
  }

  Future<void> toggleSelectedArticleRead() async {
    final articleId = selectedArticleId;
    if (articleId == null) return;

    final article = await _ref
        .read(articleRepositoryProvider)
        .getById(articleId);
    if (article == null) return;

    await _ref
        .read(articleActionServiceProvider)
        .markRead(articleId, !article.isRead);
  }

  Future<void> toggleSelectedArticleStar() async {
    final articleId = selectedArticleId;
    if (articleId == null) return;
    await _ref.read(articleActionServiceProvider).toggleStar(articleId);
  }

  void goToSearch() {
    _context.go('/search');
  }

  void goToNextArticle() {
    final items = _ref.read(articleListControllerProvider).valueOrNull?.items;
    if (items == null || items.isEmpty) return;

    final currentIndex = selectedArticleId == null
        ? -1
        : items.indexWhere((article) => article.id == selectedArticleId);
    final targetIndex = currentIndex < 0
        ? 0
        : (currentIndex + 1 >= items.length
              ? items.length - 1
              : currentIndex + 1);
    _context.go('/article/${items[targetIndex].id}');
  }

  void goToPreviousArticle() {
    final items = _ref.read(articleListControllerProvider).valueOrNull?.items;
    if (items == null || items.isEmpty) return;

    final currentIndex = selectedArticleId == null
        ? 0
        : items.indexWhere((article) => article.id == selectedArticleId);
    final targetIndex = currentIndex <= 0 ? 0 : currentIndex - 1;
    _context.go('/article/${items[targetIndex].id}');
  }
}
