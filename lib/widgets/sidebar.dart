import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fleur/l10n/app_localizations.dart';

import '../models/category.dart';
import '../models/feed.dart';
import '../providers/account_providers.dart';
import '../providers/backend_capabilities_provider.dart';
import '../providers/backend_sync_semantics_provider.dart';
import '../providers/query_providers.dart';
import '../providers/unread_providers.dart';
import '../providers/sync_status_providers.dart';
import '../services/accounts/account.dart';
import '../services/sync/backend_capabilities.dart';
import '../services/sync/sync_status_reporter.dart';
import '../theme/fleur_theme_extensions.dart';
import '../ui/layout_spec.dart';
import '../ui/motion.dart';
import '../ui/global_nav.dart';
import '../ui/sidebar/sidebar_management_actions.dart';
import '../ui/sidebar/sidebar_selection_actions.dart';
import '../ui/sidebar/sidebar_tree.dart';
import '../utils/platform.dart';
import 'account_avatar.dart';
import 'account_manager_dialog.dart';
import 'overflow_marquee.dart';

class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({super.key, required this.onSelectFeed, this.router});

  final void Function(int? feedId) onSelectFeed;
  final GoRouter? router;

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  int? _expandedCategoryId;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchText = '';

  void _closeDrawerIfDesktopDrawer() {
    if (!isDesktop || widget.router == null) return;
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null) {
      scaffold.closeDrawer();
      return;
    }
    final router = widget.router;
    if (router != null && router.canPop()) router.pop();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  NavigatorState get _navigator {
    if (widget.router != null) {
      final key = widget.router!.routerDelegate.navigatorKey;
      if (key.currentState != null) {
        return key.currentState!;
      }
    }
    return Navigator.of(context);
  }

  SidebarSelectionActions get _selectionActions => SidebarSelectionActions(
    ref: ref,
    onSelectFeed: widget.onSelectFeed,
    closeSidebar: _closeDrawerIfDesktopDrawer,
  );

  SidebarManagementActions get _managementActions => SidebarManagementActions(
    context: context,
    ref: ref,
    selectionActions: _selectionActions,
    navigator: _navigator,
    showDialogRoute: _showDialog,
    router: widget.router,
  );

  Future<T?> _showDialog<T>({required WidgetBuilder builder}) {
    return _navigator.push<T>(
      DialogRoute<T>(
        context: context,
        builder: builder,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        useSafeArea: true,
      ),
    );
  }

  Future<T?> _showModalBottomSheet<T>({required WidgetBuilder builder}) {
    return _navigator.push<T>(
      ModalBottomSheetRoute<T>(
        builder: builder,
        isScrollControlled: false,
        useSafeArea: true,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;
    // On desktop we sometimes show the sidebar inside a Scaffold drawer that is
    // *outside* the app's Navigator (see `App` overlay). In that case, using
    // `Navigator.of(context)` will throw. We only show a close button when the
    // caller provided a router to pop with.
    final showDrawerClose = isDesktop && widget.router != null;
    final feeds = ref.watch(feedsProvider);
    final categories = ref.watch(categoriesProvider);
    final selectedFeedId = ref.watch(selectedFeedIdProvider);
    final selectedCategoryId = ref.watch(selectedCategoryIdProvider);
    final selectedTagId = ref.watch(selectedTagIdProvider);
    final tags = ref.watch(tagsProvider);
    final activeAccount = ref.watch(activeAccountProvider);
    final capabilities = ref.watch(backendCapabilitiesProvider);
    final syncSemantics = ref.watch(backendSyncSemanticsProvider);
    final navMode = LayoutSpec.fromContext(context).globalNavMode;
    final showAccountFooter = navMode == GlobalNavMode.bottom;
    final syncStatus = ref.watch(syncStatusControllerProvider);
    final selectionActions = _selectionActions;
    final managementActions = _managementActions;

    final starredOnly = ref.watch(starredOnlyProvider);
    final readLaterOnly = ref.watch(readLaterOnlyProvider);
    final allUnreadCounts = ref.watch(allUnreadCountsProvider);

    return Material(
      color: surfaces.sidebar,
      child: Column(
        children: [
          SidebarSearchField(
            controller: _searchController,
            showDrawerClose: showDrawerClose,
            onCloseDrawer: _closeDrawerIfDesktopDrawer,
          ),
          Expanded(
            child: SidebarNavigationTree(
              scrollController: _scrollController,
              searchText: _searchText,
              feeds: feeds,
              categories: categories,
              tags: tags,
              allUnreadCounts: allUnreadCounts,
              selectedFeedId: selectedFeedId,
              selectedCategoryId: selectedCategoryId,
              selectedTagId: selectedTagId,
              starredOnly: starredOnly,
              readLaterOnly: readLaterOnly,
              expandedCategoryId: _expandedCategoryId,
              onExpandedCategoryChanged: (categoryId) {
                setState(() => _expandedCategoryId = categoryId);
              },
              selectionActions: selectionActions,
              managementActions: managementActions,
              capabilities: capabilities,
              syncSemantics: syncSemantics,
              onAddFeed: managementActions.addFeed,
              onAddCategory: () async {
                final id = await managementActions.addCategory();
                if (id == null) return;
                setState(() => _expandedCategoryId = id);
              },
              onShowCategoryMenu: (category) =>
                  _showCategoryMenu(category, managementActions),
              onShowFeedMenu: (feed) => _showFeedMenu(feed, managementActions),
            ),
          ),
          if (showAccountFooter)
            _AccountFooter(
              account: activeAccount,
              sync: syncStatus,
              onTap: () {
                unawaited(
                  _showDialog<void>(
                    builder: (_) => const AccountManagerDialog(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showCategoryMenu(
    Category c,
    SidebarManagementActions managementActions,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = ref.read(backendCapabilitiesProvider);
    final v = await _showModalBottomSheet<_CategoryAction>(
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (capabilities.isVisible(BackendFeature.renameCategory))
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l10n.rename),
                  onTap: () =>
                      Navigator.of(context).pop(_CategoryAction.rename),
                ),
              if (capabilities.isVisible(BackendFeature.deleteCategory))
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.deleteCategory),
                  onTap: () =>
                      Navigator.of(context).pop(_CategoryAction.delete),
                ),
            ],
          ),
        );
      },
    );
    if (!context.mounted) return;
    switch (v) {
      case _CategoryAction.rename:
        await managementActions.renameCategory(c);
        return;
      case _CategoryAction.delete:
        await managementActions.deleteCategory(c);
        return;
      case null:
        return;
    }
  }

  Future<void> _showFeedMenu(
    Feed f,
    SidebarManagementActions managementActions,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = ref.read(backendCapabilitiesProvider);
    final canMove =
        capabilities.isVisible(BackendFeature.moveSubscriptionToCategory) ||
        capabilities.isVisible(BackendFeature.moveSubscriptionToUncategorized);
    final action = await _showModalBottomSheet<_FeedAction>(
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (capabilities.isVisible(BackendFeature.clientFeedSettings))
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l10n.edit),
                  onTap: () => Navigator.of(context).pop(_FeedAction.edit),
                ),
              if (capabilities.isVisible(
                BackendFeature.refreshSubscriptionSource,
              ))
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: Text(l10n.refresh),
                  onTap: () => Navigator.of(context).pop(_FeedAction.refresh),
                ),
              if (capabilities.isVisible(BackendFeature.offlineCache))
                ListTile(
                  leading: const Icon(Icons.download_for_offline_outlined),
                  title: Text(l10n.makeAvailableOffline),
                  onTap: () =>
                      Navigator.of(context).pop(_FeedAction.offlineCache),
                ),
              if (canMove)
                ListTile(
                  leading: const Icon(Icons.drive_file_move_outline),
                  title: Text(l10n.moveToCategory),
                  onTap: () => Navigator.of(context).pop(_FeedAction.move),
                ),
              if (capabilities.isVisible(BackendFeature.deleteSubscription))
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.deleteSubscription),
                  onTap: () => Navigator.of(context).pop(_FeedAction.delete),
                ),
            ],
          ),
        );
      },
    );
    if (!context.mounted) return;

    switch (action) {
      case _FeedAction.edit:
        await managementActions.editFeedTitle(f);
        return;
      case _FeedAction.refresh:
        await managementActions.refreshFeed(f);
        return;
      case _FeedAction.offlineCache:
        await managementActions.cacheFeedOffline(f);
        return;
      case _FeedAction.move:
        await managementActions.moveFeedToCategory(f);
        return;
      case _FeedAction.delete:
        await managementActions.deleteFeed(f);
        return;
      case null:
        return;
    }
  }
}

