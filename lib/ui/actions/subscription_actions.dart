import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/account_providers.dart';
import '../../providers/app_settings_providers.dart';
import '../../providers/backend_capabilities_provider.dart';
import '../../providers/opml_providers.dart';
import '../../providers/query_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/service_providers.dart';
import '../../services/accounts/account.dart';
import '../../services/opml/opml_service.dart';
import '../../services/sync/backend_capabilities.dart';
import '../../services/sync/miniflux/miniflux_client.dart';
import '../../ui/actions/remote_structure_feedback.dart' as remote_feedback;
import '../../ui/dialogs/add_subscription_dialog.dart';
import '../../utils/context_extensions.dart';
import '../../utils/platform.dart';

typedef ProviderReadCallback = T Function<T>(ProviderListenable<T> provider);
typedef SubscriptionActionDialogPresenter =
    Future<T?> Function<T>({required WidgetBuilder builder});

class SubscriptionActions {
  static void _resetFeedBrowseFilters(WidgetRef ref) {
    ref.read(starredOnlyProvider.notifier).state = false;
    ref.read(readLaterOnlyProvider.notifier).state = false;
    ref.read(articleSearchQueryProvider.notifier).state = '';
  }

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

  static String _normalizeFeedUrl(String url) {
    return url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  @visibleForTesting
  static String remoteStructureFailureMessageForTest(
    AppLocalizations l10n,
    Object error,
  ) {
    return remote_feedback.remoteStructureFailureMessage(l10n, error);
  }

  static Future<MinifluxClient> _buildMinifluxClient(
    WidgetRef ref,
    Account account,
  ) async {
    return _buildMinifluxClientFromRead(ref.read, account);
  }

  static Future<MinifluxClient> _buildMinifluxClientFromRead(
    ProviderReadCallback read,
    Account account,
  ) async {
    final baseUrl = (account.baseUrl ?? '').trim();
    if (baseUrl.isEmpty) {
      throw StateError('Miniflux baseUrl is empty');
    }

    final credentials = read(credentialStoreProvider);
    final token = await credentials.getApiToken(
      account.id,
      AccountType.miniflux,
    );
    if (token != null && token.trim().isNotEmpty) {
      return MinifluxClient(
        dio: read(dioProvider),
        baseUrl: baseUrl,
        apiToken: token.trim(),
      );
    }

    final basic = await credentials.getBasicAuth(
      account.id,
      AccountType.miniflux,
    );
    if (basic != null) {
      return MinifluxClient(
        dio: read(dioProvider),
        baseUrl: baseUrl,
        username: basic.username,
        password: basic.password,
      );
    }

    throw StateError('Miniflux credentials are missing');
  }

  static Future<int> _resolveRemoteFeedId(
    WidgetRef ref,
    MinifluxClient client,
    int localFeedId,
  ) async {
    final feed = await ref.read(feedRepositoryProvider).getById(localFeedId);
    if (feed == null) {
      throw StateError('Local feed not found: $localFeedId');
    }

    final target = _normalizeFeedUrl(feed.url);
    if (target.isEmpty) {
      throw StateError('Local feed url is empty: $localFeedId');
    }

    final remoteFeeds = await client.getFeeds();
    for (final remote in remoteFeeds) {
      final remoteId = remote['id'];
      final remoteUrl = remote['feed_url'];
      if (remoteId is! int || remoteUrl is! String) continue;
      if (_normalizeFeedUrl(remoteUrl) == target) return remoteId;
    }

    throw StateError('Remote feed not found for url: ${feed.url}');
  }

  static Future<({int remoteId, String title})> _resolveRemoteCategory(
    WidgetRef ref,
    MinifluxClient client,
    int localCategoryId,
  ) async {
    final category = await ref
        .read(categoryRepositoryProvider)
        .getById(localCategoryId);
    if (category == null) {
      throw StateError('Local category not found: $localCategoryId');
    }
    return _resolveRemoteCategoryByTitle(client, category.name);
  }

  static Future<({int remoteId, String title})> _resolveRemoteCategoryByTitle(
    MinifluxClient client,
    String title,
  ) async {
    final target = title.trim();
    if (target.isEmpty) {
      throw StateError('Category title is empty');
    }

    final remoteCategories = await client.getCategories();
    for (final remote in remoteCategories) {
      final remoteId = remote['id'];
      final remoteTitle = remote['title'];
      if (remoteId is! int || remoteTitle is! String) continue;
      if (remoteTitle.trim() == target) {
        return (remoteId: remoteId, title: remoteTitle.trim());
      }
    }

    throw StateError('Remote category not found for title: $target');
  }

  static Future<int?> _resolveLocalFeedIdByUrlFromRead(
    ProviderReadCallback read,
    String url,
  ) async {
    final target = _normalizeFeedUrl(url);
    if (target.isEmpty) return null;

    final feeds = read(feedRepositoryProvider);
    final direct = await feeds.getByUrl(url.trim());
    if (direct != null) return direct.id;

    if (target != url.trim()) {
      final normalized = await feeds.getByUrl(target);
      if (normalized != null) return normalized.id;
    }

    final trailing = await feeds.getByUrl('$target/');
    if (trailing != null) return trailing.id;

    final all = await feeds.getAll();
    for (final feed in all) {
      if (_normalizeFeedUrl(feed.url) == target) return feed.id;
    }
    return null;
  }

  static Future<bool> _hasCategoryNameConflict(
    WidgetRef ref,
    int categoryId,
    String nextName,
  ) async {
    final trimmed = nextName.trim();
    if (trimmed.isEmpty) return false;
    final categories = await ref.read(categoryRepositoryProvider).getAll();
    for (final category in categories) {
      if (category.id == categoryId) continue;
      if (category.name == trimmed) return true;
    }
    return false;
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

  static Future<int?> _reconcileLocalCategoryIdFromRemoteFeed(
    ProviderReadCallback read,
    Map<String, Object?> remoteFeed, {
    int? fallbackCategoryId,
  }) async {
    final remoteCategory = remoteFeed['category'];
    if (remoteCategory is Map) {
      final title = (remoteCategory['title'] as String?)?.trim();
      if (title != null && title.isNotEmpty) {
        return read(categoryRepositoryProvider).upsertByName(title);
      }
    }
    return fallbackCategoryId;
  }

  static Future<void> _reconcileLocalFeedFromRemoteUpdateFromRead(
    ProviderReadCallback read,
    int localFeedId,
    Map<String, Object?> remoteFeed, {
    int? fallbackCategoryId,
  }) async {
    await read(feedRepositoryProvider).updateMeta(
      id: localFeedId,
      title: remoteFeed['title'] as String?,
      siteUrl: remoteFeed['site_url'] as String?,
      description: remoteFeed['description'] as String?,
    );
    final localCategoryId = await _reconcileLocalCategoryIdFromRemoteFeed(
      read,
      remoteFeed,
      fallbackCategoryId: fallbackCategoryId,
    );
    await read(
      feedRepositoryProvider,
    ).setCategory(feedId: localFeedId, categoryId: localCategoryId);
  }

  static Future<void> _reconcileLocalFeedFromRemoteUpdate(
    WidgetRef ref,
    int localFeedId,
    Map<String, Object?> remoteFeed, {
    int? fallbackCategoryId,
  }) {
    return _reconcileLocalFeedFromRemoteUpdateFromRead(
      ref.read,
      localFeedId,
      remoteFeed,
      fallbackCategoryId: fallbackCategoryId,
    );
  }

  @visibleForTesting
  static Future<void> reconcileLocalFeedFromRemoteUpdateForTest(
    ProviderReadCallback read,
    int localFeedId,
    Map<String, Object?> remoteFeed, {
    int? fallbackCategoryId,
  }) {
    return _reconcileLocalFeedFromRemoteUpdateFromRead(
      read,
      localFeedId,
      remoteFeed,
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
    if (resetFilters) _resetFeedBrowseFilters(ref);
    ref.read(selectedFeedIdProvider.notifier).state = feedId;
    // Selecting a feed should exit category/tag browsing context.
    ref.read(selectedCategoryIdProvider.notifier).state = null;
    ref.read(selectedTagIdProvider.notifier).state = null;
  }

  static Future<int?> addFeed(
    BuildContext context,
    WidgetRef ref, {
    NavigatorState? navigator,
  }) {
    return showAddSubscriptionDialog(context, ref, navigator: navigator);
  }

  // Back-compat alias for old call sites.
  static Future<void> showAddFeedDialog(
    BuildContext context,
    WidgetRef ref, {
    NavigatorState? navigator,
  }) async {
    await addFeed(context, ref, navigator: navigator);
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
    if (!_isOnlineRequired(capabilities, feature)) {
      return ref.read(categoryRepositoryProvider).upsertByName(name);
    }

    final account = ref.read(activeAccountProvider);
    try {
      final client = await _buildMinifluxClient(ref, account);
      final created = await client.createCategory(name);
      final remoteTitle = (created['title'] as String?)?.trim();
      final effectiveTitle = (remoteTitle == null || remoteTitle.isEmpty)
          ? name.trim()
          : remoteTitle;
      return ref.read(categoryRepositoryProvider).upsertByName(effectiveTitle);
    } catch (error) {
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
        await ref.read(categoryRepositoryProvider).rename(categoryId, trimmed);
      } catch (e) {
        if (!context.mounted) return;
        final msg = e.toString().contains('already exists')
            ? l10n.nameAlreadyExists
            : e.toString();
        context.showErrorMessage(l10n.errorMessage(msg));
      }
      return;
    }

    if (await _hasCategoryNameConflict(ref, categoryId, trimmed)) {
      if (!context.mounted) return;
      context.showErrorMessage(l10n.errorMessage(l10n.nameAlreadyExists));
      return;
    }

    try {
      final account = ref.read(activeAccountProvider);
      final client = await _buildMinifluxClient(ref, account);
      final remote = await _resolveRemoteCategory(ref, client, categoryId);
      final updated = await client.updateCategory(
        categoryId: remote.remoteId,
        title: trimmed,
      );
      final remoteTitle = (updated['title'] as String?)?.trim();
      await ref
          .read(categoryRepositoryProvider)
          .rename(
            categoryId,
            remoteTitle == null || remoteTitle.isEmpty ? trimmed : remoteTitle,
          );
    } catch (error) {
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
    } catch (error) {
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
    final capabilities = _capabilitiesFromRead(read);
    final categories = read(categoryRepositoryProvider);
    if (!capabilities.isVisible(BackendFeature.deleteCategory)) {
      throw UnsupportedError('Remote category deletion is not supported');
    }

    final isOnlineRequired = _isOnlineRequired(
      capabilities,
      BackendFeature.deleteCategory,
    );
    if (!isOnlineRequired) {
      await categories.delete(categoryId);
      return;
    }

    final account = read(activeAccountProvider);
    final client = await _buildMinifluxClientFromRead(read, account);
    final category = await categories.getById(categoryId);
    if (category == null) {
      throw StateError('Local category not found: $categoryId');
    }
    final remote = await _resolveRemoteCategoryByTitle(client, category.name);
    await client.deleteCategory(remote.remoteId);
    await categories.delete(categoryId);

    // The remote delete already succeeded, so the local mirror must at least
    // stop showing the deleted category even if follow-up reconciliation fails.
    try {
      final feeds = read(feedRepositoryProvider);
      final remoteCatIdToLocalId = <int, int>{};
      for (final remoteCategory in await client.getCategories()) {
        final remoteId = remoteCategory['id'];
        final remoteTitle = remoteCategory['title'];
        if (remoteId is! int || remoteTitle is! String) continue;
        final trimmedTitle = remoteTitle.trim();
        if (trimmedTitle.isEmpty) continue;
        final localId = await categories.upsertByName(trimmedTitle);
        remoteCatIdToLocalId[remoteId] = localId;
      }
      for (final remoteFeed in await client.getFeeds()) {
        final remoteUrl = remoteFeed['feed_url'];
        if (remoteUrl is! String) continue;
        final localFeedId = await _resolveLocalFeedIdByUrlFromRead(
          read,
          remoteUrl,
        );
        if (localFeedId == null) continue;
        final remoteCategoryId = remoteFeed['category'] is Map
            ? (remoteFeed['category'] as Map)['id']
            : remoteFeed['category_id'];
        final localCategoryId = remoteCategoryId is int
            ? remoteCatIdToLocalId[remoteCategoryId]
            : null;
        await feeds.setCategory(
          feedId: localFeedId,
          categoryId: localCategoryId,
        );
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'subscription_actions',
          context: ErrorDescription(
            'while reconciling local mirror after remote category deletion',
          ),
        ),
      );
    }
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
    } catch (error) {
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
    final capabilities = _capabilitiesFromRead(read);
    final feeds = read(feedRepositoryProvider);
    if (!capabilities.isVisible(BackendFeature.deleteSubscription)) {
      throw UnsupportedError('Remote feed deletion is not supported');
    }

    if (!_isOnlineRequired(capabilities, BackendFeature.deleteSubscription)) {
      await feeds.delete(feedId);
      return;
    }

    final account = read(activeAccountProvider);
    final client = await _buildMinifluxClientFromRead(read, account);
    final feed = await feeds.getById(feedId);
    if (feed == null) {
      throw StateError('Local feed not found: $feedId');
    }
    final target = _normalizeFeedUrl(feed.url);
    if (target.isEmpty) {
      throw StateError('Local feed url is empty: $feedId');
    }
    int? remoteFeedId;
    for (final remoteFeed in await client.getFeeds()) {
      final candidateId = remoteFeed['id'];
      final remoteUrl = remoteFeed['feed_url'];
      if (candidateId is! int || remoteUrl is! String) continue;
      if (_normalizeFeedUrl(remoteUrl) == target) {
        remoteFeedId = candidateId;
        break;
      }
    }
    if (remoteFeedId == null) {
      throw StateError('Remote feed not found for url: ${feed.url}');
    }
    await client.deleteFeed(remoteFeedId);
    await feeds.delete(feedId);
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

    if (!_isOnlineRequired(capabilities, feature)) {
      final r = await ref.read(syncServiceProvider).refreshFeedSafe(feedId);
      if (!context.mounted) return;
      context.showSnack(
        r.ok ? l10n.refreshed : l10n.errorMessage(r.error.toString()),
      );
      return;
    }

    try {
      final account = ref.read(activeAccountProvider);
      final client = await _buildMinifluxClient(ref, account);
      final remoteFeedId = await _resolveRemoteFeedId(ref, client, feedId);
      await client.refreshFeed(remoteFeedId);
      final result = await ref
          .read(syncServiceProvider)
          .refreshFeedSafe(feedId, notify: false);
      if (!context.mounted) return;
      context.showSnack(
        result.ok ? l10n.refreshed : l10n.errorMessage(result.error.toString()),
      );
    } catch (error) {
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
    final feeds = await ref.read(feedRepositoryProvider).getAll();
    if (!context.mounted) return;

    final appSettings = ref.read(appSettingsProvider).valueOrNull;
    final concurrency = appSettings?.autoRefreshConcurrency ?? 2;
    final capabilities = _capabilities(ref);
    final feedIds = feeds.map((f) => f.id);

    if (!capabilities.isVisible(BackendFeature.refreshAllSources) &&
        capabilities.isVisible(BackendFeature.syncNow)) {
      final batch = await ref
          .read(syncServiceProvider)
          .refreshFeedsSafe(feedIds, maxConcurrent: concurrency);

      if (!context.mounted) return;

      final err = batch.firstError?.error;
      context.showSnack(
        err == null ? l10n.refreshedAll : l10n.errorMessage(err.toString()),
      );
      return;
    }

    if (!capabilities.isVisible(BackendFeature.refreshAllSources)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return;
    }

    if (!_isOnlineRequired(capabilities, BackendFeature.refreshAllSources)) {
      final batch = await ref
          .read(syncServiceProvider)
          .refreshFeedsSafe(feedIds, maxConcurrent: concurrency);

      if (!context.mounted) return;

      final err = batch.firstError?.error;
      context.showSnack(
        err == null ? l10n.refreshedAll : l10n.errorMessage(err.toString()),
      );
      return;
    }

    try {
      final account = ref.read(activeAccountProvider);
      final client = await _buildMinifluxClient(ref, account);
      await client.refreshAllFeeds();
      final batch = await ref
          .read(syncServiceProvider)
          .refreshFeedsSafe(feedIds, maxConcurrent: concurrency, notify: false);
      if (!context.mounted) return;
      final err = batch.firstError?.error;
      context.showSnack(
        err == null ? l10n.refreshedAll : l10n.errorMessage(err.toString()),
      );
    } catch (error) {
      if (!context.mounted) return;
      remote_feedback.showRemoteStructureFailure(context, l10n, error);
    }
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
      await ref
          .read(feedRepositoryProvider)
          .setCategory(feedId: feedId, categoryId: categoryId);
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
      final account = ref.read(activeAccountProvider);
      final client = await _buildMinifluxClient(ref, account);
      final remoteFeedId = await _resolveRemoteFeedId(ref, client, feedId);
      final remoteCategory = await _resolveRemoteCategory(
        ref,
        client,
        categoryId!,
      );
      final updatedFeed = await client.updateFeed(
        feedId: remoteFeedId,
        categoryId: remoteCategory.remoteId,
      );
      await _reconcileLocalFeedFromRemoteUpdate(
        ref,
        feedId,
        updatedFeed,
        fallbackCategoryId: categoryId,
      );
    } catch (error) {
      if (!context.mounted) return;
      remote_feedback.showRemoteStructureFailure(context, l10n, error);
    }
  }

  static Future<void> importOpml(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    if (!_capabilities(ref).isVisible(BackendFeature.importOpml)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return;
    }

    final group = XTypeGroup(
      label: 'OPML',
      extensions: ['opml', 'xml'],
      mimeTypes: ['text/xml', 'application/xml'],
      // iPadOS: some .opml files are marked as public.data rather than public.xml.
      // Loosen UTI on iOS and validate after selection.
      uniformTypeIdentifiers: isIOS
          ? ['public.xml', 'public.text', 'public.data']
          : ['public.xml'],
    );

    XFile? file;
    try {
      file = await openFile(acceptedTypeGroups: [group]);
    } catch (e) {
      if (!context.mounted) return;
      context.showErrorMessage(l10n.errorMessage(e.toString()));
      return;
    }
    if (file == null) return;

    final nameOrPath = file.name.isNotEmpty ? file.name : file.path;
    final dot = nameOrPath.lastIndexOf('.');
    final ext = dot == -1 ? '' : nameOrPath.substring(dot).toLowerCase();
    // Allow files without extension (some providers do that).
    if (ext.isNotEmpty && ext != '.opml' && ext != '.xml') {
      if (!context.mounted) return;
      context.showErrorMessage(l10n.errorMessage(l10n.opmlParseFailed));
      return;
    }

    String xml;
    try {
      xml = await file.readAsString();
    } catch (e) {
      if (!context.mounted) return;
      context.showErrorMessage(l10n.errorMessage(e.toString()));
      return;
    }

    List<OpmlEntry> entries;
    try {
      entries = ref.read(opmlServiceProvider).parseEntries(xml);
    } catch (_) {
      if (!context.mounted) return;
      context.showErrorMessage(l10n.errorMessage(l10n.opmlParseFailed));
      return;
    }
    if (entries.isEmpty) {
      if (!context.mounted) return;
      context.showSnack(l10n.noFeedsFoundInOpml);
      return;
    }

    var added = 0;
    for (final e in entries) {
      final feedId = await ref.read(feedRepositoryProvider).upsertUrl(e.url);
      if (e.category != null && e.category!.trim().isNotEmpty) {
        final catId = await ref
            .read(categoryRepositoryProvider)
            .upsertByName(e.category!);
        await ref
            .read(feedRepositoryProvider)
            .setCategory(feedId: feedId, categoryId: catId);
      }
      added += 1;
    }
    if (!context.mounted) return;
    context.showSnack(l10n.importedFeeds(added));
  }

  static Future<void> exportOpml(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    if (!_capabilities(ref).isVisible(BackendFeature.exportOpml)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return;
    }

    final feeds = await ref.read(feedRepositoryProvider).getAll();
    if (feeds.isEmpty) return;

    final cats = await ref.read(categoryRepositoryProvider).getAll();
    final names = {for (final c in cats) c.id: c.name};

    final xml = ref
        .read(opmlServiceProvider)
        .buildOpml(feeds: feeds, categoryNames: names);

    final bytes = Uint8List.fromList(utf8.encode(xml));
    // file_selector_ios may throw UnimplementedError for save dialogs.
    // On iOS we export via the system share sheet so users can "Save to Files".
    if (isIOS) {
      final xfile = XFile.fromData(
        bytes,
        mimeType: 'text/xml',
        name: 'subscriptions.opml',
      );
      final tmpDir = await getTemporaryDirectory();
      final tmpPath = '${tmpDir.path}/subscriptions.opml';
      try {
        await xfile.saveTo(tmpPath);
        await IosShareBridge.shareFile(
          path: tmpPath,
          mimeType: 'text/xml',
          name: 'subscriptions.opml',
        );
      } catch (e) {
        if (!context.mounted) return;
        context.showErrorMessage(l10n.errorMessage(e.toString()));
        return;
      }
      if (!context.mounted) return;
      context.showSnack(l10n.exportedOpml);
      return;
    }

    const group = XTypeGroup(
      label: 'OPML',
      extensions: ['opml', 'xml'],
      mimeTypes: ['text/xml', 'application/xml'],
      uniformTypeIdentifiers: ['public.xml'],
    );

    FileSaveLocation? loc;
    try {
      loc = await getSaveLocation(
        suggestedName: 'subscriptions.opml',
        acceptedTypeGroups: [group],
      );
    } catch (e) {
      if (!context.mounted) return;
      context.showErrorMessage(l10n.errorMessage(e.toString()));
      return;
    }
    if (loc == null) return;

    final file = XFile.fromData(bytes, mimeType: 'text/xml', name: loc.path);
    try {
      await file.saveTo(loc.path);
    } catch (e) {
      if (!context.mounted) return;
      context.showErrorMessage(l10n.errorMessage(e.toString()));
      return;
    }
    if (!context.mounted) return;
    context.showSnack(l10n.exportedOpml);
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
