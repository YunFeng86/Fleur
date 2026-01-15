import 'package:rss_dart/domain/atom_feed.dart';
import 'package:rss_dart/domain/atom_link.dart';
import 'package:rss_dart/domain/rss_feed.dart';

import '../../utils/date_parse.dart';
import 'parsed_feed.dart';

class FeedParser {
  ParsedFeed parse(String xml) {
    // Try RSS first; fall back to Atom.
    try {
      return _parseRss(xml);
    } catch (_) {
      return _parseAtom(xml);
    }
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
