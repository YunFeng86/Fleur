import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/features/subscriptions/subscriptions.dart';

import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../models/feed.dart';
import '../../services/sync/backend_capabilities.dart';
import '../../services/sync/backend_sync_semantics.dart';
import '../../theme/fleur_icons.dart';
import '../../theme/fleur_theme_extensions.dart';
import '../sidebar_layout.dart';
import '../app_menu.dart';
import '../../ui/sidebar/sidebar_management_actions.dart';
import '../../ui/sidebar/sidebar_selection_actions.dart';
import '../../utils/platform.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/favicon_circle.dart';
import '../design_system/design_system.dart';
import '../../widgets/scroll_anchor_registry.dart';
import '../../widgets/tree_disclosure_button.dart';

class SidebarNavigationTree extends StatefulWidget {
  const SidebarNavigationTree({
    super.key,
    required this.presentationMode,
    required this.scrollController,
    required this.feeds,
    required this.categories,
    required this.allUnreadCounts,
    required this.selectedFeedId,
    required this.selectedCategoryId,
    required this.starredOnly,
    required this.readLaterOnly,
    required this.expandedCategoryId,
    required this.onExpandedCategoryChanged,
    required this.selectionActions,
    required this.managementActions,
    required this.capabilities,
    required this.syncSemantics,
    required this.onAddFeed,
    required this.onAddCategory,
    required this.onShowCategoryMenu,
    required this.onShowFeedMenu,
  });

  final SidebarPresentationMode presentationMode;
  final ScrollController scrollController;
  final AsyncValue<List<Feed>> feeds;
  final AsyncValue<List<Category>> categories;
  final AsyncValue<Map<int?, int>> allUnreadCounts;
  final int? selectedFeedId;
  final int? selectedCategoryId;
  final bool starredOnly;
  final bool readLaterOnly;
  final int? expandedCategoryId;
  final ValueChanged<int?> onExpandedCategoryChanged;
  final SidebarSelectionActions selectionActions;
  final SidebarManagementActions managementActions;
  final BackendCapabilities capabilities;
  final BackendSyncSemantics syncSemantics;
  final Future<void> Function() onAddFeed;
  final Future<void> Function() onAddCategory;
  final Future<void> Function(Category category) onShowCategoryMenu;
  final Future<void> Function(Feed feed) onShowFeedMenu;

  @override
  State<SidebarNavigationTree> createState() => _SidebarNavigationTreeState();
}

class _SidebarTreeRow {
  const _SidebarTreeRow({required this.rowId, required this.builder});

  final String rowId;
  final WidgetBuilder builder;
}

class _SidebarNavigationTreeState extends State<SidebarNavigationTree> {
  late final ScrollAnchorRegistry _scrollAnchors;

  @override
  void initState() {
    super.initState();
    _scrollAnchors = ScrollAnchorRegistry(
      scrollController: () => scrollController,
    );
  }

  @override
  void dispose() {
    _scrollAnchors.dispose();
    super.dispose();
  }

  SidebarPresentationMode get presentationMode => widget.presentationMode;
  ScrollController get scrollController => widget.scrollController;
  AsyncValue<List<Feed>> get feeds => widget.feeds;
  AsyncValue<List<Category>> get categories => widget.categories;
  AsyncValue<Map<int?, int>> get allUnreadCounts => widget.allUnreadCounts;
  int? get selectedFeedId => widget.selectedFeedId;
  int? get selectedCategoryId => widget.selectedCategoryId;
  bool get starredOnly => widget.starredOnly;
  bool get readLaterOnly => widget.readLaterOnly;
  int? get expandedCategoryId => widget.expandedCategoryId;
  ValueChanged<int?> get onExpandedCategoryChanged =>
      widget.onExpandedCategoryChanged;
  SidebarSelectionActions get selectionActions => widget.selectionActions;
  SidebarManagementActions get managementActions => widget.managementActions;
  BackendCapabilities get capabilities => widget.capabilities;
  BackendSyncSemantics get syncSemantics => widget.syncSemantics;
  Future<void> Function() get onAddFeed => widget.onAddFeed;
  Future<void> Function() get onAddCategory => widget.onAddCategory;
  Future<void> Function(Category category) get onShowCategoryMenu =>
      widget.onShowCategoryMenu;
  Future<void> Function(Feed feed) get onShowFeedMenu => widget.onShowFeedMenu;

