import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/nav_destination.dart';
import '../ui/actions/global_nav_actions.dart';

class GlobalNavBar extends ConsumerWidget {
  const GlobalNavBar({super.key, required this.currentUri});

  final Uri currentUri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dest = destinationForUri(currentUri);
    final selectedIndex = globalDestinationIndex(dest);

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (idx) {
        final next = GlobalNavDestination.values[idx];
        handleGlobalNavSelection(context, ref, next);
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.rss_feed_outlined),
          selectedIcon: const Icon(Icons.rss_feed),
          label: l10n.feeds,
        ),
        NavigationDestination(
          icon: const Icon(Icons.bookmark_outline),
          selectedIcon: const Icon(Icons.bookmark),
          label: l10n.saved,
        ),
        NavigationDestination(
          icon: const Icon(Icons.search_outlined),
          selectedIcon: const Icon(Icons.search),
          label: l10n.search,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: l10n.settings,
        ),
      ],
    );
  }
}
