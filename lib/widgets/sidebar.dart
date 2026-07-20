import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fleur/l10n/app_localizations.dart';

import '../models/category.dart';
import '../models/article_scope.dart';
import '../models/feed.dart';
import '../app/settings_routes.dart';
import '../providers/account_providers.dart';
import '../providers/app_update_providers.dart';
import '../providers/backend_capabilities_provider.dart';
import '../providers/backend_sync_semantics_provider.dart';
import '../providers/core_providers.dart';
import '../providers/query_providers.dart';
import '../providers/unread_providers.dart';
import '../providers/sync_status_providers.dart';
import '../services/accounts/account.dart';
import '../services/sync/sync_status_reporter.dart';
import '../services/sync/backend_capabilities.dart';
import '../services/update/app_update_manifest.dart';
import '../theme/app_typography.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../ui/app_menu.dart';
import '../ui/motion.dart';
import '../ui/shell_chrome_layout.dart';
import '../ui/sidebar_layout.dart';
import '../ui/actions/subscription_object_menus.dart';
import '../ui/sidebar/sidebar_management_actions.dart';
import '../ui/sidebar/sidebar_selection_actions.dart';
import '../ui/sidebar/sidebar_tree.dart';
import '../ui/update/app_update_dialog.dart';
import '../utils/platform.dart';
import 'account_avatar.dart';
import 'fleur_capsule_button_group.dart';
import 'fleur_selectable_button.dart';
import 'fleur_selection_transition.dart';
import 'overflow_marquee.dart';

part 'sidebar_chrome.dart';

class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({
    super.key,
    required this.onSelectScope,
    this.router,
    this.presentationModeOverride,
    this.reserveShellHeader = false,
    this.transparentBackground = false,
    this.showAccountSyncStatus = true,
    this.currentUri,
    this.onSearch,
    this.macOSWindowChromeMetrics = MacOSWindowChromeMetrics.fallback,
    this.railSurfaceStyle = SidebarRailSurfaceStyle.capsule,
    this.showHeaderActions = true,
  });

  final ValueChanged<ArticleScope> onSelectScope;
  final GoRouter? router;
  final SidebarPresentationMode? presentationModeOverride;
  final bool reserveShellHeader;
  final bool transparentBackground;
  final bool showAccountSyncStatus;
  final Uri? currentUri;
  final VoidCallback? onSearch;
  final MacOSWindowChromeMetrics macOSWindowChromeMetrics;
  final SidebarRailSurfaceStyle railSurfaceStyle;
  final bool showHeaderActions;

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

  void _pushLocation(String location) {
    _closeSidebarIfDrawerOpen();
    final router = widget.router ?? GoRouter.maybeOf(context);
    if (router != null) {
      unawaited(router.push<void>(location));
      return;
    }
    unawaited(Navigator.of(context).pushNamed(location));
  }

  void _openAddSubscriptionPage() {
    _goLocation('/add-subscription');
  }

  void _openAccountSettings() {
    _pushLocation(settingsLocation(tab: SettingsTab.services));
  }

  void _openSettings() {
    _pushLocation(settingsLocation());
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
    const menuItemHeight = 40.0;
    const menuVerticalPadding = 8.0;
    const menuGap = 8.0;
    const menuHorizontalInset = 12.0;
    final menuHeight =
        _SidebarAccountMenuAction.values.length * menuItemHeight +
        menuVerticalPadding;
    final position = renderObject.localToGlobal(
      Offset(menuHorizontalInset, -menuHeight - menuGap),
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
    final SidebarPresentationMode presentationMode =
        widget.presentationModeOverride ??
        ref.watch(sidebarPresentationModeProvider);
    final collapsed = presentationMode == SidebarPresentationMode.collapsed;
    final syncStatus = ref.watch(syncStatusControllerProvider);
    final selectionActions = _selectionActions;
    final managementActions = _managementActions;

    final starredOnly = ref.watch(starredOnlyProvider);
    final readLaterOnly = ref.watch(readLaterOnlyProvider);
    final allUnreadCounts = ref.watch(allUnreadCountsProvider);
    final currentScope = ref.watch(currentArticleScopeProvider);
    final searchSelected = _isSidebarSearchRoute(widget.currentUri);
    final addSubscriptionSelected = _isSidebarAddSubscriptionRoute(
      widget.currentUri,
    );
    final suppressScopeSelection = searchSelected || addSubscriptionSelected;
    final fixedItems = _fixedScopeItems(
      context: context,
      currentScope: currentScope,
      allUnreadCount: allUnreadCounts.valueOrNull?[null] ?? 0,
      suppressScopeSelection: suppressScopeSelection,
      addSubscriptionSelected: addSubscriptionSelected,
      showAddSubscription: capabilities.isVisible(
        BackendFeature.addSubscription,
      ),
      onSelectAll: selectionActions.selectAll,
      onSelectStarred: selectionActions.selectStarred,
      onSelectReadLater: selectionActions.selectReadLater,
      onAddSubscription: _openAddSubscriptionPage,
    );
    final navigationTree = SidebarNavigationTree(
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
    );

    return Material(
      color: widget.transparentBackground
          ? Colors.transparent
          : surfaces.sidebar,
      child: collapsed
          ? Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: double.infinity,
                child: _SidebarRail(
                  mode: presentationMode,
                  items: fixedItems,
                  account: activeAccount,
                  reserveShellHeader: widget.reserveShellHeader,
                  onAccountTap: () => unawaited(_showAccountMenu()),
                  accountAnchorKey: _accountFooterKey,
                  railSurfaceStyle: widget.railSurfaceStyle,
                ),
              ),
            )
          : _SidebarPanel(
              fixedItems: fixedItems,
              account: activeAccount,
              sync: syncStatus,
              showSyncStatus: widget.showAccountSyncStatus,
              onAccountTap: () => unawaited(_showAccountMenu()),
              accountAnchorKey: _accountFooterKey,
              reserveShellHeader: widget.reserveShellHeader,
              searchSelected: searchSelected,
              onSearch: widget.onSearch,
              macOSWindowChromeMetrics: widget.macOSWindowChromeMetrics,
              showHeaderActions: widget.showHeaderActions,
              navigationTree: navigationTree,
              navigationScrollController: _scrollController,
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
