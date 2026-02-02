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

    for (final child in element.nodes) {
      if (child is Element) {
        final tag = child.localName?.toLowerCase();

        // Special handling for iframe (allow whitelisted video embeds)
        if (tag == 'iframe') {
          final src = child.attributes['src'] ?? '';
          final uri = Uri.tryParse(src);
          if (uri != null &&
              _allowedIframeDomains.any((d) => uri.host.contains(d))) {
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

        // Remove tags not in whitelist
        if (tag == null || !_allowedTags.contains(tag)) {
          toRemove.add(child);
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
  }
}
