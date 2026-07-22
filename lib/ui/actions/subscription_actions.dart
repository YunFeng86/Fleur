import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../features/subscriptions/subscriptions.dart';
import '../../providers/account_providers.dart';
import '../../providers/app_settings_providers.dart';
import '../../providers/backend_capabilities_provider.dart';
import '../../providers/backend_sync_semantics_provider.dart';
import '../../providers/refresh_all_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/service_providers.dart';
import '../../services/accounts/account.dart';
import '../../services/logging/app_logger.dart';
import '../../services/sync/backend_capabilities.dart';
import '../../services/sync/refresh_all_coordinator.dart';
import '../../services/sync/remote_subscription_structure_executor.dart';
import '../../services/sync/subscription_mirror_service.dart';
import '../../screens/add_subscription_screen.dart';
import '../../ui/actions/remote_structure_feedback.dart' as remote_feedback;
import '../../utils/context_extensions.dart';
import 'root_sync_action.dart';

typedef ProviderReadCallback = T Function<T>(ProviderListenable<T> provider);
typedef SubscriptionActionDialogPresenter =
    Future<T?> Function<T>({required WidgetBuilder builder});

class SubscriptionActions {
  static BackendCapabilities _capabilities(WidgetRef ref) {
    return ref.read(backendCapabilitiesProvider);
  }

  static BackendCapabilities _capabilitiesFromRead(ProviderReadCallback read) {
    return read(backendCapabilitiesProvider);
  }

  static bool _isOnlineRequired(
    BackendCapabilities capabilities,
    BackendFeature feature,
  ) {
    return capabilities.availability(feature) ==
        FeatureAvailability.onlineRequired;
  }

  @visibleForTesting
  static String remoteStructureFailureMessageForTest(
    AppLocalizations l10n,
    Object error,
  ) {
    return remote_feedback.remoteStructureFailureMessage(l10n, error);
  }

  static Future<MinifluxRemoteSubscriptionStructureExecutor>
  _buildMinifluxStructureExecutorFromRead(
    ProviderReadCallback read,
    Account account,
  ) async {
    final client = await read(remoteClientFactoryProvider).miniflux(account);
    return MinifluxRemoteSubscriptionStructureExecutor(client);
  }

  static void _logSubscriptionFailure(
    WidgetRef ref,
    String operation,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    final account = ref.read(activeAccountProvider);
    final capabilities = _capabilities(ref);
    AppLogger.w(
      'Subscription operation failed',
      tag: 'subscription',
      error: error,
      stackTrace: stackTrace,
      context: subscriptionMirrorFailureContext(
        account,
        capabilities,
        error,
        operation,
      ),
    );
  }

  static SubscriptionMirrorService _mirrorService(WidgetRef ref) {
    return _mirrorServiceFromRead(ref.read);
  }

  static SubscriptionMirrorService _mirrorServiceFromRead(
    ProviderReadCallback read,
  ) {
    final account = read(activeAccountProvider);
    return SubscriptionMirrorService(
      capabilities: _capabilitiesFromRead(read),
      account: account,
      feeds: read(feedRepositoryProvider),
      categories: read(categoryRepositoryProvider),
      buildExecutor: () =>
          _buildMinifluxStructureExecutorFromRead(read, account),
    );
  }

  static Future<T?> _presentDialog<T>(
    BuildContext context, {
    SubscriptionActionDialogPresenter? dialogPresenter,
    required WidgetBuilder builder,
  }) {
    if (dialogPresenter != null) {
      return dialogPresenter<T>(builder: builder);
    }
    return showDialog<T>(context: context, builder: builder);
  }

