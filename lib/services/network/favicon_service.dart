import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../cache/favicon_store.dart';
import 'user_agents.dart';

class FaviconService {
  FaviconService({required Dio dio, required FaviconStore store})
    : _dio = dio,
      _store = store;

  final Dio _dio;
  final FaviconStore _store;

  static const Duration _successTtl = Duration(days: 30);
  static const Duration _missTtl = Duration(days: 7);

  // Session-only backoff to avoid hammering hosts on transient failures.
  // This is intentionally in-memory: we want to retry after restart/network recovery.
  static const Duration _networkErrorBackoff = Duration(seconds: 30);
  static const Duration _serverErrorBackoff = Duration(minutes: 2);
  static const Duration _rateLimitBackoff = Duration(minutes: 10);

  final Map<String, DateTime> _backoffUntil = <String, DateTime>{};

  Future<String?> resolveFaviconUrl(
    Uri input, {
    String? userAgent,
    bool forceRefresh = false,
  }) async {
    final site = _normalizeToHttpUri(input);
    if (site == null) return null;

    final hostKey = site.host.toLowerCase();
    if (!forceRefresh) {
      final cached = await _store.get(hostKey);
      if (cached != null) {
        final ttl = cached.iconUrl == null ? _missTtl : _successTtl;
        if (!cached.isExpired(ttl: ttl)) {
          return cached.iconUrl;
        }
      }
    }

    // If this host is in a session backoff window, avoid any network I/O.
    if (_isBackedOff(hostKey)) return null;

    final resolved = await _resolveFromNetwork(site, userAgent: userAgent);

    // Cache policy:
    // - success: persist 30 days
    // - miss (definite not found): persist 7 days (iconUrl == null)
    // - error (network/timeout/5xx/etc): do not persist, allow retry later
    switch (resolved.kind) {
      case _ResolveKind.success:
        await _store.set(
          hostKey,
          FaviconCacheEntry(fetchedAt: DateTime.now(), iconUrl: resolved.url),
        );
        return resolved.url;
      case _ResolveKind.miss:
        await _store.set(
          hostKey,
          FaviconCacheEntry(fetchedAt: DateTime.now(), iconUrl: null),
        );
        return null;
      case _ResolveKind.error:
        return null;
    }
  }

  Uri? _normalizeToHttpUri(Uri input) {
    if (input.host.isNotEmpty &&
        (input.scheme == 'http' || input.scheme == 'https')) {
      return input;
    }
    final raw = input.toString().trim();
    if (raw.isEmpty) return null;
    final withScheme = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';
    final parsed = Uri.tryParse(withScheme);
    if (parsed == null || parsed.host.isEmpty) return null;
    if (!(parsed.scheme == 'http' || parsed.scheme == 'https')) return null;
    return parsed;
  }

  Future<_ResolveResult> _resolveFromNetwork(
    Uri site, {
    required String? userAgent,
  }) async {
    final tries = _homePageTries(site);
    var sawDefiniteMiss = false;
    var sawError = false;

    for (final home in tries) {
      final html = await _tryFetchHtml(home, userAgent: userAgent);
      if (html != null && html.body.trim().isNotEmpty) {
        final base = html.realUri ?? home;
        final candidates = FaviconHtmlParser.extractCandidates(
          html: html.body,
          baseUri: base,
        );
        final best = await _pickReachable(candidates);
        if (best != null) return _ResolveResult.success(best);
      }

      // Probe /favicon.ico at the origin. This gives us a reliable signal for
      // "definite miss" (404) vs transient failures (timeouts/5xx/etc).
      final origin = (html?.realUri ?? home).replace(
        path: '/favicon.ico',
        query: null,
        fragment: null,
      );
      final r = await _checkReachability(origin.toString());
      switch (r) {
        case _Reachability.reachable:
          return _ResolveResult.success(origin.toString());
        case _Reachability.notFound:
          sawDefiniteMiss = true;
        case _Reachability.rateLimited:
          sawError = true;
        case _Reachability.error:
          sawError = true;
      }
    }

    // Important: do NOT return a guessed URL on failure; this prevents
    // "failure amplification" where the app keeps retrying a dead favicon URL.
    if (sawDefiniteMiss) return const _ResolveResult.miss();
    if (sawError) return const _ResolveResult.error();
    return const _ResolveResult.miss();
  }