  Future<void> _showRootContextMenu(
    Offset position,
    List<SubscriptionObjectMenuItem<SubscriptionRootMenuAction>> items,
  ) async {
    final action = await SubscriptionObjectMenus.showContextMenu(
      context: context,
      position: position,
      items: items,
    );
    if (!mounted || action == null) return;
    await _performRootAction(action);
  }

  Future<void> _performRootAction(SubscriptionRootMenuAction action) async {
    switch (action) {
      case SubscriptionRootMenuAction.showAll:
        selectionActions.selectAll();
        return;
      case SubscriptionRootMenuAction.addSubscription:
        await onAddFeed();
        return;
      case SubscriptionRootMenuAction.addCategory:
        await onAddCategory();
        return;
      case SubscriptionRootMenuAction.refreshAll:
        await managementActions.refreshAll();
        return;
      case SubscriptionRootMenuAction.importOpml:
        await managementActions.importOpml();
        return;
      case SubscriptionRootMenuAction.exportOpml:
        await managementActions.exportOpml();
        return;
      case SubscriptionRootMenuAction.settings:
        await managementActions.openSettings();
        return;
      case SubscriptionRootMenuAction.globalDefaults:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final collapsed = presentationMode == SidebarPresentationMode.collapsed;

    return feeds.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text(l10n.errorMessage(error.toString()))),
      data: (feedItems) {
        return categories.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text(l10n.errorMessage(error.toString()))),
          data: (categoryItems) {
            final feedsByCategory = <int?, List<Feed>>{};
            for (final feed in feedItems) {
              feedsByCategory.putIfAbsent(feed.categoryId, () => []).add(feed);
            }

            final unreadCounts = allUnreadCounts.value;
            final unreadByCategoryId = <int, int>{};
            if (unreadCounts != null) {
              for (final feed in feedItems) {
                final categoryId = feed.categoryId;
                if (categoryId == null) continue;
                final count = unreadCounts[feed.id] ?? 0;
                if (count <= 0) continue;
                unreadByCategoryId[categoryId] =
                    (unreadByCategoryId[categoryId] ?? 0) + count;
              }
            }
            final headerContextMenuItems =
                SubscriptionObjectMenus.sidebarHeaderItems(
                  l10n,
                  capabilities,
                  syncSemantics,
                );
            final showHeaderContextMenu =
                isDesktop && headerContextMenuItems.isNotEmpty
                ? (TapDownDetails details) => unawaited(
                    _showRootContextMenu(
                      details.globalPosition,
                      headerContextMenuItems,
                    ),
                  )
                : null;

            final rows = <_SidebarTreeRow>[];
            rows.add(
              _SidebarTreeRow(
                rowId: 'section:subscriptions',
                builder: (_) => collapsed
                    ? _SidebarCollapsedSectionTile(title: l10n.subscriptions)
                    : _SidebarSectionHeader(
                        title: l10n.subscriptions,
                        onSecondaryTapDown: showHeaderContextMenu,
                        showAddCategory: capabilities.isVisible(
                          BackendFeature.addCategory,
                        ),
                        onAddCategory: onAddCategory,
                      ),
              ),
            );

            for (final category in categoryItems) {
              final categoryFeeds =
                  feedsByCategory[category.id] ?? const <Feed>[];

              final expanded = expandedCategoryId == category.id;
              rows.add(
                _SidebarTreeRow(
                  rowId: 'category:${category.id}',
                  builder: (_) => _SidebarCategoryTile(
                    presentationMode: presentationMode,
                    category: category,
                    selectedFeedId: selectedFeedId,
                    selectedCategoryId: selectedCategoryId,
                    starredOnly: starredOnly,
                    unreadCount: unreadByCategoryId[category.id] ?? 0,
                    expanded: expanded,
                    onExpandedCategoryChanged: (categoryId) {
                      _scrollAnchors.runWithAnchor(
                        () => onExpandedCategoryChanged(categoryId),
                      );
                    },
                    selectionActions: selectionActions,
                    managementActions: managementActions,
                    capabilities: capabilities,
                    syncSemantics: syncSemantics,
                    onShowCategoryMenu: onShowCategoryMenu,
                  ),
                ),
              );
              if (!expanded) continue;
              for (final feed in categoryFeeds) {
                rows.add(
                  _SidebarTreeRow(
                    rowId: 'feed:${feed.id}',
                    builder: (_) => _SidebarFeedTile(
                      presentationMode: presentationMode,
                      feed: feed,
                      selectedFeedId: selectedFeedId,
                      unreadCount: unreadCounts?[feed.id],
                      indent: 16,
                      selectionActions: selectionActions,
                      managementActions: managementActions,
                      capabilities: capabilities,
                      onShowFeedMenu: onShowFeedMenu,
                    ),
                  ),
                );
              }
            }

            final uncategorizedFeeds = feedsByCategory[null] ?? const <Feed>[];
            for (final feed in uncategorizedFeeds) {
              rows.add(
                _SidebarTreeRow(
                  rowId: 'feed:${feed.id}',
                  builder: (_) => _SidebarFeedTile(
                    presentationMode: presentationMode,
                    feed: feed,
                    selectedFeedId: selectedFeedId,
                    unreadCount: unreadCounts?[feed.id],
                    selectionActions: selectionActions,
                    managementActions: managementActions,
                    capabilities: capabilities,
                    onShowFeedMenu: onShowFeedMenu,
                  ),
                ),
              );
            }

            final rowIndexById = <String, int>{
              for (var index = 0; index < rows.length; index++)
                rows[index].rowId: index,
            };

            return AppScrollbar(
              controller: scrollController,
              thumbVisibility: isDesktop,
              interactive: true,
              child: ListView.builder(
                key: _scrollAnchors.viewportKey,
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: rows.length,
                findChildIndexCallback: (key) {
                  if (key is ValueKey<String>) {
                    return rowIndexById[key.value];
                  }
                  return null;
                },
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return ScrollAnchorRegistryRow(
                    key: ValueKey<String>(row.rowId),
                    registry: _scrollAnchors,
                    rowId: row.rowId,
                    child: row.builder(context),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _SidebarCollapsedSectionTile extends StatelessWidget {
  const _SidebarCollapsedSectionTile({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: title,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
        child: SizedBox.square(
          dimension: 48,
          child: Icon(
            FleurIcons.feeds,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _SidebarSectionHeader extends StatelessWidget {
  const _SidebarSectionHeader({
    required this.title,
    required this.showAddCategory,
    required this.onAddCategory,
    this.onSecondaryTapDown,
  });

  final String title;
  final bool showAddCategory;
  final Future<void> Function() onAddCategory;
  final GestureTapDownCallback? onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final headerHeight = isDesktop ? 36.0 : 48.0;
    final headerPadding = isDesktop
        ? const EdgeInsets.fromLTRB(16, 0, 8, 0)
        : const EdgeInsets.fromLTRB(16, 8, 8, 4);
    return Padding(
      padding: headerPadding,
      child: SizedBox(
        height: headerHeight,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onSecondaryTapDown: onSecondaryTapDown,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            if (showAddCategory) ...[
              const SizedBox(width: 8),
              isDesktop
                  ? _SidebarActionIconButton(
                      tooltip: l10n.newCategory,
                      onPressed: onAddCategory,
                      icon: FleurIcons.addCategory,
                    )
                  : IconButton(
                      tooltip: l10n.newCategory,
                      iconSize: 20,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: onAddCategory,
                      icon: const Icon(FleurIcons.addCategory),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SidebarCollapsedTile extends StatelessWidget {
  const _SidebarCollapsedTile({
    required this.selected,
    required this.title,
    required this.icon,
    required this.onTap,
    this.onSecondaryTapDown,
    this.child,
  });

  final bool selected;
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final states = theme.fleurState;
    Widget tile = Tooltip(
      message: title,
      child: Semantics(
        button: true,
        selected: selected,
        label: title,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: InkResponse(
            onTap: onTap,
            hoverColor: states.hoverTint,
            radius: 24,
            child: SizedBox.square(
              dimension: 48,
              child: Center(
                child: FleurSelectionTransition(
                  selected: selected,
                  builder: (context, selection, _) {
                    final color = Color.lerp(
                      theme.colorScheme.onSurfaceVariant,
                      theme.colorScheme.primary,
                      selection,
                    );
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          Colors.transparent,
                          states.selectionTint,
                          selection,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: SizedBox.square(
                        dimension: 40,
                        child: Center(
                          child:
                              child ??
                              FleurAnimatedIcon(
                                icon: icon,
                                color: color,
                                size: 20,
                              ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (onSecondaryTapDown != null) {
      tile = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: onSecondaryTapDown,
        child: tile,
      );
    }
    return tile;
  }
}

class _SidebarCategoryTile extends StatelessWidget {
  const _SidebarCategoryTile({
    required this.presentationMode,
    required this.category,
    required this.selectedFeedId,
    required this.selectedCategoryId,
    required this.starredOnly,
    required this.unreadCount,
    required this.expanded,
    required this.onExpandedCategoryChanged,
    required this.selectionActions,
    required this.managementActions,
    required this.capabilities,
    required this.syncSemantics,
    required this.onShowCategoryMenu,
  });

  final SidebarPresentationMode presentationMode;
  final Category category;
  final int? selectedFeedId;
  final int? selectedCategoryId;
  final bool starredOnly;
  final int unreadCount;
  final bool expanded;
  final ValueChanged<int?> onExpandedCategoryChanged;
  final SidebarSelectionActions selectionActions;
  final SidebarManagementActions managementActions;
  final BackendCapabilities capabilities;
  final BackendSyncSemantics syncSemantics;
  final Future<void> Function(Category category) onShowCategoryMenu;

  Future<void> _showContextMenu(
    BuildContext context,
    Offset position,
    List<SubscriptionObjectMenuItem<SubscriptionCategoryMenuAction>> items,
  ) async {
    final action = await SubscriptionObjectMenus.showContextMenu(
      context: context,
      position: position,
      items: items,
    );
    if (!context.mounted || action == null) return;
    await _performAction(action);
  }

  Future<void> _performAction(SubscriptionCategoryMenuAction action) {
    return switch (action) {
      SubscriptionCategoryMenuAction.rename => managementActions.renameCategory(
        category,
      ),
      SubscriptionCategoryMenuAction.delete => managementActions.deleteCategory(
        category,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected =
        !starredOnly &&
        selectedFeedId == null &&
        selectedCategoryId == category.id;
    final menuItems = SubscriptionObjectMenus.categoryItems(l10n, capabilities);
    final hasCategoryActions = menuItems.isNotEmpty;
    final canAddFeed = capabilities.isVisible(BackendFeature.addSubscription);
    final canMarkRead =
        capabilities.isVisible(BackendFeature.articleReadState) &&
        unreadCount > 0;
    final railWidth = SidebarRailLayoutScope.widthOf(context);

    if (presentationMode == SidebarPresentationMode.collapsed) {
      return _SidebarCollapsedTile(
        selected: selected,
        title: category.name,
        icon: expanded ? FleurIcons.categoryOpen : FleurIcons.category,
        onTap: () => selectionActions.selectCategory(category.id),
        onSecondaryTapDown: isDesktop && hasCategoryActions
            ? (details) => unawaited(
                _showContextMenu(context, details.globalPosition, menuItems),
              )
            : null,
      );
    }

    return _SidebarRevealActions(
      builder: (context, showActions) {
        final child = Semantics(
          container: true,
          selected: selected,
          expanded: expanded,
          child: Column(
            children: [
              ListTile(
                selected: selected,
                contentPadding: const EdgeInsets.only(right: 12),
                minLeadingWidth: railWidth,
                horizontalTitleGap: 0,
                leading: SizedBox(
                  width: railWidth,
                  child: Center(
                    child: TreeDisclosureButton(
                      expanded: expanded,
                      tooltip: expanded ? l10n.collapse : l10n.expand,
                      onPressed: () => onExpandedCategoryChanged(
                        expanded ? null : category.id,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: _SidebarCategoryTrailing(
                  unreadCount: unreadCount,
                  showActions: showActions,
                  showReadOnlyLock: syncSemantics.isRemoteReadOnlyTaxonomy,
                  readOnlyTooltip: l10n.remoteReadOnlyTaxonomyTitle,
                  hasCategoryActions: hasCategoryActions,
                  canAddFeed: canAddFeed,
                  canMarkRead: canMarkRead,
                  onShowMenu: isDesktop
                      ? null
                      : () => onShowCategoryMenu(category),
                  menuItems: isDesktop
                      ? menuItems
                      : const <
                          SubscriptionObjectMenuItem<
                            SubscriptionCategoryMenuAction
                          >
                        >[],
                  onMenuActionSelected: (action) =>
                      unawaited(_performAction(action)),
                  onAddFeed: () async {
                    final feedId = await managementActions.addFeed(
                      initialCategoryId: category.id,
                    );
                    if (feedId == null) return;
                    onExpandedCategoryChanged(category.id);
                  },
                  onMarkRead: () =>
                      managementActions.markAllRead(categoryId: category.id),
                ),
                onTap: () => selectionActions.selectCategory(category.id),
                onLongPress: isDesktop || !hasCategoryActions
                    ? null
                    : () => onShowCategoryMenu(category),
              ),
            ],
          ),
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapDown: isDesktop && hasCategoryActions
              ? (details) => unawaited(
                  _showContextMenu(context, details.globalPosition, menuItems),
                )
              : null,
          child: child,
        );
      },
    );
  }
}

class _SidebarFeedTile extends StatelessWidget {
  const _SidebarFeedTile({
    required this.presentationMode,
    required this.feed,
    required this.selectedFeedId,
    required this.unreadCount,
    required this.selectionActions,
    required this.managementActions,
    required this.capabilities,
    required this.onShowFeedMenu,
    this.indent = 0,
  });

  final SidebarPresentationMode presentationMode;
  final Feed feed;
  final int? selectedFeedId;
  final int? unreadCount;
  final double indent;
  final SidebarSelectionActions selectionActions;
  final SidebarManagementActions managementActions;
  final BackendCapabilities capabilities;
  final Future<void> Function(Feed feed) onShowFeedMenu;

  Future<void> _showContextMenu(
    BuildContext context,
    Offset position,
    List<SubscriptionObjectMenuItem<SubscriptionFeedMenuAction>> items,
  ) async {
    final action = await SubscriptionObjectMenus.showContextMenu(
      context: context,
      position: position,
      items: items,
    );
    if (!context.mounted || action == null) return;
    await _performAction(action);
  }

  Future<void> _performAction(SubscriptionFeedMenuAction action) {
    return switch (action) {
      SubscriptionFeedMenuAction.rename => managementActions.editFeedTitle(
        feed,
      ),
      SubscriptionFeedMenuAction.refresh => managementActions.refreshFeed(feed),
      SubscriptionFeedMenuAction.offlineCache =>
        managementActions.cacheFeedOffline(feed),
      SubscriptionFeedMenuAction.move => managementActions.moveFeedToCategory(
        feed,
      ),
      SubscriptionFeedMenuAction.delete => managementActions.deleteFeed(feed),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final displayTitle = feed.userTitle?.trim().isNotEmpty == true
        ? feed.userTitle!
        : (feed.title?.trim().isNotEmpty == true ? feed.title! : feed.url);
    final siteUri = Uri.tryParse(
      (feed.siteUrl?.trim().isNotEmpty == true)
          ? feed.siteUrl!.trim()
          : feed.url,
    );
    final menuItems = SubscriptionObjectMenus.feedItems(l10n, capabilities);
    final hasFeedActions = menuItems.isNotEmpty;
    final selected = selectedFeedId == feed.id;
    final canMarkRead =
        capabilities.isVisible(BackendFeature.articleReadState) &&
        (unreadCount ?? 0) > 0;
    final railWidth = SidebarRailLayoutScope.widthOf(context);

    if (presentationMode == SidebarPresentationMode.collapsed) {
      return _SidebarCollapsedTile(
        selected: selected,
        title: displayTitle,
        icon: FleurIcons.feed,
        onTap: () => selectionActions.selectFeed(feed.id),
        onSecondaryTapDown: isDesktop && hasFeedActions
            ? (details) => unawaited(
                _showContextMenu(context, details.globalPosition, menuItems),
              )
            : null,
        child: Center(
          child: FaviconCircle(
            siteUri: siteUri,
            diameter: 28,
            avatarSize: 18,
            fallbackIcon: FleurIcons.feed,
            fallbackColor: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return _SidebarRevealActions(
      builder: (context, showActions) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapDown: isDesktop && hasFeedActions
              ? (details) => unawaited(
                  _showContextMenu(context, details.globalPosition, menuItems),
                )
              : null,
          child: ListTile(
            selected: selected,
            contentPadding: const EdgeInsets.only(right: 16),
            minLeadingWidth: railWidth + indent,
            horizontalTitleGap: 0,
            leading: SizedBox(
              width: railWidth + indent,
              child: Padding(
                padding: EdgeInsets.only(left: indent),
                child: Center(
                  child: FaviconCircle(
                    siteUri: siteUri,
                    diameter: 28,
                    avatarSize: 18,
                    fallbackIcon: FleurIcons.feed,
                    fallbackColor: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            title: Text(
              displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _SidebarFeedTrailing(
              unreadCount: unreadCount ?? 0,
              showActions: showActions,
              hasFeedActions: hasFeedActions,
              canMarkRead: canMarkRead,
              onShowMenu: isDesktop ? null : () => onShowFeedMenu(feed),
              menuItems: isDesktop
                  ? menuItems
                  : const <
                      SubscriptionObjectMenuItem<SubscriptionFeedMenuAction>
                    >[],
              onMenuActionSelected: (action) =>
                  unawaited(_performAction(action)),
              onMarkRead: () => managementActions.markAllRead(feedId: feed.id),
            ),
            onTap: () => selectionActions.selectFeed(feed.id),
            onLongPress: isDesktop || !hasFeedActions
                ? null
                : () => onShowFeedMenu(feed),
          ),
        );
      },
    );
  }
}

typedef _SidebarRevealBuilder =
    Widget Function(BuildContext context, bool showActions);

class _SidebarRevealActions extends StatefulWidget {
  const _SidebarRevealActions({required this.builder});

  final _SidebarRevealBuilder builder;

  @override
  State<_SidebarRevealActions> createState() => _SidebarRevealActionsState();
}

class _SidebarRevealActionsState extends State<_SidebarRevealActions> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final showActions = _hovered || _focused;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (_hovered) return;
        setState(() => _hovered = true);
      },
      onExit: (_) {
        if (!_hovered) return;
        setState(() => _hovered = false);
      },
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) {
          if (_focused == value) return;
          setState(() => _focused = value);
        },
        child: widget.builder(context, showActions),
      ),
    );
  }
}

class _SidebarCategoryTrailing extends StatelessWidget {
  const _SidebarCategoryTrailing({
    required this.unreadCount,
    required this.showActions,
    required this.showReadOnlyLock,
    required this.readOnlyTooltip,
    required this.hasCategoryActions,
    required this.canAddFeed,
    required this.canMarkRead,
    required this.onShowMenu,
    required this.menuItems,
    required this.onMenuActionSelected,
    required this.onAddFeed,
    required this.onMarkRead,
  });

  static const double _actionsWidth = 96;

  final int unreadCount;
  final bool showActions;
  final bool showReadOnlyLock;
  final String readOnlyTooltip;
  final bool hasCategoryActions;
  final bool canAddFeed;
  final bool canMarkRead;
  final VoidCallback? onShowMenu;
  final List<SubscriptionObjectMenuItem<SubscriptionCategoryMenuAction>>
  menuItems;
  final ValueChanged<SubscriptionCategoryMenuAction> onMenuActionSelected;
  final Future<void> Function() onAddFeed;
  final Future<void> Function() onMarkRead;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasActions = hasCategoryActions || canAddFeed || canMarkRead;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showReadOnlyLock)
          Tooltip(
            message: readOnlyTooltip,
            child: Icon(
              FleurIcons.lock,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        if (hasActions)
          SizedBox(
            width: _actionsWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: showActions
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasCategoryActions)
                          isDesktop
                              ? _SidebarMenuActionButton(
                                  tooltip: l10n.more,
                                  items: menuItems,
                                  onSelected: onMenuActionSelected,
                                )
                              : _SidebarActionIconButton(
                                  tooltip: l10n.more,
                                  onPressed: onShowMenu,
                                  icon: FleurIcons.moreVertical,
                                ),
                        if (canAddFeed)
                          _SidebarActionIconButton(
                            tooltip: l10n.addSubscription,
                            onPressed: () => unawaited(onAddFeed()),
                            icon: FleurIcons.add,
                          ),
                        if (canMarkRead)
                          _SidebarActionIconButton(
                            tooltip: l10n.markAllRead,
                            onPressed: () => unawaited(onMarkRead()),
                            icon: FleurIcons.markAllRead,
                          ),
                      ],
                    )
                  : _UnreadCountText(unreadCount),
            ),
          )
        else
          _UnreadCountText(unreadCount),
      ],
    );
  }
}

class _SidebarFeedTrailing extends StatelessWidget {
  const _SidebarFeedTrailing({
    required this.unreadCount,
    required this.showActions,
    required this.hasFeedActions,
    required this.canMarkRead,
    required this.onShowMenu,
    required this.menuItems,
    required this.onMenuActionSelected,
    required this.onMarkRead,
  });

  static const double _actionsWidth = 64;

  final int unreadCount;
  final bool showActions;
  final bool hasFeedActions;
  final bool canMarkRead;
  final VoidCallback? onShowMenu;
  final List<SubscriptionObjectMenuItem<SubscriptionFeedMenuAction>> menuItems;
  final ValueChanged<SubscriptionFeedMenuAction> onMenuActionSelected;
  final Future<void> Function() onMarkRead;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasActions = hasFeedActions || canMarkRead;

    if (!hasActions) return _UnreadCountText(unreadCount);

    return SizedBox(
      width: _actionsWidth,
      child: Align(
        alignment: Alignment.centerRight,
        child: showActions
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasFeedActions)
                    isDesktop
                        ? _SidebarMenuActionButton(
                            tooltip: l10n.more,
                            items: menuItems,
                            onSelected: onMenuActionSelected,
                          )
                        : _SidebarActionIconButton(
                            tooltip: l10n.more,
                            onPressed: onShowMenu,
                            icon: FleurIcons.moreVertical,
                          ),
                  if (canMarkRead)
                    _SidebarActionIconButton(
                      tooltip: l10n.markAllRead,
                      onPressed: () => unawaited(onMarkRead()),
                      icon: FleurIcons.markAllRead,
                    ),
                ],
              )
            : _UnreadCountText(unreadCount),
      ),
    );
  }
}

class _SidebarMenuActionButton<T> extends StatefulWidget {
  const _SidebarMenuActionButton({
    required this.tooltip,
    required this.items,
    required this.onSelected,
  });

  final String tooltip;
  final List<AppMenuItem<T>> items;
  final ValueChanged<T> onSelected;

  @override
  State<_SidebarMenuActionButton<T>> createState() =>
      _SidebarMenuActionButtonState<T>();
}

class _SidebarMenuActionButtonState<T>
    extends State<_SidebarMenuActionButton<T>> {
  final GlobalKey _buttonKey = GlobalKey();

  Future<void> _showMenu(BuildContext context) async {
    final renderObject = _buttonKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final position = renderObject.localToGlobal(
      renderObject.size.center(Offset.zero),
    );
    final action = await AppMenuHost.showAt<T>(
      context,
      position: position,
      items: widget.items,
    );
    if (action == null) return;
    widget.onSelected(action);
  }

  @override
  Widget build(BuildContext context) {
    return _SidebarActionIconButton(
      key: _buttonKey,
      tooltip: widget.tooltip,
      onPressed: widget.items.isEmpty
          ? null
          : () => unawaited(_showMenu(context)),
      icon: FleurIcons.moreVertical,
    );
  }
}

class _SidebarActionIconButton extends StatelessWidget {
  const _SidebarActionIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: tooltip,
      iconSize: 20,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        fixedSize: const WidgetStatePropertyAll(Size.square(32)),
        minimumSize: const WidgetStatePropertyAll(Size.square(32)),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withAlpha(96);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused) ||
              states.contains(WidgetState.pressed)) {
            return colorScheme.primary;
          }
          return colorScheme.onSurfaceVariant;
        }),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class _UnreadCountText extends StatelessWidget {
  const _UnreadCountText(this.count);

  static const double _rightInset = 8;
  static const double _textWidth = 30;

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _textWidth + _rightInset,
      child: Padding(
        padding: const EdgeInsets.only(right: _rightInset),
        child: Text(
          count > 99 ? '99+' : '$count',
          textAlign: TextAlign.right,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
