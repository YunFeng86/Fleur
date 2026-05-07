import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/category.dart';
import '../../../../models/feed.dart';
import '../../../../providers/query_providers.dart';
import '../../../../providers/subscription_settings_provider.dart';
import '../../../../theme/fleur_theme_extensions.dart';
import '../../../../widgets/app_scrollbar.dart';
import '../../../../widgets/favicon_avatar.dart';
import '../../../../widgets/tree_disclosure_button.dart';
import '../widgets/section_header.dart';

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
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  final Set<int> _expandedCategoryIds = <int>{};
  final Set<int> _collapsedCategoryIds = <int>{};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _rowKey(String rowId) {
    return _rowKeys.putIfAbsent(rowId, GlobalKey.new);
  }

  Widget _anchoredRow(String rowId, Widget child) {
    return KeyedSubtree(key: _rowKey(rowId), child: child);
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
    for (final entry in _rowKeys.entries) {
      final rowBox = entry.value.currentContext?.findRenderObject();
      if (rowBox is! RenderBox || !rowBox.hasSize) continue;
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
    final rowBox = _rowKeys[anchor.rowId]?.currentContext?.findRenderObject();
    if (rowBox is! RenderBox || !rowBox.hasSize) return;
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

            Widget buildSectionLabel(String label) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }

            return SettingsPane(
              color: surfaces.sidebar,
              title: widget.showPaneHeader ? l10n.subscriptions : null,
              child: AppScrollbar(
                controller: _scrollController,
                child: ListView(
                  key: _listViewKey,
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  children: [
                    _anchoredRow(
                      'section:defaults',
                      buildSectionLabel(l10n.defaultsGroup),
                    ),
                    _anchoredRow(
                      'scope:global-defaults',
                      _ScopeTreeRow(
                        icon: Icons.tune_outlined,
                        title: l10n.globalDefaults,
                        subtitle: l10n.globalDefaultsDescription,
                        selected: selection.isGlobalDefaults,
                        onTap: () => _runWithScrollAnchor(
                          () => notifier.showGlobalDefaults(
                            showDetailPane: widget.showDetailPaneOnSelection,
                          ),
                        ),
                      ),
                    ),
                    _anchoredRow(
                      'section:folders',
                      buildSectionLabel(l10n.folders),
                    ),
                    for (final category in categories)
                      () {
                        final isExpanded = visibleExpanded.contains(
                          category.id,
                        );

                        return _anchoredRow(
                          'category:${category.id}',
                          _CategoryTreeNode(
                            category: category,
                            feeds: feedsByCategory[category.id] ?? const [],
                            expanded: isExpanded,
                            isSelected:
                                !selection.isGlobalDefaults &&
                                selection.activeCategoryId == category.id &&
                                selection.selectedFeedId == null,
                            selectedFeedId: selection.selectedFeedId,
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
                                showDetailPane:
                                    widget.showDetailPaneOnSelection,
                              ),
                            ),
                            feedRowKey: (feedId) => _rowKey('feed:$feedId'),
                            onSelectFeed: (feedId) => _runWithScrollAnchor(
                              () => notifier.selectFeed(
                                feedId,
                                categoryScope: SubscriptionCategoryId(
                                  category.id,
                                ),
                                showDetailPane:
                                    widget.showDetailPaneOnSelection,
                              ),
                            ),
                          ),
                        );
                      }(),
                    if (categories.isNotEmpty && uncategorizedFeeds.isNotEmpty)
                      const SizedBox(height: 4),
                    for (final feed in uncategorizedFeeds)
                      _FeedTreeRow(
                        key: _rowKey('feed:${feed.id}'),
                        feed: feed,
                        selected: selection.selectedFeedId == feed.id,
                        indent: 0,
                        onTap: () => _runWithScrollAnchor(
                          () => notifier.selectFeed(
                            feed.id,
                            categoryScope: const SubscriptionCategoryAll(),
                            showDetailPane: widget.showDetailPaneOnSelection,
                          ),
                        ),
                      ),
                  ],
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

class _ScopeTreeRow extends StatelessWidget {
  const _ScopeTreeRow({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
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
      onTap: onTap,
    );
  }
}

class _CategoryTreeNode extends StatelessWidget {
  const _CategoryTreeNode({
    required this.category,
    required this.feeds,
    required this.expanded,
    required this.isSelected,
    required this.selectedFeedId,
    required this.onToggleExpanded,
    required this.onSelectCategory,
    required this.feedRowKey,
    required this.onSelectFeed,
  });

  final Category category;
  final List<Feed> feeds;
  final bool expanded;
  final bool isSelected;
  final int? selectedFeedId;
  final VoidCallback onToggleExpanded;
  final VoidCallback onSelectCategory;
  final Key Function(int feedId) feedRowKey;
  final ValueChanged<int> onSelectFeed;

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
            contentPadding: const EdgeInsets.only(left: 8, right: 16),
            leading: TreeDisclosureButton(
              expanded: expanded,
              tooltip: expanded ? l10n.collapse : l10n.expand,
              onPressed: onToggleExpanded,
            ),
            title: Text(category.name),
            subtitle: Text(
              '${feeds.length} ${l10n.subscriptions}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            selected: isSelected,
            trailing: Text(
              '${feeds.length}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            onTap: onSelectCategory,
          ),
          if (expanded)
            for (final feed in feeds)
              _FeedTreeRow(
                key: feedRowKey(feed.id),
                feed: feed,
                selected: selectedFeedId == feed.id,
                indent: 24,
                onTap: () => onSelectFeed(feed.id),
              ),
        ],
      ),
    );
  }
}

class _FeedTreeRow extends StatelessWidget {
  const _FeedTreeRow({
    super.key,
    required this.feed,
    required this.selected,
    required this.indent,
    required this.onTap,
  });

  final Feed feed;
  final bool selected;
  final double indent;
  final VoidCallback onTap;

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
          fallbackIcon: Icons.rss_feed,
          fallbackColor: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
