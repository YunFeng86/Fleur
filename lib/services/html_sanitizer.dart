import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

/// HTML sanitizer for cleaning untrusted RSS content.
///
/// Removes dangerous tags (script, untrusted iframe) and attributes (onclick,
/// onerror) to prevent XSS attacks and layout breakage from malicious RSS
/// feeds. Trusted video iframe hosts are preserved with a reduced attribute set.
///
/// CSS inline styles are filtered by property: layout and structural properties
/// are preserved while typography properties (font-size, color, etc.) are
/// stripped so the reader theme stays in control.
class HtmlSanitizer {
  HtmlSanitizer._();

  /// Allowed HTML tags (whitelist approach).
  static const _allowedTags = {
    'article',
    'p',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'img',
    'a',
    'ul',
    'ol',
    'li',
    'blockquote',
    'pre',
    'code',
    'strong',
    'em',
    'br',
    'hr',
    'table',
    'caption',
    'colgroup',
    'col',
    'thead',
    'tbody',
    'tfoot',
    'tr',
    'th',
    'td',
    'video',
    'audio',
    'source',
    'track',
    'div',
    'span',
    'b',
    'i',
    'u',
    's',
    'del',
    'sup',
    'sub',
    'fleur-math',
  };

  static const _dangerousTags = {
    'script',
    'style',
    'noscript',
    'object',
    'embed',
    'link',
    'meta',
    'base',
  };

  /// Allowed attributes per tag.
  static const _allowedAttributes = {
    'a': ['href', 'title', 'target', 'rel'],
    'img': [
      'src',
      'alt',
      'title',
      'width',
      'height',
      'data-src',
      'data-lazy-src',
      'data-original',
    ],
    'td': ['colspan', 'rowspan'],
    'th': ['colspan', 'rowspan'],
    'table': ['cellpadding', 'cellspacing', 'border'],
    'col': ['span'],
    'video': [
      'src',
      'title',
      'width',
      'height',
      'poster',
      'controls',
      'preload',
    ],
    'audio': ['src', 'title', 'controls', 'preload'],
    'source': ['src', 'type'],
    'track': ['src', 'kind', 'srclang', 'label', 'default'],
    'code': ['class', 'data-language'],
    'pre': ['class', 'data-language'],
    'fleur-math': ['data-fleur-math', 'data-fleur-math-display'],
  };

  static final _safeClassPattern = RegExp(r'^[a-zA-Z0-9_\- ]+$');

  static const _safeMediaPreloadValues = {'none', 'metadata', 'auto'};

  static const _safeTrackKinds = {
    'subtitles',
    'captions',
    'descriptions',
    'chapters',
    'metadata',
  };

  /// CSS properties allowed in inline styles.
  ///
  /// Layout and structural properties are preserved (reader-immersive),
  /// typography properties are stripped (reader-controlled).
  static const _allowedCssProperties = {
    // Alignment & spacing
    'text-align',
    'margin',
    'margin-top',
    'margin-right',
    'margin-bottom',
    'margin-left',
    'padding',
    'padding-top',
    'padding-right',
    'padding-bottom',
    'padding-left',
    // Borders
    'border',
    'border-top',
    'border-right',
    'border-bottom',
    'border-left',
    'border-radius',
    'border-color',
    'border-style',
    'border-width',
    'border-top-color',
    'border-right-color',
    'border-bottom-color',
    'border-left-color',
    'border-top-style',
    'border-right-style',
    'border-bottom-style',
    'border-left-style',
    'border-top-width',
    'border-right-width',
    'border-bottom-width',
    'border-left-width',
    // Sizing (clamped)
    'width',
    'max-width',
    'min-width',
    'height',
    'max-height',
    'min-height',
    // Layout
    'display',
    'white-space',
    'vertical-align',
    'overflow',
    'list-style-type',
    'table-layout',
    // Background
    'background-color',
  };

  /// Safe values for the `display` property.
  static const _safeDisplayValues = {'inline', 'block', 'none'};

  static const _dangerousCssValuePatterns = ['expression(', 'javascript:'];

  /// Allowed iframe domains (for embedded videos).
  static const _allowedIframeDomains = {
    'youtube.com',
    'youtu.be',
    'youtube-nocookie.com',
    'vimeo.com',
    'bilibili.com',
  };

  static bool _isAllowedIframeHost(String host) {
    final h = host.toLowerCase().trim();
    if (h.isEmpty) return false;
    for (final d in _allowedIframeDomains) {
      final domain = d.toLowerCase();
      if (h == domain || h.endsWith('.$domain')) return true;
    }
    return false;
  }

