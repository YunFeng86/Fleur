import 'dart:async';

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
import '../actions/subscription_object_menus.dart';
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

class SidebarNavigationTree extends StatefulWidget {
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
  State<SidebarNavigationTree> createState() => _SidebarNavigationTreeState();
}

class _SidebarScrollAnchor {
  const _SidebarScrollAnchor({required this.rowId, required this.top});

  final String rowId;
  final double top;
}

class _SidebarTreeRow {
  const _SidebarTreeRow({required this.rowId, required this.builder});

  final String rowId;
  final WidgetBuilder builder;
}

class _SidebarAnchorRegistryRow extends StatefulWidget {
  const _SidebarAnchorRegistryRow({
    super.key,
    required this.rowId,
    required this.child,
    required this.onRegister,
    required this.onUnregister,
  });

  final String rowId;
  final Widget child;
  final void Function(String rowId, BuildContext context) onRegister;
  final void Function(String rowId, BuildContext context) onUnregister;

  @override
  State<_SidebarAnchorRegistryRow> createState() =>
      _SidebarAnchorRegistryRowState();
}

class _SidebarAnchorRegistryRowState extends State<_SidebarAnchorRegistryRow> {
  @override
  void initState() {
    super.initState();
    widget.onRegister(widget.rowId, context);
  }

