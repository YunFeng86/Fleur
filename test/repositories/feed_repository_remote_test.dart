import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/repositories/feed_repository.dart';

import '../test_utils/isar_test_utils.dart';

void main() {
  Isar? isar;
  Directory? tempDir;

  setUpAll(() async {
    await ensureIsarCoreInitialized();
    tempDir = await Directory.systemTemp.createTemp('isar_feed_repo_remote_');
    isar = await Isar.open([
      FeedSchema,
      ArticleSchema,
      CategorySchema,
      TagSchema,
    ], directory: tempDir!.path);
  });

  tearDownAll(() async {
    await isar?.close();
    await tempDir?.delete(recursive: true);
  });

  setUp(() async {
    await isar!.writeTxn(() async {
      await isar!.articles.clear();
      await isar!.feeds.clear();
      await isar!.categorys.clear();
      await isar!.tags.clear();
    });
  });

  Future<void> seedCategorizedFeed({
    String url = 'https://example.com/feed.xml',
    String? remoteId,
  }) async {
    final now = DateTime.utc(2026, 3, 1, 10);
    await isar!.writeTxn(() async {
      await isar!.categorys.put(
        Category()
          ..id = 1
          ..name = 'Category'
          ..createdAt = now
          ..updatedAt = now,
      );
      await isar!.feeds.put(
        Feed()
          ..id = 1
          ..remoteId = remoteId
          ..url = url
          ..title = 'Feed'
          ..categoryId = 1
          ..createdAt = now
          ..updatedAt = now,
      );
      await isar!.articles.put(
        Article()
          ..feedId = 1
          ..categoryId = 1
          ..link = 'https://example.com/articles/1'
          ..title = 'Article'
          ..publishedAt = now
          ..fetchedAt = now
          ..updatedAt = now,
      );
    });
  }

  test('upsertRemote can update metadata while preserving category', () async {
    final repo = FeedRepository(isar!);
    await seedCategorizedFeed();

    final id = await repo.upsertRemote(
      remoteId: '10',
      url: 'https://example.com/feed.xml',
      title: 'Remote Feed',
      siteUrl: 'https://example.com',
      categoryId: null,
      updateCategory: false,
    );

    final feed = await isar!.feeds.get(id);
    final article = await isar!.articles.where().findFirst();

    expect(id, 1);
    expect(feed?.remoteId, '10');
    expect(feed?.title, 'Remote Feed');
    expect(feed?.siteUrl, 'https://example.com');
    expect(feed?.categoryId, 1);
    expect(article?.categoryId, 1);
  });

  test(
    'upsertRemote clears category when category update is explicit',
    () async {
      final repo = FeedRepository(isar!);
      await seedCategorizedFeed();

      await repo.upsertRemote(
        remoteId: '10',
        url: 'https://example.com/feed.xml',
        categoryId: null,
      );

      final feed = await isar!.feeds.get(1);
      final article = await isar!.articles.where().findFirst();

      expect(feed?.categoryId, isNull);
      expect(article?.categoryId, isNull);
    },
  );

  test('upsertRemote binds equivalent url to preferred local feed', () async {
    final repo = FeedRepository(isar!);
    await seedCategorizedFeed(url: 'https://example.com/feed.xml/');

    final id = await repo.upsertRemote(
      remoteId: '91',
      url: 'https://example.com/feed.xml',
      title: 'Remote Feed',
      preferredLocalFeedId: 1,
    );

    final feeds = await isar!.feeds.where().findAll();
    final feed = await isar!.feeds.get(1);

    expect(id, 1);
    expect(feeds, hasLength(1));
    expect(feed?.remoteId, '91');
    expect(feed?.url, 'https://example.com/feed.xml');
    expect(feed?.title, 'Remote Feed');
  });

  test(
    'upsertRemote does not bind preferred feed with different remote id',
    () async {
      final repo = FeedRepository(isar!);
      await seedCategorizedFeed(
        url: 'https://example.com/feed.xml/',
        remoteId: '77',
      );

      final id = await repo.upsertRemote(
        remoteId: '91',
        url: 'https://example.com/feed.xml',
        title: 'Remote Feed',
        preferredLocalFeedId: 1,
      );

      final feeds = await isar!.feeds.where().findAll();
      final original = await isar!.feeds.get(1);
      final remote = await repo.getByRemoteId('91');

      expect(id, isNot(1));
      expect(feeds, hasLength(2));
      expect(original?.remoteId, '77');
      expect(remote?.id, id);
      expect(remote?.title, 'Remote Feed');
    },
  );

  test(
    'upsertRemote does not bind exact url with different remote id',
    () async {
      final repo = FeedRepository(isar!);
      await seedCategorizedFeed(remoteId: '77');

      final id = await repo.upsertRemote(
        remoteId: '91',
        url: 'https://example.com/feed.xml',
        title: 'Remote Feed',
      );

      final feeds = await isar!.feeds.where().findAll();
      final original = await isar!.feeds.get(1);
      final remote = await repo.getByRemoteId('91');

      expect(id, 1);
      expect(feeds, hasLength(1));
      expect(original?.remoteId, '77');
      expect(original?.title, 'Feed');
      expect(remote, isNull);
    },
  );
}
