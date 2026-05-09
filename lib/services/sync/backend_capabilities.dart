// Operation capability surface: buttons, menus, actions, outbox, and runtime affordances.

import '../accounts/account.dart';

enum BackendFeature {
  syncNow,
  addSubscription,
  deleteSubscription,
  addCategory,
  renameCategory,
  deleteCategory,
  moveSubscriptionToCategory,
  moveSubscriptionToUncategorized,
  refreshSubscriptionSource,
  refreshAllSources,
  importOpml,
  exportOpml,
  articleReadState,
  articleStarState,
  articleReadLater,
  clientFeedSettings,
  clientCategorySettings,
  offlineCache,
  outboxFlush,
}

enum FeatureAvailability {
  local,
  localOnly,
  deferredRemote,
  onlineRequired,
  hidden,
}

class BackendCapabilities {
  const BackendCapabilities._(this.accountType);

  factory BackendCapabilities.forAccountType(AccountType type) {
    return BackendCapabilities._(type);
  }

  final AccountType accountType;

  String get diagnosticAccountType => accountType.wire;

  bool get isRemoteBacked => accountType != AccountType.local;

  bool get refreshesRemoteSourcesUpstream =>
      accountType == AccountType.miniflux;

  bool get isOutboxCapable =>
      availability(BackendFeature.outboxFlush) != FeatureAvailability.hidden;

  FeatureAvailability availability(BackendFeature feature) {
    return switch (accountType) {
      AccountType.local => _localAvailability(feature),
      AccountType.miniflux => _minifluxAvailability(feature),
      AccountType.fever => _feverAvailability(feature),
    };
  }

  bool isVisible(BackendFeature feature) {
    return availability(feature) != FeatureAvailability.hidden;
  }

  bool isOnlineRequired(BackendFeature feature) {
    return availability(feature) == FeatureAvailability.onlineRequired;
  }

  static FeatureAvailability _localAvailability(BackendFeature feature) {
    return switch (feature) {
      BackendFeature.outboxFlush => FeatureAvailability.hidden,
      BackendFeature.syncNow ||
      BackendFeature.addSubscription ||
      BackendFeature.deleteSubscription ||
      BackendFeature.addCategory ||
      BackendFeature.renameCategory ||
      BackendFeature.deleteCategory ||
      BackendFeature.moveSubscriptionToCategory ||
      BackendFeature.moveSubscriptionToUncategorized ||
      BackendFeature.refreshSubscriptionSource ||
      BackendFeature.refreshAllSources ||
      BackendFeature.importOpml ||
      BackendFeature.exportOpml ||
      BackendFeature.articleReadState ||
      BackendFeature.articleStarState ||
      BackendFeature.articleReadLater ||
      BackendFeature.clientFeedSettings ||
      BackendFeature.clientCategorySettings ||
      BackendFeature.offlineCache => FeatureAvailability.local,
    };
  }

  static FeatureAvailability _minifluxAvailability(BackendFeature feature) {
    return switch (feature) {
      BackendFeature.moveSubscriptionToUncategorized ||
      BackendFeature.importOpml => FeatureAvailability.hidden,
      BackendFeature.exportOpml ||
      BackendFeature.articleReadLater ||
      BackendFeature.clientFeedSettings ||
      BackendFeature.clientCategorySettings ||
      BackendFeature.offlineCache => FeatureAvailability.localOnly,
      BackendFeature.articleReadState ||
      BackendFeature.articleStarState ||
      BackendFeature.outboxFlush => FeatureAvailability.deferredRemote,
      BackendFeature.syncNow ||
      BackendFeature.addSubscription ||
      BackendFeature.deleteSubscription ||
      BackendFeature.addCategory ||
      BackendFeature.renameCategory ||
      BackendFeature.deleteCategory ||
      BackendFeature.moveSubscriptionToCategory ||
      BackendFeature.refreshSubscriptionSource ||
      BackendFeature.refreshAllSources => FeatureAvailability.onlineRequired,
    };
  }

  static FeatureAvailability _feverAvailability(BackendFeature feature) {
    return switch (feature) {
      BackendFeature.addSubscription ||
      BackendFeature.deleteSubscription ||
      BackendFeature.addCategory ||
      BackendFeature.renameCategory ||
      BackendFeature.deleteCategory ||
      BackendFeature.moveSubscriptionToCategory ||
      BackendFeature.moveSubscriptionToUncategorized ||
      BackendFeature.refreshSubscriptionSource ||
      BackendFeature.refreshAllSources ||
      BackendFeature.importOpml => FeatureAvailability.hidden,
      BackendFeature.exportOpml ||
      BackendFeature.articleReadLater ||
      BackendFeature.clientFeedSettings ||
      BackendFeature.clientCategorySettings ||
      BackendFeature.offlineCache => FeatureAvailability.localOnly,
      BackendFeature.articleReadState ||
      BackendFeature.articleStarState ||
      BackendFeature.outboxFlush => FeatureAvailability.deferredRemote,
      BackendFeature.syncNow => FeatureAvailability.onlineRequired,
    };
  }
}