  static Future<String?> _presentTextInputDialog(
    BuildContext context, {
    SubscriptionActionDialogPresenter? dialogPresenter,
    required String title,
    String? labelText,
    String initialText = '',
    String? confirmText,
  }) async {
    final controller = TextEditingController(text: initialText);
    try {
      return _presentDialog<String>(
        context,
        dialogPresenter: dialogPresenter,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(labelText: labelText),
              autofocus: true,
              onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text),
                child: Text(
                  confirmText ??
                      MaterialLocalizations.of(dialogContext).okButtonLabel,
                ),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  @visibleForTesting
  static Future<void> reconcileLocalFeedFromRemoteUpdateForTest(
    ProviderReadCallback read,
    int localFeedId,
    Map<String, Object?> remoteFeed, {
    int? fallbackCategoryId,
  }) {
    return _mirrorServiceFromRead(read).reconcileLocalFeedFromRemoteUpdate(
      localFeedId: localFeedId,
      remoteFeed: remoteFeed,
      fallbackCategoryId: fallbackCategoryId,
    );
  }

  /// Select a feed for browsing.
  ///
  /// When [resetFilters] is true (default), clears global filters/search that
  /// may not make sense after switching feeds.
  static void selectFeed(
    WidgetRef ref,
    int feedId, {
    bool resetFilters = true,
  }) {
    SubscriptionFeedBrowsing.selectFeed(
      ref.read,
      feedId,
      resetFilters: resetFilters,
    );
  }

  static Future<int?> addFeed(
    BuildContext context,
    WidgetRef ref, {
    NavigatorState? navigator,
    int? initialCategoryId,
  }) async {
    final capabilities = _capabilities(ref);
    if (!capabilities.isVisible(BackendFeature.addSubscription)) {
      final l10n = AppLocalizations.of(context)!;
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return null;
    }

    final location = _addSubscriptionLocation(
      initialCategoryId: initialCategoryId,
    );
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(location);
      return null;
    }

    await (navigator ?? Navigator.of(context)).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            AddSubscriptionScreen(initialCategoryId: initialCategoryId),
      ),
    );
    return null;
  }

  static String _addSubscriptionLocation({int? initialCategoryId}) {
    if (initialCategoryId == null) return '/add-subscription';
    return Uri(
      path: '/add-subscription',
      queryParameters: <String, String>{
        'categoryId': initialCategoryId.toString(),
      },
    ).toString();
  }

  static Future<int?> addCategory(
    BuildContext context,
    WidgetRef ref, {
    SubscriptionActionDialogPresenter? dialogPresenter,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = _capabilities(ref);
    const feature = BackendFeature.addCategory;
    if (!capabilities.isVisible(feature)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return null;
    }

    final name = await _presentTextInputDialog(
      context,
      dialogPresenter: dialogPresenter,
      title: l10n.newCategory,
      labelText: l10n.name,
      confirmText: l10n.create,
    );
    if (!context.mounted) return null;
    if (name == null || name.trim().isEmpty) return null;

    try {
      return await _mirrorService(ref).addCategory(name);
    } catch (error, stackTrace) {
      _logSubscriptionFailure(ref, 'createCategory', error, stackTrace);
      if (!context.mounted) return null;
      remote_feedback.showRemoteStructureFailure(context, l10n, error);
      return null;
    }
  }

  static Future<void> renameCategory(
    BuildContext context,
    WidgetRef ref, {
    required int categoryId,
    required String currentName,
    SubscriptionActionDialogPresenter? dialogPresenter,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = _capabilities(ref);
    const feature = BackendFeature.renameCategory;
    if (!capabilities.isVisible(feature)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return;
    }

    final next = await _presentTextInputDialog(
      context,
      dialogPresenter: dialogPresenter,
      title: l10n.rename,
      labelText: l10n.name,
      initialText: currentName,
      confirmText: l10n.done,
    );
    if (!context.mounted) return;
    if (next == null) return;

    final trimmed = next.trim();
    if (trimmed.isEmpty) return;

    if (!_isOnlineRequired(capabilities, feature)) {
      try {
        await _mirrorService(ref).renameCategory(
          categoryId: categoryId,
          currentName: currentName,
          nextName: trimmed,
        );
      } catch (e) {
        if (!context.mounted) return;
        final msg = e.toString().contains('already exists')
            ? l10n.nameAlreadyExists
            : e.toString();
        context.showErrorMessage(l10n.errorMessage(msg));
      }
      return;
    }

    try {
      await _mirrorService(ref).renameCategory(
        categoryId: categoryId,
        currentName: currentName,
        nextName: trimmed,
      );
    } on CategoryNameConflictException {
      if (!context.mounted) return;
      context.showErrorMessage(l10n.errorMessage(l10n.nameAlreadyExists));
    } catch (error, stackTrace) {
      _logSubscriptionFailure(ref, 'renameCategory', error, stackTrace);
      if (!context.mounted) return;
      remote_feedback.showRemoteStructureFailure(context, l10n, error);
    }
  }

  static Future<bool> deleteCategory(
    BuildContext context,
    WidgetRef ref, {
    required int categoryId,
    SubscriptionActionDialogPresenter? dialogPresenter,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = _capabilities(ref);
    if (!capabilities.isVisible(BackendFeature.deleteCategory)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return false;
    }
    final isOnlineRequired = _isOnlineRequired(
      capabilities,
      BackendFeature.deleteCategory,
    );
    final ok = await _presentDialog<bool>(
      context,
      dialogPresenter: dialogPresenter,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteCategoryConfirmTitle),
          content: Text(
            isOnlineRequired
                ? l10n.remoteDeleteCategoryConfirmContent
                : l10n.deleteCategoryConfirmContent,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (!context.mounted) return false;
    if (ok != true) return false;

    return deleteCategoryConfirmed(context, ref, categoryId);
  }

  @visibleForTesting
  static Future<bool> deleteCategoryConfirmed(
    BuildContext context,
    WidgetRef ref,
    int categoryId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (!_capabilities(ref).isVisible(BackendFeature.deleteCategory)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return false;
    }

    try {
      await deleteCategoryConfirmedCore(ref, categoryId);
      if (!context.mounted) return true;
      context.showSnack(l10n.categoryDeleted);
      return true;
    } catch (error, stackTrace) {
      _logSubscriptionFailure(ref, 'deleteCategory', error, stackTrace);
      if (!context.mounted) return false;
      remote_feedback.showRemoteStructureFailure(context, l10n, error);
      return false;
    }
  }

  @visibleForTesting
  static Future<void> deleteCategoryConfirmedCore(
    WidgetRef ref,
    int categoryId,
  ) async {
    return deleteCategoryConfirmedCoreFromRead(ref.read, categoryId);
  }

  @visibleForTesting
  static Future<void> deleteCategoryConfirmedCoreFromRead(
    ProviderReadCallback read,
    int categoryId,
  ) async {
    return _mirrorServiceFromRead(read).deleteCategory(categoryId);
  }

  static Future<void> editFeedTitle(
    BuildContext context,
    WidgetRef ref, {
    required int feedId,
    required String? currentTitle,
    SubscriptionActionDialogPresenter? dialogPresenter,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentTitle ?? '');
    try {
      final next = await _presentDialog<String?>(
        context,
        dialogPresenter: dialogPresenter,
        builder: (context) {
          return buildEditFeedTitleDialogForTest(
            context,
            l10n: l10n,
            controller: controller,
          );
        },
      );
      if (next == null) return;
      await ref
          .read(feedRepositoryProvider)
          .setUserTitle(feedId: feedId, userTitle: next);
    } finally {
      controller.dispose();
    }
  }

  @visibleForTesting
  static Widget buildEditFeedTitleDialogForTest(
    BuildContext context, {
    required AppLocalizations l10n,
    required TextEditingController controller,
  }) {
    return AlertDialog(
      title: Text(l10n.edit),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: l10n.name),
        autofocus: true,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(''),
          child: Text(l10n.delete),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(l10n.done),
        ),
      ],
    );
  }

  static Future<bool> deleteFeed(
    BuildContext context,
    WidgetRef ref, {
    required int feedId,
    SubscriptionActionDialogPresenter? dialogPresenter,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (!_capabilities(ref).isVisible(BackendFeature.deleteSubscription)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return false;
    }

    final ok = await _presentDialog<bool>(
      context,
      dialogPresenter: dialogPresenter,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteSubscriptionConfirmTitle),
          content: Text(l10n.deleteSubscriptionConfirmContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (!context.mounted) return false;
    if (ok != true) return false;

    return deleteFeedConfirmed(context, ref, feedId);
  }

  @visibleForTesting
  static Future<bool> deleteFeedConfirmed(
    BuildContext context,
    WidgetRef ref,
    int feedId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = _capabilities(ref);
    if (!capabilities.isVisible(BackendFeature.deleteSubscription)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return false;
    }

    try {
      await deleteFeedConfirmedCore(ref, feedId);
      if (!context.mounted) return true;
      context.showSnack(l10n.deleted);
      return true;
    } catch (error, stackTrace) {
      _logSubscriptionFailure(ref, 'deleteFeed', error, stackTrace);
      if (!context.mounted) return false;
      remote_feedback.showRemoteStructureFailure(context, l10n, error);
      return false;
    }
  }

  @visibleForTesting
  static Future<void> deleteFeedConfirmedCore(WidgetRef ref, int feedId) async {
    return deleteFeedConfirmedCoreFromRead(ref.read, feedId);
  }

  @visibleForTesting
  static Future<void> deleteFeedConfirmedCoreFromRead(
    ProviderReadCallback read,
    int feedId,
  ) async {
    return _mirrorServiceFromRead(read).deleteFeed(feedId);
  }

  /// Feed settings remain client-only even for remote-backed accounts.
  static Future<void> updateFeedSettings(
    BuildContext context,
    WidgetRef ref, {
    required int feedId,
    bool? filterEnabled,
    bool updateFilterEnabled = false,
    String? filterKeywords,
    bool updateFilterKeywords = false,
    bool? syncEnabled,
    bool updateSyncEnabled = false,
    bool? syncImages,
    bool updateSyncImages = false,
    bool? syncWebPages,
    bool updateSyncWebPages = false,
    bool? showAiSummary,
    bool updateShowAiSummary = false,
    bool? autoTranslate,
    bool updateAutoTranslate = false,
  }) async {
    await ref
        .read(feedRepositoryProvider)
        .updateSettings(
          id: feedId,
          filterEnabled: filterEnabled,
          updateFilterEnabled: updateFilterEnabled,
          filterKeywords: filterKeywords,
          updateFilterKeywords: updateFilterKeywords,
          syncEnabled: syncEnabled,
          updateSyncEnabled: updateSyncEnabled,
          syncImages: syncImages,
          updateSyncImages: updateSyncImages,
          syncWebPages: syncWebPages,
          updateSyncWebPages: updateSyncWebPages,
          showAiSummary: showAiSummary,
          updateShowAiSummary: updateShowAiSummary,
          autoTranslate: autoTranslate,
          updateAutoTranslate: updateAutoTranslate,
        );
  }

  /// Category settings remain client-only even for remote-backed accounts.
  static Future<void> updateCategorySettings(
    BuildContext context,
    WidgetRef ref, {
    required int categoryId,
    bool? filterEnabled,
    bool updateFilterEnabled = false,
    String? filterKeywords,
    bool updateFilterKeywords = false,
    bool? syncEnabled,
    bool updateSyncEnabled = false,
    bool? syncImages,
    bool updateSyncImages = false,
    bool? syncWebPages,
    bool updateSyncWebPages = false,
    bool? showAiSummary,
    bool updateShowAiSummary = false,
    bool? autoTranslate,
    bool updateAutoTranslate = false,
  }) async {
    await ref
        .read(categoryRepositoryProvider)
        .updateSettings(
          id: categoryId,
          filterEnabled: filterEnabled,
          updateFilterEnabled: updateFilterEnabled,
          filterKeywords: filterKeywords,
          updateFilterKeywords: updateFilterKeywords,
          syncEnabled: syncEnabled,
          updateSyncEnabled: updateSyncEnabled,
          syncImages: syncImages,
          updateSyncImages: updateSyncImages,
          syncWebPages: syncWebPages,
          updateSyncWebPages: updateSyncWebPages,
          showAiSummary: showAiSummary,
          updateShowAiSummary: updateShowAiSummary,
          autoTranslate: autoTranslate,
          updateAutoTranslate: updateAutoTranslate,
        );
  }

  // Back-compat alias.
  static Future<void> showAddCategoryDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await addCategory(context, ref);
  }

  static Future<void> refreshFeed(
    BuildContext context,
    WidgetRef ref,
    int feedId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = _capabilities(ref);
    const feature = BackendFeature.refreshSubscriptionSource;
    if (!capabilities.isVisible(feature)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return;
    }

    try {
      final result = await ref
          .read(scopedRefreshCoordinatorProvider)
          .refreshScope(scope: FeedRefreshScope(feedId));
      if (!context.mounted) return;
      final err = result.firstError;
      if (result.error != null) {
        _logSubscriptionFailure(
          ref,
          'refreshFeed',
          result.error!,
          result.stackTrace,
        );
        remote_feedback.showRemoteStructureFailure(
          context,
          l10n,
          result.error!,
        );
        return;
      }
      context.showSnack(
        err == null ? l10n.refreshed : l10n.errorMessage(err.toString()),
      );
    } catch (error, stackTrace) {
      _logSubscriptionFailure(ref, 'refreshFeed', error, stackTrace);
      if (!context.mounted) return;
      remote_feedback.showRemoteStructureFailure(context, l10n, error);
    }
  }

  static Future<void> cacheFeedOffline(
    BuildContext context,
    WidgetRef ref,
    int feedId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final count = await ref.read(syncServiceProvider).offlineCacheFeed(feedId);
    if (!context.mounted) return;
    context.showSnack(l10n.cachingArticles(count));
  }

  static Future<void> refreshAll(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final appSettings = ref.read(appSettingsProvider).valueOrNull;
    final concurrency = appSettings?.autoRefreshConcurrency ?? 2;
    final capabilities = _capabilities(ref);
    final syncSemantics = ref.read(backendSyncSemanticsProvider);
    final mode = resolveSubscriptionRootSyncMode(capabilities, syncSemantics);
    if (mode == null) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return;
    }

    final result = await ref
        .read(scopedRefreshCoordinatorProvider)
        .refreshScope(
          scope: const AllRefreshScope(),
          maxConcurrent: concurrency,
        );
    if (!context.mounted) return;
    final err = result.firstError;
    if (result.error != null) {
      _logSubscriptionFailure(
        ref,
        'refreshAllFeeds',
        result.error!,
        result.stackTrace,
      );
      remote_feedback.showRemoteStructureFailure(context, l10n, result.error!);
      return;
    }
    context.showSnack(
      err == null
          ? subscriptionRootSyncSuccessLabel(l10n, mode)
          : l10n.errorMessage(err.toString()),
    );
  }

  static Future<void> moveFeedToCategory(
    BuildContext context,
    WidgetRef ref, {
    required int feedId,
    SubscriptionActionDialogPresenter? dialogPresenter,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = _capabilities(ref);
    final canMoveToCategory = capabilities.isVisible(
      BackendFeature.moveSubscriptionToCategory,
    );
    final canMoveToUncategorized = capabilities.isVisible(
      BackendFeature.moveSubscriptionToUncategorized,
    );
    if (!canMoveToCategory && !canMoveToUncategorized) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return;
    }

    final isOnlineRequired = _isOnlineRequired(
      capabilities,
      BackendFeature.moveSubscriptionToCategory,
    );
    final cats = await ref.read(categoryRepositoryProvider).getAll();
    if (!context.mounted) return;

    if (!canMoveToUncategorized && cats.isEmpty) {
      context.showErrorMessage(l10n.remoteCommandRequiresCategory);
      return;
    }

    final selected = await _presentDialog<_MoveFeedCategoryPick?>(
      context,
      dialogPresenter: dialogPresenter,
      builder: (context) {
        return SimpleDialog(
          title: Text(l10n.moveToCategory),
          children: [
            if (canMoveToUncategorized)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.of(context).pop(const _MoveFeedToUncategorized()),
                child: Text(l10n.uncategorized),
              ),
            for (final c in cats)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.of(context).pop(_MoveFeedToCategory(c.id)),
                child: Text(c.name),
              ),
          ],
        );
      },
    );

    if (selected == null) return;

    final categoryId = switch (selected) {
      _MoveFeedToUncategorized() => null,
      _MoveFeedToCategory(:final categoryId) => categoryId,
    };

    if (!isOnlineRequired) {
      await _mirrorService(
        ref,
      ).moveFeedToCategory(feedId: feedId, categoryId: categoryId);
      return;
    }

    final feature = categoryId == null
        ? BackendFeature.moveSubscriptionToUncategorized
        : BackendFeature.moveSubscriptionToCategory;
    if (!capabilities.isVisible(feature)) {
      final message = categoryId == null
          ? l10n.remoteCommandRequiresCategory
          : l10n.remoteCommandNotSupported;
      if (!context.mounted) return;
      context.showErrorMessage(message);
      return;
    }

    try {
      await _mirrorService(
        ref,
      ).moveFeedToCategory(feedId: feedId, categoryId: categoryId);
    } catch (error, stackTrace) {
      _logSubscriptionFailure(ref, 'moveFeedToCategory', error, stackTrace);
      if (!context.mounted) return;
      remote_feedback.showRemoteStructureFailure(context, l10n, error);
    }
  }
}

sealed class _MoveFeedCategoryPick {
  const _MoveFeedCategoryPick();
}

final class _MoveFeedToUncategorized extends _MoveFeedCategoryPick {
  const _MoveFeedToUncategorized();
}

final class _MoveFeedToCategory extends _MoveFeedCategoryPick {
  const _MoveFeedToCategory(this.categoryId);

  final int categoryId;
}
