// Sync semantics profile: refresh scope, history coverage, remote taxonomy, and notification granularity.

import '../accounts/account.dart';

enum BackendRefreshScope { feed, account }

enum BackendHistoryCoverage {
  localFeedContent,
  remotePaginatedEntries,
  remoteUnreadAndSavedItems,
}

enum BackendEntrySyncLimitScope { none, remoteAccountWindow }

enum BackendRemoteFetchConcurrencyScope { none, remoteArticleBatches }

enum BackendTaxonomySemantics {
  localOnly,
  remoteWritableAuthoritative,
  remoteReadOnlyMirror,
}

enum BackendNotificationGranularity { none, summaryOnly, perFeedAndSummary }

class BackendSyncSemantics {
  const BackendSyncSemantics._({
    required this.accountType,
    required this.refreshScope,
    required this.historyCoverage,
    required this.entrySyncLimitScope,
    required this.remoteFetchConcurrencyScope,
    required this.taxonomySemantics,
    required this.notificationGranularity,
  });

  factory BackendSyncSemantics.forAccount(Account account) {
    return BackendSyncSemantics.forAccountType(account.type);
  }

  factory BackendSyncSemantics.forAccountType(AccountType type) {
    return switch (type) {
      AccountType.local => const BackendSyncSemantics._(
        accountType: AccountType.local,
        refreshScope: BackendRefreshScope.feed,
        historyCoverage: BackendHistoryCoverage.localFeedContent,
        entrySyncLimitScope: BackendEntrySyncLimitScope.none,
        remoteFetchConcurrencyScope: BackendRemoteFetchConcurrencyScope.none,
        taxonomySemantics: BackendTaxonomySemantics.localOnly,
        notificationGranularity:
            BackendNotificationGranularity.perFeedAndSummary,
      ),
      AccountType.miniflux => const BackendSyncSemantics._(
        accountType: AccountType.miniflux,
        refreshScope: BackendRefreshScope.account,
        historyCoverage: BackendHistoryCoverage.remotePaginatedEntries,
        entrySyncLimitScope: BackendEntrySyncLimitScope.remoteAccountWindow,
        remoteFetchConcurrencyScope:
            BackendRemoteFetchConcurrencyScope.remoteArticleBatches,
        taxonomySemantics: BackendTaxonomySemantics.remoteWritableAuthoritative,
        notificationGranularity: BackendNotificationGranularity.none,
      ),
      AccountType.fever => const BackendSyncSemantics._(
        accountType: AccountType.fever,
        refreshScope: BackendRefreshScope.account,
        historyCoverage: BackendHistoryCoverage.remoteUnreadAndSavedItems,
        entrySyncLimitScope: BackendEntrySyncLimitScope.remoteAccountWindow,
        remoteFetchConcurrencyScope:
            BackendRemoteFetchConcurrencyScope.remoteArticleBatches,
        taxonomySemantics: BackendTaxonomySemantics.remoteReadOnlyMirror,
        notificationGranularity: BackendNotificationGranularity.summaryOnly,
      ),
      AccountType.googleReader => const BackendSyncSemantics._(
        accountType: AccountType.googleReader,
        refreshScope: BackendRefreshScope.account,
        historyCoverage: BackendHistoryCoverage.remotePaginatedEntries,
        entrySyncLimitScope: BackendEntrySyncLimitScope.remoteAccountWindow,
        remoteFetchConcurrencyScope:
            BackendRemoteFetchConcurrencyScope.remoteArticleBatches,
        taxonomySemantics: BackendTaxonomySemantics.remoteReadOnlyMirror,
        notificationGranularity: BackendNotificationGranularity.none,
      ),
    };
  }

  final AccountType accountType;
  final BackendRefreshScope refreshScope;
  final BackendHistoryCoverage historyCoverage;
  final BackendEntrySyncLimitScope entrySyncLimitScope;
  final BackendRemoteFetchConcurrencyScope remoteFetchConcurrencyScope;
  final BackendTaxonomySemantics taxonomySemantics;
  final BackendNotificationGranularity notificationGranularity;

  bool get isAccountWideRefresh => refreshScope == BackendRefreshScope.account;

  bool get isFeedScopedRefresh => refreshScope == BackendRefreshScope.feed;

  bool get supportsEntrySyncLimit =>
      entrySyncLimitScope != BackendEntrySyncLimitScope.none;

  bool get supportsRemoteFetchConcurrency =>
      remoteFetchConcurrencyScope != BackendRemoteFetchConcurrencyScope.none;

  bool get mirrorsRemoteTaxonomy =>
      taxonomySemantics != BackendTaxonomySemantics.localOnly;

  bool get isLocalOnlyTaxonomy =>
      taxonomySemantics == BackendTaxonomySemantics.localOnly;

  bool get isRemoteWritableTaxonomy =>
      taxonomySemantics == BackendTaxonomySemantics.remoteWritableAuthoritative;

  bool get isRemoteReadOnlyTaxonomy =>
      taxonomySemantics == BackendTaxonomySemantics.remoteReadOnlyMirror;

  bool get canWriteRemoteTaxonomy =>
      taxonomySemantics == BackendTaxonomySemantics.remoteWritableAuthoritative;

  bool get usesSummaryNotifications =>
      notificationGranularity == BackendNotificationGranularity.summaryOnly ||
      notificationGranularity ==
          BackendNotificationGranularity.perFeedAndSummary;
}
