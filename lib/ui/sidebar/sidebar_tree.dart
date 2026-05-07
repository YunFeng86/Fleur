import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../models/feed.dart';
import '../../models/tag.dart';
import '../../services/sync/backend_capabilities.dart';
import '../../services/sync/backend_sync_semantics.dart';
import '../../theme/app_typography.dart';
import '../../ui/sidebar/sidebar_management_actions.dart';
import '../../ui/sidebar/sidebar_selection_actions.dart';
import '../../utils/platform.dart';
import '../../utils/tag_colors.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/favicon_circle.dart';
import '../../widgets/tree_disclosure_button.dart';

class SidebarSearchField extends StatelessWidget {
  const SidebarSearchField({
    super.key,
    required this.controller,
    required this.showDrawerClose,
    required this.onCloseDrawer,
  });

  final TextEditingController controller;
  final bool showDrawerClose;
  final VoidCallback onCloseDrawer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          if (showDrawerClose) ...[
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onCloseDrawer,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class SidebarNavigationTree extends StatelessWidget {
  const SidebarNavigationTree({
    super.key,
    required this.scrollController,
    required this.searchText,
    required this.feeds,
    required this.categories,
    required this.tags,
    required this.allUnreadCounts,
    required this.selectedFeedId,
    required this.selectedCategoryId,
    required this.selectedTagId,
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

  final ScrollController scrollController;
  final String searchText;
  final AsyncValue<List<Feed>> feeds;
  final AsyncValue<List<Category>> categories;
  final AsyncValue<List<Tag>> tags;
  final AsyncValue<Map<int?, int>> allUnreadCounts;
  final int? selectedFeedId;
  final int? selectedCategoryId;
  final int? selectedTagId;
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showsSourceRefresh = capabilities.isVisible(
      BackendFeature.refreshAllSources,
    );
    final showsRootRefresh =
        showsSourceRefresh || capabilities.isVisible(BackendFeature.syncNow);
    final rootRefreshLabel =
        !showsSourceRefresh && syncSemantics.isAccountWideRefresh
        ? l10n.syncAccount
        : l10n.refreshAll;

    return feeds.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text(l10n.errorMessage(error.toString()))),
      data: (feedItems) {
        final filteredFeeds = searchText.isEmpty
            ? feedItems
            : feedItems.where((feed) {
                final title = (feed.userTitle ?? feed.title ?? '')
                    .toLowerCase();
                final url = feed.url.toLowerCase();
                return title.contains(searchText) || url.contains(searchText);
              }).toList();

        return categories.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text(l10n.errorMessage(error.toString()))),
          data: (categoryItems) {
            final feedsByCategory = <int?, List<Feed>>{};
            for (final feed in filteredFeeds) {
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

            final children = <Widget>[
              allUnreadCounts.when(
                loading: () => _SidebarItem(
                  selected:
                      !starredOnly &&
                      !readLaterOnly &&
                      selectedFeedId == null &&
                      selectedCategoryId == null &&
                      selectedTagId == null,
                  icon: Icons.all_inbox,
                  title: l10n.all,
                  onTap: selectionActions.selectAll,
                ),
                error: (_, _) => _SidebarItem(
                  key: const ValueKey('all_inbox'),
                  selected:
                      !starredOnly &&
                      !readLaterOnly &&
                      selectedFeedId == null &&
                      selectedCategoryId == null &&
                      selectedTagId == null,
                  icon: Icons.all_inbox,
                  title: l10n.all,
                  onTap: selectionActions.selectAll,
                ),
                data: (counts) => _SidebarItem(
                  selected:
                      !starredOnly &&
                      !readLaterOnly &&
                      selectedFeedId == null &&
                      selectedCategoryId == null &&
                      selectedTagId == null,
                  icon: Icons.all_inbox,
                  title: l10n.all,
                  count: counts[null] ?? 0,
                  onTap: selectionActions.selectAll,
                ),
              ),
              tags.when(
                data: (tagItems) {
                  if (tagItems.isEmpty) return const SizedBox.shrink();
                  return ExpansionTile(
                    leading: const Icon(Icons.label_outline),
                    title: Text(l10n.tags),
                    initiallyExpanded: selectedTagId != null,
                    children: tagItems.map((tag) {
                      return _SidebarItem(
                        selected: selectedTagId == tag.id,
                        icon: Icons.label,
                        title: tag.name,
                        iconColor: resolveTagColor(tag.name, tag.color),
                        onTap: () => selectionActions.selectTag(tag.id),
                        indent: 16,
                      );
                    }).toList(),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.subscriptions,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: AppTypography.platformWeight(
                            FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    PopupMenuButton<_SidebarTreeMenu>(
                      icon: const Icon(Icons.more_horiz, size: 20),
                      tooltip: l10n.more,
                      iconSize: 20,
                      onSelected: (value) async {
                        switch (value) {
                          case _SidebarTreeMenu.settings:
                            await managementActions.openSettings();
                            return;
                          case _SidebarTreeMenu.refreshAll:
                            await managementActions.refreshAll();
                            return;
                          case _SidebarTreeMenu.importOpml:
                            await managementActions.importOpml();
                            return;
                          case _SidebarTreeMenu.exportOpml:
                            await managementActions.exportOpml();
                            return;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _SidebarTreeMenu.settings,
                          child: Text(l10n.settings),
                        ),
                        if (showsRootRefresh)
                          PopupMenuItem(
                            value: _SidebarTreeMenu.refreshAll,
                            child: Text(rootRefreshLabel),
                          ),
                        if (capabilities.isVisible(BackendFeature.importOpml))
                          PopupMenuItem(
                            value: _SidebarTreeMenu.importOpml,
                            child: Text(l10n.importOpml),
                          ),
                        if (capabilities.isVisible(BackendFeature.exportOpml))
                          PopupMenuItem(
                            value: _SidebarTreeMenu.exportOpml,
                            child: Text(l10n.exportOpml),
                          ),
                      ],
                    ),
                    if (capabilities.isVisible(
                      BackendFeature.addSubscription,
                    )) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        iconSize: 20,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        tooltip: l10n.addSubscription,
                        onPressed: onAddFeed,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                    if (capabilities.isVisible(BackendFeature.addCategory)) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        iconSize: 20,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        tooltip: l10n.newCategory,
                        onPressed: onAddCategory,
                        icon: const Icon(Icons.create_new_folder_outlined),
                      ),
                    ],
                  ],
                ),
              ),
            ];

            for (final category in categoryItems) {
              final categoryFeeds =
                  feedsByCategory[category.id] ?? const <Feed>[];
              if (searchText.isNotEmpty && categoryFeeds.isEmpty) continue;

              children.add(
                _SidebarCategoryTile(
                  category: category,
                  feeds: categoryFeeds,
                  selectedFeedId: selectedFeedId,
                  selectedCategoryId: selectedCategoryId,
                  starredOnly: starredOnly,
                  unreadCount: unreadByCategoryId[category.id] ?? 0,
                  unreadCounts: unreadCounts,
                  expanded: expandedCategoryId == category.id,
                  onExpandedCategoryChanged: onExpandedCategoryChanged,
                  selectionActions: selectionActions,
                  managementActions: managementActions,
                  capabilities: capabilities,
                  syncSemantics: syncSemantics,
                  onShowCategoryMenu: onShowCategoryMenu,
                  onShowFeedMenu: onShowFeedMenu,
                ),
              );
            }

            final uncategorizedFeeds = feedsByCategory[null] ?? const <Feed>[];
            if (searchText.isEmpty || uncategorizedFeeds.isNotEmpty) {
              for (final feed in uncategorizedFeeds) {
                children.add(
                  _SidebarFeedTile(
                    key: ValueKey('feed_${feed.id}'),
                    feed: feed,
                    selectedFeedId: selectedFeedId,
                    unreadCount: unreadCounts?[feed.id],
                    selectionActions: selectionActions,
                    managementActions: managementActions,
                    capabilities: capabilities,
                    onShowFeedMenu: onShowFeedMenu,
                  ),
                );
              }
            }

            return AppScrollbar(
              controller: scrollController,
              thumbVisibility: isDesktop,
              interactive: true,
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: children,
              ),
            );
          },
        );
      },
    );
  }
}

