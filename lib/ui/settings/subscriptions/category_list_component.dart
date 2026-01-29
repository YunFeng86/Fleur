import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/query_providers.dart';
import '../../../../providers/subscription_settings_provider.dart';
import '../../../../l10n/app_localizations.dart';

class CategoryListComponent extends ConsumerWidget {
  const CategoryListComponent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final selection = ref.watch(subscriptionSelectionProvider);
    final l10n = AppLocalizations.of(context)!;

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (categories) {
        if (categories.isEmpty) {
          // If no categories exist at all, this column might be hidden or show empty state?
          // For now, allow selecting "Uncategorized" or "Global" (clear).
          // We always show "Uncategorized" if there are feeds there?
          // We can't easily know if there are uncategorized feeds without fetching feeds.
          // Let's assume we always show "Uncategorized" item if we are in this view.
        }

        return ListView(
          controller: ScrollController(),
          children: [
            // List actual categories
            for (final category in categories)
              ListTile(
                title: Text(category.name),
                selected: selection.activeCategoryId == category.id,
                onTap: () {
                  ref
                      .read(subscriptionSelectionProvider.notifier)
                      .selectCategory(category.id);
                },
                leading: const Icon(Icons.folder_outlined),
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer,
              ),

            const Divider(),

            // Uncategorized
            ListTile(
              title: Text(l10n.uncategorized),
              leading: const Icon(Icons.rss_feed),
              selected: selection.isUncategorized,
              onTap: () {
                ref
                    .read(subscriptionSelectionProvider.notifier)
                    .selectUncategorized();
              },
              selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          ],
        );
      },
    );
  }
}
