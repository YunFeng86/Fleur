import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../providers/query_providers.dart';
import '../../../../providers/subscription_settings_provider.dart';
import '../../../../theme/fleur_icons.dart';
import '../../../../theme/fleur_theme_extensions.dart';
import '../../../../ui/actions/subscription_object_menus.dart';
import '../../../../utils/platform.dart';
import '../../../../widgets/app_scrollbar.dart';
import '../../../../widgets/favicon_avatar.dart';
import '../widgets/section_header.dart';

class FeedListComponent extends ConsumerWidget {
  const FeedListComponent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(subscriptionSelectionProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;

    final feedsAsync = ref.watch(feedsProvider);

    return feedsAsync.when(
      loading: () => SettingsPane(
        color: surfaces.list,
        title: l10n.subscriptions,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SettingsPane(
        color: surfaces.list,
        title: l10n.subscriptions,
        child: Center(child: Text(e.toString())),
      ),
      data: (allFeeds) {
        final visibleFeeds = allFeeds
            .where((feed) => selection.matchesCategoryId(feed.categoryId))
            .toList();

        final scopeTitle = switch (selection.categoryScope) {
          SubscriptionCategoryAll() => l10n.subscriptions,
          SubscriptionCategoryUncategorized() => l10n.uncategorized,
          SubscriptionCategoryId(:final id) =>
            categories
                    .where((category) => category.id == id)
                    .firstOrNull
                    ?.name ??
                l10n.subscriptions,
        };

        return SettingsPane(
          color: surfaces.list,
          title: scopeTitle,
          subtitle: '${visibleFeeds.length} ${l10n.subscriptions}',
          child: visibleFeeds.isEmpty
              ? Center(
                  child: Text(
                    l10n.notFound,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : AppScrollbar(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: visibleFeeds.length,
                    itemBuilder: (context, index) {
                      final feed = visibleFeeds[index];
                      final isSelected = selection.selectedFeedId == feed.id;
                      final siteUri = Uri.tryParse(
                        (feed.siteUrl?.trim().isNotEmpty == true)
                            ? feed.siteUrl!.trim()
                            : feed.url,
                      );

                      return SettingsTile(
                        leading: SettingsLeadingAvatar(
                          child: FaviconAvatar(
                            siteUri: siteUri,
                            size: 16,
                            fallbackIcon: FleurIcons.feed,
                            fallbackColor: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        title: Text(
                          feed.userTitle ?? feed.title ?? feed.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          feed.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: isSelected,
                        onSecondaryTapDown: isDesktop
                            ? (details) => unawaited(
                                SubscriptionObjectMenus.showSettingsFeedContextMenu(
                                  context,
                                  ref,
                                  feed: feed,
                                  position: details.globalPosition,
                                ),
                              )
                            : null,
                        onTap: () {
                          ref
                              .read(subscriptionSelectionProvider.notifier)
                              .selectFeed(feed.id);
                        },
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}
