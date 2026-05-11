/// URL normalization utility for RSS article deduplication.
///
/// Removes tracking parameters and normalizes URL format to ensure
/// the same article with slightly different URLs is correctly identified.
class LinkNormalizer {
  LinkNormalizer._();

  /// Tracking parameters to strip from URLs.
  static const _trackingParams = {
    // Google Analytics
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    // Facebook
    'fbclid',
    // Google Ads
    'gclid',
    // Microsoft Ads
    'msclkid',
    // Other common trackers
    'ref',
    'referrer',
    '_ga',
    'mc_cid',
    'mc_eid',
    'source',
  };

  /// Normalize URL for deduplication.
  ///
  /// Steps:
  /// 1. Remove tracking query parameters
  /// 2. Remove fragment (#anchor)
  /// 3. Remove trailing slash (except for root path)
  /// 4. Trim whitespace
  static String normalize(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;

    final cleanParams = <String, List<String>>{};
    for (final entry in uri.queryParametersAll.entries) {
      if (!_trackingParams.contains(entry.key.toLowerCase())) {
        cleanParams[entry.key] = entry.value;
      }
    }

    final normalized = Uri(
      scheme: uri.scheme,
      userInfo: uri.hasAuthority ? uri.userInfo : '',
      host: uri.hasAuthority ? uri.host : null,
      port: uri.hasPort ? uri.port : null,
      path: _withoutTrailingSlash(uri),
      queryParameters: cleanParams.isEmpty ? null : cleanParams,
    );

    return normalized.toString();
  }

  static String _withoutTrailingSlash(Uri uri) {
    final path = uri.path;
    if (path.endsWith('/') && uri.pathSegments.isNotEmpty) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }
}
