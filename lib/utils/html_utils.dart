// Lightweight HTML helpers used in list views/previews.
//
// Prefer regex/substring extraction for tiny tasks; full HTML parsing is
// expensive in scrolling lists.

final RegExp _imgSrcRegex = RegExp(
  // Whitespace before `src` avoids matching `data-src`.
  r"""<img[^>]*\ssrc\s*=\s*['"]([^'"]+)['"]""",
  caseSensitive: false,
);

final RegExp _imgDataSrcRegex = RegExp(
  r"""<img[^>]*\sdata-src\s*=\s*['"]([^'"]+)['"]""",
  caseSensitive: false,
);

final RegExp _imgTagRegex = RegExp(r"""<img\b[^>]*>""", caseSensitive: false);

final RegExp _attrRegex = RegExp(
  r"""([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))""",
);

final RegExp _styleDimensionRegex = RegExp(
  r"""(?:^|;)\s*(width|height)\s*:\s*([0-9]+(?:\.[0-9]+)?)px\b""",
  caseSensitive: false,
);

final RegExp _stripBlockedTagsRegex = RegExp(
  r"""<(script|style|noscript)\b[^>]*>.*?</\1>""",
  caseSensitive: false,
  dotAll: true,
);

final RegExp _stripTagsRegex = RegExp(r"""<[^>]+>""");

final RegExp _numericEntityRegex = RegExp(r"""&#(x?[0-9a-fA-F]+);""");

const double _minPreviewImageSide = 96;
const double _minPreviewImageArea = 16000;

class PreviewImageSize {
  const PreviewImageSize({required this.width, required this.height});

  final double width;
  final double height;
}

/// Cached preview data for an article's HTML content.
class ArticlePreviewData {
  const ArticlePreviewData({required this.previewText, this.previewImageUrl});

  /// Plain-text preview extracted from article HTML.
  final String previewText;

  /// First suitable preview image URL, or null if none found.
  final String? previewImageUrl;
}

/// Bounded FIFO cache for article preview extractions.
///
/// Keyed by `(articleId, contentHash)` — cached data auto-invalidates when
/// article content changes. FIFO eviction matches typical list scroll patterns.
class ArticlePreviewCache {
  static final _entries = <String, ArticlePreviewData>{};
  static const _maxSize = 500;

  static String _key(int articleId, String? contentHash) =>
      '$articleId:${contentHash ?? ''}';

  /// Return cached [ArticlePreviewData] for [articleId], or compute and cache
  /// it from [contentHtml] / [contentHash].
  static ArticlePreviewData getOrCompute(
    int articleId,
    String? contentHtml,
    String? contentHash, {
    Uri? baseUrl,
    PreviewImageSize? Function(String url)? metaLookup,
  }) {
    final key = _key(articleId, contentHash);
    final cached = _entries[key];
    if (cached != null) return cached;

    final previewText = extractPreviewText(contentHtml);
    final imageUrl = extractPreviewImageSrc(
      contentHtml,
      baseUrl: baseUrl,
      metaLookup: metaLookup,
    );

    if (_entries.length >= _maxSize) {
      _entries.remove(_entries.keys.first);
    }

    return _entries[key] = ArticlePreviewData(
      previewText: previewText,
      previewImageUrl: imageUrl,
    );
  }

  /// Clear all cached entries.
  static void clear() => _entries.clear();
}

String? extractFirstImageSrc(String? html) {
  if (html == null || html.isEmpty) return null;
  // Prefer real src, but fall back to data-src for lazy-loaded markup.
  final src = _imgSrcRegex.firstMatch(html)?.group(1);
  if (src != null) return src;
  return _imgDataSrcRegex.firstMatch(html)?.group(1);
}

String extractPreviewText(String? html) {
  if (html == null || html.trim().isEmpty) return '';
  return _decodeHtmlEntities(
    html
        .replaceAll(_stripBlockedTagsRegex, ' ')
        .replaceAll(_stripTagsRegex, ' ')
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim(),
  ).replaceAll(RegExp(r'\s+'), ' ').trim();
}

String? extractPreviewImageSrc(
  String? html, {
  Uri? baseUrl,
  PreviewImageSize? Function(String url)? metaLookup,
}) {
  if (html == null || html.trim().isEmpty) return null;

  for (final match in _imgTagRegex.allMatches(html)) {
    final attrs = _parseAttributes(match.group(0)!);
    String? url;
    for (final candidate in _imageSourceCandidates(attrs)) {
      if (_looksDecorativeImage(candidate, attrs)) continue;
      final normalized = _normalizePreviewUrl(candidate, baseUrl: baseUrl);
      if (normalized == null) continue;
      if (_looksDecorativeImage(normalized, attrs)) continue;
      url = normalized;
      break;
    }
    if (url == null) continue;

    final declared = _declaredImageSize(attrs);
    if (_isKnownSmallImage(declared)) continue;

    final cached = metaLookup?.call(url);
    if (_isKnownSmallImage(cached)) continue;

    return url;
  }

  return null;
}

