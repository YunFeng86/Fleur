import 'package:rss_dart/domain/atom_feed.dart';
import 'package:rss_dart/domain/atom_link.dart';
import 'package:rss_dart/domain/rss_feed.dart';

import '../../utils/date_parse.dart';
import 'parsed_feed.dart';

class FeedParser {
  ParsedFeed parse(String xml) {
    final trimmed = xml.trim();

    // Detect feed format by checking the actual root element tag name
    // This is more reliable than searching for substrings in arbitrary positions
    try {
      final rootTag = _extractRootTag(trimmed);
      final localName = _localName(rootTag).toLowerCase();

      if (localName == 'rss' || localName == 'channel') {
        // RSS 2.0 or malformed RSS without version attribute
        return _parseRss(trimmed);
      } else if (localName == 'rdf') {
        // RSS 1.0 (RDF-based)
        return _parseRss(trimmed);
      } else if (localName == 'feed') {
        // Atom feed
        return _parseAtom(trimmed);
      } else {
        throw FormatException(
          'Unknown feed format. Root element: <$rootTag>. Expected <rss>, <feed>, or <rdf:RDF>.',
        );
      }
    } catch (e) {
      // Fallback to old substring-based detection if XML parsing fails
      final header = trimmed.length > 512 ? trimmed.substring(0, 512) : trimmed;

      if (_isRssFeed(header)) {
        try {
          return _parseRss(trimmed);
        } catch (e) {
          throw FormatException('Failed to parse RSS feed: $e');
        }
      } else if (_isAtomFeed(header)) {
        try {
          return _parseAtom(trimmed);
        } catch (e) {
          throw FormatException('Failed to parse Atom feed: $e');
        }
      } else {
        throw FormatException(
          'Unknown feed format. Expected RSS 1.0/2.0 or Atom feed.',
        );
      }
    }
  }

  /// Extract root element tag name from XML
  String _extractRootTag(String xml) {
    // Find first '<' that isn't '<?xml' or '<!DOCTYPE'
    var pos = 0;
    while (pos < xml.length) {
      final start = xml.indexOf('<', pos);
      if (start == -1) break;

      // Skip XML declaration and DOCTYPE
      if (xml.startsWith('<?', start) || xml.startsWith('<!', start)) {
        final end = xml.indexOf('>', start);
        if (end == -1) break;
        pos = end + 1;
        continue;
      }

      // Found root element
      final end = xml.indexOf('>', start);
      if (end == -1) break;

      var tag = xml.substring(start + 1, end);
      // Remove attributes and whitespace
      final spacePos = tag.indexOf(RegExp(r'\s'));
      if (spacePos != -1) {
        tag = tag.substring(0, spacePos);
      }
      return tag.trim();
    }

    return '';
  }

  String _localName(String tag) {
    final t = tag.trim();
    final idx = t.indexOf(':');
    return idx >= 0 ? t.substring(idx + 1) : t;
  }

  bool _isAtomFeed(String xmlHeader) {
    // Atom must have <feed> root and xmlns="http://www.w3.org/2005/Atom"
    return xmlHeader.contains('<feed') &&
           xmlHeader.contains('http://www.w3.org/2005/Atom');
  }

  bool _isRssFeed(String xmlHeader) {
    // RSS 2.0: <rss version="2.0">
    // RSS 1.0: <rdf:RDF> with RSS 1.0 namespace
    // Also accept <channel> as RSS indicator (some feeds omit version)
    return xmlHeader.contains('<rss') ||
           xmlHeader.contains('<channel>') ||
           (xmlHeader.contains('<rdf:RDF') && xmlHeader.contains('http://purl.org/rss/1.0/'));
  }

  ParsedFeed _parseRss(String xml) {
    final feed = RssFeed.parse(xml);
    return ParsedFeed(
      title: feed.title,
      siteUrl: feed.link,
      description: feed.description,
      items: feed.items
          .map((it) {
            final link = it.link?.trim();
            if (link == null || link.isEmpty) return null;
            return ParsedItem(
              remoteId: it.guid ?? link,
              link: link,
              title: it.title,
              author: it.author ?? it.dc?.creator,
              publishedAt: tryParseFeedDate(it.pubDate),
              contentHtml: it.content?.value ?? it.description,
            );
          })
          .whereType<ParsedItem>()
          .toList(growable: false),
    );
  }

  ParsedFeed _parseAtom(String xml) {
    final feed = AtomFeed.parse(xml);
    final siteUrl = _pickAlternate(feed.links);
    return ParsedFeed(
      title: feed.title,
      siteUrl: siteUrl,
      description: feed.subtitle,
      items: feed.items
          .map((it) {
            final link = _pickAlternate(it.links) ?? '';
            if (link.trim().isEmpty) return null;
            return ParsedItem(
              remoteId: it.id ?? link,
              link: link,
              title: it.title,
              author: it.authors.isNotEmpty ? it.authors.first.name : null,
              publishedAt:
                  tryParseFeedDate(it.published) ?? tryParseFeedDate(it.updated),
              contentHtml: it.content ?? it.summary,
            );
          })
          .whereType<ParsedItem>()
          .toList(growable: false),
    );
  }

  String? _pickAlternate(List<AtomLink> links) {
    for (final l in links) {
      final rel = l.rel;
      final href = l.href;
      if (href == null) continue;
      if (rel == null || rel == 'alternate') return href;
    }
    for (final l in links) {
      final href = l.href;
      if (href != null) return href;
    }
    return null;
  }
}