  /// Sanitize HTML content.
  ///
  /// Returns cleaned HTML with dangerous elements removed.
  static String sanitize(String html) {
    if (html.trim().isEmpty) return '';

    final doc = html_parser.parse(html);
    final body = doc.body;
    if (body == null) return '';

    _cleanNode(body);
    return body.innerHtml;
  }

  /// Recursively clean DOM nodes.
  static void _cleanNode(Element element, {bool inCodeBlock = false}) {
    final toRemove = <Node>[];
    final toUnwrap = <Element>[];

    for (final child in element.nodes) {
      if (child is Element) {
        final tag = child.localName?.toLowerCase();

        if (tag == null) {
          toRemove.add(child);
          continue;
        }

        // Special handling for iframe (allow whitelisted video embeds)
        if (tag == 'iframe') {
          final src = child.attributes['src'] ?? '';
          final uri = Uri.tryParse(src);
          if (uri != null && _isAllowedIframeHost(uri.host)) {
            // Keep iframe but clean attributes
            child.attributes.clear();
            child.attributes['src'] = src;
            child.attributes['frameborder'] = '0';
            child.attributes['allowfullscreen'] = 'true';
            continue;
          } else {
            // Remove untrusted iframe
            toRemove.add(child);
            continue;
          }
        }

        if (_dangerousTags.contains(tag)) {
          toRemove.add(child);
          continue;
        }

        if (!_allowedTags.contains(tag)) {
          _cleanNode(child, inCodeBlock: inCodeBlock);
          toUnwrap.add(child);
          continue;
        }

        // Filter style attribute first
        final rawStyle = child.attributes['style'];
        String? filteredStyle;
        if (rawStyle != null) {
          filteredStyle = inCodeBlock
              ? _filterCodeTokenStyleAttribute(rawStyle)
              : _filterStyleAttribute(rawStyle);
          child.attributes.remove('style');
        }

        // Clean attributes
        final allowed = _allowedAttributes[tag] ?? <String>[];
        final allowedAttributes = inCodeBlock && _canKeepCodeTokenClass(tag)
            ? [...allowed, 'class']
            : allowed;
        child.attributes.removeWhere(
          (k, v) =>
              (k is String && k.startsWith('on')) ||
              !allowedAttributes.contains(k),
        );
        _sanitizeTagAttributes(child, tag, inCodeBlock: inCodeBlock);

        // Re-add filtered style
        if (filteredStyle != null) {
          child.attributes['style'] = filteredStyle;
        }

        // Recursively clean children
        _cleanNode(child, inCodeBlock: inCodeBlock || tag == 'pre');
      }
    }

    // Remove marked nodes
    for (final node in toRemove) {
      element.nodes.remove(node);
    }
    for (final node in toUnwrap) {
      _unwrapNode(element, node);
    }
  }

  static void _sanitizeTagAttributes(
    Element element,
    String tag, {
    required bool inCodeBlock,
  }) {
    if (tag == 'code' || tag == 'pre') {
      final rawClass = element.attributes['class'];
      if (rawClass != null) {
        final filtered = rawClass
            .split(RegExp(r'\s+'))
            .where((part) => part.startsWith('language-'))
            .where((part) => _safeClassPattern.hasMatch(part))
            .join(' ')
            .trim();
        if (filtered.isEmpty) {
          element.attributes.remove('class');
        } else {
          element.attributes['class'] = filtered;
        }
      }
      final dataLanguage = element.attributes['data-language'];
      if (dataLanguage != null && !_safeClassPattern.hasMatch(dataLanguage)) {
        element.attributes.remove('data-language');
      }
      return;
    }

    if (inCodeBlock && _canKeepCodeTokenClass(tag)) {
      _sanitizeCodeTokenClass(element);
      return;
    }

    if (tag == 'video' || tag == 'audio') {
      _sanitizeMediaSrc(element, 'src');
      _sanitizeMediaSrc(element, 'poster');
      final preload = element.attributes['preload'];
      if (preload != null &&
          !_safeMediaPreloadValues.contains(preload.toLowerCase())) {
        element.attributes.remove('preload');
      }
      return;
    }

    if (tag == 'source') {
      _sanitizeMediaSrc(element, 'src');
      return;
    }

    if (tag == 'track') {
      _sanitizeMediaSrc(element, 'src');
      final kind = element.attributes['kind'];
      if (kind != null && !_safeTrackKinds.contains(kind.toLowerCase())) {
        element.attributes.remove('kind');
      }
      return;
    }
  }

