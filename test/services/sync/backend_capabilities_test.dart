import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/sync/backend_capabilities.dart';

void main() {
  const localMatrix = <BackendFeature, FeatureAvailability>{
    BackendFeature.syncNow: FeatureAvailability.local,
    BackendFeature.addSubscription: FeatureAvailability.local,
    BackendFeature.deleteSubscription: FeatureAvailability.local,
    BackendFeature.addCategory: FeatureAvailability.local,
    BackendFeature.renameCategory: FeatureAvailability.local,
    BackendFeature.deleteCategory: FeatureAvailability.local,
    BackendFeature.moveSubscriptionToCategory: FeatureAvailability.local,
    BackendFeature.moveSubscriptionToUncategorized: FeatureAvailability.local,
    BackendFeature.refreshSubscriptionSource: FeatureAvailability.local,
    BackendFeature.refreshAllSources: FeatureAvailability.local,
    BackendFeature.importOpml: FeatureAvailability.local,
    BackendFeature.exportOpml: FeatureAvailability.local,
    BackendFeature.articleReadState: FeatureAvailability.local,
    BackendFeature.articleStarState: FeatureAvailability.local,
    BackendFeature.articleReadLater: FeatureAvailability.local,
    BackendFeature.clientFeedSettings: FeatureAvailability.local,
    BackendFeature.clientCategorySettings: FeatureAvailability.local,
    BackendFeature.offlineCache: FeatureAvailability.local,
    BackendFeature.outboxFlush: FeatureAvailability.hidden,
    BackendFeature.serverContentFetchMode: FeatureAvailability.hidden,
    BackendFeature.clientWebPageFetch: FeatureAvailability.local,
    BackendFeature.serverArticleContentFetch: FeatureAvailability.hidden,
    BackendFeature.syncImagePrefetch: FeatureAvailability.local,
  };

  const minifluxMatrix = <BackendFeature, FeatureAvailability>{
    BackendFeature.syncNow: FeatureAvailability.onlineRequired,
    BackendFeature.addSubscription: FeatureAvailability.onlineRequired,
    BackendFeature.deleteSubscription: FeatureAvailability.onlineRequired,
    BackendFeature.addCategory: FeatureAvailability.onlineRequired,
    BackendFeature.renameCategory: FeatureAvailability.onlineRequired,
    BackendFeature.deleteCategory: FeatureAvailability.onlineRequired,
    BackendFeature.moveSubscriptionToCategory:
        FeatureAvailability.onlineRequired,
    BackendFeature.moveSubscriptionToUncategorized: FeatureAvailability.hidden,
    BackendFeature.refreshSubscriptionSource:
        FeatureAvailability.onlineRequired,
    BackendFeature.refreshAllSources: FeatureAvailability.onlineRequired,
    BackendFeature.importOpml: FeatureAvailability.hidden,
    BackendFeature.exportOpml: FeatureAvailability.localOnly,
    BackendFeature.articleReadState: FeatureAvailability.deferredRemote,
    BackendFeature.articleStarState: FeatureAvailability.deferredRemote,
    BackendFeature.articleReadLater: FeatureAvailability.localOnly,
    BackendFeature.clientFeedSettings: FeatureAvailability.localOnly,
    BackendFeature.clientCategorySettings: FeatureAvailability.localOnly,
    BackendFeature.offlineCache: FeatureAvailability.localOnly,
    BackendFeature.outboxFlush: FeatureAvailability.deferredRemote,
    BackendFeature.serverContentFetchMode: FeatureAvailability.localOnly,
    BackendFeature.clientWebPageFetch: FeatureAvailability.localOnly,
    BackendFeature.serverArticleContentFetch:
        FeatureAvailability.onlineRequired,
    BackendFeature.syncImagePrefetch: FeatureAvailability.localOnly,
  };

  const feverMatrix = <BackendFeature, FeatureAvailability>{
    BackendFeature.syncNow: FeatureAvailability.onlineRequired,
    BackendFeature.addSubscription: FeatureAvailability.hidden,
    BackendFeature.deleteSubscription: FeatureAvailability.hidden,
    BackendFeature.addCategory: FeatureAvailability.hidden,
    BackendFeature.renameCategory: FeatureAvailability.hidden,
    BackendFeature.deleteCategory: FeatureAvailability.hidden,
    BackendFeature.moveSubscriptionToCategory: FeatureAvailability.hidden,
    BackendFeature.moveSubscriptionToUncategorized: FeatureAvailability.hidden,
    BackendFeature.refreshSubscriptionSource: FeatureAvailability.hidden,
    BackendFeature.refreshAllSources: FeatureAvailability.hidden,
    BackendFeature.importOpml: FeatureAvailability.hidden,
    BackendFeature.exportOpml: FeatureAvailability.localOnly,
    BackendFeature.articleReadState: FeatureAvailability.deferredRemote,
    BackendFeature.articleStarState: FeatureAvailability.deferredRemote,
    BackendFeature.articleReadLater: FeatureAvailability.localOnly,
    BackendFeature.clientFeedSettings: FeatureAvailability.localOnly,
    BackendFeature.clientCategorySettings: FeatureAvailability.localOnly,
    BackendFeature.offlineCache: FeatureAvailability.localOnly,
    BackendFeature.outboxFlush: FeatureAvailability.deferredRemote,
    BackendFeature.serverContentFetchMode: FeatureAvailability.hidden,
    BackendFeature.clientWebPageFetch: FeatureAvailability.localOnly,
    BackendFeature.serverArticleContentFetch: FeatureAvailability.hidden,
    BackendFeature.syncImagePrefetch: FeatureAvailability.localOnly,
  };

  test('matches the declared capability matrix for every backend', () {
    final matrices = {
      AccountType.local: localMatrix,
      AccountType.miniflux: minifluxMatrix,
      AccountType.fever: feverMatrix,
    };

    for (final entry in matrices.entries) {
      final capabilities = BackendCapabilities.forAccountType(entry.key);
      final expected = entry.value;

      expect(
        expected.keys,
        unorderedEquals(BackendFeature.values),
        reason: '${entry.key} matrix must cover every BackendFeature',
      );

      for (final feature in BackendFeature.values) {
        expect(
          capabilities.availability(feature),
          expected[feature],
          reason: '${entry.key}.$feature',
        );
      }
    }
  });

  test('exposes remote-backed and outbox helper flags', () {
    final local = BackendCapabilities.forAccountType(AccountType.local);
    final miniflux = BackendCapabilities.forAccountType(AccountType.miniflux);
    final fever = BackendCapabilities.forAccountType(AccountType.fever);

    expect(local.isRemoteBacked, isFalse);
    expect(miniflux.isRemoteBacked, isTrue);
    expect(fever.isRemoteBacked, isTrue);

    expect(local.isOutboxCapable, isFalse);
    expect(miniflux.isOutboxCapable, isTrue);
    expect(fever.isOutboxCapable, isTrue);

    expect(fever.isVisible(BackendFeature.addSubscription), isFalse);
    expect(fever.isVisible(BackendFeature.exportOpml), isTrue);
    expect(miniflux.isOnlineRequired(BackendFeature.addCategory), isTrue);
    expect(local.isOnlineRequired(BackendFeature.addCategory), isFalse);
  });
}
