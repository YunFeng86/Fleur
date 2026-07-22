import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../application/subscription_root_sync_action.dart';
import '../../../providers/app_settings_providers.dart';
import '../../../providers/backend_capabilities_provider.dart';
import '../../../providers/backend_sync_semantics_provider.dart';
import '../../../providers/refresh_all_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../services/sync/backend_capabilities.dart';
import '../../../services/sync/refresh_all_coordinator.dart';
import '../../../utils/context_extensions.dart';
import 'subscription_remote_feedback.dart' as remote_feedback;

/// Runs feed refresh commands and owns the resulting user feedback.
abstract final class SubscriptionRefreshActions {
  static Future<void> refreshFeed(
    BuildContext context,
    WidgetRef ref,
    int feedId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = ref.read(backendCapabilitiesProvider);
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
        remote_feedback.logSubscriptionFailure(
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
      remote_feedback.logSubscriptionFailure(
        ref,
        'refreshFeed',
        error,
        stackTrace,
      );
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
    final capabilities = ref.read(backendCapabilitiesProvider);
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
      remote_feedback.logSubscriptionFailure(
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
}
