import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Normalizes feed or extracted HTML before reader math normalization/sanitizing.
///
/// This layer canonicalizes known publisher structures and resource attributes
/// into the regular HTML shape expected by the reader.
class FeedHtmlNormalizer {
  FeedHtmlNormalizer._();

  static String normalize(String html, {Uri? baseUrl}) {
    if (html.trim().isEmpty) return '';

    final fragment = html_parser.parseFragment(html);
    _normalizeHighlightFigures(fragment);
    _normalizeImages(fragment, baseUrl: baseUrl);
    _normalizeLinks(fragment, baseUrl: baseUrl);
    return fragment.outerHtml;
  }

  static void _normalizeHighlightFigures(dom.DocumentFragment fragment) {
    for (final figure in fragment.querySelectorAll('figure.highlight')) {
      final table = figure.children
          .where((element) => element.localName == 'table')
          .firstOrNull;
      if (table == null) continue;

      final sourcePre = table.querySelector('td.code pre');
      if (sourcePre == null) continue;

      final pre = dom.Element.tag('pre');
      final code = dom.Element.tag('code');
      final language = _highlightLanguage(figure);
      if (language != null) {
        final languageClass = 'language-$language';
        pre.attributes
          ..['class'] = languageClass
          ..['data-language'] = language;
        code.attributes
          ..['class'] = languageClass
          ..['data-language'] = language;
      }

      final source = _codeContents(sourcePre);
      code.nodes.addAll(source.nodes.map((node) => node.clone(true)));
      pre.append(code);
      figure.replaceWith(pre);
    }
  }

  static dom.Element _codeContents(dom.Element pre) {
    if (pre.children.length != 1) return pre;
    final code = pre.children.single;
    if (code.localName != 'code') return pre;
    final onlyWhitespaceAroundCode = pre.nodes.every(
      (node) =>
          identical(node, code) || node is dom.Text && node.data.trim().isEmpty,
    );
    return onlyWhitespaceAroundCode ? code : pre;
  }

  static String? _highlightLanguage(dom.Element figure) {
    for (final rawClass in figure.classes) {
      final candidate = rawClass.startsWith('language-')
          ? rawClass.substring('language-'.length)
          : rawClass;
      final normalized = candidate.trim().toLowerCase();
      if (_highlightPresentationClasses.contains(normalized)) continue;
      if (_safeLanguagePattern.hasMatch(normalized)) return normalized;
    }
    return null;
  }

  static const _highlightPresentationClasses = {
    'highlight',
    'hljs',
    'code',
    'code-block',
    'line-numbers',
  };

  static final _safeLanguagePattern = RegExp(r'^[a-z0-9_-]+$');

  static void _normalizeImages(dom.DocumentFragment fragment, {Uri? baseUrl}) {
    for (final img in fragment.querySelectorAll('img')) {
      final best = _bestImageSource(img);
      if (best == null) {
        img.attributes.remove('src');
        continue;
      }

      final resolved = _resolveUrl(best, baseUrl: baseUrl);
      if (resolved == null || !_isHttpUrl(resolved)) {
        img.attributes.remove('src');
        continue;
      }

      img.attributes['src'] = resolved;
    }
  }

  static void _normalizeLinks(dom.DocumentFragment fragment, {Uri? baseUrl}) {
    for (final a in fragment.querySelectorAll('a')) {
      final href = a.attributes['href']?.trim();
      if (href == null || href.isEmpty) continue;

      final resolved = _resolveUrl(href, baseUrl: baseUrl);
      if (resolved == null || !_isSafeLinkUrl(resolved)) {
        a.attributes.remove('href');
        continue;
      }

      a.attributes['href'] = resolved;
    }
  }

  static String? _bestImageSource(dom.Element img) {
    final src = img.attributes['src']?.trim();
    if (_isUsableImageSrc(src)) return src;

    for (final attr in const [
      'data-lazy-src',
      'data-src',
      'data-original',
      'data-lazyload',
    ]) {
      final value = img.attributes[attr]?.trim();
      if (_isUsableImageSrc(value)) return value;
    }

    final srcset =
        img.attributes['srcset']?.trim() ??
        img.attributes['data-srcset']?.trim();
    final srcsetSource = _firstSrcFromSrcset(srcset);
    if (_isUsableImageSrc(srcsetSource)) return srcsetSource;

    return null;
  }

  static String? _firstSrcFromSrcset(String? srcset) {
    if (srcset == null || srcset.trim().isEmpty) return null;
    final first = srcset.split(',').first.trim();
    if (first.isEmpty) return null;
    return first.split(RegExp(r'\s+')).first.trim();
  }

  static bool _isUsableImageSrc(String? raw) {
    if (raw == null) return false;
    final src = raw.trim();
    if (src.isEmpty) return false;

    final lower = src.toLowerCase();
    if (lower.startsWith('data:')) return false;
    if (lower == 'about:blank') return false;
    return !RegExp(
      r'(b_ld\.|loading|placeholder|blank|transparent|spacer|pixel)',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  static String? _resolveUrl(String raw, {Uri? baseUrl}) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    if (value.startsWith('//')) {
      final scheme = (baseUrl?.scheme == 'http' || baseUrl?.scheme == 'https')
          ? baseUrl!.scheme
          : 'https';
      return '$scheme:$value';
    }

    try {
      final uri = Uri.parse(value);
      if (uri.hasScheme) return uri.toString();
      return baseUrl?.resolve(value).toString() ?? value;
    } on FormatException {
      return null;
    }
  }

  static bool _isHttpUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  static bool _isSafeLinkUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return false;
    if (!uri.hasScheme) return true;
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https' || scheme == 'mailto';
  }
}
