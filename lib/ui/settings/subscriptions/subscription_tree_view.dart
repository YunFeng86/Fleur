import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/category.dart';
import '../../../../models/feed.dart';
import '../../../../providers/query_providers.dart';
import '../../../../providers/subscription_settings_provider.dart';
import '../../../../widgets/favicon_avatar.dart';

class SubscriptionTreeView extends ConsumerWidget {
  const SubscriptionTreeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedsAsync = ref.watch(feedsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final l10n = AppLocalizations.of(context)!;
    final selection = ref.watch(subscriptionSelectionProvider);
    final notifier = ref.read(subscriptionSelectionProvider.notifier);

    return feedsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (feeds) {
        return categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (categories) {
            // Group feeds
            final byCat = <int?, List<Feed>>{};
            for (final f in feeds) {
              byCat.putIfAbsent(f.categoryId, () => []).add(f);
            }

            final uncategorized = byCat[null] ?? [];

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Categories (Expansion Tiles)
                for (final category in categories) ...[
                  _CategoryExpansionTile(
                    category: category,
                    feeds: byCat[category.id] ?? [],
                    isSelected: selection.activeCategoryId == category.id,
                    selectedFeedId: selection.selectedFeedId,
                    onCategoryTap: () {
                      notifier.selectCategory(category.id);
                    },
                    onFeedTap: (feedId) {
                      notifier.selectFeed(feedId, category.id);
                    },
                  ),
                ],

                // Uncategorized Header (if needed) or just list feeds?
                // Usually "Uncategorized" acts like a folder in tree view
                if (uncategorized.isNotEmpty) ...[
                  // We can use a simplified ExpansionTile for Uncategorized or just list them.
                  // Let's use an ExpansionTile labeled "Uncategorized" for consistency
                  ExpansionTile(
                    initiallyExpanded: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      l10n.uncategorized,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${uncategorized.length} 订阅源',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    leading: null,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    children: [
                      for (final feed in uncategorized)
                        ListTile(
                          leading: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHigh,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: FaviconAvatar(
                              siteUri: Uri.tryParse(
                                (feed.siteUrl?.trim().isNotEmpty == true)
                                    ? feed.siteUrl!.trim()
                                    : feed.url,
                              ),
                              size: 16,
                              fallbackIcon: Icons.rss_feed,
                              fallbackColor: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          title: Text(feed.userTitle ?? feed.title ?? feed.url),
                          selected: selection.selectedFeedId == feed.id,
                          contentPadding: const EdgeInsets.only(
                            left: 56,
                            right: 16,
                          ),
                          onTap: () => notifier.selectFeed(feed.id, null),
                          dense: true,
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _CategoryExpansionTile extends StatelessWidget {
  final Category category;
  final List<Feed> feeds;
  final bool isSelected;
  final int? selectedFeedId;
  final VoidCallback onCategoryTap;
  final ValueChanged<int> onFeedTap;

  const _CategoryExpansionTile({
    required this.category,
    required this.feeds,
    required this.isSelected,
    required this.selectedFeedId,
    required this.onCategoryTap,
    required this.onFeedTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      key: PageStorageKey(category.id),
      initiallyExpanded: isSelected,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        category.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${feeds.length} 订阅源',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      // Remove default leading icon as arrow is now leading
      leading: null,
      shape: const Border(), // Remove default borders
      collapsedShape: const Border(),

      onExpansionChanged: (expanded) {
        onCategoryTap();
      },
      children: [
        for (final feed in feeds)
          ListTile(
            leading: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: FaviconAvatar(
                siteUri: Uri.tryParse(
                  (feed.siteUrl?.trim().isNotEmpty == true)
                      ? feed.siteUrl!.trim()
                      : feed.url,
                ),
                size: 16,
                fallbackIcon: Icons.rss_feed,
                fallbackColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            title: Text(feed.userTitle ?? feed.title ?? feed.url),
            selected: selectedFeedId == feed.id,
            contentPadding: const EdgeInsets.only(left: 56, right: 16),
            onTap: () => onFeedTap(feed.id),
            dense: true,
          ),
        if (feeds.isEmpty)
          ListTile(
            title: Text(
              'No subscriptions',
              style: TextStyle(color: Theme.of(context).disabledColor),
            ),
            contentPadding: const EdgeInsets.only(left: 56, right: 16),
            dense: true,
          ),
      ],
    );
  }
}
