// Content enrichment capability surface: web fetch, server content, image prefetch, and user-agent applicability.

import '../accounts/account.dart';
import 'backend_capabilities.dart';

enum BackendContentFeature {
  clientWebPageFetch,
  serverArticleContentFetch,
  syncImagePrefetch,
  webFetchUserAgent,
}

class BackendContentCapabilities {
  const BackendContentCapabilities._(this.accountType);

  factory BackendContentCapabilities.forAccountType(AccountType type) {
    return BackendContentCapabilities._(type);
  }

  final AccountType accountType;

  FeatureAvailability availability(BackendContentFeature feature) {
    return switch (accountType) {
      AccountType.local => _localAvailability(feature),
      AccountType.miniflux => _minifluxAvailability(feature),
      AccountType.fever => _feverAvailability(feature),
      AccountType.googleReader => _googleReaderAvailability(feature),
    };
  }

  bool isVisible(BackendContentFeature feature) {
    return availability(feature) != FeatureAvailability.hidden;
  }

  bool get canFetchWebPages =>
      isVisible(BackendContentFeature.clientWebPageFetch) ||
      isVisible(BackendContentFeature.serverArticleContentFetch);

  bool get canPrefetchImages =>
      isVisible(BackendContentFeature.syncImagePrefetch);

  bool get canChooseServerArticleContentFetchMode =>
      isVisible(BackendContentFeature.serverArticleContentFetch);

  bool get isWebFetchUserAgentApplicable =>
      isVisible(BackendContentFeature.webFetchUserAgent);

  static FeatureAvailability _localAvailability(BackendContentFeature feature) {
    return switch (feature) {
      BackendContentFeature.serverArticleContentFetch =>
        FeatureAvailability.hidden,
      BackendContentFeature.clientWebPageFetch ||
      BackendContentFeature.syncImagePrefetch ||
      BackendContentFeature.webFetchUserAgent => FeatureAvailability.local,
    };
  }

  static FeatureAvailability _minifluxAvailability(
    BackendContentFeature feature,
  ) {
    return switch (feature) {
      BackendContentFeature.clientWebPageFetch ||
      BackendContentFeature.syncImagePrefetch ||
      BackendContentFeature.webFetchUserAgent => FeatureAvailability.localOnly,
      BackendContentFeature.serverArticleContentFetch =>
        FeatureAvailability.onlineRequired,
    };
  }

  static FeatureAvailability _feverAvailability(BackendContentFeature feature) {
    return switch (feature) {
      BackendContentFeature.serverArticleContentFetch =>
        FeatureAvailability.hidden,
      BackendContentFeature.clientWebPageFetch ||
      BackendContentFeature.syncImagePrefetch ||
      BackendContentFeature.webFetchUserAgent => FeatureAvailability.localOnly,
    };
  }

  static FeatureAvailability _googleReaderAvailability(
    BackendContentFeature feature,
  ) {
    return switch (feature) {
      BackendContentFeature.serverArticleContentFetch =>
        FeatureAvailability.hidden,
      BackendContentFeature.clientWebPageFetch ||
      BackendContentFeature.syncImagePrefetch ||
      BackendContentFeature.webFetchUserAgent => FeatureAvailability.localOnly,
    };
  }
}
