class UserAgents {
  UserAgents._();

  /// A lightweight UA for RSS/Atom fetches. Some CDNs block the default Dio UA.
  static const String rss = 'FlutterReader (Dart/Dio)';

  /// A modern desktop browser UA to improve server compatibility for HTML fetch.
  /// (Some sites return simplified/blocked pages for unknown clients.)
  static const String web =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

