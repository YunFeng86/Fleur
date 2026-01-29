import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/category.dart';
import '../../../../models/feed.dart';
import '../../../../providers/query_providers.dart';
import '../../../../providers/subscription_settings_provider.dart';

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
                    title: Text(l10n.uncategorized),
                    leading: const Icon(Icons.rss_feed),
                    // If we tap Uncategorized, do we select it as a "category"?
                    // Our SelectionModel supports selecting Uncategorized (activeCategoryId == null, but logic might vary).
                    // Let's assume we can select the "Uncategorized" faux-category.
                    // Actually SubscriptionSelectionModel: selectUncategorized() -> activeCategoryId = null, selectedFeedId = null.
                    // But wait! activeCategoryId = null usually means "No category selected" (Global mode).
                    // How did we handle this in CategoryListComponent?
                    // `selectUncategorized()` sets a special state?
                    // Let's check SubscriptionSelectionModel.
                    // Ideally "Uncategorized" is just a filter.
                    // In Tree View, "Global Settings" is shown when NOTHING is selected.
                    // Tapping "Uncategorized" header could show "Uncategorized" filter settings? (None really).
                    // Let's just allow expanding it.
                    children: [
                      for (final feed in uncategorized)
                        ListTile(
                          title: Text(feed.userTitle ?? feed.title ?? feed.url),
                          selected: selection.selectedFeedId == feed.id,
                          contentPadding: const EdgeInsets.only(
                            left: 32,
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
    // We want the Title Row to be selectable AND expandable.
    // Standard ExpansionTile expands on title tap.
    // To support "Select Category", we might need a custom layout or trailing button.
    // User asked for "Folder folding but can expand".
    // Usually: Click Arrow to Expand, Click Text to Select.
    // OR: Click anywhere -> Selects AND Expands.
    // Let's do: Click anywhere -> Selects AND (Toggle Expansion).
    // But if I want to just select without toggling?
    // Let's try standard ExpansionTile.
    // If I tap it, it toggles. I can ALSO trigger `onCategoryTap`.

    return ExpansionTile(
      key: PageStorageKey(category.id), // Persist expansion state
      leading: const Icon(Icons.folder_outlined),
      title: Text(category.name),
      // To visually show selection of the category itself:
      backgroundColor: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1)
          : null,
      collapsedBackgroundColor: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,

      onExpansionChanged: (expanded) {
        // When interacting with the folder, we select it.
        onCategoryTap();
      },
      children: [
        for (final feed in feeds)
          ListTile(
            title: Text(feed.userTitle ?? feed.title ?? feed.url),
            selected: selectedFeedId == feed.id,
            // Indent for hierarchy
            contentPadding: const EdgeInsets.only(left: 32, right: 16),
            onTap: () => onFeedTap(feed.id),
            dense: true,
          ),
        if (feeds.isEmpty)
          ListTile(
            title: Text(
              'No subscriptions',
              style: TextStyle(color: Theme.of(context).disabledColor),
            ),
            contentPadding: const EdgeInsets.only(left: 32, right: 16),
            dense: true,
          ),
      ],
    );
  }
}