  @override
  void didUpdateWidget(covariant _SidebarAnchorRegistryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rowId != widget.rowId) {
      oldWidget.onUnregister(oldWidget.rowId, context);
      widget.onRegister(widget.rowId, context);
    }
  }

  @override
  void dispose() {
    widget.onUnregister(widget.rowId, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _SidebarNavigationTreeState extends State<SidebarNavigationTree> {
  final GlobalKey _listViewKey = GlobalKey();
  final Map<String, BuildContext> _rowContexts = <String, BuildContext>{};
  bool? _tagsExpanded;

  ScrollController get scrollController => widget.scrollController;
  String get searchText => widget.searchText;
  AsyncValue<List<Feed>> get feeds => widget.feeds;
  AsyncValue<List<Category>> get categories => widget.categories;
  AsyncValue<List<Tag>> get tags => widget.tags;
  AsyncValue<Map<int?, int>> get allUnreadCounts => widget.allUnreadCounts;
  int? get selectedFeedId => widget.selectedFeedId;
  int? get selectedCategoryId => widget.selectedCategoryId;
  int? get selectedTagId => widget.selectedTagId;
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

  void _registerRow(String rowId, BuildContext context) {
    _rowContexts[rowId] = context;
  }

  void _unregisterRow(String rowId, BuildContext context) {
    if (identical(_rowContexts[rowId], context)) {
      _rowContexts.remove(rowId);
    }
  }

  _SidebarScrollAnchor? _captureScrollAnchor() {
    if (!scrollController.hasClients) return null;
    final listBox = _listViewKey.currentContext?.findRenderObject();
    if (listBox is! RenderBox || !listBox.hasSize) return null;
    final viewportTop = listBox.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + listBox.size.height;

    _SidebarScrollAnchor? bestFullyVisible;
    double bestFullyVisibleTop = double.infinity;
    _SidebarScrollAnchor? bestPartial;
    double bestPartialDistance = double.infinity;
    for (final entry in _rowContexts.entries) {
      final rowBox = entry.value.findRenderObject();
      if (rowBox is! RenderBox || !rowBox.attached || !rowBox.hasSize) {
        continue;
      }
      final top = rowBox.localToGlobal(Offset.zero).dy;
      final bottom = top + rowBox.size.height;
      if (bottom < viewportTop || top > viewportBottom) continue;
      if (top >= viewportTop) {
        if (top < bestFullyVisibleTop) {
          bestFullyVisibleTop = top;
          bestFullyVisible = _SidebarScrollAnchor(rowId: entry.key, top: top);
        }
      } else {
        final distance = (top - viewportTop).abs();
        if (distance < bestPartialDistance) {
          bestPartialDistance = distance;
          bestPartial = _SidebarScrollAnchor(rowId: entry.key, top: top);
        }
      }
    }
    return bestFullyVisible ?? bestPartial;
  }

  void _restoreScrollAnchor(_SidebarScrollAnchor? anchor) {
    if (!mounted || anchor == null || !scrollController.hasClients) return;
    final rowBox = _rowContexts[anchor.rowId]?.findRenderObject();
    if (rowBox is! RenderBox || !rowBox.attached || !rowBox.hasSize) return;
    final nextTop = rowBox.localToGlobal(Offset.zero).dy;
    final delta = nextTop - anchor.top;
    if (delta.abs() < 0.5) return;
    final position = scrollController.position;
    final next = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((next - position.pixels).abs() < 0.5) return;
    scrollController.jumpTo(next);
  }

  void _runWithScrollAnchor(VoidCallback action) {
    final anchor = _captureScrollAnchor();
    action();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScrollAnchor(anchor);
    });
  }

  @override
  void didUpdateWidget(covariant SidebarNavigationTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTagId != null &&
        widget.selectedTagId != oldWidget.selectedTagId) {
      _tagsExpanded = true;
    }
  }

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
            final tagsExpanded = _tagsExpanded ?? selectedTagId != null;

            final rows = <_SidebarTreeRow>[
              _SidebarTreeRow(
                rowId: 'scope:all',
                builder: (_) => allUnreadCounts.when(
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
              ),
            ];
            tags.when<void>(
              data: (tagItems) {
                if (tagItems.isEmpty) return;
                rows.add(
                  _SidebarTreeRow(
                    rowId: 'section:tags',
                    builder: (_) => _SidebarTagHeaderTile(
                      expanded: tagsExpanded,
                      onToggleExpanded: () {
                        _runWithScrollAnchor(() {
                          setState(() => _tagsExpanded = !tagsExpanded);
                        });
                      },
                    ),
                  ),
                );
                if (!tagsExpanded) return;
                for (final tag in tagItems) {
                  rows.add(
                    _SidebarTreeRow(
                      rowId: 'tag:${tag.id}',
                      builder: (_) => _SidebarItem(
                        selected: selectedTagId == tag.id,
                        icon: Icons.label,
                        title: tag.name,
                        iconColor: resolveTagColor(tag.name, tag.color),
                        onTap: () => _runWithScrollAnchor(
                          () => selectionActions.selectTag(tag.id),
                        ),
                        indent: 16,
                      ),
                    ),
                  );
                }
              },
              loading: () {},
              error: (_, _) {},
            );
            rows.add(
              _SidebarTreeRow(
                rowId: 'section:subscriptions',
                builder: (_) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.subscriptions,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
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
                      if (capabilities.isVisible(
                        BackendFeature.addCategory,
                      )) ...[
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
              ),
            );

            for (final category in categoryItems) {
              final categoryFeeds =
                  feedsByCategory[category.id] ?? const <Feed>[];
              if (searchText.isNotEmpty && categoryFeeds.isEmpty) continue;

              final expanded = expandedCategoryId == category.id;
              rows.add(
                _SidebarTreeRow(
                  rowId: 'category:${category.id}',
                  builder: (_) => _SidebarCategoryTile(
                    category: category,
                    selectedFeedId: selectedFeedId,
                    selectedCategoryId: selectedCategoryId,
                    starredOnly: starredOnly,
                    unreadCount: unreadByCategoryId[category.id] ?? 0,
                    expanded: expanded,
                    onExpandedCategoryChanged: (categoryId) {
                      _runWithScrollAnchor(
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
            if (searchText.isEmpty || uncategorizedFeeds.isNotEmpty) {
              for (final feed in uncategorizedFeeds) {
                rows.add(
                  _SidebarTreeRow(
                    rowId: 'feed:${feed.id}',
                    builder: (_) => _SidebarFeedTile(
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
                key: _listViewKey,
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: rows.length,
                findChildIndexCallback: (key) {
                  if (key is ValueKey<String>) {
                    return rowIndexById[key.value];
                  }
                  return null;
                },
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return _SidebarAnchorRegistryRow(
                    key: ValueKey<String>(row.rowId),
                    rowId: row.rowId,
                    onRegister: _registerRow,
                    onUnregister: _unregisterRow,
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

class _SidebarTagHeaderTile extends StatelessWidget {
  const _SidebarTagHeaderTile({
    required this.expanded,
    required this.onToggleExpanded,
  });

  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      container: true,
      expanded: expanded,
      child: Column(
        children: [
          ListTile(
            minLeadingWidth: 0,
            horizontalTitleGap: 4,
            leading: TreeDisclosureButton(
              expanded: expanded,
              tooltip: expanded ? l10n.collapse : l10n.expand,
              onPressed: onToggleExpanded,
            ),
            title: Row(
              children: [
                const Icon(Icons.label_outline, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.tags)),
              ],
            ),
            onTap: onToggleExpanded,
          ),
        ],
      ),
    );
  }
}

enum _SidebarTreeMenu { settings, refreshAll, importOpml, exportOpml }

class _SidebarCategoryTile extends StatelessWidget {
  const _SidebarCategoryTile({
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

    final child = Semantics(
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
                    menuChildren: SubscriptionObjectMenus.menuButtons(
                      context: context,
                      items: menuItems,
                      onSelected: (action) => unawaited(_performAction(action)),
                    ),
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
  }
}

class _SidebarFeedTile extends StatelessWidget {
  const _SidebarFeedTile({
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: isDesktop && hasFeedActions
          ? (details) => unawaited(
              _showContextMenu(context, details.globalPosition, menuItems),
            )
          : null,
      child: ListTile(
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
                      menuChildren: SubscriptionObjectMenus.menuButtons(
                        context: context,
                        items: menuItems,
                        onSelected: (action) =>
                            unawaited(_performAction(action)),
                      ),
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
      ),
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