  List<Uri> _homePageTries(Uri site) {
    final root = site.replace(path: '/', query: null, fragment: null);

    // If caller didn't provide scheme, we normalized to https://..., so also try http://.
    final altScheme = root.scheme == 'https' ? 'http' : 'https';
    final alt = root.replace(scheme: altScheme);

    final out = <Uri>[root];
    if (alt != root) out.add(alt);
    return out;
  }

  Future<_HtmlFetchResult?> _tryFetchHtml(
    Uri uri, {
    required String? userAgent,
  }) async {
    try {
      final res = await _dio.get<String>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s >= 200 && s < 400,
          headers: <String, String>{
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'User-Agent': (userAgent != null && userAgent.trim().isNotEmpty)
                ? userAgent.trim()
                : UserAgents.web,
          },
        ),
      );
      final body = res.data ?? '';
      return _HtmlFetchResult(body: body, realUri: res.realUri);
    } on DioException catch (e) {
      _maybeBackoffFromDioException(uri.host.toLowerCase(), e);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _pickReachable(List<String> candidates) async {
    // Try a few best-looking candidates; avoid turning list rendering into a crawler.
    final limit = candidates.length > 6 ? 6 : candidates.length;
    for (var i = 0; i < limit; i++) {
      final url = candidates[i];
      final r = await _checkReachability(url);
      if (r == _Reachability.reachable) return url;
    }
    return null;
  }

  Future<_Reachability> _checkReachability(String url) async {
    final hostKey = _hostKeyFromUrl(url);

    // Some servers reject HEAD; try a minimal GET as fallback.
    try {
      final head = await _dio.head<void>(
        url,
        options: Options(
          // Always return response so we can distinguish 404 vs network errors.
          validateStatus: (_) => true,
          headers: const <String, String>{'Accept': 'image/*,*/*;q=0.8'},
        ),
      );
      final s = head.statusCode ?? 0;
      if (s >= 200 && s < 400) return _Reachability.reachable;
      if (s == 404) return _Reachability.notFound;
      if (s == 429) {
        if (hostKey != null) _setBackoff(hostKey, _rateLimitBackoff);
        return _Reachability.rateLimited;
      }
      if (s >= 500 && s < 600) {
        if (hostKey != null) _setBackoff(hostKey, _serverErrorBackoff);
        return _Reachability.error;
      }
    } on DioException catch (e) {
      if (hostKey != null) _maybeBackoffFromDioException(hostKey, e);
      // ignore
    } catch (_) {
      // ignore
    }

    try {
      final get = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (_) => true,
          headers: const <String, String>{
            'Accept': 'image/*,*/*;q=0.8',
            'Range': 'bytes=0-0',
          },
        ),
      );
      final s = get.statusCode ?? 0;
      if (s >= 200 && s < 400) return _Reachability.reachable;
      if (s == 404) return _Reachability.notFound;
      if (s == 429) {
        if (hostKey != null) _setBackoff(hostKey, _rateLimitBackoff);
        return _Reachability.rateLimited;
      }
      if (s >= 500 && s < 600) {
        if (hostKey != null) _setBackoff(hostKey, _serverErrorBackoff);
        return _Reachability.error;
      }
      return _Reachability.error;
    } on DioException catch (e) {
      if (hostKey != null) _maybeBackoffFromDioException(hostKey, e);
      return _Reachability.error;
    } catch (_) {
      return _Reachability.error;
    }
  }

  bool _isBackedOff(String hostKey) {
    final until = _backoffUntil[hostKey];
    if (until == null) return false;
    if (until.isAfter(DateTime.now())) return true;
    _backoffUntil.remove(hostKey);
    return false;
  }

  void _setBackoff(String hostKey, Duration duration) {
    final nextUntil = DateTime.now().add(duration);
    final prev = _backoffUntil[hostKey];
    if (prev == null || prev.isBefore(nextUntil)) {
      _backoffUntil[hostKey] = nextUntil;
    }
  }

  void _maybeBackoffFromDioException(String hostKey, DioException e) {
    final s = e.response?.statusCode;
    if (s == 429) {
      _setBackoff(hostKey, _rateLimitBackoff);
      return;
    }
    if (s != null && s >= 500 && s < 600) {
      _setBackoff(hostKey, _serverErrorBackoff);
      return;
    }

    // Timeouts/offline: short backoff to avoid retry storms while scrolling.
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        _setBackoff(hostKey, _networkErrorBackoff);
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        // no-op
        break;
    }
  }

  String? _hostKeyFromUrl(String url) {
    final u = Uri.tryParse(url);
    final host = u?.host ?? '';
    if (host.isEmpty) return null;
    return host.toLowerCase();
  }
}

