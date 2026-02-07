import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/nav_destination.dart';
import '../ui/actions/global_nav_actions.dart';
import '../ui/actions/subscription_actions.dart';
import '../ui/global_nav.dart';

class GlobalNavRail extends ConsumerWidget {
  const GlobalNavRail({super.key, required this.currentUri});

  final Uri currentUri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dest = destinationForUri(currentUri);
    final selectedIndex = globalDestinationIndex(dest);

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: NavigationRail(
        minWidth: kGlobalNavRailWidth,
        groupAlignment: -1,
        labelType: NavigationRailLabelType.all,
        selectedIndex: selectedIndex,
        leading: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Icon(
            Icons.rss_feed,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        destinations: [
          NavigationRailDestination(
            icon: const Icon(Icons.rss_feed_outlined),
            selectedIcon: const Icon(Icons.rss_feed),
            label: Text(l10n.feeds),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.bookmark_outline),
            selectedIcon: const Icon(Icons.bookmark),
            label: Text(l10n.saved),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search),
            label: Text(l10n.search),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: Text(l10n.settings),
          ),
        ],
        trailing: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: l10n.addSubscription,
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final id = await SubscriptionActions.addFeed(
                    context,
                    ref,
                    navigator: nav,
                  );
                  if (id == null) return;
                  // After adding, jump to Feeds and select the feed.
                  SubscriptionActions.selectFeed(ref, id);
                  if (context.mounted) context.go('/');
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        onDestinationSelected: (idx) {
          final next = GlobalNavDestination.values[idx];
          handleGlobalNavSelection(context, ref, next);
        },
      ),
    );
  }
}