enum _SidebarTreeMenu { settings, refreshAll, importOpml, exportOpml }

class _SidebarCategoryTile extends StatelessWidget {
  const _SidebarCategoryTile({
    required this.category,
    required this.feeds,
    required this.selectedFeedId,
    required this.selectedCategoryId,
    required this.starredOnly,
    required this.unreadCount,
    required this.unreadCounts,
    required this.expanded,
    required this.onExpandedCategoryChanged,
    required this.selectionActions,
    required this.managementActions,
    required this.capabilities,
    required this.syncSemantics,
    required this.onShowCategoryMenu,
    required this.onShowFeedMenu,
  });

  final Category category;
  final List<Feed> feeds;
  final int? selectedFeedId;
  final int? selectedCategoryId;
  final bool starredOnly;
  final int unreadCount;
  final Map<int?, int>? unreadCounts;
  final bool expanded;
  final ValueChanged<int?> onExpandedCategoryChanged;
  final SidebarSelectionActions selectionActions;
  final SidebarManagementActions managementActions;
  final BackendCapabilities capabilities;
  final BackendSyncSemantics syncSemantics;
  final Future<void> Function(Category category) onShowCategoryMenu;
  final Future<void> Function(Feed feed) onShowFeedMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected =
        !starredOnly &&
        selectedFeedId == null &&
        selectedCategoryId == category.id;
    final hasCategoryActions =
        capabilities.isVisible(BackendFeature.renameCategory) ||
        capabilities.isVisible(BackendFeature.deleteCategory);