  static bool _canKeepCodeTokenClass(String tag) {
    return tag == 'span' ||
        tag == 'div' ||
        tag == 'p' ||
        tag == 'li' ||
        tag == 'mark';
  }

  static void _sanitizeCodeTokenClass(Element element) {
    final rawClass = element.attributes['class'];
    if (rawClass == null) return;
    final filtered = rawClass
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .where((part) => _safeClassPattern.hasMatch(part))
        .join(' ')
        .trim();
    if (filtered.isEmpty) {
      element.attributes.remove('class');
    } else {
      element.attributes['class'] = filtered;
    }
  }

  static void _sanitizeMediaSrc(Element element, String attribute) {
    final raw = element.attributes[attribute];
    if (raw == null || raw.trim().isEmpty) return;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.hasScheme && !_isSafeMediaScheme(uri.scheme)) {
      element.attributes.remove(attribute);
    }
  }

  static bool _isSafeMediaScheme(String scheme) {
    final s = scheme.toLowerCase();
    return s == 'http' || s == 'https';
  }

  static void _unwrapNode(Element parent, Element child) {
    final index = parent.nodes.indexOf(child);
    if (index == -1) return;
    final replacement = List<Node>.from(child.nodes);
    child.nodes.clear();
    parent.nodes.removeAt(index);
    parent.nodes.insertAll(index, replacement);
  }

  /// Parse inline `style` and keep only safe layout/structural CSS properties.
  static String? _filterStyleAttribute(String style) {
    if (style.trim().isEmpty) return null;

    final buffer = StringBuffer();
    for (final declaration in style.split(';')) {
      final colonIndex = declaration.indexOf(':');
      if (colonIndex < 0) continue;
      final property = declaration
          .substring(0, colonIndex)
          .trim()
          .toLowerCase();
      if (property.isEmpty || !_allowedCssProperties.contains(property)) {
        continue;
      }
      var value = declaration.substring(colonIndex + 1).trim();
      if (value.isEmpty) continue;

      // Block dangerous CSS values
      if (_containsDangerousValue(value)) continue;

      // Only allow safe display values
      if (property == 'display') {
        if (!_safeDisplayValues.contains(value.toLowerCase())) continue;
      }

      // Clamp oversized width/max-width
      if (property == 'width' || property == 'max-width') {
        value = _clampDimension(value, maxPx: 1200);
      }

      if (buffer.isNotEmpty) buffer.write('; ');
      buffer.write('$property: $value');
    }
    return buffer.isEmpty ? null : buffer.toString();
  }

  static String? _filterCodeTokenStyleAttribute(String style) {
    if (style.trim().isEmpty) return null;

    for (final declaration in style.split(';')) {
      final colonIndex = declaration.indexOf(':');
      if (colonIndex < 0) continue;
      final property = declaration
          .substring(0, colonIndex)
          .trim()
          .toLowerCase();
      if (property != 'color') continue;
      final value = declaration.substring(colonIndex + 1).trim();
      if (value.isEmpty || _containsDangerousValue(value)) continue;
      if (_isSafeCssColor(value)) return 'color: $value';
    }
    return null;
  }

  static bool _isSafeCssColor(String value) {
    final normalized = value.trim().toLowerCase();
    if (RegExp(r'^#[0-9a-f]{3}([0-9a-f]{3})?$').hasMatch(normalized)) {
      return true;
    }
    return RegExp(
      r'^rgba?\(\s*(\d{1,3}%?\s*,\s*){2}\d{1,3}%?(\s*,\s*(0|1|0?\.\d+|\d{1,3}%))?\s*\)$',
    ).hasMatch(normalized);
  }

  static bool _containsDangerousValue(String value) {
    final lower = value.toLowerCase();
    for (final pattern in _dangerousCssValuePatterns) {
      if (lower.contains(pattern)) return true;
    }
    if (lower.contains('url(')) return true;
    return false;
  }

  /// Clamp a CSS dimension value (e.g. "800px") to [maxPx].
  /// Passes through non-px values (%, em, auto, etc.) unchanged.
  static String _clampDimension(String value, {required double maxPx}) {
    final trimmed = value.trim();
    if (trimmed.endsWith('px')) {
      final numeric = double.tryParse(trimmed.replaceAll('px', ''));
      if (numeric != null && numeric > maxPx) return '${maxPx.toInt()}px';
    }
    return trimmed;
  }
}
