import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/article_scope_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../models/feed.dart';
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
    final intent = resolveHomeRefreshIntent(
      capabilities: capabilities,
      syncSemantics: syncSemantics,
      selectedFeedId: feedId,
      selectedCategoryId: categoryId,
    );

    return switch (intent) {
      HomeRefreshIntent.refreshFeed => _refreshFeed(
        capabilities: capabilities,
        feedId: feedId!,
        maxConcurrent: maxConcurrent,
      ),
      HomeRefreshIntent.refreshCategory => _refreshCategory(
        categoryId: categoryId!,
        maxConcurrent: maxConcurrent,
      ),
      HomeRefreshIntent.refreshSources => _refreshSources(
        maxConcurrent: maxConcurrent,
        successFeedback: HomeRefreshSuccessFeedback.refreshedAll,
      ),
      HomeRefreshIntent.refreshFeedAndSync => _refreshRemoteFeedAndSync(
        feedId: feedId!,
        maxConcurrent: maxConcurrent,
      ),
      HomeRefreshIntent.refreshCategoryAndSync => _refreshRemoteCategoryAndSync(
        categoryId: categoryId!,
        maxConcurrent: maxConcurrent,
      ),
      HomeRefreshIntent.refreshSourcesAndSync => _refreshSources(
        maxConcurrent: maxConcurrent,
        successFeedback: HomeRefreshSuccessFeedback.refreshedAndSynced,
      ),
      HomeRefreshIntent.syncAccount => _syncAccount(
        maxConcurrent: maxConcurrent,
      ),
    };
  }

  Future<HomeRefreshOutcome> _refreshFeed({
    required BackendCapabilities capabilities,
    required int feedId,
    required int maxConcurrent,
  }) async {
    final feed = await _ref.read(feedRepositoryProvider).getById(feedId);
    if (feed == null) return _feedNotFound(feedId);

    if (capabilities.isVisible(BackendFeature.refreshSubscriptionSource)) {
      final result = await _ref
          .read(syncServiceProvider)
          .refreshFeedSafe(feed.id);
      return HomeRefreshOutcome(
        batch: BatchRefreshResult([result]),
        successFeedback: HomeRefreshSuccessFeedback.refreshed,
      );
    }

    final batch = await _ref.read(syncServiceProvider).refreshFeedsSafe([
      feed.id,
    ], maxConcurrent: maxConcurrent);
    return HomeRefreshOutcome(
      batch: batch,
      successFeedback: HomeRefreshSuccessFeedback.refreshed,
    );
  }

  Future<HomeRefreshOutcome> _refreshCategory({
    required int categoryId,
    required int maxConcurrent,
  }) async {
    final feeds = await _ref.read(feedRepositoryProvider).getAll();
    final filtered = feeds.where((feed) => feed.categoryId == categoryId);
    final batch = await _ref
        .read(syncServiceProvider)
        .refreshFeedsSafe(
          filtered.map((feed) => feed.id),
          maxConcurrent: maxConcurrent,
        );
    return HomeRefreshOutcome(
      batch: batch,
      successFeedback: HomeRefreshSuccessFeedback.refreshed,
    );
  }

  Future<HomeRefreshOutcome> _refreshSources({
    required int maxConcurrent,
    required HomeRefreshSuccessFeedback successFeedback,
  }) async {
    final result = await _ref
        .read(refreshSourcesCoordinatorProvider)
        .refreshSources(
          trigger: RefreshSourcesTrigger.manual,
          maxConcurrent: maxConcurrent,
        );
    return HomeRefreshOutcome(
      batch: result.batch,
      successFeedback: successFeedback,
    );
  }

  Future<HomeRefreshOutcome> _refreshRemoteFeedAndSync({
    required int feedId,
    required int maxConcurrent,
  }) async {
    final feed = await _ref.read(feedRepositoryProvider).getById(feedId);
    if (feed == null) return _feedNotFound(feedId);
    final refreshFailure = await _refreshRemoteSources([feed]);
    if (refreshFailure != null) return refreshFailure;
    return _syncAccount(
      maxConcurrent: maxConcurrent,
      successFeedback: HomeRefreshSuccessFeedback.refreshedAndSynced,
    );
  }

  Future<HomeRefreshOutcome> _refreshRemoteCategoryAndSync({
    required int categoryId,
    required int maxConcurrent,
  }) async {
    final feeds = await _ref.read(feedRepositoryProvider).getAll();
    final filtered = feeds
        .where((feed) => feed.categoryId == categoryId)
        .toList(growable: false);
    if (filtered.isEmpty) {
      return const HomeRefreshOutcome(
        batch: BatchRefreshResult([]),
        successFeedback: HomeRefreshSuccessFeedback.refreshed,
      );
    }
    final refreshFailure = await _refreshRemoteSources(
      filtered,
      maxConcurrent: maxConcurrent,
    );
    if (refreshFailure != null) return refreshFailure;
    return _syncAccount(
      maxConcurrent: maxConcurrent,
      successFeedback: HomeRefreshSuccessFeedback.refreshedAndSynced,
    );
  }

  Future<HomeRefreshOutcome?> _refreshRemoteSources(
    List<Feed> feeds, {
    int maxConcurrent = 2,
  }) async {
    try {
      await _ref
          .read(minifluxSourceRefreshProvider)
          .refreshFeeds(feeds, maxConcurrent: maxConcurrent);
      return null;
    } catch (error) {
      final feedId = feeds.isEmpty ? -1 : feeds.first.id;
      return HomeRefreshOutcome(
        batch: BatchRefreshResult([
          FeedRefreshResult(
            feedId: feedId,
            incomingCount: 0,
            newCount: 0,
            error: error,
          ),
        ]),
        successFeedback: HomeRefreshSuccessFeedback.refreshed,
      );
    }
  }

  Future<HomeRefreshOutcome> _syncAccount({
    required int maxConcurrent,
    HomeRefreshSuccessFeedback successFeedback =
        HomeRefreshSuccessFeedback.syncedAccount,
  }) async {
    final result = await _ref
        .read(accountSyncCoordinatorProvider)
        .syncAccount(
          trigger: AccountSyncTrigger.manual,
          maxConcurrent: maxConcurrent,
        );
    return HomeRefreshOutcome(
      batch: result.batch,
      successFeedback: successFeedback,
    );
  }

  HomeRefreshOutcome _feedNotFound(int feedId) {
    return HomeRefreshOutcome(
      batch: BatchRefreshResult([
        FeedRefreshResult(
          feedId: feedId,
          incomingCount: 0,
          newCount: 0,
          error: StateError('Feed $feedId not found'),
        ),
      ]),
      successFeedback: HomeRefreshSuccessFeedback.refreshed,
    );
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
    final scope = _ref.read(currentArticleScopeProvider);
    _context.go(scopedArticleLocation(scope, items[targetIndex].id));
  }

  void goToPreviousArticle() {
    final items = _ref.read(articleListControllerProvider).valueOrNull?.items;
    if (items == null || items.isEmpty) return;

    final currentIndex = selectedArticleId == null
        ? 0
        : items.indexWhere((article) => article.id == selectedArticleId);
    final targetIndex = currentIndex <= 0 ? 0 : currentIndex - 1;
    final scope = _ref.read(currentArticleScopeProvider);
    _context.go(scopedArticleLocation(scope, items[targetIndex].id));
  }
}
