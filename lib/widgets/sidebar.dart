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
import '../theme/app_typography.dart';
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
import 'fleur_capsule_button_group.dart';
import 'overflow_marquee.dart';

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
  });

  final ValueChanged<ArticleScope> onSelectScope;
  final GoRouter? router;
  final SidebarPresentationMode? presentationModeOverride;
  final bool reserveShellHeader;
  final bool transparentBackground;
  final bool showAccountSyncStatus;
  final Uri? currentUri;
  final VoidCallback? onSearch;

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
                width: kSidebarRailWidth,
                child: _SidebarRail(
                  mode: presentationMode,
                  items: fixedItems,
                  account: activeAccount,
                  reserveShellHeader: widget.reserveShellHeader,
                  onAccountTap: () => unawaited(_showAccountMenu()),
                  accountAnchorKey: _accountFooterKey,
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

enum _SidebarAccountMenuAction { account, settings }

const double _kSidebarFixedItemHeight = 40;
const double _kSidebarRailButtonSize = kShellControlSize;
const double _kSidebarRailIconSize = kShellControlIconSize;
const double _kSidebarAccountHeight = 56;
const double _kSidebarRailHorizontalInset = 10;
const double _kSidebarAccountAvatarRadius = 16;

bool _isSidebarSearchRoute(Uri? uri) {
  if (uri == null || uri.pathSegments.isEmpty) return false;
  return uri.pathSegments.first == 'search';
}

bool _isSidebarAddSubscriptionRoute(Uri? uri) {
  if (uri == null || uri.pathSegments.isEmpty) return false;
  return uri.pathSegments.first == 'add-subscription';
}

List<_SidebarFixedItemData> _fixedScopeItems({
  required BuildContext context,
  required ArticleScope currentScope,
  required int allUnreadCount,
  required bool suppressScopeSelection,
  required bool addSubscriptionSelected,
  required bool showAddSubscription,
  required VoidCallback onSelectAll,
  required VoidCallback onSelectStarred,
  required VoidCallback onSelectReadLater,
  required VoidCallback onAddSubscription,
}) {
  final l10n = AppLocalizations.of(context)!;
  return [
    _SidebarFixedItemData(
      key: const Key('sidebar_all_button'),
      selected: !suppressScopeSelection && currentScope == ArticleScope.all,
      icon: FleurIcons.feed,
      title: l10n.all,
      count: allUnreadCount,
      onTap: onSelectAll,
    ),
    _SidebarFixedItemData(
      key: const Key('sidebar_starred_button'),
      selected: !suppressScopeSelection && currentScope == ArticleScope.starred,
      icon: FleurIcons.star,
      selectedIcon: FleurIcons.starActive,
      title: l10n.starred,
      onTap: onSelectStarred,
    ),
    _SidebarFixedItemData(
      key: const Key('sidebar_read_later_button'),
      selected:
          !suppressScopeSelection && currentScope == ArticleScope.readLater,
      icon: FleurIcons.readLater,
      selectedIcon: FleurIcons.readLaterActive,
      title: l10n.readLater,
      onTap: onSelectReadLater,
    ),
    if (showAddSubscription)
      _SidebarFixedItemData(
        key: const Key('sidebar_add_subscription_button'),
        selected: addSubscriptionSelected,
        icon: FleurIcons.add,
        title: l10n.addSubscription,
        onTap: onAddSubscription,
      ),
  ];
}

class _SidebarFixedItemData {
  const _SidebarFixedItemData({
    required this.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
    this.selectedIcon,
    this.count,
  });

  final Key key;
  final bool selected;
  final IconData icon;
  final IconData? selectedIcon;
  final String title;
  final VoidCallback onTap;
  final int? count;

  IconData get effectiveIcon => selected ? (selectedIcon ?? icon) : icon;
}

class _SidebarRail extends StatelessWidget {
  const _SidebarRail({
    required this.mode,
    required this.items,
    required this.account,
    required this.reserveShellHeader,
    required this.onAccountTap,
    required this.accountAnchorKey,
  });

  final SidebarPresentationMode mode;
  final List<_SidebarFixedItemData> items;
  final Account account;
  final bool reserveShellHeader;
  final VoidCallback onAccountTap;
  final Key accountAnchorKey;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).fleurSurface;
    final collapsed = mode == SidebarPresentationMode.collapsed;
    final railButtons = Column(
      mainAxisSize: MainAxisSize.min,
      children: [for (final item in items) _SidebarRailScopeButton(item: item)],
    );

    return Column(
      children: [
        if (reserveShellHeader) const SizedBox(height: kWorkspaceHeaderHeight),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _kSidebarRailHorizontalInset,
            ),
            child: Column(
              children: [
                DecoratedBox(
                  key: collapsed
                      ? const Key('sidebar_collapsed_rail_surface')
                      : null,
                  decoration: collapsed
                      ? BoxDecoration(
                          color: surfaces.floating,
                          border: Border.all(color: surfaces.subtleDivider),
                          borderRadius: BorderRadius.circular(999),
                        )
                      : const BoxDecoration(),
                  child: railButtons,
                ),
                const Expanded(child: SizedBox.shrink()),
                SafeArea(
                  top: false,
                  child: SizedBox(
                    height: _kSidebarAccountHeight,
                    child: Center(
                      child: SizedBox.square(
                        key: accountAnchorKey,
                        dimension: _kSidebarRailButtonSize,
                        child: _SidebarRailAccountButton(
                          key: const Key('sidebar_account_button'),
                          account: account,
                          onTap: onAccountTap,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarRailScopeButton extends StatelessWidget {
  const _SidebarRailScopeButton({required this.item});

  final _SidebarFixedItemData item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kSidebarFixedItemHeight,
      child: Center(
        child: Semantics(
          button: true,
          selected: item.selected,
          label: item.title,
          child: _SidebarRailIconButton(
            key: item.key,
            tooltip: item.title,
            icon: item.effectiveIcon,
            selected: item.selected,
            onPressed: item.onTap,
          ),
        ),
      ),
    );
  }
}

class _SidebarRailAccountButton extends StatelessWidget {
  const _SidebarRailAccountButton({
    super.key,
    required this.account,
    required this.onTap,
  });

  final Account account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final states = Theme.of(context).fleurState;
    return Tooltip(
      message: account.name,
      child: Semantics(
        button: true,
        label: account.name,
        child: InkResponse(
          onTap: onTap,
          hoverColor: states.hoverTint,
          radius: 20,
          child: SizedBox.square(
            dimension: _kSidebarRailButtonSize,
            child: Center(
              child: AccountAvatar(
                account: account,
                radius: _kSidebarAccountAvatarRadius,
                showTypeBadge: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarRailIconButton extends StatelessWidget {
  const _SidebarRailIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color, size: _kSidebarRailIconSize),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(_kSidebarRailButtonSize),
        minimumSize: const Size.square(_kSidebarRailButtonSize),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _SidebarPanel extends StatelessWidget {
  const _SidebarPanel({
    required this.fixedItems,
    required this.account,
    required this.sync,
    required this.showSyncStatus,
    required this.onAccountTap,
    required this.accountAnchorKey,
    required this.reserveShellHeader,
    required this.searchSelected,
    required this.onSearch,
    required this.navigationTree,
    required this.navigationScrollController,
  });

  final List<_SidebarFixedItemData> fixedItems;
  final Account account;
  final SyncStatusState sync;
  final bool showSyncStatus;
  final VoidCallback onAccountTap;
  final Key accountAnchorKey;
  final bool reserveShellHeader;
  final bool searchSelected;
  final VoidCallback? onSearch;
  final Widget navigationTree;
  final ScrollController navigationScrollController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (reserveShellHeader)
          _SidebarPanelHeader(
            searchSelected: searchSelected,
            onSearch: onSearch,
          ),
        _SidebarPanelFixedItems(
          items: fixedItems,
          scrollController: navigationScrollController,
        ),
        Expanded(child: navigationTree),
        _AccountPanelFooter(
          account: account,
          sync: sync,
          showSyncStatus: showSyncStatus,
          onTap: onAccountTap,
          accountAnchorKey: accountAnchorKey,
        ),
      ],
    );
  }
}

class _SidebarPanelHeader extends StatelessWidget {
  const _SidebarPanelHeader({
    required this.searchSelected,
    required this.onSearch,
  });

  final bool searchSelected;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onPressed = onSearch;

    return SizedBox(
      key: const Key('app_shell_sidebar_header'),
      height: kWorkspaceHeaderHeight,
      child: onPressed == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  button: true,
                  selected: searchSelected,
                  label: l10n.search,
                  child: IconButton(
                    key: const Key('shell_search_button'),
                    tooltip: l10n.search,
                    onPressed: onPressed,
                    icon: Icon(
                      searchSelected
                          ? FleurIcons.searchSelected
                          : FleurIcons.search,
                    ),
                    iconSize: kShellControlIconSize,
                    style: FleurCapsuleIconButton.styleFor(
                      context,
                      selected: searchSelected,
                      size: kShellControlSize,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _SidebarPanelFixedItems extends StatelessWidget {
  const _SidebarPanelFixedItems({
    required this.items,
    required this.scrollController,
  });

  final List<_SidebarFixedItemData> items;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).fleurSurface;
    final reduceMotion = AppMotion.reduceMotion(context);
    final duration = reduceMotion ? Duration.zero : AppMotion.short;

    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items) _SidebarPanelFixedItem(item: item),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedBuilder(
            animation: scrollController,
            builder: (context, _) {
              final showDivider =
                  scrollController.hasClients && scrollController.offset > 0.5;
              return AnimatedOpacity(
                opacity: showDivider ? 1 : 0,
                duration: duration,
                curve: AppMotion.standardCurve,
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: surfaces.subtleDivider,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SidebarPanelFixedItem extends StatelessWidget {
  const _SidebarPanelFixedItem({required this.item});

  final _SidebarFixedItemData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;
    final states = theme.fleurState;
    final scheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(8);
    final iconColor = item.selected ? scheme.primary : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: _kSidebarFixedItemHeight,
        child: Semantics(
          button: true,
          selected: item.selected,
          label: item.title,
          child: ListTile(
            selected: item.selected,
            selectedTileColor: surfaces.cardSelected,
            hoverColor: states.hoverTint,
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
            minTileHeight: _kSidebarFixedItemHeight,
            minLeadingWidth: kSidebarRailWidth - 16,
            horizontalTitleGap: 8,
            contentPadding: const EdgeInsets.only(right: 8),
            leading: SizedBox(
              width: kSidebarRailWidth - 16,
              child: Center(
                child: SizedBox.square(
                  key: item.key,
                  dimension: _kSidebarRailButtonSize,
                  child: Icon(
                    item.effectiveIcon,
                    color: iconColor,
                    size: _kSidebarRailIconSize,
                  ),
                ),
              ),
            ),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface,
                fontSize: 13,
                fontWeight: AppTypography.platformWeight(FontWeight.w500),
                letterSpacing: 0,
                height: 1.2,
              ),
            ),
            trailing: item.count == null
                ? null
                : _SidebarFixedCount(item.count!),
            onTap: item.onTap,
          ),
        ),
      ),
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
        fontSize: 11,
        fontWeight: AppTypography.platformWeight(FontWeight.w600),
        letterSpacing: 0,
      ),
    );
  }
}

class _AccountPanelFooter extends StatelessWidget {
  const _AccountPanelFooter({
    required this.account,
    required this.sync,
    required this.showSyncStatus,
    required this.onTap,
    required this.accountAnchorKey,
  });

  final Account account;
  final SyncStatusState sync;
  final bool showSyncStatus;
  final VoidCallback onTap;
  final Key accountAnchorKey;

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

    final showSync = showSyncStatus && sync.visible;
    final syncText = _syncText(l10n);
    final borderRadius = BorderRadius.circular(8);

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaces.card,
          border: Border(top: BorderSide(color: surfaces.subtleDivider)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Tooltip(
            message: account.name,
            child: Semantics(
              button: true,
              label: account.name,
              child: Material(
                key: accountAnchorKey,
                color: Colors.transparent,
                borderRadius: borderRadius,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: borderRadius,
                  hoverColor: states.hoverTint,
                  child: SizedBox(
                    height: _kSidebarAccountHeight - 12,
                    child: Row(
                      children: [
                        SizedBox(
                          width: kSidebarRailWidth - 12,
                          child: Center(
                            child: AccountAvatar(
                              key: const Key('sidebar_account_button'),
                              account: account,
                              radius: _kSidebarAccountAvatarRadius,
                              showTypeBadge: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  account.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurface,
                                    fontSize: 13,
                                    fontWeight: AppTypography.platformWeight(
                                      FontWeight.w500,
                                    ),
                                    letterSpacing: 0,
                                    height: 1.2,
                                  ),
                                ),
                                AnimatedSwitcher(
                                  duration: duration,
                                  switchInCurve: AppMotion.standardCurve,
                                  switchOutCurve:
                                      AppMotion.emphasizedAccelerate,
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
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Row(
                                            children: [
                                              if (sync.running)
                                                const SizedBox(
                                                  width: 10,
                                                  height: 10,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              else
                                                Icon(
                                                  sync.label ==
                                                          SyncStatusLabel.failed
                                                      ? FleurIcons.statusError
                                                      : FleurIcons.statusOk,
                                                  size: 12,
                                                  color:
                                                      sync.label ==
                                                          SyncStatusLabel.failed
                                                      ? states.errorAccent
                                                      : states.syncAccent,
                                                ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: OverflowMarquee(
                                                  text: syncText,
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            AppTypography.platformWeight(
                                                              FontWeight.w500,
                                                            ),
                                                        letterSpacing: 0,
                                                        height: 1.15,
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
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          FleurIcons.accountSwitcher,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
