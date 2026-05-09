import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../models/feed.dart';
import '../../providers/backend_capabilities_provider.dart';
import '../../providers/backend_sync_semantics_provider.dart';
import '../../providers/subscription_settings_provider.dart';
import '../../services/sync/backend_capabilities.dart';
import '../../services/sync/backend_sync_semantics.dart';
import '../context_menu_position.dart';
import 'subscription_actions.dart';

enum SubscriptionFeedMenuAction { rename, refresh, offlineCache, move, delete }

enum SubscriptionCategoryMenuAction { rename, delete }

enum SubscriptionRootMenuAction {
  showAll,
  globalDefaults,
  addSubscription,
  addCategory,
  refreshAll,
  importOpml,
  exportOpml,
  settings,
}

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

  static List<SubscriptionObjectMenuItem<SubscriptionRootMenuAction>>
  sidebarAllItems(
    AppLocalizations l10n,
    BackendCapabilities capabilities,
    BackendSyncSemantics syncSemantics,
  ) {
    return [
      SubscriptionObjectMenuItem(
        action: SubscriptionRootMenuAction.showAll,
        icon: Icons.all_inbox,
        label: l10n.showAll,
      ),
      ...managementItems(
        l10n,
        capabilities,
        syncSemantics,
        includeSettings: true,
      ),
    ];
  }

  static List<SubscriptionObjectMenuItem<SubscriptionRootMenuAction>>
  sidebarHeaderItems(
    AppLocalizations l10n,
    BackendCapabilities capabilities,
    BackendSyncSemantics syncSemantics,
  ) {
    return managementItems(
      l10n,
      capabilities,
      syncSemantics,
      includeSettings: true,
    );
  }

  static List<SubscriptionObjectMenuItem<SubscriptionRootMenuAction>>
  globalDefaultsItems(AppLocalizations l10n) {
    return [
      SubscriptionObjectMenuItem(
        action: SubscriptionRootMenuAction.globalDefaults,
        icon: Icons.tune_outlined,
        label: l10n.globalDefaults,
      ),
    ];
  }

  static List<SubscriptionObjectMenuItem<SubscriptionRootMenuAction>>
  settingsHeaderItems(
    AppLocalizations l10n,
    BackendCapabilities capabilities,
    BackendSyncSemantics syncSemantics,
  ) {
    return managementItems(
      l10n,
      capabilities,
      syncSemantics,
      includeSettings: false,
    );
  }

  static List<SubscriptionObjectMenuItem<SubscriptionRootMenuAction>>
  managementItems(
    AppLocalizations l10n,
    BackendCapabilities capabilities,
    BackendSyncSemantics syncSemantics, {
    required bool includeSettings,
  }) {
    final showsSourceRefresh = capabilities.isVisible(
      BackendFeature.refreshAllSources,
    );
    final showsRootRefresh =
        showsSourceRefresh || capabilities.isVisible(BackendFeature.syncNow);
    final rootRefreshLabel =
        !showsSourceRefresh && syncSemantics.isAccountWideRefresh
        ? l10n.syncAccount
        : l10n.refreshAll;

    return [
      if (showsRootRefresh)
        SubscriptionObjectMenuItem(
          action: SubscriptionRootMenuAction.refreshAll,
          icon: Icons.refresh,
          label: rootRefreshLabel,
        ),
      if (capabilities.isVisible(BackendFeature.addSubscription))
        SubscriptionObjectMenuItem(
          action: SubscriptionRootMenuAction.addSubscription,
          icon: Icons.add,
          label: l10n.addSubscription,
        ),
      if (capabilities.isVisible(BackendFeature.addCategory))
        SubscriptionObjectMenuItem(
          action: SubscriptionRootMenuAction.addCategory,
          icon: Icons.create_new_folder_outlined,
          label: l10n.newCategory,
        ),
      if (capabilities.isVisible(BackendFeature.importOpml))
        SubscriptionObjectMenuItem(
          action: SubscriptionRootMenuAction.importOpml,
          icon: Icons.file_upload_outlined,
          label: l10n.importOpml,
        ),
      if (capabilities.isVisible(BackendFeature.exportOpml))
        SubscriptionObjectMenuItem(
          action: SubscriptionRootMenuAction.exportOpml,
          icon: Icons.file_download_outlined,
          label: l10n.exportOpml,
        ),
      if (includeSettings)
        SubscriptionObjectMenuItem(
          action: SubscriptionRootMenuAction.settings,
          icon: Icons.settings_outlined,
          label: l10n.settings,
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

  static Future<void> showSettingsManagementContextMenu(
    BuildContext context,
    WidgetRef ref, {
    required Offset position,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = ref.read(backendCapabilitiesProvider);
    final syncSemantics = ref.read(backendSyncSemanticsProvider);
    final action = await showContextMenu(
      context: context,
      position: position,
      items: settingsHeaderItems(l10n, capabilities, syncSemantics),
    );
    if (!context.mounted || action == null) return;
    await performSettingsManagementAction(context, ref, action);
  }

  static Future<void> performSettingsManagementAction(
    BuildContext context,
    WidgetRef ref,
    SubscriptionRootMenuAction action,
  ) async {
    switch (action) {
      case SubscriptionRootMenuAction.addSubscription:
        await SubscriptionActions.showAddFeedDialog(context, ref);
        return;
      case SubscriptionRootMenuAction.addCategory:
        await SubscriptionActions.showAddCategoryDialog(context, ref);
        return;
      case SubscriptionRootMenuAction.refreshAll:
        await SubscriptionActions.refreshAll(context, ref);
        return;
      case SubscriptionRootMenuAction.importOpml:
        await SubscriptionActions.importOpml(context, ref);
        return;
      case SubscriptionRootMenuAction.exportOpml:
        await SubscriptionActions.exportOpml(context, ref);
        return;
      case SubscriptionRootMenuAction.showAll:
      case SubscriptionRootMenuAction.globalDefaults:
      case SubscriptionRootMenuAction.settings:
        return;
    }
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
