import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/features/subscriptions/subscriptions.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/category.dart';
import '../../../../models/feed.dart';
import '../../../../providers/query_providers.dart';
import '../../../../theme/fleur_icons.dart';
import '../../../../theme/fleur_theme_extensions.dart';
import '../../../../ui/actions/subscription_object_menus.dart';
import '../../../../utils/platform.dart';
import '../../../../widgets/app_scrollbar.dart';
import '../../../../widgets/favicon_avatar.dart';
import '../../../../widgets/tree_disclosure_button.dart';
import '../widgets/settings_controls.dart';

class SubscriptionTreeView extends ConsumerStatefulWidget {
  const SubscriptionTreeView({
    super.key,
    this.showDetailPaneOnSelection = false,
    this.showPaneHeader = true,
  });

  final bool showDetailPaneOnSelection;
  final bool showPaneHeader;

  @override
  ConsumerState<SubscriptionTreeView> createState() =>
      _SubscriptionTreeViewState();
}

class _SubscriptionTreeViewState extends ConsumerState<SubscriptionTreeView> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listViewKey = GlobalKey();
  final Map<String, BuildContext> _rowContexts = <String, BuildContext>{};
  final Set<int> _expandedCategoryIds = <int>{};
  final Set<int> _collapsedCategoryIds = <int>{};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _registerRow(String rowId, BuildContext context) {
    _rowContexts[rowId] = context;
  }

  void _unregisterRow(String rowId, BuildContext context) {
    if (identical(_rowContexts[rowId], context)) {
      _rowContexts.remove(rowId);
    }
  }

  _SubscriptionTreeScrollAnchor? _captureScrollAnchor() {
    if (!_scrollController.hasClients) return null;
    final listBox = _listViewKey.currentContext?.findRenderObject();
    if (listBox is! RenderBox || !listBox.hasSize) return null;
    final viewportTop = listBox.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + listBox.size.height;

    _SubscriptionTreeScrollAnchor? bestFullyVisible;
    double bestFullyVisibleTop = double.infinity;
    _SubscriptionTreeScrollAnchor? bestPartial;
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
          bestFullyVisible = _SubscriptionTreeScrollAnchor(
            rowId: entry.key,
            top: top,
          );
        }
      } else {
        final distance = (top - viewportTop).abs();
        if (distance < bestPartialDistance) {
          bestPartialDistance = distance;
          bestPartial = _SubscriptionTreeScrollAnchor(
            rowId: entry.key,
            top: top,
          );
        }
      }
    }
    return bestFullyVisible ?? bestPartial;
  }

  void _restoreScrollAnchor(_SubscriptionTreeScrollAnchor? anchor) {
    if (!mounted || anchor == null || !_scrollController.hasClients) return;
    final rowBox = _rowContexts[anchor.rowId]?.findRenderObject();
    if (rowBox is! RenderBox || !rowBox.attached || !rowBox.hasSize) return;
    final nextTop = rowBox.localToGlobal(Offset.zero).dy;
    final delta = nextTop - anchor.top;
    if (delta.abs() < 0.5) return;
    final position = _scrollController.position;
    final next = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((next - position.pixels).abs() < 0.5) return;
    _scrollController.jumpTo(next);
  }

  void _runWithScrollAnchor(VoidCallback action) {
    final anchor = _captureScrollAnchor();
    action();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScrollAnchor(anchor);
    });
  }

  _SubscriptionTreeRow _buildFeedRow({
    required BuildContext context,
    required Feed feed,
    required int? selectedFeedId,
    required SubscriptionCategoryScope categoryScope,
    required double indent,
    required SubscriptionSelectionNotifier notifier,
  }) {
    return _SubscriptionTreeRow(
      rowId: 'feed:${feed.id}',
      builder: (_) => _FeedTreeRow(
        feed: feed,
        selected: selectedFeedId == feed.id,
        indent: indent,
        onTap: () => _runWithScrollAnchor(
          () => notifier.selectFeed(
            feed.id,
            categoryScope: categoryScope,
            showDetailPane: widget.showDetailPaneOnSelection,
          ),
        ),
        onSecondaryTapDown: isDesktop
            ? (details) => unawaited(
                SubscriptionObjectMenus.showSettingsFeedContextMenu(
                  context,
                  ref,
                  feed: feed,
                  position: details.globalPosition,
                ),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedsAsync = ref.watch(feedsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final l10n = AppLocalizations.of(context)!;
    final selection = ref.watch(subscriptionSelectionProvider);
    final notifier = ref.read(subscriptionSelectionProvider.notifier);
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;

    return feedsAsync.when(
      loading: () => SettingsPane(
        color: surfaces.sidebar,
        title: widget.showPaneHeader ? l10n.subscriptions : null,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SettingsPane(
        color: surfaces.sidebar,
        title: widget.showPaneHeader ? l10n.subscriptions : null,
        child: Center(child: Text(e.toString())),
      ),
      data: (feeds) {
        return categoriesAsync.when(
          loading: () => SettingsPane(
            color: surfaces.sidebar,
            title: widget.showPaneHeader ? l10n.subscriptions : null,
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SettingsPane(
            color: surfaces.sidebar,
            title: widget.showPaneHeader ? l10n.subscriptions : null,
            child: Center(child: Text(e.toString())),
          ),
          data: (categories) {
            final feedsByCategory = <int?, List<Feed>>{};
            for (final feed in feeds) {
              feedsByCategory.putIfAbsent(feed.categoryId, () => []).add(feed);
            }
            final uncategorizedFeeds = feedsByCategory[null] ?? const <Feed>[];

            final visibleExpanded = <int>{
              ..._expandedCategoryIds,
              ...?switch (selection.activeCategoryId) {
                final activeCategoryId?
                    when !_collapsedCategoryIds.contains(activeCategoryId) =>
                  <int>{activeCategoryId},
                _ => null,
              },
            };

            final showSettingsManagementContextMenu = isDesktop
                ? (TapDownDetails details) => unawaited(
                    SubscriptionObjectMenus.showSettingsManagementContextMenu(
                      context,
                      ref,
                      position: details.globalPosition,
                    ),
                  )
                : null;

            Future<void> showGlobalDefaultsContextMenu(Offset position) async {
              final action = await SubscriptionObjectMenus.showContextMenu(
                context: context,
                position: position,
                items: SubscriptionObjectMenus.globalDefaultsItems(l10n),
              );
              if (!mounted || action == null) return;
              if (action == SubscriptionRootMenuAction.globalDefaults) {
                _runWithScrollAnchor(
                  () => notifier.showGlobalDefaults(
                    showDetailPane: widget.showDetailPaneOnSelection,
                  ),
                );
              }
            }

            final showGlobalDefaultsMenu = isDesktop
                ? (TapDownDetails details) => unawaited(
                    showGlobalDefaultsContextMenu(details.globalPosition),
                  )
                : null;

            Widget buildSectionLabel(
              String label, {
              GestureTapDownCallback? onSecondaryTapDown,
            }) {
              final labelWidget = Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
              if (onSecondaryTapDown == null) return labelWidget;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onSecondaryTapDown: onSecondaryTapDown,
                child: labelWidget,
              );
            }

            final rows = <_SubscriptionTreeRow>[
              _SubscriptionTreeRow(
                rowId: 'section:defaults',
                builder: (_) => buildSectionLabel(l10n.defaultsGroup),
              ),
              _SubscriptionTreeRow(
                rowId: 'scope:global-defaults',
                builder: (_) => _ScopeTreeRow(
                  icon: FleurIcons.subscriptionDefaults,
                  title: l10n.globalDefaults,
                  subtitle: l10n.globalDefaultsDescription,
                  selected: selection.isGlobalDefaults,
                  onSecondaryTapDown: showGlobalDefaultsMenu,
                  onTap: () => _runWithScrollAnchor(
                    () => notifier.showGlobalDefaults(
                      showDetailPane: widget.showDetailPaneOnSelection,
                    ),
                  ),
                ),
              ),
              _SubscriptionTreeRow(
                rowId: 'section:folders',
                builder: (_) => buildSectionLabel(
                  l10n.folders,
                  onSecondaryTapDown: showSettingsManagementContextMenu,
                ),
              ),
            ];
            for (final category in categories) {
              final isExpanded = visibleExpanded.contains(category.id);
              final categoryFeeds = feedsByCategory[category.id] ?? const [];
              rows.add(
                _SubscriptionTreeRow(
                  rowId: 'category:${category.id}',
                  builder: (_) => _CategoryTreeNode(
                    category: category,
                    feedCount: categoryFeeds.length,
                    expanded: isExpanded,
                    isSelected:
                        !selection.isGlobalDefaults &&
                        selection.activeCategoryId == category.id &&
                        selection.selectedFeedId == null,
                    onToggleExpanded: () {
                      _runWithScrollAnchor(() {
                        setState(() {
                          if (isExpanded) {
                            _expandedCategoryIds.remove(category.id);
                            _collapsedCategoryIds.add(category.id);
                          } else {
                            _expandedCategoryIds.add(category.id);
                            _collapsedCategoryIds.remove(category.id);
                          }
                        });
                      });
                    },
                    onSelectCategory: () => _runWithScrollAnchor(
                      () => notifier.selectCategory(
                        category.id,
                        showDetailPane: widget.showDetailPaneOnSelection,
                      ),
                    ),
                    onSecondaryTapDown: isDesktop
                        ? (details) => unawaited(
                            SubscriptionObjectMenus.showSettingsCategoryContextMenu(
                              context,
                              ref,
                              category: category,
                              position: details.globalPosition,
                            ),
                          )
                        : null,
                  ),
                ),
              );
              if (!isExpanded) continue;
              for (final feed in categoryFeeds) {
                rows.add(
                  _buildFeedRow(
                    context: context,
                    feed: feed,
                    selectedFeedId: selection.selectedFeedId,
                    categoryScope: SubscriptionCategoryId(category.id),
                    indent: 24,
                    notifier: notifier,
                  ),
                );
              }
            }
            if (categories.isNotEmpty && uncategorizedFeeds.isNotEmpty) {
              rows.add(
                const _SubscriptionTreeRow(
                  rowId: 'gap:uncategorized',
                  builder: _buildUncategorizedGap,
                ),
              );
            }
            for (final feed in uncategorizedFeeds) {
              rows.add(
                _buildFeedRow(
                  context: context,
                  feed: feed,
                  selectedFeedId: selection.selectedFeedId,
                  categoryScope: const SubscriptionCategoryAll(),
                  indent: 0,
                  notifier: notifier,
                ),
              );
            }

            final rowIndexById = <String, int>{
              for (var index = 0; index < rows.length; index++)
                rows[index].rowId: index,
            };

            return SettingsPane(
              color: surfaces.sidebar,
              title: widget.showPaneHeader ? l10n.subscriptions : null,
              onHeaderSecondaryTapDown: widget.showPaneHeader
                  ? showSettingsManagementContextMenu
                  : null,
              child: AppScrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  key: _listViewKey,
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  itemCount: rows.length,
                  findChildIndexCallback: (key) {
                    if (key is ValueKey<String>) {
                      return rowIndexById[key.value];
                    }
                    return null;
                  },
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return _SubscriptionAnchorRegistryRow(
                      key: ValueKey<String>(row.rowId),
                      rowId: row.rowId,
                      onRegister: _registerRow,
                      onUnregister: _unregisterRow,
                      child: row.builder(context),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SubscriptionTreeScrollAnchor {
  const _SubscriptionTreeScrollAnchor({required this.rowId, required this.top});

  final String rowId;
  final double top;
}

class _SubscriptionTreeRow {
  const _SubscriptionTreeRow({required this.rowId, required this.builder});

  final String rowId;
  final WidgetBuilder builder;
}

Widget _buildUncategorizedGap(BuildContext context) {
  return const SizedBox(height: 4);
}

class _SubscriptionAnchorRegistryRow extends StatefulWidget {
  const _SubscriptionAnchorRegistryRow({
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
  State<_SubscriptionAnchorRegistryRow> createState() =>
      _SubscriptionAnchorRegistryRowState();
}

class _SubscriptionAnchorRegistryRowState
    extends State<_SubscriptionAnchorRegistryRow> {
  @override
  void initState() {
    super.initState();
    widget.onRegister(widget.rowId, context);
  }

  @override
  void didUpdateWidget(covariant _SubscriptionAnchorRegistryRow oldWidget) {
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

class _ScopeTreeRow extends StatelessWidget {
  const _ScopeTreeRow({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.onSecondaryTapDown,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final GestureTapDownCallback? onSecondaryTapDown;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
      selected: selected,
      onSecondaryTapDown: onSecondaryTapDown,
      onTap: onTap,
    );
  }
}

class _CategoryTreeNode extends StatelessWidget {
  const _CategoryTreeNode({
    required this.category,
    required this.feedCount,
    required this.expanded,
    required this.isSelected,
    required this.onToggleExpanded,
    required this.onSelectCategory,
    this.onSecondaryTapDown,
  });

  final Category category;
  final int feedCount;
  final bool expanded;
  final bool isSelected;
  final VoidCallback onToggleExpanded;
  final VoidCallback onSelectCategory;
  final GestureTapDownCallback? onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      selected: isSelected,
      expanded: expanded,
      child: Column(
        children: [
          SettingsTile(
            contentPadding: const EdgeInsets.only(left: 4, right: 16),
            leading: TreeDisclosureButton(
              expanded: expanded,
              tooltip: expanded ? l10n.collapse : l10n.expand,
              onPressed: onToggleExpanded,
            ),
            title: Text(category.name),
            subtitle: Text(
              '$feedCount ${l10n.subscriptions}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            selected: isSelected,
            onSecondaryTapDown: onSecondaryTapDown,
            trailing: Text(
              '$feedCount',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            onTap: onSelectCategory,
          ),
        ],
      ),
    );
  }
}

class _FeedTreeRow extends StatelessWidget {
  const _FeedTreeRow({
    required this.feed,
    required this.selected,
    required this.indent,
    required this.onTap,
    this.onSecondaryTapDown,
  });

  final Feed feed;
  final bool selected;
  final double indent;
  final VoidCallback onTap;
  final GestureTapDownCallback? onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    final siteUri = Uri.tryParse(
      (feed.siteUrl?.trim().isNotEmpty == true)
          ? feed.siteUrl!.trim()
          : feed.url,
    );

    return SettingsTile(
      leading: _IndentedAvatar(indent: indent, siteUri: siteUri),
      title: Text(
        feed.userTitle ?? feed.title ?? feed.url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(feed.url, maxLines: 1, overflow: TextOverflow.ellipsis),
      selected: selected,
      onSecondaryTapDown: onSecondaryTapDown,
      onTap: onTap,
    );
  }
}

class _IndentedAvatar extends StatelessWidget {
  const _IndentedAvatar({required this.indent, required this.siteUri});

  final double indent;
  final Uri? siteUri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: SettingsLeadingAvatar(
        child: FaviconAvatar(
          siteUri: siteUri,
          size: 16,
          fallbackIcon: FleurIcons.feed,
          fallbackColor: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
