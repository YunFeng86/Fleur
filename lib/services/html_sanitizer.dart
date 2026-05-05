import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

/// HTML sanitizer for cleaning untrusted RSS content.
///
/// Removes dangerous tags (script, iframe) and attributes (onclick, onerror)
/// to prevent XSS attacks and layout breakage from malicious RSS feeds.
class HtmlSanitizer {
  HtmlSanitizer._();

  /// Allowed HTML tags (whitelist approach).
  static const _allowedTags = {
    // Wrapper used by our full-text extractor.
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
    'a': ['href', 'title'],
    'img': ['src', 'alt', 'title'],
    'td': ['colspan', 'rowspan'],
    'th': ['colspan', 'rowspan'],
  };

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

        // Clean attributes
        final allowed = _allowedAttributes[tag] ?? <String>[];
        child.attributes.removeWhere(
          (k, v) => !allowed.contains(k) || (k is String && k.startsWith('on')),
        );

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
}
