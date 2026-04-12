import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/feed.dart';
import '../../../../providers/query_providers.dart';
import '../../../../providers/subscription_settings_provider.dart';
import '../../../../theme/fleur_theme_extensions.dart';
import '../../../../widgets/favicon_avatar.dart';
import '../widgets/section_header.dart';

class CategoryListComponent extends ConsumerWidget {
  const CategoryListComponent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final feeds = ref.watch(feedsProvider).valueOrNull ?? const [];
    final selection = ref.watch(subscriptionSelectionProvider);
    final notifier = ref.read(subscriptionSelectionProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;

    return categoriesAsync.when(
      loading: () => SettingsPane(
        color: surfaces.sidebar,
        title: l10n.subscriptions,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SettingsPane(
        color: surfaces.sidebar,
        title: l10n.subscriptions,
        child: Center(child: Text(e.toString())),
      ),
      data: (categories) {
        final feedCounts = <int?, int>{};
        for (final feed in feeds) {
          feedCounts.update(
            feed.categoryId,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
        final uncategorizedFeeds = feeds
            .where((feed) => feed.categoryId == null)
            .toList(growable: false);

        final globalSelected = selection.isGlobalDefaults;

        Widget buildSectionLabel(String label) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        Widget buildScopeTile({
          required Widget title,
          required Widget leading,
          required bool selected,
          required VoidCallback onTap,
          int? count,
          Widget? subtitle,
        }) {
          return SettingsTile(
            leading: leading,
            title: title,
            subtitle: subtitle,
            selected: selected,
            trailing: count == null
                ? null
                : Text(
                    '$count',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            onTap: onTap,
          );
        }

        return SettingsPane(
          color: surfaces.sidebar,
          title: l10n.subscriptions,
          child: ListView(
            primary: false,
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            children: [
              buildSectionLabel(l10n.defaultsGroup),
              buildScopeTile(
                leading: const Icon(Icons.tune_outlined),
                title: Text(l10n.globalDefaults),
                subtitle: Text(
                  l10n.globalDefaultsDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: globalSelected,
                onTap: () => notifier.showGlobalDefaults(),
              ),
              buildSectionLabel(l10n.folders),
              for (final category in categories)
                buildScopeTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(category.name),
                  count: feedCounts[category.id] ?? 0,
                  selected:
                      !globalSelected &&
                      selection.activeCategoryId == category.id,
                  onTap: () => notifier.selectCategory(category.id),
                ),
              if (categories.isNotEmpty && uncategorizedFeeds.isNotEmpty)
                const SizedBox(height: 4),
              for (final feed in uncategorizedFeeds)
                _RootFeedTile(
                  feed: feed,
                  selected: selection.selectedFeedId == feed.id,
                  onTap: () => notifier.selectFeed(
                    feed.id,
                    categoryScope: const SubscriptionCategoryAll(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RootFeedTile extends StatelessWidget {
  const _RootFeedTile({
    required this.feed,
    required this.selected,
    required this.onTap,
  });

  final Feed feed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          fallbackIcon: Icons.rss_feed,
          fallbackColor: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        feed.userTitle ?? feed.title ?? feed.url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(feed.url, maxLines: 1, overflow: TextOverflow.ellipsis),
      selected: selected,
      onTap: onTap,
    );
  }
}
