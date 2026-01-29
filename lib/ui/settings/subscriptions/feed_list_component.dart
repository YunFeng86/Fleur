import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/feed.dart';
import '../../../../providers/subscription_settings_provider.dart';
import '../../../../providers/query_providers.dart';
import '../../../../l10n/app_localizations.dart';

class FeedListComponent extends ConsumerWidget {
  const FeedListComponent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(subscriptionSelectionProvider);
    final l10n = AppLocalizations.of(context)!;

    // Using filtered list based on selection
    final feedsAsync = ref.watch(feedsProvider);

    return feedsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (allFeeds) {
        List<Feed> visibleFeeds;
        if (selection.activeCategoryId == null) {
          // If no folder selected, show empty or maybe all?
          // Per requirements: "No folder -> Show feeds".
          // If layout logic says we are visible, we should show all if uncategorized isn't explicitly active?
          // Actually, if activeCategoryId is null, we might be in "Global" mode (no specific filter).
          // But strict 3-pane usually implies selecting a folder to see feeds.
          // IF we are in NARROW mode, `activeCategoryId` might be null but we want to show feeds?
          // But `SubscriptionLayoutManager` will handle hiding/showing columns.
          // Here we just render what is asked.
          // Let's assume if null, we show *all* feeds (default behavior) or empty?
          // Let's show ALL feeds if category is null.
          visibleFeeds = allFeeds;
        } else if (selection.isUncategorized) {
          visibleFeeds = allFeeds.where((f) => f.categoryId == null).toList();
        } else {
          visibleFeeds = allFeeds
              .where((f) => f.categoryId == selection.activeCategoryId)
              .toList();
        }

        if (visibleFeeds.isEmpty) {
          return Center(child: Text(l10n.notFound));
        }

        return ListView.builder(
          itemCount: visibleFeeds.length,
          itemBuilder: (context, index) {
            final feed = visibleFeeds[index];
            final isSelected = selection.selectedFeedId == feed.id;

            return ListTile(
              title: Text(
                feed.userTitle ?? feed.title ?? feed.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                feed.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              selected: isSelected,
              onTap: () {
                ref
                    .read(subscriptionSelectionProvider.notifier)
                    .selectFeed(feed.id);
              },
              selectedTileColor: Theme.of(
                context,
              ).colorScheme.secondaryContainer,
            );
          },
        );
      },
    );
  }
}