List<String> _imageSourceCandidates(Map<String, String> attrs) {
  return [
    attrs['src'],
    attrs['data-lazy-src'],
    attrs['data-src'],
    attrs['data-original'],
    _firstSrcFromSrcset(attrs['srcset']),
    _firstSrcFromSrcset(attrs['data-srcset']),
  ].whereType<String>().toList(growable: false);
}

Map<String, String> _parseAttributes(String tag) {
  final attrs = <String, String>{};
  for (final match in _attrRegex.allMatches(tag)) {
    final name = match.group(1)?.toLowerCase();
    final value = match.group(2) ?? match.group(3) ?? match.group(4);
    if (name == null || value == null) continue;
    attrs[name] = _decodeHtmlEntities(value.trim());
  }
  return attrs;
}

String? _firstSrcFromSrcset(String? srcset) {
  if (srcset == null || srcset.trim().isEmpty) return null;
  final first = srcset.split(',').first.trim();
  if (first.isEmpty) return null;
  return first.split(RegExp(r'\s+')).first.trim();
}

String? _normalizePreviewUrl(String raw, {required Uri? baseUrl}) {
  final value = _decodeHtmlEntities(raw.trim());
  if (value.isEmpty) return null;
  final lower = value.toLowerCase();
  if (lower.startsWith('data:')) return null;
  if (lower == 'about:blank') return null;

  if (value.startsWith('//')) {
    final scheme = (baseUrl?.scheme == 'http' || baseUrl?.scheme == 'https')
        ? baseUrl!.scheme
        : 'https';
    return '$scheme:$value';
  }

  try {
    final uri = Uri.parse(value);
    if (uri.hasScheme) {
      final scheme = uri.scheme.toLowerCase();
      if (scheme != 'http' && scheme != 'https') return null;
      return uri.toString();
    }
    return baseUrl?.resolve(value).toString() ?? value;
  } on FormatException {
    return null;
  }
}

PreviewImageSize? _declaredImageSize(Map<String, String> attrs) {
  double? width = _parseCssNumber(attrs['width']);
  double? height = _parseCssNumber(attrs['height']);

  final style = attrs['style'];
  if (style != null) {
    for (final match in _styleDimensionRegex.allMatches(style)) {
      final key = match.group(1)?.toLowerCase();
      final value = _parseCssNumber(match.group(2));
      if (key == 'width') width ??= value;
      if (key == 'height') height ??= value;
    }
  }

  if (width == null && height == null) return null;
  return PreviewImageSize(
    width: width ?? double.nan,
    height: height ?? double.nan,
  );
}

double? _parseCssNumber(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r"""[0-9]+(?:\.[0-9]+)?""").firstMatch(raw);
  if (match == null) return null;
  final parsed = double.tryParse(match.group(0)!);
  if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
  return parsed;
}

bool _isKnownSmallImage(PreviewImageSize? size) {
  if (size == null) return false;
  final hasWidth = size.width.isFinite;
  final hasHeight = size.height.isFinite;
  if (hasWidth && size.width < _minPreviewImageSide) return true;
  if (hasHeight && size.height < _minPreviewImageSide) return true;
  if (hasWidth && hasHeight) {
    return size.width * size.height < _minPreviewImageArea;
  }
  return false;
}

bool _looksDecorativeImage(String url, Map<String, String> attrs) {
  final haystack = [
    url,
    attrs['alt'],
    attrs['class'],
    attrs['id'],
    attrs['role'],
  ].whereType<String>().join(' ').toLowerCase();

  const tokens = [
    '1x1',
    'avatar',
    'beacon',
    'blank',
    'emoji',
    'favicon',
    'icon',
    'logo',
    'loading',
    'pixel',
    'placeholder',
    'spacer',
    'sprite',
    'tracking',
    'transparent',
  ];

  return tokens.any((token) {
    return RegExp(
      '(^|[^a-z0-9])${RegExp.escape(token)}([^a-z0-9]|\$)',
    ).hasMatch(haystack);
  });
}

String _decodeHtmlEntities(String input) {
  return input
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAllMapped(_numericEntityRegex, (match) {
        final raw = match.group(1)!;
        final radix = raw.startsWith('x') || raw.startsWith('X') ? 16 : 10;
        final body = radix == 16 ? raw.substring(1) : raw;
        final codePoint = int.tryParse(body, radix: radix);
        if (codePoint == null) return match.group(0)!;
        return String.fromCharCode(codePoint);
      });
}