enum _ResolveKind { success, miss, error }

class _ResolveResult {
  const _ResolveResult._({required this.kind, required this.url});

  const _ResolveResult.success(String url)
    : this._(kind: _ResolveKind.success, url: url);

  const _ResolveResult.miss() : this._(kind: _ResolveKind.miss, url: null);

  const _ResolveResult.error() : this._(kind: _ResolveKind.error, url: null);

  final _ResolveKind kind;
  final String? url;
}

enum _Reachability { reachable, notFound, rateLimited, error }

class FaviconHtmlParser {
  /// Extract candidate favicon URLs, best-first.
  static List<String> extractCandidates({
    required String html,
    required Uri baseUri,
  }) {
    final doc = html_parser.parse(html);
    final links = doc.querySelectorAll('link');

    final candidates = <_IconCandidate>[];
    for (final link in links) {
      final rel = (link.attributes['rel'] ?? '').trim().toLowerCase();
      if (rel.isEmpty) continue;
      if (!_relLooksLikeIcon(rel)) continue;
      final href = (link.attributes['href'] ?? '').trim();
      if (href.isEmpty) continue;

      final resolved = _resolveUrl(baseUri, href);
      if (resolved == null) continue;
      if (!(resolved.scheme == 'http' || resolved.scheme == 'https')) continue;

      final sizes = (link.attributes['sizes'] ?? '').trim().toLowerCase();
      candidates.add(
        _IconCandidate(
          url: resolved.toString(),
          rel: rel,
          sizeScore: _sizeScore(sizes),
          relScore: _relScore(rel),
        ),
      );
    }

    // Ensure /favicon.ico is considered even if page doesn't declare it.
    final fallback = baseUri.replace(
      path: '/favicon.ico',
      query: null,
      fragment: null,
    );
    candidates.add(
      _IconCandidate(
        url: fallback.toString(),
        rel: 'fallback',
        sizeScore: 0,
        relScore: -1,
      ),
    );

    candidates.sort((a, b) {
      final relCmp = b.relScore.compareTo(a.relScore);
      if (relCmp != 0) return relCmp;
      return b.sizeScore.compareTo(a.sizeScore);
    });

    final seen = <String>{};
    final out = <String>[];
    for (final c in candidates) {
      if (seen.add(c.url)) out.add(c.url);
    }
    return out;
  }

  static bool _relLooksLikeIcon(String rel) {
    // rel is space-separated tokens, but many pages use "shortcut icon".
    final tokens = rel.split(RegExp(r'\\s+'));
    if (tokens.contains('icon')) return true;
    if (tokens.contains('shortcut') && tokens.contains('icon')) return true;
    if (tokens.contains('apple-touch-icon')) return true;
    if (tokens.contains('apple-touch-icon-precomposed')) return true;
    if (tokens.contains('mask-icon')) return true;
    return false;
  }

  static int _relScore(String rel) {
    // Prefer standard icons; apple-touch is still good.
    final tokens = rel.split(RegExp(r'\\s+'));
    if (tokens.contains('icon') && !tokens.contains('shortcut')) return 30;
    if (tokens.contains('shortcut') && tokens.contains('icon')) return 25;
    if (tokens.contains('apple-touch-icon') ||
        tokens.contains('apple-touch-icon-precomposed')) {
      return 20;
    }
    if (tokens.contains('mask-icon')) return 10;
    return 0;
  }

  static int _sizeScore(String sizes) {
    if (sizes.isEmpty) return 0;
    if (sizes == 'any') return 16;
    // Common formats: "32x32" or "180x180".
    final first = sizes.split(RegExp(r'\\s+')).first;
    final parts = first.split('x');
    if (parts.length != 2) return 0;
    final w = int.tryParse(parts[0]);
    final h = int.tryParse(parts[1]);
    if (w == null || h == null) return 0;
    return w > h ? w : h;
  }

  static Uri? _resolveUrl(Uri baseUri, String href) {
    try {
      return baseUri.resolve(href);
    } catch (_) {
      return Uri.tryParse(href);
    }
  }
}

class _IconCandidate {
  const _IconCandidate({
    required this.url,
    required this.rel,
    required this.sizeScore,
    required this.relScore,
  });

  final String url;
  final String rel;
  final int sizeScore;
  final int relScore;
}

class _HtmlFetchResult {
  const _HtmlFetchResult({required this.body, required this.realUri});

  final String body;
  final Uri? realUri;
}
