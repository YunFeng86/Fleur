import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/query_providers.dart';

enum _GlobalDest { dashboard, feeds, saved, automate, search, settings }

class GlobalNavBar extends ConsumerWidget {
  const GlobalNavBar({super.key, required this.currentUri});

  final Uri currentUri;

  _GlobalDest _destForUri(Uri uri) {
    final seg = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    return switch (seg) {
      'dashboard' => _GlobalDest.dashboard,
      'saved' => _GlobalDest.saved,
      'automate' => _GlobalDest.automate,
      'search' => _GlobalDest.search,
      'settings' => _GlobalDest.settings,
      // article + home live under the Feeds section.
      '' || 'article' => _GlobalDest.feeds,
      _ => _GlobalDest.feeds,
    };
  }

  int _indexForDest(_GlobalDest d) => _GlobalDest.values.indexOf(d);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dest = _destForUri(currentUri);
    final selectedIndex = _indexForDest(dest);

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (idx) {
        final next = _GlobalDest.values[idx];
        switch (next) {
          case _GlobalDest.dashboard:
            context.go('/dashboard');
            return;
          case _GlobalDest.feeds:
            // Leaving other top-level sections should bring you back to the
            // normal feed browsing state.
            ref.read(starredOnlyProvider.notifier).state = false;
            ref.read(readLaterOnlyProvider.notifier).state = false;
            // Keep current feed/category selection, but clear global search.
            ref.read(articleSearchQueryProvider.notifier).state = '';
            context.go('/');
            return;
          case _GlobalDest.saved:
            context.go('/saved');
            return;
          case _GlobalDest.automate:
            context.go('/automate');
            return;
          case _GlobalDest.search:
            context.go('/search');
            return;
          case _GlobalDest.settings:
            context.go('/settings');
            return;
        }
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard),
          label: l10n.dashboard,
        ),
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
          icon: const Icon(Icons.auto_awesome_outlined),
          selectedIcon: const Icon(Icons.auto_awesome),
          label: l10n.automate,
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
