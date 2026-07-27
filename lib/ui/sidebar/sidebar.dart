import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/features/subscriptions/subscriptions.dart';
import 'package:fleur/l10n/app_localizations.dart';

import '../../app/settings_routes.dart';
import '../../models/article_scope.dart';
import '../../models/category.dart';
import '../../models/feed.dart';
import '../../providers/backend_capabilities_provider.dart';
import '../../providers/backend_sync_semantics_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/navigation_history_provider.dart';
import '../../providers/query_providers.dart';
import '../../providers/sync_status_providers.dart';
import '../../providers/unread_providers.dart';
import '../../services/sync/backend_capabilities.dart';
import '../../services/sync/sync_status_reporter.dart';
import '../../theme/fleur_icons.dart';
import '../../theme/fleur_theme_extensions.dart';
import '../../widgets/overflow_marquee.dart';
import '../app_menu.dart';
import '../design_system/design_system.dart';
import '../motion.dart';
import '../shell_chrome_layout.dart';
import '../sidebar_layout.dart';
import 'sidebar_management_actions.dart';
import 'sidebar_selection_actions.dart';
import 'sidebar_tree.dart';

part 'sidebar_chrome.dart';
part 'sidebar_rail.dart';

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
    this.railSurfaceStyle = SidebarRailSurfaceStyle.capsule,
    this.railWidth = kSidebarRailWidth,
    this.expandedWidth = kDefaultWorkspaceSidebarWidth,
  });

  final ValueChanged<ArticleScope> onSelectScope;
  final GoRouter? router;
  final SidebarPresentationMode? presentationModeOverride;
  final bool reserveShellHeader;
  final bool transparentBackground;
  final bool showAccountSyncStatus;
  final Uri? currentUri;
  final SidebarRailSurfaceStyle railSurfaceStyle;
  final double railWidth;
  final double expandedWidth;

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
  }

  void _goLocation(String location) {
    _closeSidebarIfDrawerOpen();
    final router = widget.router;
    if (router != null) {
      ref
          .read(navigationHistoryControllerProvider.notifier)
          .visit(location, router: router);
      return;
    }
    final contextRouter = GoRouter.of(context);
    ref
        .read(navigationHistoryControllerProvider.notifier)
        .visit(location, router: contextRouter);
  }

  void _pushLocation(String location) {
    _closeSidebarIfDrawerOpen();
    final router = widget.router ?? GoRouter.maybeOf(context);
    if (router != null) {
      unawaited(
        ref
            .read(navigationHistoryControllerProvider.notifier)
            .push<void>(location, router: router),
      );
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

    return SidebarRailLayoutScope(
      railWidth: widget.railWidth,
      child: Material(
        color: widget.transparentBackground
            ? Colors.transparent
            : surfaces.sidebar,
        child: _PersistentSidebarChrome(
          collapsed: collapsed,
          expandedWidth: widget.expandedWidth,
          railWidth: widget.railWidth,
          rail: _SidebarRail(
            mode: presentationMode,
            items: fixedItems,
            account: activeAccount,
            reserveShellHeader: widget.reserveShellHeader,
            onAccountTap: () => unawaited(_showAccountMenu()),
            accountAnchorKey: _accountFooterKey,
            railSurfaceStyle: widget.railSurfaceStyle,
            showAnchorKeys: collapsed,
          ),
          detail: _SidebarPanel(
            fixedItems: fixedItems,
            account: activeAccount,
            sync: syncStatus,
            showSyncStatus: widget.showAccountSyncStatus,
            onAccountTap: () => unawaited(_showAccountMenu()),
            reserveShellHeader: widget.reserveShellHeader,
            navigationTree: navigationTree,
            navigationScrollController: _scrollController,
            showRailAnchors: !collapsed,
          ),
        ),
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
