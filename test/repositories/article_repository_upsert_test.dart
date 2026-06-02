import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/repositories/article_repository.dart';
import 'package:fleur/utils/content_hash.dart';
import 'package:fleur/utils/link_normalizer.dart';

import '../test_utils/isar_test_utils.dart';

void main() {
  Isar? isar;
  Directory? tempDir;

  setUpAll(() async {
    await ensureIsarCoreInitialized();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'fleur_article_repository_upsert_',
    );
    isar = await Isar.open(
      [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
      directory: tempDir!.path,
      name: 'article_repository_upsert_test',
    );
  });

  tearDown(() async {
    await isar?.close();
    final dir = tempDir;
    tempDir = null;
    isar = null;
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  Future<int> insertFeed({int? categoryId}) async {
    late int id;
    await isar!.writeTxn(() async {
      final feed = Feed()
        ..url = 'https://example.com/feed.xml'
        ..title = 'Example'
        ..categoryId = categoryId
        ..createdAt = DateTime.utc(2026, 1, 1)
        ..updatedAt = DateTime.utc(2026, 1, 1);
      id = await isar!.feeds.put(feed);
    });
    return id;
  }

  Future<int> insertArticle({
    required int feedId,
    required String link,
    String? remoteId,
    String? contentHtml,
    bool isRead = false,
    bool isStarred = false,
    bool isReadLater = false,
    ContentSource contentSource = ContentSource.feed,
    String? extractedContentHtml,
    ArticleContentView preferredContentView = ArticleContentView.feed,
    DateTime? publishedAt,
  }) async {
    late int id;
    await isar!.writeTxn(() async {
      final article = Article()
        ..feedId = feedId
        ..remoteId = remoteId
        ..link = link
        ..contentHtml = contentHtml
        ..contentHash = ContentHash.compute(contentHtml)
        ..isRead = isRead
        ..isStarred = isStarred
        ..isReadLater = isReadLater
        ..contentSource = contentSource
        ..extractedContentHtml = extractedContentHtml
        ..preferredContentView = preferredContentView
        ..publishedAt = publishedAt ?? DateTime.utc(2026, 1, 1)
        ..fetchedAt = DateTime.utc(2026, 1, 1)
        ..updatedAt = DateTime.utc(2026, 1, 1);
      id = await isar!.articles.put(article);
    });
    return id;
  }

  Article incomingArticle({
    required String link,
    String? remoteId,
    String? contentHtml,
    bool isRead = false,
    bool isStarred = false,
    DateTime? publishedAt,
  }) {
    return Article()
      ..feedId = -1
      ..remoteId = remoteId
      ..link = link
      ..title = 'Incoming'
      ..contentHtml = contentHtml
      ..isRead = isRead
      ..isStarred = isStarred
      ..publishedAt =
          publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  test('preserves user state when feed content is unchanged', () async {
    final feedId = await insertFeed(categoryId: 7);
    final existingId = await insertArticle(
      feedId: feedId,
      remoteId: 'item-1',
      link: 'https://example.com/articles/1',
      contentHtml: '<p>same</p>',
      isRead: true,
      isStarred: true,
      isReadLater: true,
      contentSource: ContentSource.extracted,
      extractedContentHtml: '<article>extracted</article>',
      preferredContentView: ArticleContentView.extracted,
      publishedAt: DateTime.utc(2025, 5, 1),
    );

    final newArticles = await ArticleRepository(isar!).upsertMany(feedId, [
      incomingArticle(
        remoteId: 'item-1',
        link: ' https://example.com/articles/1/?utm_source=newsletter#top ',
        contentHtml: '<p>same</p>',
        publishedAt: DateTime.utc(2025, 5, 2),
      ),
    ]);

    expect(newArticles, isEmpty);
    final stored = await isar!.articles.get(existingId);
    expect(stored, isNotNull);
    expect(stored!.isRead, isTrue);
    expect(stored.isStarred, isTrue);
    expect(stored.isReadLater, isTrue);
    expect(stored.contentHash, ContentHash.compute('<p>same</p>'));
    expect(stored.contentSource, ContentSource.extracted);
    expect(stored.extractedContentHtml, '<article>extracted</article>');
    expect(stored.preferredContentView, ArticleContentView.extracted);
    expect(
      stored.link,
      LinkNormalizer.normalize(
        ' https://example.com/articles/1/?utm_source=newsletter#top ',
      ),
    );
    expect(stored.categoryId, 7);
  });

  test('marks article unread when feed content changes', () async {
    final feedId = await insertFeed();
    final existingId = await insertArticle(
      feedId: feedId,
      remoteId: 'item-2',
      link: 'https://example.com/articles/2',
      contentHtml: '<p>old</p>',
      isRead: true,
      isStarred: true,
      isReadLater: true,
      contentSource: ContentSource.extracted,
      extractedContentHtml: '<article>old extracted</article>',
      preferredContentView: ArticleContentView.extracted,
    );

    await ArticleRepository(isar!).upsertMany(feedId, [
      incomingArticle(
        remoteId: 'item-2',
        link: 'https://example.com/articles/2',
        contentHtml: '<p>new</p>',
        publishedAt: DateTime.utc(2025, 5, 2),
      ),
    ]);

    final stored = await isar!.articles.get(existingId);
    expect(stored, isNotNull);
    expect(stored!.isRead, isFalse);
    expect(stored.isStarred, isTrue);
    expect(stored.isReadLater, isTrue);
    expect(stored.contentHash, ContentHash.compute('<p>new</p>'));
    expect(stored.contentHtml, '<p>new</p>');
    expect(stored.extractedContentHtml, '<article>old extracted</article>');
    expect(stored.preferredContentView, ArticleContentView.extracted);
  });

  test(
    'remote-authoritative sync clears stale hash but keeps client fields',
    () async {
      final feedId = await insertFeed();
      final existingId = await insertArticle(
        feedId: feedId,
        remoteId: 'item-3',
        link: 'https://example.com/articles/3',
        contentHtml: '<p>old</p>',
        isRead: true,
        isStarred: true,
        isReadLater: true,
        contentSource: ContentSource.extracted,
        extractedContentHtml: '<article>old extracted</article>',
        preferredContentView: ArticleContentView.extracted,
      );

      await ArticleRepository(isar!).upsertMany(feedId, [
        incomingArticle(
          remoteId: 'item-3',
          link: 'https://example.com/articles/3',
          contentHtml: '<p>remote</p>',
          isRead: false,
          isStarred: false,
          publishedAt: DateTime.utc(2025, 5, 3),
        ),
      ], preserveUserState: false);

      final stored = await isar!.articles.get(existingId);
      expect(stored, isNotNull);
      expect(stored!.contentHash, isNull);
      expect(stored.isRead, isFalse);
      expect(stored.isStarred, isFalse);
      expect(stored.isReadLater, isTrue);
      expect(stored.contentSource, ContentSource.extracted);
      expect(stored.extractedContentHtml, '<article>old extracted</article>');
      expect(stored.preferredContentView, ArticleContentView.extracted);
    },
  );

  test('matches by remote id before link when incoming link changes', () async {
    final feedId = await insertFeed();
    final existingId = await insertArticle(
      feedId: feedId,
      remoteId: 'stable-guid',
      link: 'https://example.com/old-link',
      contentHtml: '<p>same</p>',
      isRead: true,
    );

    final newArticles = await ArticleRepository(isar!).upsertMany(feedId, [
      incomingArticle(
        remoteId: 'stable-guid',
        link: 'https://example.com/new-link',
        contentHtml: '<p>same</p>',
        publishedAt: DateTime.utc(2025, 5, 4),
      ),
    ]);

    final allArticles = await isar!.articles.where().findAll();
    final stored = await isar!.articles.get(existingId);
    expect(newArticles, isEmpty);
    expect(allArticles, hasLength(1));
    expect(stored, isNotNull);
    expect(
      stored!.link,
      LinkNormalizer.normalize('https://example.com/new-link'),
    );
  });

  test('matches existing legacy links with empty fragments', () async {
    final feedId = await insertFeed();
    final existingId = await insertArticle(
      feedId: feedId,
      link: 'https://example.com/articles/legacy#',
      contentHtml: '<p>same</p>',
      isRead: true,
    );

    final newArticles = await ArticleRepository(isar!).upsertMany(feedId, [
      incomingArticle(
        link: 'https://example.com/articles/legacy',
        contentHtml: '<p>same</p>',
        publishedAt: DateTime.utc(2025, 5, 5),
      ),
    ]);

    final allArticles = await isar!.articles.where().findAll();
    final stored = await isar!.articles.get(existingId);
    expect(newArticles, isEmpty);
    expect(allArticles, hasLength(1));
    expect(stored, isNotNull);
    expect(stored!.link, 'https://example.com/articles/legacy');
    expect(stored.isRead, isTrue);
  });

  test('matches existing legacy links with tracking params', () async {
    final feedId = await insertFeed();
    final existingId = await insertArticle(
      feedId: feedId,
      link: 'https://example.com/articles/legacy-tracking/?utm_source=rss#',
      contentHtml: '<p>same</p>',
      isRead: true,
    );

    final newArticles = await ArticleRepository(isar!).upsertMany(feedId, [
      incomingArticle(
        link:
            ' https://example.com/articles/legacy-tracking/?utm_source=rss#top ',
        contentHtml: '<p>same</p>',
        publishedAt: DateTime.utc(2025, 5, 6),
      ),
    ]);

    final allArticles = await isar!.articles.where().findAll();
    final stored = await isar!.articles.get(existingId);
    expect(newArticles, isEmpty);
    expect(allArticles, hasLength(1));
    expect(stored, isNotNull);
    expect(stored!.link, 'https://example.com/articles/legacy-tracking');
    expect(stored.isRead, isTrue);
  });

  test('falls back publishedAt for existing and new articles', () async {
    final feedId = await insertFeed();
    final existingPublishedAt = DateTime.utc(2025, 1, 1);
    final existingId = await insertArticle(
      feedId: feedId,
      remoteId: 'item-4',
      link: 'https://example.com/articles/4',
      contentHtml: '<p>existing</p>',
      publishedAt: existingPublishedAt,
    );

    final newArticles = await ArticleRepository(isar!).upsertMany(feedId, [
      incomingArticle(
        remoteId: 'item-4',
        link: 'https://example.com/articles/4',
        contentHtml: '<p>existing</p>',
      ),
      incomingArticle(
        remoteId: 'item-5',
        link: 'https://example.com/articles/5',
        contentHtml: '<p>new</p>',
      ),
    ]);

    final existing = await isar!.articles.get(existingId);
    final created = await isar!.articles.get(newArticles.single.id);
    expect(existing!.publishedAt.isAtSameMomentAs(existingPublishedAt), isTrue);
    expect(created!.publishedAt.millisecondsSinceEpoch, isNot(0));
  });
}
