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
import '../../theme/fleur_icons.dart';
import '../app_menu.dart';
import 'root_sync_action.dart';
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

class SubscriptionObjectMenuItem<T> extends AppMenuItem<T> {
  const SubscriptionObjectMenuItem({
    required T action,
    required super.icon,
    required super.label,
    super.destructive = false,
  }) : super(value: action);

  T get action => value;
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
          icon: FleurIcons.rename,
          label: l10n.rename,
        ),
      if (capabilities.isVisible(BackendFeature.refreshSubscriptionSource))
        SubscriptionObjectMenuItem(
          action: SubscriptionFeedMenuAction.refresh,
          icon: FleurIcons.refresh,
          label: l10n.refresh,
        ),
      if (capabilities.isVisible(BackendFeature.offlineCache))
        SubscriptionObjectMenuItem(
          action: SubscriptionFeedMenuAction.offlineCache,
          icon: FleurIcons.offlineCache,
          label: l10n.makeAvailableOffline,
        ),
      if (canMove)
        SubscriptionObjectMenuItem(
          action: SubscriptionFeedMenuAction.move,
          icon: FleurIcons.moveToCategory,
          label: l10n.moveToCategory,
        ),
      if (capabilities.isVisible(BackendFeature.deleteSubscription))
        SubscriptionObjectMenuItem(
          action: SubscriptionFeedMenuAction.delete,
          icon: FleurIcons.delete,
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
          icon: FleurIcons.rename,
          label: l10n.rename,
        ),
      if (capabilities.isVisible(BackendFeature.deleteCategory))
        SubscriptionObjectMenuItem(
          action: SubscriptionCategoryMenuAction.delete,
          icon: FleurIcons.delete,
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
        icon: FleurIcons.allArticles,
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
  sidebarOverflowItems(
    AppLocalizations l10n,
    BackendCapabilities capabilities,
    BackendSyncSemantics syncSemantics,
  ) {
    return [
      SubscriptionObjectMenuItem(
        action: SubscriptionRootMenuAction.settings,
        icon: FleurIcons.settings,
        label: l10n.settings,
      ),
      ...managementItems(
        l10n,
        capabilities,
        syncSemantics,
        includeSettings: false,
        includeAddActions: false,
      ),
    ];
  }

  static List<SubscriptionObjectMenuItem<SubscriptionRootMenuAction>>
  globalDefaultsItems(AppLocalizations l10n) {
    return [
      SubscriptionObjectMenuItem(
        action: SubscriptionRootMenuAction.globalDefaults,
        icon: FleurIcons.subscriptionDefaults,
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
  toolbarOverflowItems(
    AppLocalizations l10n,
    BackendCapabilities capabilities,
    BackendSyncSemantics syncSemantics,
  ) {
    return managementItems(
      l10n,
      capabilities,
      syncSemantics,
      includeSettings: false,
      includeAddActions: false,
    );
  }

  static SubscriptionRootSyncMode? rootSyncMode(
    BackendCapabilities capabilities,
    BackendSyncSemantics syncSemantics,
  ) {
    return resolveSubscriptionRootSyncMode(capabilities, syncSemantics);
  }

  static bool showsRootRefresh(
    BackendCapabilities capabilities,
    BackendSyncSemantics syncSemantics,
  ) {
    return rootSyncMode(capabilities, syncSemantics) != null;
  }

  static String rootRefreshLabel(
    AppLocalizations l10n,
    BackendCapabilities capabilities,
    BackendSyncSemantics syncSemantics,
  ) {
    final mode = rootSyncMode(capabilities, syncSemantics);
    return mode == null
        ? l10n.refreshAll
        : subscriptionRootSyncLabel(l10n, mode);
  }

  static String rootRefreshSuccessLabel(
    AppLocalizations l10n,
    BackendCapabilities capabilities,
    BackendSyncSemantics syncSemantics,
  ) {
    final mode = rootSyncMode(capabilities, syncSemantics);
    return mode == null
        ? l10n.refreshedAll
        : subscriptionRootSyncSuccessLabel(l10n, mode);
  }

  static List<SubscriptionObjectMenuItem<SubscriptionRootMenuAction>>
  managementItems(
    AppLocalizations l10n,
    BackendCapabilities capabilities,
    BackendSyncSemantics syncSemantics, {
    required bool includeSettings,
    bool includeAddActions = true,
  }) {
    return [
      if (showsRootRefresh(capabilities, syncSemantics))
        SubscriptionObjectMenuItem(
          action: SubscriptionRootMenuAction.refreshAll,
          icon: FleurIcons.refresh,
          label: rootRefreshLabel(l10n, capabilities, syncSemantics),
        ),
      if (includeAddActions &&
          capabilities.isVisible(BackendFeature.addSubscription))
        SubscriptionObjectMenuItem(
          action: SubscriptionRootMenuAction.addSubscription,
          icon: FleurIcons.add,
          label: l10n.addSubscription,
        ),
      if (includeAddActions &&
          capabilities.isVisible(BackendFeature.addCategory))
        SubscriptionObjectMenuItem(
          action: SubscriptionRootMenuAction.addCategory,
          icon: FleurIcons.addCategory,
          label: l10n.newCategory,
        ),
      if (capabilities.isVisible(BackendFeature.importOpml))
        SubscriptionObjectMenuItem(
          action: SubscriptionRootMenuAction.importOpml,
          icon: FleurIcons.importOpml,
          label: l10n.importOpml,
        ),
      if (capabilities.isVisible(BackendFeature.exportOpml))
        SubscriptionObjectMenuItem(
          action: SubscriptionRootMenuAction.exportOpml,
          icon: FleurIcons.exportOpml,
          label: l10n.exportOpml,
        ),
      if (includeSettings)
        SubscriptionObjectMenuItem(
          action: SubscriptionRootMenuAction.settings,
          icon: FleurIcons.settings,
          label: l10n.settings,
        ),
    ];
  }

  static List<Widget> menuButtons<T>({
    required BuildContext context,
    required List<SubscriptionObjectMenuItem<T>> items,
    required ValueChanged<T> onSelected,
  }) {
    return AppMenuTiles.menuButtons<T>(
      context: context,
      items: items,
      onSelected: onSelected,
    );
  }

  static List<Widget> bottomSheetTiles<T>({
    required BuildContext context,
    required List<SubscriptionObjectMenuItem<T>> items,
  }) {
    return AppMenuTiles.bottomSheetTiles<T>(context: context, items: items);
  }

  static Future<T?> showContextMenu<T>({
    required BuildContext context,
    required Offset position,
    required List<SubscriptionObjectMenuItem<T>> items,
  }) {
    return AppMenuHost.showAt<T>(context, position: position, items: items);
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
        await SubscriptionActions.addFeed(context, ref);
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
