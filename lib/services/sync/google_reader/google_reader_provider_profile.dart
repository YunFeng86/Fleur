import 'package:fleur/features/accounts/accounts.dart';

class GoogleReaderProviderProfile {
  const GoogleReaderProviderProfile({
    required this.id,
    required this.displayName,
    required this.apiPathSegments,
    required this.clientLoginPathSegments,
    this.requiresOutputJson = true,
    this.itemIdsPageSize = 100,
    this.contentBatchSize = 100,
    this.editTagBatchSize = 100,
    this.verifyMarkAllAsRead = true,
    this.retryTokenOnAuthFailure = true,
  });

  final String id;
  final String displayName;
  final List<String> apiPathSegments;
  final List<String> clientLoginPathSegments;
  final bool requiresOutputJson;
  final int itemIdsPageSize;
  final int contentBatchSize;
  final int editTagBatchSize;
  final bool verifyMarkAllAsRead;
  final bool retryTokenOnAuthFailure;

  String get apiPath => '/${apiPathSegments.join('/')}';

  String get clientLoginPath => '/${clientLoginPathSegments.join('/')}';
}

class GoogleReaderProviderProfiles {
  const GoogleReaderProviderProfiles._();

  static const genericId = Account.googleReaderGenericProfileId;
  static const freshRssId = 'freshRss';
  static const minifluxId = 'minifluxGoogleReader';
  static const autoId = 'auto';

  static const generic = GoogleReaderProviderProfile(
    id: genericId,
    displayName: 'Generic',
    apiPathSegments: ['reader', 'api', '0'],
    clientLoginPathSegments: ['accounts', 'ClientLogin'],
  );

  static const freshRss = GoogleReaderProviderProfile(
    id: freshRssId,
    displayName: 'FreshRSS',
    apiPathSegments: ['api', 'greader.php', 'reader', 'api', '0'],
    clientLoginPathSegments: ['api', 'greader.php', 'accounts', 'ClientLogin'],
  );

  static const miniflux = GoogleReaderProviderProfile(
    id: minifluxId,
    displayName: 'Miniflux',
    apiPathSegments: ['reader', 'api', '0'],
    clientLoginPathSegments: ['accounts', 'ClientLogin'],
  );

  static const values = <GoogleReaderProviderProfile>[
    generic,
    freshRss,
    miniflux,
  ];

  static const probeOrder = <GoogleReaderProviderProfile>[
    freshRss,
    miniflux,
    generic,
  ];

  static GoogleReaderProviderProfile fromId(String? id) {
    final trimmed = id?.trim();
    for (final profile in values) {
      if (profile.id == trimmed) return profile;
    }
    return generic;
  }

  static GoogleReaderProviderProfile forAccount(Account account) {
    if (account.type != AccountType.googleReader) return generic;
    return fromId(account.profileId);
  }

  static bool isKnownProfileId(String? id) {
    final trimmed = id?.trim();
    return values.any((profile) => profile.id == trimmed);
  }
}
