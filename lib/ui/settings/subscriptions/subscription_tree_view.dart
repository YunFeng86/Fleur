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
  final Set<int> _expandedCategoryIds = <int>{};
  final Set<int> _collapsedCategoryIds = <int>{};

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
                child: ListView(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  children: [
                    buildSectionLabel(l10n.defaultsGroup),
                    _ScopeTreeRow(
                      icon: Icons.tune_outlined,
                      title: l10n.globalDefaults,
                      subtitle: l10n.globalDefaultsDescription,
                      selected: selection.isGlobalDefaults,
                      onTap: () => notifier.showGlobalDefaults(
                        showDetailPane: widget.showDetailPaneOnSelection,
                      ),
                    ),
                    buildSectionLabel(l10n.folders),
                    for (final category in categories)
                      () {
                        final isExpanded = visibleExpanded.contains(
                          category.id,
                        );

                        return _CategoryTreeNode(
                          category: category,
                          feeds: feedsByCategory[category.id] ?? const [],
                          expanded: isExpanded,
                          isSelected:
                              !selection.isGlobalDefaults &&
                              selection.activeCategoryId == category.id &&
                              selection.selectedFeedId == null,
                          selectedFeedId: selection.selectedFeedId,
                          showDetailPaneOnSelection:
                              widget.showDetailPaneOnSelection,
                          onToggleExpanded: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedCategoryIds.remove(category.id);
                                _collapsedCategoryIds.add(category.id);
                              } else {
                                _expandedCategoryIds.add(category.id);
                                _collapsedCategoryIds.remove(category.id);
                              }
                            });
                          },
                        );
                      }(),
                    if (categories.isNotEmpty && uncategorizedFeeds.isNotEmpty)
                      const SizedBox(height: 4),
                    for (final feed in uncategorizedFeeds)
                      _FeedTreeRow(
                        feed: feed,
                        selected: selection.selectedFeedId == feed.id,
                        indent: 0,
                        onTap: () => notifier.selectFeed(
                          feed.id,
                          categoryScope: const SubscriptionCategoryAll(),
                          showDetailPane: widget.showDetailPaneOnSelection,
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

class _CategoryTreeNode extends ConsumerWidget {
  const _CategoryTreeNode({
    required this.category,
    required this.feeds,
    required this.expanded,
    required this.isSelected,
    required this.selectedFeedId,
    required this.showDetailPaneOnSelection,
    required this.onToggleExpanded,
  });

  final Category category;
  final List<Feed> feeds;
  final bool expanded;
  final bool isSelected;
  final int? selectedFeedId;
  final bool showDetailPaneOnSelection;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final notifier = ref.read(subscriptionSelectionProvider.notifier);

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
            onTap: () => notifier.selectCategory(
              category.id,
              showDetailPane: showDetailPaneOnSelection,
            ),
          ),
          if (expanded)
            for (final feed in feeds)
              _FeedTreeRow(
                feed: feed,
                selected: selectedFeedId == feed.id,
                indent: 24,
                onTap: () => notifier.selectFeed(
                  feed.id,
                  categoryScope: SubscriptionCategoryId(category.id),
                  showDetailPane: showDetailPaneOnSelection,
                ),
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
