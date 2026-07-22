import '../../../l10n/app_localizations.dart';
import '../../../services/sync/backend_capabilities.dart';
import '../../../services/sync/backend_sync_semantics.dart';

enum SubscriptionRootSyncMode { refreshSources, syncAccount }

SubscriptionRootSyncMode? resolveSubscriptionRootSyncMode(
  BackendCapabilities capabilities,
  BackendSyncSemantics syncSemantics,
) {
  if (capabilities.isVisible(BackendFeature.refreshAllSources)) {
    return SubscriptionRootSyncMode.refreshSources;
  }
  if (capabilities.isVisible(BackendFeature.syncNow) &&
      syncSemantics.isAccountWideRefresh) {
    return SubscriptionRootSyncMode.syncAccount;
  }
  return null;
}

String subscriptionRootSyncLabel(
  AppLocalizations l10n,
  SubscriptionRootSyncMode mode,
) {
  return switch (mode) {
    SubscriptionRootSyncMode.refreshSources => l10n.refreshAll,
    SubscriptionRootSyncMode.syncAccount => l10n.syncAccount,
  };
}

String subscriptionRootSyncSuccessLabel(
  AppLocalizations l10n,
  SubscriptionRootSyncMode mode,
) {
  return switch (mode) {
    SubscriptionRootSyncMode.refreshSources => l10n.refreshedAll,
    SubscriptionRootSyncMode.syncAccount => l10n.syncedAccount,
  };
}
