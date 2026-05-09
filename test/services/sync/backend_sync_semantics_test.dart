import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/sync/backend_sync_semantics.dart';

void main() {
  const expected = <AccountType, _ExpectedSyncSemantics>{
    AccountType.local: _ExpectedSyncSemantics(
      refreshScope: BackendRefreshScope.feed,
      historyCoverage: BackendHistoryCoverage.localFeedContent,
      entrySyncLimitScope: BackendEntrySyncLimitScope.none,
      remoteFetchConcurrencyScope: BackendRemoteFetchConcurrencyScope.none,
      taxonomySemantics: BackendTaxonomySemantics.localOnly,
      notificationGranularity: BackendNotificationGranularity.perFeedAndSummary,
    ),
    AccountType.miniflux: _ExpectedSyncSemantics(
      refreshScope: BackendRefreshScope.account,
      historyCoverage: BackendHistoryCoverage.remotePaginatedEntries,
      entrySyncLimitScope: BackendEntrySyncLimitScope.remoteAccountWindow,
      remoteFetchConcurrencyScope:
          BackendRemoteFetchConcurrencyScope.remoteArticleBatches,
      taxonomySemantics: BackendTaxonomySemantics.remoteWritableAuthoritative,
      notificationGranularity: BackendNotificationGranularity.none,
    ),
    AccountType.fever: _ExpectedSyncSemantics(
      refreshScope: BackendRefreshScope.account,
      historyCoverage: BackendHistoryCoverage.remoteUnreadAndSavedItems,
      entrySyncLimitScope: BackendEntrySyncLimitScope.remoteAccountWindow,
      remoteFetchConcurrencyScope:
          BackendRemoteFetchConcurrencyScope.remoteArticleBatches,
      taxonomySemantics: BackendTaxonomySemantics.remoteReadOnlyMirror,
      notificationGranularity: BackendNotificationGranularity.summaryOnly,
    ),
  };

  test('matches the declared sync semantics for every backend', () {
    for (final entry in expected.entries) {
      final semantics = BackendSyncSemantics.forAccountType(entry.key);
      final expected = entry.value;

      expect(semantics.refreshScope, expected.refreshScope);
      expect(semantics.historyCoverage, expected.historyCoverage);
      expect(semantics.entrySyncLimitScope, expected.entrySyncLimitScope);
      expect(
        semantics.remoteFetchConcurrencyScope,
        expected.remoteFetchConcurrencyScope,
      );
      expect(semantics.taxonomySemantics, expected.taxonomySemantics);
      expect(
        semantics.notificationGranularity,
        expected.notificationGranularity,
      );
    }
  });

  test('exposes sync semantics helper flags', () {
    final local = BackendSyncSemantics.forAccountType(AccountType.local);
    final miniflux = BackendSyncSemantics.forAccountType(AccountType.miniflux);
    final fever = BackendSyncSemantics.forAccountType(AccountType.fever);

    expect(local.isFeedScopedRefresh, isTrue);
    expect(local.isAccountWideRefresh, isFalse);
    expect(local.supportsEntrySyncLimit, isFalse);
    expect(local.supportsRemoteFetchConcurrency, isFalse);
    expect(local.mirrorsRemoteTaxonomy, isFalse);
    expect(local.isLocalOnlyTaxonomy, isTrue);
    expect(local.isRemoteWritableTaxonomy, isFalse);
    expect(local.isRemoteReadOnlyTaxonomy, isFalse);
    expect(local.canWriteRemoteTaxonomy, isFalse);
    expect(local.usesSummaryNotifications, isTrue);

    expect(miniflux.isFeedScopedRefresh, isFalse);
    expect(miniflux.isAccountWideRefresh, isTrue);
    expect(miniflux.supportsEntrySyncLimit, isTrue);
    expect(miniflux.supportsRemoteFetchConcurrency, isTrue);
    expect(miniflux.mirrorsRemoteTaxonomy, isTrue);
    expect(miniflux.isLocalOnlyTaxonomy, isFalse);
    expect(miniflux.isRemoteWritableTaxonomy, isTrue);
    expect(miniflux.isRemoteReadOnlyTaxonomy, isFalse);
    expect(miniflux.canWriteRemoteTaxonomy, isTrue);
    expect(miniflux.usesSummaryNotifications, isFalse);

    expect(fever.isFeedScopedRefresh, isFalse);
    expect(fever.isAccountWideRefresh, isTrue);
    expect(fever.supportsEntrySyncLimit, isTrue);
    expect(fever.supportsRemoteFetchConcurrency, isTrue);
    expect(fever.mirrorsRemoteTaxonomy, isTrue);
    expect(fever.isLocalOnlyTaxonomy, isFalse);
    expect(fever.isRemoteWritableTaxonomy, isFalse);
    expect(fever.isRemoteReadOnlyTaxonomy, isTrue);
    expect(fever.canWriteRemoteTaxonomy, isFalse);
    expect(fever.usesSummaryNotifications, isTrue);
  });
}

class _ExpectedSyncSemantics {
  const _ExpectedSyncSemantics({
    required this.refreshScope,
    required this.historyCoverage,
    required this.entrySyncLimitScope,
    required this.remoteFetchConcurrencyScope,
    required this.taxonomySemantics,
    required this.notificationGranularity,
  });

  final BackendRefreshScope refreshScope;
  final BackendHistoryCoverage historyCoverage;
  final BackendEntrySyncLimitScope entrySyncLimitScope;
  final BackendRemoteFetchConcurrencyScope remoteFetchConcurrencyScope;
  final BackendTaxonomySemantics taxonomySemantics;
  final BackendNotificationGranularity notificationGranularity;
}
