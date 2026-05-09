import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../models/feed.dart';
import '../../providers/backend_capabilities_provider.dart';
import '../../providers/subscription_settings_provider.dart';
import '../../services/sync/backend_capabilities.dart';
import '../context_menu_position.dart';
import 'subscription_actions.dart';

enum SubscriptionFeedMenuAction { rename, refresh, offlineCache, move, delete }

enum SubscriptionCategoryMenuAction { rename, delete }

class SubscriptionObjectMenuItem<T> {
  const SubscriptionObjectMenuItem({
    required this.action,
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final T action;
  final IconData icon;
  final String label;
  final bool destructive;
}

class SubscriptionObjectMenus {
  const SubscriptionObjectMenus._();

  static List<SubscriptionObjectMenuItem<SubscriptionFeedMenuAction>> feedItems(
    AppLocalizations l10n,
    BackendCapabilities capabilities,
  ) {
    final canMove =
        capabilities.isVisible(BackendFeature.moveSubscriptionToCategory) ||
        capabilities.isVisible(BackendFeature.moveSubscriptionToUncategorized);

    return [
      if (capabilities.isVisible(BackendFeature.clientFeedSettings))
        SubscriptionObjectMenuItem(
          action: SubscriptionFeedMenuAction.rename,
          icon: Icons.edit_outlined,
          label: l10n.rename,
        ),
      if (capabilities.isVisible(BackendFeature.refreshSubscriptionSource))
        SubscriptionObjectMenuItem(
          action: SubscriptionFeedMenuAction.refresh,
          icon: Icons.refresh,
          label: l10n.refresh,
        ),
      if (capabilities.isVisible(BackendFeature.offlineCache))
        SubscriptionObjectMenuItem(
          action: SubscriptionFeedMenuAction.offlineCache,
          icon: Icons.download_for_offline_outlined,
          label: l10n.makeAvailableOffline,
        ),
      if (canMove)
        SubscriptionObjectMenuItem(
          action: SubscriptionFeedMenuAction.move,
          icon: Icons.drive_file_move_outline,
          label: l10n.moveToCategory,
        ),
      if (capabilities.isVisible(BackendFeature.deleteSubscription))
        SubscriptionObjectMenuItem(
          action: SubscriptionFeedMenuAction.delete,
          icon: Icons.delete_outline,
          label: l10n.deleteSubscription,
          destructive: true,
        ),
    ];
  }

  static List<SubscriptionObjectMenuItem<SubscriptionCategoryMenuAction>>
  categoryItems(AppLocalizations l10n, BackendCapabilities capabilities) {
    return [
      if (capabilities.isVisible(BackendFeature.renameCategory))
        SubscriptionObjectMenuItem(
          action: SubscriptionCategoryMenuAction.rename,
          icon: Icons.edit_outlined,
          label: l10n.rename,
        ),
      if (capabilities.isVisible(BackendFeature.deleteCategory))
        SubscriptionObjectMenuItem(
          action: SubscriptionCategoryMenuAction.delete,
          icon: Icons.delete_outline,
          label: l10n.deleteCategory,
          destructive: true,
        ),
    ];
  }

  static List<Widget> menuButtons<T>({
    required BuildContext context,
    required List<SubscriptionObjectMenuItem<T>> items,
    required ValueChanged<T> onSelected,
  }) {
    final errorColor = Theme.of(context).colorScheme.error;
    return [
      for (final item in items)
        MenuItemButton(
          leadingIcon: Icon(
            item.icon,
            color: item.destructive ? errorColor : null,
          ),
          onPressed: () => onSelected(item.action),
          child: Text(
            item.label,
            style: item.destructive ? TextStyle(color: errorColor) : null,
          ),
        ),
    ];
  }

  static List<Widget> bottomSheetTiles<T>({
    required BuildContext context,
    required List<SubscriptionObjectMenuItem<T>> items,
  }) {
    final errorColor = Theme.of(context).colorScheme.error;
    return [
      for (final item in items)
        ListTile(
          leading: Icon(item.icon, color: item.destructive ? errorColor : null),
          title: Text(
            item.label,
            style: item.destructive ? TextStyle(color: errorColor) : null,
          ),
          onTap: () => Navigator.of(context).pop(item.action),
        ),
    ];
  }

  static Future<T?> showContextMenu<T>({
    required BuildContext context,
    required Offset position,
    required List<SubscriptionObjectMenuItem<T>> items,
  }) {
    if (items.isEmpty) return Future<T?>.value();
    final errorColor = Theme.of(context).colorScheme.error;
    return showMenu<T>(
      context: context,
      position: contextMenuPositionForGlobalPoint(context, position),
      items: [
        for (final item in items)
          PopupMenuItem<T>(
            value: item.action,
            child: ListTile(
              leading: Icon(
                item.icon,
                color: item.destructive ? errorColor : null,
              ),
              title: Text(
                item.label,
                style: item.destructive ? TextStyle(color: errorColor) : null,
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  static Future<void> showSettingsFeedContextMenu(
    BuildContext context,
    WidgetRef ref, {
    required Feed feed,
    required Offset position,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = ref.read(backendCapabilitiesProvider);
    final action = await showContextMenu(
      context: context,
      position: position,
      items: feedItems(l10n, capabilities),
    );
    if (!context.mounted || action == null) return;
    await performSettingsFeedAction(context, ref, feed, action);
  }

  static Future<void> showSettingsCategoryContextMenu(
    BuildContext context,
    WidgetRef ref, {
    required Category category,
    required Offset position,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = ref.read(backendCapabilitiesProvider);
    final action = await showContextMenu(
      context: context,
      position: position,
      items: categoryItems(l10n, capabilities),
    );
    if (!context.mounted || action == null) return;
    await performSettingsCategoryAction(context, ref, category, action);
  }

  static Future<void> performSettingsFeedAction(
    BuildContext context,
    WidgetRef ref,
    Feed feed,
    SubscriptionFeedMenuAction action,
  ) async {
    switch (action) {
      case SubscriptionFeedMenuAction.rename:
        await SubscriptionActions.editFeedTitle(
          context,
          ref,
          feedId: feed.id,
          currentTitle: feed.userTitle ?? feed.title,
        );
        return;
      case SubscriptionFeedMenuAction.refresh:
        await SubscriptionActions.refreshFeed(context, ref, feed.id);
        return;
      case SubscriptionFeedMenuAction.offlineCache:
        await SubscriptionActions.cacheFeedOffline(context, ref, feed.id);
        return;
      case SubscriptionFeedMenuAction.move:
        await SubscriptionActions.moveFeedToCategory(
          context,
          ref,
          feedId: feed.id,
        );
        return;
      case SubscriptionFeedMenuAction.delete:
        final deleted = await SubscriptionActions.deleteFeed(
          context,
          ref,
          feedId: feed.id,
        );
        if (!deleted || !context.mounted) return;
        final selection = ref.read(subscriptionSelectionProvider);
        if (selection.selectedFeedId != feed.id) return;
        ref
            .read(subscriptionSelectionProvider.notifier)
            .returnToScopeDetails(showDetailPane: selection.showDetailPane);
        return;
    }
  }

  static Future<void> performSettingsCategoryAction(
    BuildContext context,
    WidgetRef ref,
    Category category,
    SubscriptionCategoryMenuAction action,
  ) async {
    switch (action) {
      case SubscriptionCategoryMenuAction.rename:
        await SubscriptionActions.renameCategory(
          context,
          ref,
          categoryId: category.id,
          currentName: category.name,
        );
        return;
      case SubscriptionCategoryMenuAction.delete:
        final deleted = await SubscriptionActions.deleteCategory(
          context,
          ref,
          categoryId: category.id,
        );
        if (!deleted || !context.mounted) return;
        final selection = ref.read(subscriptionSelectionProvider);
        if (selection.activeCategoryId != category.id) return;
        ref.read(subscriptionSelectionProvider.notifier).selectAll();
        return;
    }
  }
}
