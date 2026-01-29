import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/subscription_settings_provider.dart';
import '../../../../providers/query_providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/feed.dart';
import 'subscription_actions.dart'; // Import actions

class SettingsDetailPanel extends ConsumerWidget {
  const SettingsDetailPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(subscriptionSelectionProvider);
    final l10n = AppLocalizations.of(context)!;

    // 1. Feed Selected -> Show Feed Settings
    if (selection.selectedFeedId != null) {
      final feedAsync = ref.watch(feedsProvider);
      final feed = feedAsync.valueOrNull
          ?.where((f) => f.id == selection.selectedFeedId)
          .firstOrNull;

      if (feed == null) {
        return Center(child: Text(l10n.notFound));
      }
      return _FeedSettings(feed: feed);
    }
    // 2. Category Selected (and NO Feed selected) -> Show Category Settings
    else if (selection.isRealCategory) {
      final categoriesAsync = ref.watch(categoriesProvider);
      final category = categoriesAsync.valueOrNull
          ?.where((c) => c.id == selection.activeCategoryId)
          .firstOrNull;

      if (category == null) {
        return Center(child: Text(l10n.notFound));
      }
      return _CategorySettings(
        categoryName: category.name,
        categoryId: category.id,
      );
    }
    // 3. Fallback -> Global Settings
    else {
      return const _GlobalSettings();
    }
  }
}

class _GlobalSettings extends ConsumerWidget {
  const _GlobalSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.subscriptions,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),

        ListTile(
          leading: const Icon(Icons.add),
          title: Text(l10n.addSubscription),
          onTap: () => SubscriptionActions.showAddFeedDialog(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.create_new_folder_outlined),
          title: Text(l10n.newCategory),
          onTap: () => SubscriptionActions.showAddCategoryDialog(context, ref),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: Text(l10n.refreshAll),
          subtitle: Text('${l10n.lastSynced}: Just now'),

          onTap: () => SubscriptionActions.refreshAll(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.file_upload_outlined),
          title: Text(l10n.importOpml),
          onTap: () => SubscriptionActions.importOpml(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: Text(l10n.exportOpml),
          onTap: () => SubscriptionActions.exportOpml(context, ref),
        ),
      ],
    );
  }
}

class _CategorySettings extends ConsumerWidget {
  final String categoryName;
  final int categoryId;

  const _CategorySettings({
    required this.categoryName,
    required this.categoryId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(categoryName, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.edit),
          title: Text(l10n.rename),
          onTap: () => SubscriptionActions.renameCategory(
            context,
            ref,
            categoryId: categoryId,
            currentName: categoryName,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.red),
          title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          onTap: () {
            SubscriptionActions.deleteCategory(context, ref, categoryId);
            // If deleted, we should clear logic selection.
            // Ideally repository or provider listener handles this,
            // but explicit clear might be safer if provider doesn't auto-reset.
            ref
                .read(subscriptionSelectionProvider.notifier)
                .selectCategory(null);
          },
        ),
      ],
    );
  }
}

class _FeedSettings extends ConsumerWidget {
  final Feed feed;

  const _FeedSettings({required this.feed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          feed.userTitle ?? feed.title ?? 'Feed',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SelectableText(feed.url),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.edit),
          title: Text(l10n.rename),
          onTap: () => SubscriptionActions.editFeedTitle(
            context,
            ref,
            feedId: feed.id,
            currentTitle: feed.userTitle ?? feed.title,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.folder_open),
          title: Text(l10n.moveToCategory),
          onTap: () =>
              SubscriptionActions.moveFeedToCategory(context, ref, feed.id),
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: Text(l10n.refresh), // Add "Refresh Feed"
          onTap: () => SubscriptionActions.refreshFeed(context, ref, feed.id),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.red),
          title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          onTap: () {
            SubscriptionActions.deleteFeed(context, ref, feed.id);
            // Clear selection
            ref
                .read(subscriptionSelectionProvider.notifier)
                .clearFeedSelection();
          },
        ),
      ],
    );
  }
}
