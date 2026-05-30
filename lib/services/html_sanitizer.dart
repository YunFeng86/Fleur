import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

/// HTML sanitizer for cleaning untrusted RSS content.
///
/// Removes dangerous tags (script, iframe) and attributes (onclick, onerror)
/// to prevent XSS attacks and layout breakage from malicious RSS feeds.
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
    'thead',
    'tbody',
    'tr',
    'th',
    'td',
    'div',
    'span',
    'b',
    'i',
    'u',
    's',
    'del',
    'sup',
    'sub',
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
  static void _cleanNode(Element element) {
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
          _cleanNode(child);
          toUnwrap.add(child);
          continue;
        }

        // Filter style attribute first
        final rawStyle = child.attributes['style'];
        String? filteredStyle;
        if (rawStyle != null) {
          filteredStyle = _filterStyleAttribute(rawStyle);
          child.attributes.remove('style');
        }

        // Clean attributes
        final allowed = _allowedAttributes[tag] ?? <String>[];
        child.attributes.removeWhere(
          (k, v) => (k is String && k.startsWith('on')) || !allowed.contains(k),
        );

        // Re-add filtered style
        if (filteredStyle != null) {
          child.attributes['style'] = filteredStyle;
        }

        // Recursively clean children
        _cleanNode(child);
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
      if (property.isEmpty || !_allowedCssProperties.contains(property))
        continue;
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
