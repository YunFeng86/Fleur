import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../network/user_agents.dart';
import 'feed_parser.dart';

enum DiscoveredFeedSource { direct, alternateLink, commonPath }

class DiscoveredFeed {
  const DiscoveredFeed({
    required this.url,
    this.title,
    this.type,
    this.siteUrl,
    this.siteTitle,
    this.source = DiscoveredFeedSource.alternateLink,
  });

  final String url;
  final String? title;
  final String? type;
  final String? siteUrl;
  final String? siteTitle;
  final DiscoveredFeedSource source;
}

class FeedDiscoveryService {
  FeedDiscoveryService(this._dio, {FeedParser? parser})
    : _parser = parser ?? FeedParser();

  final Dio _dio;
  final FeedParser _parser;

  static const _rootFeedPaths = <String>[
    '/feed',
    '/feed.xml',
    '/rss.xml',
    '/atom.xml',
  ];
  static const _relativeFeedPaths = <String>['feed', 'rss.xml', 'atom.xml'];

  Uri _normalizeInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('URL is empty');
    }

    final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null) {
      throw ArgumentError('Invalid URL: $input');
    }
    if (!(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw ArgumentError('URL must be http/https: $input');
    }
    return uri;
  }

  bool _looksLikeFeed(String contentType, String body) {
    final ct = contentType.toLowerCase();
    if (ct.contains('application/rss+xml') ||
        ct.contains('application/atom+xml')) {
      return true;
    }
    if (ct.contains('xml')) {
      final head = body.length > 800 ? body.substring(0, 800) : body;
      final lower = head.toLowerCase();
      if (lower.contains('<rss') || lower.contains('<feed')) return true;
    }
    return false;
  }

  bool _looksLikeHtml(String contentType, String body) {
    final ct = contentType.toLowerCase();
    if (ct.contains('text/html') || ct.contains('application/xhtml+xml')) {
      return true;
    }
    final head = body.length > 800 ? body.substring(0, 800) : body;
    return head.toLowerCase().contains('<html');
  }

  bool _isPotentialFeedMime(String type) {
    final t = type.toLowerCase();
    if (t.contains('application/rss+xml')) return true;
    if (t.contains('application/atom+xml')) return true;
    if (t.contains('application/xml')) return true;
    if (t.contains('text/xml')) return true;
    return false;
  }

  String? _trimOrNull(String? v) {
    final s = v?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  String? _htmlTitle(dom.Document doc) {
    return _trimOrNull(doc.querySelector('title')?.text);
  }

  DiscoveredFeed _directFeedCandidate({
    required Uri url,
    required String contentType,
    required String body,
  }) {
    try {
      final parsed = _parser.parse(body);
      return DiscoveredFeed(
        url: url.toString(),
        title: _trimOrNull(parsed.title),
        type: _trimOrNull(contentType),
        siteUrl: _trimOrNull(parsed.siteUrl),
        source: DiscoveredFeedSource.direct,
      );
    } catch (_) {
      return DiscoveredFeed(
        url: url.toString(),
        type: _trimOrNull(contentType),
        source: DiscoveredFeedSource.direct,
      );
    }
  }

  /// Discover RSS/Atom feeds from a user-provided URL.
  ///
  /// - If the URL itself looks like a feed, returns it directly.
  /// - Otherwise, fetches HTML and parses `<link rel="alternate" ...>` tags.
  Future<List<DiscoveredFeed>> discover(
    String input, {
    String? userAgent,
  }) async {
    final uri = _normalizeInput(input);
    return discoverFromUri(uri, userAgent: userAgent);
  }

  Future<List<DiscoveredFeed>> discoverFromUri(
    Uri uri, {
    String? userAgent,
  }) async {
    final ua = (userAgent != null && userAgent.trim().isNotEmpty)
        ? userAgent.trim()
        : UserAgents.webForCurrentPlatform();

    final resp = await _dio.getUri<String>(
      uri,
      options: Options(
        responseType: ResponseType.plain,
        validateStatus: (s) => s != null && s >= 200 && s < 400,
        headers: <String, String>{
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          if (!kIsWeb) 'User-Agent': ua,
        },
      ),
    );

    final contentType = resp.headers.value('content-type') ?? '';
    final body = (resp.data ?? '').trim();
    final realUri = resp.realUri;

    if (_looksLikeFeed(contentType, body)) {
      return [
        _directFeedCandidate(
          url: realUri,
          contentType: contentType,
          body: body,
        ),
      ];
    }

    if (body.isEmpty) return const [];

    final doc = html_parser.parse(body);
    final baseHref = _trimOrNull(doc.querySelector('base')?.attributes['href']);
    final baseUri = baseHref == null ? realUri : realUri.resolve(baseHref);

    final siteTitle = _htmlTitle(doc);
    final feeds = <DiscoveredFeed>[];
    final seen = <String>{};

    for (final link in doc.getElementsByTagName('link')) {
      final href = _trimOrNull(link.attributes['href']);
      if (href == null) continue;

      final relRaw = _trimOrNull(link.attributes['rel'])?.toLowerCase() ?? '';
      final relTokens = relRaw
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toSet();
      final isAlternate =
          relTokens.contains('alternate') || relTokens.contains('feed');
      if (!isAlternate) continue;

      final type = _trimOrNull(link.attributes['type']);
      final title = _trimOrNull(link.attributes['title']);

      final looksFeed = type != null && _isPotentialFeedMime(type);
      final hrefLower = href.toLowerCase();
      final hintsFeed =
          hrefLower.contains('rss') ||
          hrefLower.contains('atom') ||
          hrefLower.contains('feed') ||
          hrefLower.contains('xml');
      if (!looksFeed && !hintsFeed) continue;

      final resolved = baseUri.resolve(href);
      if (!(resolved.scheme == 'http' || resolved.scheme == 'https')) continue;

      final url = resolved.toString();
      if (!seen.add(url)) continue;
      feeds.add(
        DiscoveredFeed(
          url: url,
          title: title,
          type: type,
          siteUrl: realUri.toString(),
          siteTitle: siteTitle,
          source: DiscoveredFeedSource.alternateLink,
        ),
      );
    }

    if (feeds.isNotEmpty || !_looksLikeHtml(contentType, body)) {
      return feeds;
    }

    return _discoverCommonFeedPaths(
      pageUri: realUri,
      userAgent: ua,
      siteTitle: siteTitle,
    );
  }

  Future<List<DiscoveredFeed>> _discoverCommonFeedPaths({
    required Uri pageUri,
    required String userAgent,
    required String? siteTitle,
  }) async {
    final probes = <Uri>[];
    final seenProbe = <String>{};

    void addProbe(Uri uri) {
      if (!(uri.scheme == 'http' || uri.scheme == 'https')) return;
      final key = uri.toString();
      if (seenProbe.add(key)) probes.add(uri);
    }

    for (final path in _rootFeedPaths) {
      addProbe(_replacePathWithoutQueryOrFragment(pageUri, path));
    }
    if (pageUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .isNotEmpty) {
      for (final path in _relativeFeedPaths) {
        addProbe(pageUri.resolve(path));
      }
    }

    final feeds = <DiscoveredFeed>[];
    final seenFeed = <String>{};
    for (final probe in probes) {
      final candidate = await _tryCommonFeedPath(
        probe,
        userAgent: userAgent,
        siteUrl: pageUri.toString(),
        siteTitle: siteTitle,
      );
      if (candidate == null) continue;
      if (!seenFeed.add(candidate.url)) continue;
      feeds.add(candidate);
    }
    return feeds;
  }

  Uri _replacePathWithoutQueryOrFragment(Uri uri, String path) {
    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: path,
    );
  }

  Future<DiscoveredFeed?> _tryCommonFeedPath(
    Uri uri, {
    required String userAgent,
    required String siteUrl,
    required String? siteTitle,
  }) async {
    try {
      final resp = await _dio.getUri<String>(
        uri,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s >= 200 && s < 400,
          headers: <String, String>{
            'Accept':
                'application/rss+xml,application/atom+xml,application/xml,text/xml;q=0.9,*/*;q=0.8',
            if (!kIsWeb) 'User-Agent': userAgent,
          },
        ),
      );
      final contentType = resp.headers.value('content-type') ?? '';
      final body = (resp.data ?? '').trim();
      if (!_looksLikeFeed(contentType, body)) return null;
      final direct = _directFeedCandidate(
        url: resp.realUri,
        contentType: contentType,
        body: body,
      );
      return DiscoveredFeed(
        url: direct.url,
        title: direct.title,
        type: direct.type,
        siteUrl: direct.siteUrl ?? siteUrl,
        siteTitle: siteTitle,
        source: DiscoveredFeedSource.commonPath,
      );
    } catch (_) {
      return null;
    }
  }
}
