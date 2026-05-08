import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
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
import '../../services/logging/app_logger.dart';
import '../../services/logging/log_context.dart';
import '../../services/opml/opml_service.dart';
import '../../services/sync/backend_capabilities.dart';
import '../../services/sync/remote_subscription_structure_executor.dart';
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

  static int? _remoteIdAsInt(String? remoteId) {
    final trimmed = remoteId?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final value = int.tryParse(trimmed);
    return value != null && value > 0 ? value : null;
  }

  static String? _remoteIdString(Object? value) {
    if (value is int && value > 0) return value.toString();
    if (value is num && value > 0) return value.toInt().toString();
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  @visibleForTesting
  static String remoteStructureFailureMessageForTest(
    AppLocalizations l10n,
    Object error,
  ) {
    return remote_feedback.remoteStructureFailureMessage(l10n, error);
  }

  static Future<MinifluxRemoteSubscriptionStructureExecutor>
  _buildMinifluxStructureExecutor(WidgetRef ref, Account account) async {
    final client = await ref
        .read(remoteClientFactoryProvider)
        .miniflux(account);
    return MinifluxRemoteSubscriptionStructureExecutor(client);
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
      context: _subscriptionFailureContext(
        account,
        capabilities,
        error,
        operation,
      ),
    );
  }

  static Map<String, Object?> _subscriptionFailureContext(
    Account account,
    BackendCapabilities capabilities,
    Object error,
    String operation,
  ) {
    final extra = <String, Object?>{
      'accountId': account.id,
      'accountType': capabilities.diagnosticAccountType,
      'operation': operation,
    };
    if (error is DioException) {
      return logContextForDioException(error, extra: extra);
    }
    final baseUrl = account.baseUrl?.trim();
    final uri = baseUrl == null || baseUrl.isEmpty
        ? null
        : Uri.tryParse(baseUrl);
    if (uri == null) return extra;
    return logContextForUri(uri, extra: extra);
  }

  static Future<String> _localFeedUrlFromRead(
    ProviderReadCallback read,
    int localFeedId,
  ) async {
    final feed = await read(feedRepositoryProvider).getById(localFeedId);
    if (feed == null) {
      throw StateError('Local feed not found: $localFeedId');
    }

    final target = _normalizeFeedUrl(feed.url);
    if (target.isEmpty) {
      throw StateError('Local feed url is empty: $localFeedId');
    }
    return feed.url;
  }

  static Future<int?> _localFeedRemoteIdFromRead(
    ProviderReadCallback read,
    int localFeedId,
  ) async {
    final feed = await read(feedRepositoryProvider).getById(localFeedId);
    if (feed == null) {
      throw StateError('Local feed not found: $localFeedId');
    }
    return _remoteIdAsInt(feed.remoteId);
  }

  static Future<String> _localCategoryTitleFromRead(
    ProviderReadCallback read,
    int localCategoryId,
  ) async {
    final category = await read(
      categoryRepositoryProvider,
    ).getById(localCategoryId);
    if (category == null) {
      throw StateError('Local category not found: $localCategoryId');
    }
    return category.name;
  }

  static Future<int?> _localCategoryRemoteIdFromRead(
    ProviderReadCallback read,
    int localCategoryId,
  ) async {
    final category = await read(
      categoryRepositoryProvider,
    ).getById(localCategoryId);
    if (category == null) {
      throw StateError('Local category not found: $localCategoryId');
    }
    return _remoteIdAsInt(category.remoteId);
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
      final remoteId = _remoteIdString(remoteCategory['id']);
      final title = (remoteCategory['title'] as String?)?.trim();
      if (title != null && title.isNotEmpty) {
        if (remoteId != null) {
          return read(
            categoryRepositoryProvider,
          ).upsertRemote(remoteId: remoteId, name: title);
        }
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
    final localCategoryId = await _reconcileLocalCategoryIdFromRemoteFeed(
      read,
      remoteFeed,
      fallbackCategoryId: fallbackCategoryId,
    );
    final remoteId = _remoteIdString(remoteFeed['id']);
    final remoteUrl = remoteFeed['feed_url'];
    if (remoteId != null &&
        remoteUrl is String &&
        remoteUrl.trim().isNotEmpty) {
      await read(feedRepositoryProvider).upsertRemote(
        remoteId: remoteId,
        url: remoteUrl,
        title: remoteFeed['title'] as String?,
        siteUrl: remoteFeed['site_url'] as String?,
        description: remoteFeed['description'] as String?,
        categoryId: localCategoryId,
        preferredLocalFeedId: localFeedId,
      );
      return;
    }

    await read(feedRepositoryProvider).updateMeta(
      id: localFeedId,
      title: remoteFeed['title'] as String?,
      siteUrl: remoteFeed['site_url'] as String?,
      description: remoteFeed['description'] as String?,
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
      final executor = await _buildMinifluxStructureExecutor(ref, account);
      final created = await executor.createCategory(name);
      final remoteId = _remoteIdString(created['id']);
      final remoteTitle = (created['title'] as String?)?.trim();
      final effectiveTitle = (remoteTitle == null || remoteTitle.isEmpty)
          ? name.trim()
          : remoteTitle;
      if (remoteId != null) {
        return ref
            .read(categoryRepositoryProvider)
            .upsertRemote(remoteId: remoteId, name: effectiveTitle);
      }
      return ref.read(categoryRepositoryProvider).upsertByName(effectiveTitle);
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
      final executor = await _buildMinifluxStructureExecutor(ref, account);
      final categoryRemoteId = await _localCategoryRemoteIdFromRead(
        ref.read,
        categoryId,
      );
      final updated = categoryRemoteId == null
          ? await executor.renameCategoryByTitle(
              currentTitle: await _localCategoryTitleFromRead(
                ref.read,
                categoryId,
              ),
              title: trimmed,
            )
          : await executor.renameCategoryById(
              categoryId: categoryRemoteId,
              title: trimmed,
            );
      final remoteTitle = (updated['title'] as String?)?.trim();
      final effectiveTitle = remoteTitle == null || remoteTitle.isEmpty
          ? trimmed
          : remoteTitle;
      if (categoryRemoteId == null) {
        await ref
            .read(categoryRepositoryProvider)
            .rename(categoryId, effectiveTitle);
      } else {
        await ref
            .read(categoryRepositoryProvider)
            .upsertRemote(
              remoteId: categoryRemoteId.toString(),
              name: effectiveTitle,
            );
      }
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
    final executor = await _buildMinifluxStructureExecutorFromRead(
      read,
      account,
    );
    final categoryRemoteId = await _localCategoryRemoteIdFromRead(
      read,
      categoryId,
    );
    if (categoryRemoteId == null) {
      final categoryTitle = await _localCategoryTitleFromRead(read, categoryId);
      await executor.deleteCategoryByTitle(categoryTitle);
    } else {
      await executor.deleteCategoryById(categoryRemoteId);
    }
    await categories.delete(categoryId);

    // The remote delete already succeeded, so the local mirror must at least
    // stop showing the deleted category even if follow-up reconciliation fails.
    try {
      final feeds = read(feedRepositoryProvider);
      final remoteCatIdToLocalId = <int, int>{};
      final seenCategoryRemoteIds = <String>{};
      for (final remoteCategory in await executor.listCategories()) {
        final remoteId = remoteCategory['id'];
        final remoteTitle = remoteCategory['title'];
        if (remoteId is! int || remoteTitle is! String) continue;
        final trimmedTitle = remoteTitle.trim();
        if (trimmedTitle.isEmpty) continue;
        final remoteIdString = remoteId.toString();
        final localId = await categories.upsertRemote(
          remoteId: remoteIdString,
          name: trimmedTitle,
        );
        seenCategoryRemoteIds.add(remoteIdString);
        remoteCatIdToLocalId[remoteId] = localId;
      }
      final seenFeedRemoteIds = <String>{};
      for (final remoteFeed in await executor.listFeeds()) {
        final remoteFeedId = remoteFeed['id'];
        final remoteUrl = remoteFeed['feed_url'];
        if (remoteFeedId is! int || remoteUrl is! String) continue;
        final remoteCategoryId = remoteFeed['category'] is Map
            ? (remoteFeed['category'] as Map)['id']
            : remoteFeed['category_id'];
        final localCategoryId = remoteCategoryId is int
            ? remoteCatIdToLocalId[remoteCategoryId]
            : null;
        final remoteFeedIdString = remoteFeedId.toString();
        await feeds.upsertRemote(
          remoteId: remoteFeedIdString,
          url: remoteUrl,
          title: remoteFeed['title'] as String?,
          siteUrl: remoteFeed['site_url'] as String?,
          description: remoteFeed['description'] as String?,
          categoryId: localCategoryId,
        );
        seenFeedRemoteIds.add(remoteFeedIdString);
      }
      await feeds.deleteRemoteMissing(seenFeedRemoteIds);
      await categories.deleteRemoteMissing(seenCategoryRemoteIds);
    } catch (error, stackTrace) {
      AppLogger.w(
        'Subscription mirror reconciliation failed',
        tag: 'subscription',
        error: error,
        stackTrace: stackTrace,
        context: _subscriptionFailureContext(
          account,
          capabilities,
          error,
          'reconcileAfterDeleteCategory',
        ),
      );
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
    final executor = await _buildMinifluxStructureExecutorFromRead(
      read,
      account,
    );
    final feedRemoteId = await _localFeedRemoteIdFromRead(read, feedId);
    if (feedRemoteId == null) {
      final feedUrl = await _localFeedUrlFromRead(read, feedId);
      await executor.deleteFeedByUrl(feedUrl);
    } else {
      await executor.deleteFeedById(feedRemoteId);
    }
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
      final executor = await _buildMinifluxStructureExecutor(ref, account);
      final feedRemoteId = await _localFeedRemoteIdFromRead(ref.read, feedId);
      if (feedRemoteId == null) {
        final feedUrl = await _localFeedUrlFromRead(ref.read, feedId);
        await executor.refreshFeedByUrl(feedUrl);
      } else {
        await executor.refreshFeedById(feedRemoteId);
      }
      final result = await ref
          .read(syncServiceProvider)
          .refreshFeedSafe(feedId, notify: false);
      if (!context.mounted) return;
      context.showSnack(
        result.ok ? l10n.refreshed : l10n.errorMessage(result.error.toString()),
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
      final executor = await _buildMinifluxStructureExecutor(ref, account);
      await executor.refreshAllFeeds();
      final batch = await ref
          .read(syncServiceProvider)
          .refreshFeedsSafe(feedIds, maxConcurrent: concurrency, notify: false);
      if (!context.mounted) return;
      final err = batch.firstError?.error;
      context.showSnack(
        err == null ? l10n.refreshedAll : l10n.errorMessage(err.toString()),
      );
    } catch (error, stackTrace) {
      _logSubscriptionFailure(ref, 'refreshAllFeeds', error, stackTrace);
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
      final executor = await _buildMinifluxStructureExecutor(ref, account);
      final feedRemoteId = await _localFeedRemoteIdFromRead(ref.read, feedId);
      final categoryRemoteId = await _localCategoryRemoteIdFromRead(
        ref.read,
        categoryId!,
      );
      final updatedFeed = feedRemoteId == null || categoryRemoteId == null
          ? await executor.moveFeedToCategory(
              feedUrl: await _localFeedUrlFromRead(ref.read, feedId),
              categoryTitle: await _localCategoryTitleFromRead(
                ref.read,
                categoryId,
              ),
            )
          : await executor.moveFeedToCategoryByIds(
              feedId: feedRemoteId,
              categoryId: categoryRemoteId,
            );
      await _reconcileLocalFeedFromRemoteUpdate(
        ref,
        feedId,
        updatedFeed,
        fallbackCategoryId: categoryId,
      );
    } catch (error, stackTrace) {
      _logSubscriptionFailure(ref, 'moveFeedToCategory', error, stackTrace);
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
    } catch (e, s) {
      _logSubscriptionFailure(ref, 'importOpml.openFile', e, s);
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
    } catch (e, s) {
      _logSubscriptionFailure(ref, 'importOpml.readFile', e, s);
      if (!context.mounted) return;
      context.showErrorMessage(l10n.errorMessage(e.toString()));
      return;
    }

    List<OpmlEntry> entries;
    try {
      entries = ref.read(opmlServiceProvider).parseEntries(xml);
    } catch (e, s) {
      _logSubscriptionFailure(ref, 'importOpml.parse', e, s);
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
      } catch (e, s) {
        _logSubscriptionFailure(ref, 'exportOpml.share', e, s);
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
    } catch (e, s) {
      _logSubscriptionFailure(ref, 'exportOpml.pickPath', e, s);
      if (!context.mounted) return;
      context.showErrorMessage(l10n.errorMessage(e.toString()));
      return;
    }
    if (loc == null) return;

    final file = XFile.fromData(bytes, mimeType: 'text/xml', name: loc.path);
    try {
      await file.saveTo(loc.path);
    } catch (e, s) {
      _logSubscriptionFailure(ref, 'exportOpml.saveFile', e, s);
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