    return Semantics(
      container: true,
      selected: selected,
      expanded: expanded,
      child: Column(
        children: [
          ListTile(
            selected: selected,
            minLeadingWidth: 0,
            horizontalTitleGap: 4,
            leading: TreeDisclosureButton(
              expanded: expanded,
              tooltip: expanded ? l10n.collapse : l10n.expand,
              onPressed: () =>
                  onExpandedCategoryChanged(expanded ? null : category.id),
            ),
            title: Text(category.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _UnreadBadge(unreadCount),
                if (syncSemantics.isRemoteReadOnlyTaxonomy)
                  Tooltip(
                    message: l10n.remoteReadOnlyTaxonomyTitle,
                    child: Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (!isDesktop && hasCategoryActions)
                  IconButton(
                    tooltip: l10n.more,
                    onPressed: () => onShowCategoryMenu(category),
                    icon: const Icon(Icons.more_vert),
                  ),
                if (isDesktop && hasCategoryActions)
                  MenuAnchor(
                    menuChildren: [
                      if (capabilities.isVisible(BackendFeature.renameCategory))
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              managementActions.renameCategory(category),
                          child: Text(l10n.rename),
                        ),
                      if (capabilities.isVisible(BackendFeature.deleteCategory))
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              managementActions.deleteCategory(category),
                          child: Text(l10n.deleteCategory),
                        ),
                    ],
                    builder: (context, controller, child) {
                      return IconButton(
                        tooltip: l10n.more,
                        onPressed: () {
                          controller.isOpen
                              ? controller.close()
                              : controller.open();
                        },
                        icon: const Icon(Icons.more_vert),
                      );
                    },
                  ),
              ],
            ),
            onTap: () => selectionActions.selectCategory(category.id),
            onLongPress: isDesktop || !hasCategoryActions
                ? null
                : () => onShowCategoryMenu(category),
          ),
          if (expanded)
            ...feeds.map(
              (feed) => _SidebarFeedTile(
                key: ValueKey('feed_${feed.id}'),
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
        ],
      ),
    );
  }
}

class _SidebarFeedTile extends StatelessWidget {
  const _SidebarFeedTile({
    super.key,
    required this.feed,
    required this.selectedFeedId,
    required this.unreadCount,
    required this.selectionActions,
    required this.managementActions,
    required this.capabilities,
    required this.onShowFeedMenu,
    this.indent = 0,
  });

