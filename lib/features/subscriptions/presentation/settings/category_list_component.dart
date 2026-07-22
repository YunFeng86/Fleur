import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/subscription_selection.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/feed.dart';
import '../../../../providers/query_providers.dart';
import '../../../../theme/fleur_icons.dart';
import '../../../../theme/fleur_theme_extensions.dart';
import '../../../../ui/settings/widgets/settings_controls.dart';
import '../../../../utils/platform.dart';
import '../../../../widgets/app_scrollbar.dart';
import '../../../../widgets/favicon_avatar.dart';
import '../subscription_object_menus.dart';

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
        final showSettingsManagementContextMenu = isDesktop
            ? (TapDownDetails details) => unawaited(
                SubscriptionObjectMenus.showSettingsManagementContextMenu(
                  context,
                  ref,
                  position: details.globalPosition,
                ),
              )
            : null;

        Future<void> showGlobalDefaultsContextMenu(Offset position) async {
          final action = await SubscriptionObjectMenus.showContextMenu(
            context: context,
            position: position,
            items: SubscriptionObjectMenus.globalDefaultsItems(l10n),
          );
          if (!context.mounted || action == null) return;
          if (action == SubscriptionRootMenuAction.globalDefaults) {
            notifier.showGlobalDefaults();
          }
        }

        final showGlobalDefaultsMenu = isDesktop
            ? (TapDownDetails details) => unawaited(
                showGlobalDefaultsContextMenu(details.globalPosition),
              )
            : null;

        Widget buildSectionLabel(
          String label, {
          GestureTapDownCallback? onSecondaryTapDown,
        }) {
          final labelWidget = Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
          if (onSecondaryTapDown == null) return labelWidget;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onSecondaryTapDown: onSecondaryTapDown,
            child: labelWidget,
          );
        }

        Widget buildScopeTile({
          required Widget title,
          required Widget leading,
          required bool selected,
          required VoidCallback onTap,
          int? count,
          Widget? subtitle,
          GestureTapDownCallback? onSecondaryTapDown,
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
            onSecondaryTapDown: onSecondaryTapDown,
            onTap: onTap,
          );
        }

        return SettingsPane(
          color: surfaces.sidebar,
          title: l10n.subscriptions,
          onHeaderSecondaryTapDown: showSettingsManagementContextMenu,
          child: AppScrollbar(
            child: ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              children: [
                buildSectionLabel(l10n.defaultsGroup),
                buildScopeTile(
                  leading: const Icon(FleurIcons.subscriptionDefaults),
                  title: Text(l10n.globalDefaults),
                  subtitle: Text(
                    l10n.globalDefaultsDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: globalSelected,
                  onSecondaryTapDown: showGlobalDefaultsMenu,
                  onTap: () => notifier.showGlobalDefaults(),
                ),
                buildSectionLabel(
                  l10n.folders,
                  onSecondaryTapDown: showSettingsManagementContextMenu,
                ),
                for (final category in categories)
                  buildScopeTile(
                    leading: const Icon(FleurIcons.category),
                    title: Text(category.name),
                    count: feedCounts[category.id] ?? 0,
                    selected:
                        !globalSelected &&
                        selection.activeCategoryId == category.id,
                    onSecondaryTapDown: isDesktop
                        ? (details) => unawaited(
                            SubscriptionObjectMenus.showSettingsCategoryContextMenu(
                              context,
                              ref,
                              category: category,
                              position: details.globalPosition,
                            ),
                          )
                        : null,
                    onTap: () => notifier.selectCategory(category.id),
                  ),
                if (categories.isNotEmpty && uncategorizedFeeds.isNotEmpty)
                  const SizedBox(height: 4),
                for (final feed in uncategorizedFeeds)
                  _RootFeedTile(
                    feed: feed,
                    selected: selection.selectedFeedId == feed.id,
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
                    onTap: () => notifier.selectFeed(
                      feed.id,
                      categoryScope: const SubscriptionCategoryAll(),
                    ),
                  ),
              ],
            ),
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
    this.onSecondaryTapDown,
  });

  final Feed feed;
  final bool selected;
  final VoidCallback onTap;
  final GestureTapDownCallback? onSecondaryTapDown;

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
          fallbackIcon: FleurIcons.feed,
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
      onSecondaryTapDown: onSecondaryTapDown,
      onTap: onTap,
    );
  }
}
