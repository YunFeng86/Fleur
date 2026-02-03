import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../providers/query_providers.dart';
import '../ui/dialogs/add_subscription_dialog.dart';
import '../ui/dialogs/article_search_dialog.dart';
import '../ui/global_nav.dart';

enum _GlobalDest { dashboard, feeds, saved, automate, search, settings }

class GlobalNavRail extends ConsumerWidget {
  const GlobalNavRail({super.key, required this.currentUri});

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
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: Text(l10n.dashboard),
          ),
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
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: Text(l10n.automate),
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
                  final id = await showAddSubscriptionDialog(
                    context,
                    ref,
                    navigator: nav,
                  );
                  if (id == null) return;
                  // After adding, jump to Feeds and select the feed.
                  ref.read(starredOnlyProvider.notifier).state = false;
                  ref.read(readLaterOnlyProvider.notifier).state = false;
                  ref.read(selectedFeedIdProvider.notifier).state = id;
                  ref.read(selectedCategoryIdProvider.notifier).state = null;
                  ref.read(selectedTagIdProvider.notifier).state = null;
                  ref.read(articleSearchQueryProvider.notifier).state = '';
                  if (context.mounted) context.go('/');
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        onDestinationSelected: (idx) async {
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
              // Prefer the dedicated Search section; allow re-opening quickly
              // when we're already there.
              final wasSearch = _destForUri(currentUri) == _GlobalDest.search;
              if (!wasSearch) {
                context.go('/search');
                return;
              }

              await showArticleSearchDialog(context, ref);
              if (!context.mounted) return;
              // If we were on an embedded article route, return to list root.
              if (currentUri.pathSegments.length > 1) context.go('/search');
              return;
            case _GlobalDest.settings:
              context.go('/settings');
              return;
          }
        },
      ),
    );
  }
}
