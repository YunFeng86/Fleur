import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fleur/l10n/app_localizations.dart';

import '../models/category.dart';
import '../models/article_scope.dart';
import '../models/feed.dart';
import '../app/settings_routes.dart';
import '../providers/account_providers.dart';
import '../providers/backend_capabilities_provider.dart';
import '../providers/backend_sync_semantics_provider.dart';
import '../providers/core_providers.dart';
import '../providers/query_providers.dart';
import '../providers/unread_providers.dart';
import '../providers/sync_status_providers.dart';
import '../services/accounts/account.dart';
import '../services/sync/sync_status_reporter.dart';
import '../services/sync/backend_capabilities.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../ui/app_menu.dart';
import '../ui/motion.dart';
import '../ui/sidebar_layout.dart';
import '../ui/actions/subscription_object_menus.dart';
import '../ui/sidebar/sidebar_management_actions.dart';
import '../ui/sidebar/sidebar_selection_actions.dart';
import '../ui/sidebar/sidebar_tree.dart';
import '../utils/platform.dart';
import 'account_avatar.dart';
import 'overflow_marquee.dart';

class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({super.key, required this.onSelectScope, this.router});

  final ValueChanged<ArticleScope> onSelectScope;
  final GoRouter? router;

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  int? _expandedCategoryId;
  final _scrollController = ScrollController();
  final _accountFooterKey = GlobalKey();

  void _closeSidebarIfDrawerOpen() {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
      return;
    }
    final router = widget.router;
    if (isDesktop && router != null && router.canPop()) router.pop();
  }

  void _goLocation(String location) {
    _closeSidebarIfDrawerOpen();
    final router = widget.router;
    if (router != null) {
      router.go(location);
      return;
    }
    context.go(location);
  }

  void _openAddSubscriptionPage() {
    _goLocation('/add-subscription');
  }

  void _openAccountSettings() {
    _goLocation(settingsLocation(tab: SettingsTab.services));
  }

  void _openSettings() {
    _goLocation(settingsLocation());
  }

  @override
  void dispose() {
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
    onSelectScope: widget.onSelectScope,
    closeSidebar: _closeSidebarIfDrawerOpen,
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

  Future<void> _showAccountMenu() async {
    final renderObject = _accountFooterKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final l10n = AppLocalizations.of(context)!;
    final position = renderObject.localToGlobal(
      Offset(renderObject.size.width / 2, 8),
    );
    final action = await AppMenuHost.showAt<_SidebarAccountMenuAction>(
      context,
      position: position,
      items: [
        AppMenuItem(
          value: _SidebarAccountMenuAction.account,
          icon: FleurIcons.services,
          label: l10n.account,
          key: const Key('sidebar_account_menu_account'),
        ),
        AppMenuItem(
          value: _SidebarAccountMenuAction.settings,
          icon: FleurIcons.settings,
          label: l10n.settings,
          key: const Key('sidebar_account_menu_settings'),
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _SidebarAccountMenuAction.account:
        _openAccountSettings();
        return;
      case _SidebarAccountMenuAction.settings:
        _openSettings();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;
    final feeds = ref.watch(feedsProvider);
    final categories = ref.watch(categoriesProvider);
    final selectedFeedId = ref.watch(selectedFeedIdProvider);
    final selectedCategoryId = ref.watch(selectedCategoryIdProvider);
    final activeAccount = ref.watch(activeAccountProvider);
    final capabilities = ref.watch(backendCapabilitiesProvider);
    final syncSemantics = ref.watch(backendSyncSemanticsProvider);
    final presentationMode = ref.watch(sidebarPresentationModeProvider);
    final syncStatus = ref.watch(syncStatusControllerProvider);
    final selectionActions = _selectionActions;
    final managementActions = _managementActions;

    final starredOnly = ref.watch(starredOnlyProvider);
    final readLaterOnly = ref.watch(readLaterOnlyProvider);
    final allUnreadCounts = ref.watch(allUnreadCountsProvider);
    final currentScope = ref.watch(currentArticleScopeProvider);

    return Material(
      color: surfaces.sidebar,
      child: Column(
        children: [
          _SidebarFixedItems(
            mode: presentationMode,
            currentScope: currentScope,
            allUnreadCount: allUnreadCounts.valueOrNull?[null] ?? 0,
            showAddSubscription: capabilities.isVisible(
              BackendFeature.addSubscription,
            ),
            onSelectAll: selectionActions.selectAll,
            onSelectStarred: selectionActions.selectStarred,
            onSelectReadLater: selectionActions.selectReadLater,
            onAddSubscription: _openAddSubscriptionPage,
          ),
          Expanded(
            child: SidebarNavigationTree(
              presentationMode: presentationMode,
              scrollController: _scrollController,
              feeds: feeds,
              categories: categories,
              allUnreadCounts: allUnreadCounts,
              selectedFeedId: selectedFeedId,
              selectedCategoryId: selectedCategoryId,
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
              onAddFeed: () async {
                await managementActions.addFeed();
              },
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
          _AccountFooter(
            key: _accountFooterKey,
            account: activeAccount,
            sync: syncStatus,
            mode: presentationMode,
            onTap: () => unawaited(_showAccountMenu()),
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
    final items = SubscriptionObjectMenus.categoryItems(l10n, capabilities);
    if (items.isEmpty) return;
    final v = await _showModalBottomSheet<SubscriptionCategoryMenuAction>(
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: SubscriptionObjectMenus.bottomSheetTiles(
              context: context,
              items: items,
            ),
          ),
        );
      },
    );
    if (!context.mounted) return;
    switch (v) {
      case SubscriptionCategoryMenuAction.rename:
        await managementActions.renameCategory(c);
        return;
      case SubscriptionCategoryMenuAction.delete:
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
    final items = SubscriptionObjectMenus.feedItems(l10n, capabilities);
    if (items.isEmpty) return;
    final action = await _showModalBottomSheet<SubscriptionFeedMenuAction>(
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: SubscriptionObjectMenus.bottomSheetTiles(
              context: context,
              items: items,
            ),
          ),
        );
      },
    );
    if (!context.mounted) return;

    switch (action) {
      case SubscriptionFeedMenuAction.rename:
        await managementActions.editFeedTitle(f);
        return;
      case SubscriptionFeedMenuAction.refresh:
        await managementActions.refreshFeed(f);
        return;
      case SubscriptionFeedMenuAction.offlineCache:
        await managementActions.cacheFeedOffline(f);
        return;
      case SubscriptionFeedMenuAction.move:
        await managementActions.moveFeedToCategory(f);
        return;
      case SubscriptionFeedMenuAction.delete:
        await managementActions.deleteFeed(f);
        return;
      case null:
        return;
    }
  }
}

enum _SidebarAccountMenuAction { account, settings }

class _SidebarFixedItems extends StatelessWidget {
  const _SidebarFixedItems({
    required this.mode,
    required this.currentScope,
    required this.allUnreadCount,
    required this.showAddSubscription,
    required this.onSelectAll,
    required this.onSelectStarred,
    required this.onSelectReadLater,
    required this.onAddSubscription,
  });

  final SidebarPresentationMode mode;
  final ArticleScope currentScope;
  final int allUnreadCount;
  final bool showAddSubscription;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectStarred;
  final VoidCallback onSelectReadLater;
  final VoidCallback onAddSubscription;

  bool get _collapsed => mode == SidebarPresentationMode.collapsed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final surfaces = Theme.of(context).fleurSurface;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: surfaces.subtleDivider)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _collapsed ? 4 : 8,
            8,
            _collapsed ? 4 : 8,
            8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SidebarFixedItem(
                key: const Key('sidebar_all_button'),
                mode: mode,
                selected: currentScope == ArticleScope.all,
                icon: FleurIcons.allArticles,
                title: l10n.all,
                count: allUnreadCount,
                onTap: onSelectAll,
              ),
              _SidebarFixedItem(
                key: const Key('sidebar_starred_button'),
                mode: mode,
                selected: currentScope == ArticleScope.starred,
                icon: FleurIcons.star,
                selectedIcon: FleurIcons.starActive,
                title: l10n.starred,
                onTap: onSelectStarred,
              ),
              _SidebarFixedItem(
                key: const Key('sidebar_read_later_button'),
                mode: mode,
                selected: currentScope == ArticleScope.readLater,
                icon: FleurIcons.readLater,
                selectedIcon: FleurIcons.readLaterActive,
                title: l10n.readLater,
                onTap: onSelectReadLater,
              ),
              if (showAddSubscription)
                _SidebarFixedItem(
                  key: const Key('sidebar_add_subscription_button'),
                  mode: mode,
                  selected: false,
                  icon: FleurIcons.add,
                  title: l10n.addSubscription,
                  onTap: onAddSubscription,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarFixedItem extends StatelessWidget {
  const _SidebarFixedItem({
    super.key,
    required this.mode,
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
    this.selectedIcon,
    this.count,
  });

  final SidebarPresentationMode mode;
  final bool selected;
  final IconData icon;
  final IconData? selectedIcon;
  final String title;
  final VoidCallback onTap;
  final int? count;

  bool get _collapsed => mode == SidebarPresentationMode.collapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final states = theme.fleurState;
    final iconData = selected ? (selectedIcon ?? icon) : icon;

    if (_collapsed) {
      return Tooltip(
        message: title,
        child: Semantics(
          button: true,
          selected: selected,
          label: title,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: InkResponse(
              onTap: onTap,
              hoverColor: states.hoverTint,
              radius: 24,
              child: SizedBox.square(
                dimension: 48,
                child: Icon(
                  iconData,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return ListTile(
      selected: selected,
      minLeadingWidth: 0,
      leading: Icon(iconData),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: count == null ? null : _SidebarFixedCount(count!),
      onTap: onTap,
    );
  }
}

class _SidebarFixedCount extends StatelessWidget {
  const _SidebarFixedCount(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Text(
      count > 99 ? '99+' : '$count',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _AccountFooter extends StatelessWidget {
  const _AccountFooter({
    required this.account,
    required this.sync,
    required this.mode,
    required this.onTap,
    super.key,
  });

  final Account account;
  final SyncStatusState sync;
  final SidebarPresentationMode mode;
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
    final collapsed = mode == SidebarPresentationMode.collapsed;

    if (collapsed) {
      return SafeArea(
        top: false,
        child: Material(
          color: surfaces.card,
          child: Tooltip(
            message: account.name,
            child: InkWell(
              key: const Key('sidebar_account_button'),
              onTap: onTap,
              hoverColor: states.hoverTint,
              child: SizedBox(
                height: 64,
                child: Center(
                  child: AccountAvatar(
                    account: account,
                    radius: 18,
                    showTypeBadge: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: surfaces.card,
      child: InkWell(
        key: const Key('sidebar_account_button'),
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
                                          ? FleurIcons.statusError
                                          : FleurIcons.statusOk,
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
              Icon(
                FleurIcons.accountSwitcher,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
