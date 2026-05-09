import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/nav_destination.dart';
import '../providers/account_providers.dart';
import '../theme/fleur_theme_extensions.dart';
import '../ui/actions/global_nav_actions.dart';
import '../ui/actions/subscription_actions.dart';
import '../ui/global_nav.dart';
import 'account_avatar.dart';

class GlobalNavRail extends ConsumerWidget {
  const GlobalNavRail({super.key, required this.currentUri});

  final Uri currentUri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;
    final states = theme.fleurState;
    final dest = destinationForUri(currentUri);
    final selectedIndex = globalDestinationIndex(dest);
    final activeAccount = ref.watch(activeAccountProvider);

    return Material(
      color: surfaces.nav,
      child: Column(
        children: [
          Expanded(
            child: NavigationRail(
              minWidth: kGlobalNavRailWidth,
              groupAlignment: -1,
              labelType: NavigationRailLabelType.all,
              selectedIndex: selectedIndex,
              leading: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: states.selectionTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.rss_feed, color: theme.colorScheme.primary),
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
                        SubscriptionActions.selectFeed(ref, id);
                        if (context.mounted) context.go('/');
                      },
                      icon: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    Visibility(
                      visible: false,
                      maintainAnimation: true,
                      maintainSize: true,
                      maintainState: true,
                      child: AccountAvatar(
                        account: activeAccount,
                        radius: 18,
                        showTypeBadge: true,
                      ),
                    ),
                  ],
                ),
              ),
              onDestinationSelected: (idx) {
                final next = GlobalNavDestination.values[idx];
                handleGlobalNavSelection(context, ref, next);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Tooltip(
                message: activeAccount.name,
                child: InkResponse(
                  key: const Key('global_nav_account_button'),
                  radius: 24,
                  hoverColor: states.hoverTint,
                  onTap: () =>
                      context.go(settingsLocation(tab: SettingsTab.services)),
                  child: AccountAvatar(
                    account: activeAccount,
                    radius: 18,
                    showTypeBadge: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
