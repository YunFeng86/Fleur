import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import 'subscription_actions.dart';

class SubscriptionToolbar extends ConsumerWidget {
  const SubscriptionToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Title
          Text(
            l10n.subscriptions,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),

          // Action Buttons
          // Add Feed
          FilledButton.icon(
            onPressed: () {
              unawaited(SubscriptionActions.showAddFeedDialog(context, ref));
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.addSubscription),
          ),
          const SizedBox(width: 8),

          // Add Category
          IconButton(
            tooltip: l10n.newCategory,
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () {
              unawaited(
                SubscriptionActions.showAddCategoryDialog(context, ref),
              );
            },
          ),

          // Refresh All
          IconButton(
            tooltip: l10n.refreshAll,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              unawaited(SubscriptionActions.refreshAll(context, ref));
            },
          ),

          // More Menu (Import/Export)
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert),
            tooltip: l10n.more,
            onSelected: (value) {
              if (value == 0) {
                unawaited(SubscriptionActions.importOpml(context, ref));
              }
              if (value == 1) {
                unawaited(SubscriptionActions.exportOpml(context, ref));
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 0,
                child: ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: Text(l10n.importOpml),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: Text(l10n.exportOpml),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