enum _FeedAction { edit, refresh, offlineCache, move, delete }

enum _CategoryAction { rename, delete }

class _AccountFooter extends StatelessWidget {
  const _AccountFooter({
    required this.account,
    required this.sync,
    required this.onTap,
  });

  final Account account;
  final SyncStatusState sync;
  final VoidCallback onTap;

  String _syncText(AppLocalizations l10n) {
    String labelFor(SyncStatusLabel label) => switch (label) {
      SyncStatusLabel.syncing => l10n.syncStatusSyncing,
      SyncStatusLabel.syncingFeeds => l10n.syncStatusSyncingFeeds,
      SyncStatusLabel.syncingSubscriptions =>
        l10n.syncStatusSyncingSubscriptions,
      SyncStatusLabel.syncingUnreadArticles =>
        l10n.syncStatusSyncingUnreadArticles,
      SyncStatusLabel.uploadingChanges => l10n.syncStatusUploadingChanges,
      SyncStatusLabel.completed => l10n.syncStatusCompleted,
      SyncStatusLabel.failed => l10n.syncStatusFailed,
    };

    final label = labelFor(sync.label);
    final base = label;
    final cur = sync.current;
    final total = sync.total;
    if (cur != null && total != null && total > 0) {
      return '$base（$cur/$total）';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;
    final states = theme.fleurState;
    final scheme = theme.colorScheme;
    final reduceMotion = AppMotion.reduceMotion(context);
    final duration = reduceMotion ? Duration.zero : AppMotion.short;

    final showSync = sync.visible;
    final syncText = _syncText(l10n);

    return Material(
      color: surfaces.card,
      child: InkWell(
        onTap: onTap,
        hoverColor: states.hoverTint,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              AccountAvatar(account: account, radius: 18, showTypeBadge: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AnimatedSwitcher(
                      duration: duration,
                      switchInCurve: AppMotion.standardCurve,
                      switchOutCurve: AppMotion.emphasizedAccelerate,
                      transitionBuilder: (child, animation) {
                        return SizeTransition(
                          sizeFactor: animation,
                          axisAlignment: -1,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: showSync
                          ? Padding(
                              key: const ValueKey('sync'),
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  if (sync.running)
                                    const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    Icon(
                                      sync.label == SyncStatusLabel.failed
                                          ? Icons.error_outline
                                          : Icons.check,
                                      size: 12,
                                      color:
                                          sync.label == SyncStatusLabel.failed
                                          ? states.errorAccent
                                          : states.syncAccent,
                                    ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: OverflowMarquee(
                                      text: syncText,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox(key: ValueKey('empty')),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.unfold_more, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
