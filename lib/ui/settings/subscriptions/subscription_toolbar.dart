import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import 'subscription_actions.dart';

class SubscriptionToolbar extends ConsumerWidget {
  const SubscriptionToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final centerTitle = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };

    Widget buildActions() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: () {
              unawaited(SubscriptionActions.showAddFeedDialog(context, ref));
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.addSubscription),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: l10n.newCategory,
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () {
              unawaited(
                SubscriptionActions.showAddCategoryDialog(context, ref),
              );
            },
          ),
          IconButton(
            tooltip: l10n.refreshAll,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              unawaited(SubscriptionActions.refreshAll(context, ref));
            },
          ),
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
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: centerTitle
          ? Row(
              children: [
                // Balance trailing actions so the title is truly centered in the
                // full toolbar width (not just centered between start/end slots).
                ExcludeSemantics(
                  child: IgnorePointer(
                    child: Opacity(opacity: 0, child: buildActions()),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      l10n.subscriptions,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                buildActions(),
              ],
            )
          : Row(
              children: [
                Text(
                  l10n.subscriptions,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                buildActions(),
              ],
            ),
    );
  }
}
