import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/sync/backend_capabilities.dart';
import 'package:fleur/services/sync/backend_content_capabilities.dart';

void main() {
  const localMatrix = <BackendContentFeature, FeatureAvailability>{
    BackendContentFeature.clientWebPageFetch: FeatureAvailability.local,
    BackendContentFeature.serverArticleContentFetch: FeatureAvailability.hidden,
    BackendContentFeature.syncImagePrefetch: FeatureAvailability.local,
    BackendContentFeature.webFetchUserAgent: FeatureAvailability.local,
  };

  const minifluxMatrix = <BackendContentFeature, FeatureAvailability>{
    BackendContentFeature.clientWebPageFetch: FeatureAvailability.localOnly,
    BackendContentFeature.serverArticleContentFetch:
        FeatureAvailability.onlineRequired,
    BackendContentFeature.syncImagePrefetch: FeatureAvailability.localOnly,
    BackendContentFeature.webFetchUserAgent: FeatureAvailability.localOnly,
  };

  const feverMatrix = <BackendContentFeature, FeatureAvailability>{
    BackendContentFeature.clientWebPageFetch: FeatureAvailability.localOnly,
    BackendContentFeature.serverArticleContentFetch: FeatureAvailability.hidden,
    BackendContentFeature.syncImagePrefetch: FeatureAvailability.localOnly,
    BackendContentFeature.webFetchUserAgent: FeatureAvailability.localOnly,
  };

  const googleReaderMatrix = <BackendContentFeature, FeatureAvailability>{
    BackendContentFeature.clientWebPageFetch: FeatureAvailability.hidden,
    BackendContentFeature.serverArticleContentFetch: FeatureAvailability.hidden,
    BackendContentFeature.syncImagePrefetch: FeatureAvailability.hidden,
    BackendContentFeature.webFetchUserAgent: FeatureAvailability.hidden,
  };

  test('matches the declared content capability matrix for every backend', () {
    final matrices = {
      AccountType.local: localMatrix,
      AccountType.miniflux: minifluxMatrix,
      AccountType.fever: feverMatrix,
      AccountType.googleReader: googleReaderMatrix,
    };

    for (final entry in matrices.entries) {
      final capabilities = BackendContentCapabilities.forAccountType(entry.key);
      final expected = entry.value;

      expect(
        expected.keys,
        unorderedEquals(BackendContentFeature.values),
        reason: '${entry.key} matrix must cover every BackendContentFeature',
      );

      for (final feature in BackendContentFeature.values) {
        expect(
          capabilities.availability(feature),
          expected[feature],
          reason: '${entry.key}.$feature',
        );
      }
    }
  });

  test('exposes content helper flags', () {
    final local = BackendContentCapabilities.forAccountType(AccountType.local);
    final miniflux = BackendContentCapabilities.forAccountType(
      AccountType.miniflux,
    );
    final fever = BackendContentCapabilities.forAccountType(AccountType.fever);
    final googleReader = BackendContentCapabilities.forAccountType(
      AccountType.googleReader,
    );

    expect(local.canFetchWebPages, isTrue);
    expect(local.canPrefetchImages, isTrue);
    expect(local.canFetchArticleContentFromServer, isFalse);
    expect(local.canChooseServerArticleContentFetchMode, isFalse);
    expect(local.isWebFetchUserAgentApplicable, isTrue);

    expect(miniflux.canFetchWebPages, isTrue);
    expect(miniflux.canPrefetchImages, isTrue);
    expect(miniflux.canFetchArticleContentFromServer, isTrue);
    expect(miniflux.canChooseServerArticleContentFetchMode, isTrue);
    expect(miniflux.isWebFetchUserAgentApplicable, isTrue);

    expect(fever.canFetchWebPages, isTrue);
    expect(fever.canPrefetchImages, isTrue);
    expect(fever.canFetchArticleContentFromServer, isFalse);
    expect(fever.canChooseServerArticleContentFetchMode, isFalse);
    expect(fever.isWebFetchUserAgentApplicable, isTrue);

    expect(googleReader.canFetchWebPages, isFalse);
    expect(googleReader.canPrefetchImages, isFalse);
    expect(googleReader.canFetchArticleContentFromServer, isFalse);
    expect(googleReader.canChooseServerArticleContentFetchMode, isFalse);
    expect(googleReader.isWebFetchUserAgentApplicable, isFalse);
  });
}
