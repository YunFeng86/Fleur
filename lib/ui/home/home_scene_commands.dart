import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/article_scope_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/article_list_controller.dart';
import '../../providers/app_settings_providers.dart';
import '../../providers/backend_capabilities_provider.dart';
import '../../providers/backend_sync_semantics_provider.dart';
import '../../providers/query_providers.dart';
import '../../providers/refresh_all_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/service_providers.dart';
import '../../services/sync/backend_capabilities.dart';
import '../../services/sync/backend_sync_semantics.dart';
import '../../services/sync/refresh_all_coordinator.dart';
import '../../services/sync/sync_service.dart';
import '../../utils/platform.dart';
import '../layout.dart';
import '../layout_spec.dart';

enum HomeRefreshIntent {
  refreshFeed,
  refreshCategory,
  refreshSources,
  refreshFeedAndSync,
  refreshCategoryAndSync,
  refreshSourcesAndSync,
  syncAccount;

  String label(AppLocalizations l10n) {
    return switch (this) {
      HomeRefreshIntent.refreshFeed => l10n.refreshFeed,
      HomeRefreshIntent.refreshCategory => l10n.refreshCategory,
      HomeRefreshIntent.refreshSources => l10n.refreshAll,
      HomeRefreshIntent.refreshFeedAndSync => l10n.refreshFeedAndSync,
      HomeRefreshIntent.refreshCategoryAndSync => l10n.refreshCategoryAndSync,
      HomeRefreshIntent.refreshSourcesAndSync => l10n.refreshSourcesAndSync,
      HomeRefreshIntent.syncAccount => l10n.syncAccount,
    };
  }
}

enum HomeRefreshSuccessFeedback {
  refreshed,
  refreshedAll,
  refreshedAndSynced,
  syncedAccount,
}

HomeRefreshIntent resolveHomeRefreshIntent({
  required BackendCapabilities capabilities,
  required BackendSyncSemantics syncSemantics,
  required int? selectedFeedId,
  required int? selectedCategoryId,
}) {
  final refreshesSources = capabilities.isVisible(
    BackendFeature.refreshAllSources,
  );
  final syncsAccount =
      capabilities.isVisible(BackendFeature.syncNow) &&
      syncSemantics.isAccountWideRefresh;

  if (!refreshesSources && syncsAccount) {
    return HomeRefreshIntent.syncAccount;
  }

  if (capabilities.refreshesRemoteSourcesUpstream && syncsAccount) {
    if (selectedFeedId != null) return HomeRefreshIntent.refreshFeedAndSync;
    if (selectedCategoryId != null) {
      return HomeRefreshIntent.refreshCategoryAndSync;
    }
    return HomeRefreshIntent.refreshSourcesAndSync;
  }

  if (selectedFeedId != null) return HomeRefreshIntent.refreshFeed;
  if (selectedCategoryId != null) return HomeRefreshIntent.refreshCategory;
  return HomeRefreshIntent.refreshSources;
}

class HomeRefreshOutcome {
  const HomeRefreshOutcome({
    required this.batch,
    required this.successFeedback,
  });

  final BatchRefreshResult batch;
  final HomeRefreshSuccessFeedback successFeedback;

  String successLabel(AppLocalizations l10n) {
    return switch (successFeedback) {
      HomeRefreshSuccessFeedback.refreshed => l10n.refreshed,
      HomeRefreshSuccessFeedback.refreshedAll => l10n.refreshedAll,
      HomeRefreshSuccessFeedback.refreshedAndSynced => l10n.refreshedAndSynced,
      HomeRefreshSuccessFeedback.syncedAccount => l10n.syncedAccount,
    };
  }
}

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

  Future<HomeRefreshOutcome> refreshAll() async {
    final capabilities = _ref.read(backendCapabilitiesProvider);
    final syncSemantics = _ref.read(backendSyncSemanticsProvider);
    final appSettings = _ref.read(appSettingsProvider).valueOrNull;
    final maxConcurrent = appSettings?.autoRefreshConcurrency ?? 2;
    final feedId = _ref.read(selectedFeedIdProvider);
    final categoryId = _ref.read(selectedCategoryIdProvider);
    final scope = _scopeForSelection(
      selectedFeedId: feedId,
      selectedCategoryId: categoryId,
    );
    final result = await _ref
        .read(scopedRefreshCoordinatorProvider)
        .refreshScope(scope: scope, maxConcurrent: maxConcurrent);
    return HomeRefreshOutcome(
      batch: result.batch,
      successFeedback: _successFeedbackForScope(
        scope,
        capabilities: capabilities,
        syncSemantics: syncSemantics,
      ),
    );
  }

  RefreshScope _scopeForSelection({
    required int? selectedFeedId,
    required int? selectedCategoryId,
  }) {
    if (selectedFeedId != null) return FeedRefreshScope(selectedFeedId);
    if (selectedCategoryId != null) {
      return CategoryRefreshScope(selectedCategoryId);
    }
    return const AllRefreshScope();
  }

  HomeRefreshSuccessFeedback _successFeedbackForScope(
    RefreshScope scope, {
    required BackendCapabilities capabilities,
    required BackendSyncSemantics syncSemantics,
  }) {
    if (!capabilities.isVisible(BackendFeature.refreshAllSources) &&
        capabilities.isVisible(BackendFeature.syncNow) &&
        syncSemantics.isAccountWideRefresh) {
      return HomeRefreshSuccessFeedback.syncedAccount;
    }
    if (scope is FeedRefreshScope || scope is CategoryRefreshScope) {
      return HomeRefreshSuccessFeedback.refreshed;
    }
    if (capabilities.refreshesRemoteSourcesUpstream &&
        capabilities.isVisible(BackendFeature.syncNow) &&
        syncSemantics.isAccountWideRefresh) {
      return HomeRefreshSuccessFeedback.refreshedAndSynced;
    }
    return HomeRefreshSuccessFeedback.refreshedAll;
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

  void _goToArticle(int articleId) {
    final scope = _ref.read(currentArticleScopeProvider);
    final location = scopedArticleLocation(scope, articleId);
    final spec = LayoutSpec.fromContext(_context);
    final listWidth = isDesktop ? spec.listWidth : kHomeListWidth;
    final openAsSecondaryPage = isDesktop
        ? !spec.desktopEmbedsReader
        : !spec.canEmbedReader(listWidth: listWidth);

    if (!openAsSecondaryPage) {
      _context.go(location);
      return;
    }

    if (selectedArticleId == null) {
      unawaited(_context.push<void>(location));
      return;
    }
    _context.replace(location);
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
    _goToArticle(items[targetIndex].id);
  }

  void goToPreviousArticle() {
    final items = _ref.read(articleListControllerProvider).valueOrNull?.items;
    if (items == null || items.isEmpty) return;

    final currentIndex = selectedArticleId == null
        ? 0
        : items.indexWhere((article) => article.id == selectedArticleId);
    final targetIndex = currentIndex <= 0 ? 0 : currentIndex - 1;
    _goToArticle(items[targetIndex].id);
  }
}
