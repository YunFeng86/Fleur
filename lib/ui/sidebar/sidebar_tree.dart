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
import '../../theme/fleur_icons.dart';
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
                prefixIcon: const Icon(FleurIcons.search, size: 20),
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
            final allContextMenuItems = SubscriptionObjectMenus.sidebarAllItems(
              l10n,
              capabilities,
              syncSemantics,
            );
            final headerContextMenuItems =
                SubscriptionObjectMenus.sidebarHeaderItems(
                  l10n,
                  capabilities,
                  syncSemantics,
                );
            final showAllContextMenu =
                isDesktop && allContextMenuItems.isNotEmpty
                ? (TapDownDetails details) => unawaited(
                    _showRootContextMenu(
                      details.globalPosition,
                      allContextMenuItems,
                    ),
                  )
                : null;
            final showHeaderContextMenu =
                isDesktop && headerContextMenuItems.isNotEmpty
                ? (TapDownDetails details) => unawaited(
                    _showRootContextMenu(
                      details.globalPosition,
                      headerContextMenuItems,
                    ),
                  )
                : null;

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
                    icon: FleurIcons.allArticles,
                    title: l10n.all,
                    onSecondaryTapDown: showAllContextMenu,
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
                    icon: FleurIcons.allArticles,
                    title: l10n.all,
                    onSecondaryTapDown: showAllContextMenu,
                    onTap: selectionActions.selectAll,
                  ),
                  data: (counts) => _SidebarItem(
                    selected:
                        !starredOnly &&
                        !readLaterOnly &&
                        selectedFeedId == null &&
                        selectedCategoryId == null &&
                        selectedTagId == null,
                    icon: FleurIcons.allArticles,
                    title: l10n.all,
                    count: counts[null] ?? 0,
                    onSecondaryTapDown: showAllContextMenu,
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
                        icon: FleurIcons.tag,
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
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onSecondaryTapDown: showHeaderContextMenu,
                          child: SizedBox(
                            height: 48,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                l10n.subscriptions,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: AppTypography.platformWeight(
                                        FontWeight.w700,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (capabilities.isVisible(
                        BackendFeature.addCategory,
                      )) ...[
                        const SizedBox(width: 8),
                        _SidebarActionIconButton(
                          tooltip: l10n.newCategory,
                          onPressed: onAddCategory,
                          icon: FleurIcons.addCategory,
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
            contentPadding: const EdgeInsets.only(left: 4, right: 8),
            minLeadingWidth: 0,
            horizontalTitleGap: 4,
            leading: TreeDisclosureButton(
              expanded: expanded,
              tooltip: expanded ? l10n.collapse : l10n.expand,
              onPressed: onToggleExpanded,
            ),
            title: Row(
              children: [
                const Icon(FleurIcons.tag, size: 20),
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
    final canAddFeed = capabilities.isVisible(BackendFeature.addSubscription);
    final canMarkRead =
        capabilities.isVisible(BackendFeature.articleReadState) &&
        unreadCount > 0;

    return _SidebarRevealActions(
      selected: selected,
      builder: (context, showActions, onMenuOpenChanged) {
        final child = Semantics(
          container: true,
          selected: selected,
          expanded: expanded,
          child: Column(
            children: [
              ListTile(
                selected: selected,
                contentPadding: const EdgeInsets.only(left: 4, right: 8),
                minLeadingWidth: 0,
                horizontalTitleGap: 4,
                leading: TreeDisclosureButton(
                  expanded: expanded,
                  tooltip: expanded ? l10n.collapse : l10n.expand,
                  onPressed: () =>
                      onExpandedCategoryChanged(expanded ? null : category.id),
                ),
                title: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: _SidebarCategoryTrailing(
                  unreadCount: unreadCount,
                  showActions: showActions,
                  selected: selected,
                  showReadOnlyLock: syncSemantics.isRemoteReadOnlyTaxonomy,
                  readOnlyTooltip: l10n.remoteReadOnlyTaxonomyTitle,
                  hasCategoryActions: hasCategoryActions,
                  canAddFeed: canAddFeed,
                  canMarkRead: canMarkRead,
                  onShowMenu: isDesktop
                      ? null
                      : () => onShowCategoryMenu(category),
                  menuChildren: isDesktop
                      ? SubscriptionObjectMenus.menuButtons(
                          context: context,
                          items: menuItems,
                          onSelected: (action) =>
                              unawaited(_performAction(action)),
                        )
                      : const <Widget>[],
                  onMenuOpenChanged: onMenuOpenChanged,
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
    final selected = selectedFeedId == feed.id;
    final canMarkRead =
        capabilities.isVisible(BackendFeature.articleReadState) &&
        (unreadCount ?? 0) > 0;

    return _SidebarRevealActions(
      selected: selected,
      builder: (context, showActions, onMenuOpenChanged) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapDown: isDesktop && hasFeedActions
              ? (details) => unawaited(
                  _showContextMenu(context, details.globalPosition, menuItems),
                )
              : null,
          child: ListTile(
            selected: selected,
            contentPadding: EdgeInsets.only(left: 16 + indent, right: 16),
            leading: FaviconCircle(
              siteUri: siteUri,
              diameter: 28,
              avatarSize: 18,
              fallbackIcon: FleurIcons.feed,
              fallbackColor: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(
              displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _SidebarFeedTrailing(
              unreadCount: unreadCount ?? 0,
              showActions: showActions,
              selected: selected,
              hasFeedActions: hasFeedActions,
              canMarkRead: canMarkRead,
              onShowMenu: isDesktop ? null : () => onShowFeedMenu(feed),
              menuChildren: isDesktop
                  ? SubscriptionObjectMenus.menuButtons(
                      context: context,
                      items: menuItems,
                      onSelected: (action) => unawaited(_performAction(action)),
                    )
                  : const <Widget>[],
              onMenuOpenChanged: onMenuOpenChanged,
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
    Widget Function(
      BuildContext context,
      bool showActions,
      ValueChanged<bool> onMenuOpenChanged,
    );

class _SidebarRevealActions extends StatefulWidget {
  const _SidebarRevealActions({required this.selected, required this.builder});

  final bool selected;
  final _SidebarRevealBuilder builder;

  @override
  State<_SidebarRevealActions> createState() => _SidebarRevealActionsState();
}

class _SidebarRevealActionsState extends State<_SidebarRevealActions> {
  bool _hovered = false;
  bool _focused = false;
  bool _menuOpen = false;

  void _handleMenuOpenChanged(bool value) {
    if (!mounted || _menuOpen == value) return;
    setState(() => _menuOpen = value);
  }

  @override
  Widget build(BuildContext context) {
    final showActions = widget.selected || _hovered || _focused || _menuOpen;

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
        child: widget.builder(context, showActions, _handleMenuOpenChanged),
      ),
    );
  }
}

class _SidebarCategoryTrailing extends StatelessWidget {
  const _SidebarCategoryTrailing({
    required this.unreadCount,
    required this.showActions,
    required this.selected,
    required this.showReadOnlyLock,
    required this.readOnlyTooltip,
    required this.hasCategoryActions,
    required this.canAddFeed,
    required this.canMarkRead,
    required this.onShowMenu,
    required this.menuChildren,
    required this.onMenuOpenChanged,
    required this.onAddFeed,
    required this.onMarkRead,
  });

  static const double _actionsWidth = 96;

  final int unreadCount;
  final bool showActions;
  final bool selected;
  final bool showReadOnlyLock;
  final String readOnlyTooltip;
  final bool hasCategoryActions;
  final bool canAddFeed;
  final bool canMarkRead;
  final VoidCallback? onShowMenu;
  final List<Widget> menuChildren;
  final ValueChanged<bool> onMenuOpenChanged;
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
                                  active: selected,
                                  menuChildren: menuChildren,
                                  onMenuOpenChanged: onMenuOpenChanged,
                                )
                              : _SidebarActionIconButton(
                                  tooltip: l10n.more,
                                  active: selected,
                                  onPressed: onShowMenu,
                                  icon: FleurIcons.moreVertical,
                                ),
                        if (canAddFeed)
                          _SidebarActionIconButton(
                            tooltip: l10n.addSubscription,
                            active: selected,
                            onPressed: () => unawaited(onAddFeed()),
                            icon: FleurIcons.add,
                          ),
                        if (canMarkRead)
                          _SidebarActionIconButton(
                            tooltip: l10n.markAllRead,
                            active: selected,
                            onPressed: () => unawaited(onMarkRead()),
                            icon: FleurIcons.markAllRead,
                          ),
                      ],
                    )
                  : _UnreadCountText(unreadCount, selected: selected),
            ),
          )
        else
          _UnreadCountText(unreadCount, selected: selected),
      ],
    );
  }
}

class _SidebarFeedTrailing extends StatelessWidget {
  const _SidebarFeedTrailing({
    required this.unreadCount,
    required this.showActions,
    required this.selected,
    required this.hasFeedActions,
    required this.canMarkRead,
    required this.onShowMenu,
    required this.menuChildren,
    required this.onMenuOpenChanged,
    required this.onMarkRead,
  });

  static const double _actionsWidth = 64;

  final int unreadCount;
  final bool showActions;
  final bool selected;
  final bool hasFeedActions;
  final bool canMarkRead;
  final VoidCallback? onShowMenu;
  final List<Widget> menuChildren;
  final ValueChanged<bool> onMenuOpenChanged;
  final Future<void> Function() onMarkRead;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasActions = hasFeedActions || canMarkRead;

    if (!hasActions) return _UnreadCountText(unreadCount, selected: selected);

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
                            active: selected,
                            menuChildren: menuChildren,
                            onMenuOpenChanged: onMenuOpenChanged,
                          )
                        : _SidebarActionIconButton(
                            tooltip: l10n.more,
                            active: selected,
                            onPressed: onShowMenu,
                            icon: FleurIcons.moreVertical,
                          ),
                  if (canMarkRead)
                    _SidebarActionIconButton(
                      tooltip: l10n.markAllRead,
                      active: selected,
                      onPressed: () => unawaited(onMarkRead()),
                      icon: FleurIcons.markAllRead,
                    ),
                ],
              )
            : _UnreadCountText(unreadCount, selected: selected),
      ),
    );
  }
}

class _SidebarMenuActionButton extends StatelessWidget {
  const _SidebarMenuActionButton({
    required this.tooltip,
    required this.active,
    required this.menuChildren,
    required this.onMenuOpenChanged,
  });

  final String tooltip;
  final bool active;
  final List<Widget> menuChildren;
  final ValueChanged<bool> onMenuOpenChanged;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      onOpen: () => onMenuOpenChanged(true),
      onClose: () => onMenuOpenChanged(false),
      menuChildren: menuChildren,
      builder: (context, controller, child) {
        return _SidebarActionIconButton(
          tooltip: tooltip,
          active: active || controller.isOpen,
          onPressed: () {
            controller.isOpen ? controller.close() : controller.open();
          },
          icon: FleurIcons.moreVertical,
        );
      },
    );
  }
}

class _SidebarActionIconButton extends StatelessWidget {
  const _SidebarActionIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;

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
          if (active ||
              states.contains(WidgetState.hovered) ||
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
  const _UnreadCountText(this.count, {this.selected = false});

  static const double _rightInset = 8;
  static const double _textWidth = 30;

  final int count;
  final bool selected;

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
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: AppTypography.platformWeight(FontWeight.w700),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
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
    this.onSecondaryTapDown,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int? count;
  final double indent;
  final Color? iconColor;
  final GestureTapDownCallback? onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      selected: selected,
      contentPadding: EdgeInsets.only(left: 16 + indent, right: 8),
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      trailing: count == null
          ? null
          : _UnreadCountText(count!, selected: selected),
      onTap: onTap,
    );
    if (onSecondaryTapDown == null) return tile;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: onSecondaryTapDown,
      child: tile,
    );
  }
}
