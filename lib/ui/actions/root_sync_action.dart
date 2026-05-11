import '../../l10n/app_localizations.dart';
import '../../services/sync/backend_capabilities.dart';

enum SubscriptionRootSyncMode { refreshSources, syncAccount }

SubscriptionRootSyncMode? resolveSubscriptionRootSyncMode(
  BackendCapabilities capabilities,
) {
  if (capabilities.isVisible(BackendFeature.refreshAllSources)) {
    return SubscriptionRootSyncMode.refreshSources;
  }
  if (capabilities.isVisible(BackendFeature.syncNow)) {
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
