import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/nav_destination.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../ui/actions/global_nav_actions.dart';

class GlobalNavBar extends ConsumerWidget {
  const GlobalNavBar({super.key, required this.currentUri});

  final Uri currentUri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dest = destinationForUri(currentUri);
    final selectedIndex = globalDestinationIndex(dest);
    final surfaces = Theme.of(context).fleurSurface;

    return Material(
      color: surfaces.nav,
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (idx) {
          final next = GlobalNavDestination.values[idx];
          handleGlobalNavSelection(context, ref, next);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(FleurIcons.feeds),
            selectedIcon: const Icon(FleurIcons.feedsSelected),
            label: l10n.feeds,
          ),
          NavigationDestination(
            icon: const Icon(FleurIcons.saved),
            selectedIcon: const Icon(FleurIcons.savedSelected),
            label: l10n.saved,
          ),
          NavigationDestination(
            icon: const Icon(FleurIcons.search),
            selectedIcon: const Icon(FleurIcons.searchSelected),
            label: l10n.search,
          ),
          NavigationDestination(
            icon: const Icon(FleurIcons.settings),
            selectedIcon: const Icon(FleurIcons.settingsSelected),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}
