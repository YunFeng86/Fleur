import '../../models/article.dart';
import '../../repositories/article_repository.dart';
import '../../repositories/feed_repository.dart';
import '../rss/feed_parser.dart';
import '../rss/rss_client.dart';

class SyncService {
  SyncService({
    required FeedRepository feeds,
    required ArticleRepository articles,
    required RssClient client,
    required FeedParser parser,
  })  : _feeds = feeds,
        _articles = articles,
        _client = client,
        _parser = parser;

  final FeedRepository _feeds;
  final ArticleRepository _articles;
  final RssClient _client;
  final FeedParser _parser;

  Future<int> refreshFeed(int feedId) async {
    final feed = await _feeds.getById(feedId);
    if (feed == null) return 0;

    final xml = await _client.fetchXml(feed.url);
    final parsed = _parser.parse(xml);

    await _feeds.updateMeta(
      id: feedId,
      title: parsed.title,
      siteUrl: parsed.siteUrl,
      description: parsed.description,
      lastSyncedAt: DateTime.now(),
    );

    final incoming = parsed.items.map((it) {
      final a = Article()
        ..remoteId = it.remoteId
        ..link = it.link
        ..title = it.title
        ..author = it.author
        ..contentHtml = it.contentHtml
        ..publishedAt = (it.publishedAt ?? DateTime.now()).toUtc();
      return a;
    }).toList(growable: false);

    await _articles.upsertMany(feedId, incoming);
    return incoming.length;
  }
}