  final Feed feed;
  final int? selectedFeedId;
  final int? unreadCount;
  final double indent;
  final SidebarSelectionActions selectionActions;
  final SidebarManagementActions managementActions;
  final BackendCapabilities capabilities;
  final Future<void> Function(Feed feed) onShowFeedMenu;

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
    final canMove =
        capabilities.isVisible(BackendFeature.moveSubscriptionToCategory) ||
        capabilities.isVisible(BackendFeature.moveSubscriptionToUncategorized);
    final hasFeedActions =
        capabilities.isVisible(BackendFeature.clientFeedSettings) ||
        capabilities.isVisible(BackendFeature.refreshSubscriptionSource) ||
        capabilities.isVisible(BackendFeature.offlineCache) ||
        canMove ||
        capabilities.isVisible(BackendFeature.deleteSubscription);

    return ListTile(
      selected: selectedFeedId == feed.id,
      contentPadding: EdgeInsets.only(left: 16 + indent, right: 8),
      leading: FaviconCircle(
        siteUri: siteUri,
        diameter: 28,
        avatarSize: 18,
        fallbackIcon: Icons.rss_feed,
        fallbackColor: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(displayTitle),
      subtitle:
          (feed.userTitle?.trim().isNotEmpty == true ||
              feed.title?.trim().isNotEmpty == true)
          ? Text(feed.url, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: isDesktop
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unreadCount != null) _UnreadBadge(unreadCount!),
                if (hasFeedActions)
                  MenuAnchor(
                    menuChildren: [
                      if (capabilities.isVisible(
                        BackendFeature.clientFeedSettings,
                      ))
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              managementActions.editFeedTitle(feed),
                          child: Text(l10n.edit),
                        ),
                      if (capabilities.isVisible(
                        BackendFeature.refreshSubscriptionSource,
                      ))
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.refresh),
                          onPressed: () => managementActions.refreshFeed(feed),
                          child: Text(l10n.refresh),
                        ),
                      if (capabilities.isVisible(BackendFeature.offlineCache))
                        MenuItemButton(
                          leadingIcon: const Icon(
                            Icons.download_for_offline_outlined,
                          ),
                          onPressed: () =>
                              managementActions.cacheFeedOffline(feed),
                          child: Text(l10n.makeAvailableOffline),
                        ),
                      if (canMove)
                        MenuItemButton(
                          leadingIcon: const Icon(
                            Icons.drive_file_move_outline,
                          ),
                          onPressed: () =>
                              managementActions.moveFeedToCategory(feed),
                          child: Text(l10n.moveToCategory),
                        ),
                      if (capabilities.isVisible(
                        BackendFeature.deleteSubscription,
                      ))
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.delete_outline),
                          onPressed: () => managementActions.deleteFeed(feed),
                          child: Text(l10n.deleteSubscription),
                        ),
                    ],
                    builder: (context, controller, child) {
                      return IconButton(
                        tooltip: l10n.more,
                        onPressed: () {
                          controller.isOpen
                              ? controller.close()
                              : controller.open();
                        },
                        icon: const Icon(Icons.more_vert),
                      );
                    },
                  ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unreadCount != null) _UnreadBadge(unreadCount!),
                if (hasFeedActions)
                  IconButton(
                    tooltip: l10n.more,
                    onPressed: () => onShowFeedMenu(feed),
                    icon: const Icon(Icons.more_vert),
                  ),
              ],
            ),
      onTap: () => selectionActions.selectFeed(feed.id),
      onLongPress: isDesktop || !hasFeedActions
          ? null
          : () => onShowFeedMenu(feed),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: AppTypography.platformWeight(FontWeight.w700),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    super.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
    this.count,
    this.indent = 0,
    this.iconColor,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int? count;
  final double indent;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      contentPadding: EdgeInsets.only(left: 16 + indent, right: 8),
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      trailing: count == null ? null : _UnreadBadge(count!),
      onTap: onTap,
    );
  }
}
