import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/repositories/feed_repository.dart';
import 'package:fleur/repositories/remote_mirror_upsert_result.dart';

import '../test_utils/isar_test_utils.dart';

class _CountingFeedRepository extends FeedRepository {
  _CountingFeedRepository(super.isar);

  int getAllCalls = 0;

  @override
  Future<List<Feed>> getAll() {
    getAllCalls += 1;
    return super.getAll();
  }
}

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

      final result = await repo.upsertRemoteDetailed(
        remoteId: '91',
        url: 'https://example.com/feed.xml',
        title: 'Remote Feed',
        preferredLocalFeedId: 1,
      );

      final feeds = await isar!.feeds.where().findAll();
      final original = await isar!.feeds.get(1);
      final remote = await repo.getByRemoteId('91');

      expect(result.localId, 1);
      expect(result.status, RemoteMirrorUpsertStatus.identityConflict);
      expect(result.effectiveRemoteId, '77');
      expect(feeds, hasLength(1));
      expect(original?.remoteId, '77');
      expect(original?.title, 'Feed');
      expect(remote, isNull);
    },
  );

  test(
    'upsertRemote does not bind exact url with different remote id',
    () async {
      final repo = FeedRepository(isar!);
      await seedCategorizedFeed(remoteId: '77');

      final result = await repo.upsertRemoteDetailed(
        remoteId: '91',
        url: 'https://example.com/feed.xml',
        title: 'Remote Feed',
      );

      final feeds = await isar!.feeds.where().findAll();
      final original = await isar!.feeds.get(1);
      final remote = await repo.getByRemoteId('91');

      expect(result.localId, 1);
      expect(result.status, RemoteMirrorUpsertStatus.identityConflict);
      expect(result.effectiveRemoteId, '77');
      expect(feeds, hasLength(1));
      expect(original?.remoteId, '77');
      expect(original?.title, 'Feed');
      expect(remote, isNull);
    },
  );

  test(
    'upsertRemote preserves target url when new url belongs to remote feed',
    () async {
      final repo = FeedRepository(isar!);
      final now = DateTime.utc(2026, 3, 1, 10);
      await isar!.writeTxn(() async {
        await isar!.feeds.putAll([
          Feed()
            ..id = 1
            ..remoteId = '91'
            ..url = 'https://example.com/old.xml'
            ..title = 'Target'
            ..createdAt = now
            ..updatedAt = now,
          Feed()
            ..id = 2
            ..remoteId = '77'
            ..url = 'https://example.com/feed.xml/'
            ..title = 'Other'
            ..createdAt = now
            ..updatedAt = now,
        ]);
      });

      final result = await repo.upsertRemoteDetailed(
        remoteId: '91',
        url: 'https://example.com/feed.xml',
        title: 'Updated Target',
      );

      final target = await isar!.feeds.get(1);
      final other = await isar!.feeds.get(2);

      expect(result.status, RemoteMirrorUpsertStatus.bound);
      expect(result.localId, 1);
      expect(target?.remoteId, '91');
      expect(target?.url, 'https://example.com/old.xml');
      expect(target?.title, 'Updated Target');
      expect(other?.remoteId, '77');
      expect(other?.url, 'https://example.com/feed.xml/');
    },
  );

  test('upsertRemote keeps article-bearing duplicate feed', () async {
    final repo = FeedRepository(isar!);
    final now = DateTime.utc(2026, 3, 1, 10);
    await isar!.writeTxn(() async {
      await isar!.feeds.putAll([
        Feed()
          ..id = 1
          ..remoteId = '91'
          ..url = 'https://example.com/old.xml'
          ..title = 'Target'
          ..createdAt = now
          ..updatedAt = now,
        Feed()
          ..id = 2
          ..url = 'https://example.com/feed.xml'
          ..title = 'Duplicate'
          ..createdAt = now
          ..updatedAt = now,
      ]);
      await isar!.articles.put(
        Article()
          ..feedId = 2
          ..link = 'https://example.com/articles/duplicate'
          ..title = 'Duplicate Article'
          ..publishedAt = now
          ..fetchedAt = now
          ..updatedAt = now,
      );
    });

    final result = await repo.upsertRemoteDetailed(
      remoteId: '91',
      url: 'https://example.com/feed.xml',
      title: 'Updated Target',
    );

    final feeds = await isar!.feeds.where().findAll();
    final target = await isar!.feeds.get(1);
    final duplicate = await isar!.feeds.get(2);
    final articles = await isar!.articles.where().findAll();

    expect(result.status, RemoteMirrorUpsertStatus.bound);
    expect(feeds, hasLength(2));
    expect(target?.url, 'https://example.com/old.xml');
    expect(duplicate?.url, 'https://example.com/feed.xml');
    expect(articles, hasLength(1));
    expect(articles.single.feedId, 2);
  });

  test('upsertRemote deletes empty unbound duplicate feed', () async {
    final repo = FeedRepository(isar!);
    final now = DateTime.utc(2026, 3, 1, 10);
    await isar!.writeTxn(() async {
      await isar!.feeds.putAll([
        Feed()
          ..id = 1
          ..remoteId = '91'
          ..url = 'https://example.com/old.xml'
          ..title = 'Target'
          ..createdAt = now
          ..updatedAt = now,
        Feed()
          ..id = 2
          ..url = 'https://example.com/feed.xml'
          ..title = 'Duplicate'
          ..createdAt = now
          ..updatedAt = now,
      ]);
    });

    final result = await repo.upsertRemoteDetailed(
      remoteId: '91',
      url: 'https://example.com/feed.xml',
      title: 'Updated Target',
    );

    final feeds = await isar!.feeds.where().findAll();
    final target = await isar!.feeds.get(1);
    final duplicate = await isar!.feeds.get(2);

    expect(result.status, RemoteMirrorUpsertStatus.bound);
    expect(feeds, hasLength(1));
    expect(target?.url, 'https://example.com/feed.xml');
    expect(target?.title, 'Updated Target');
    expect(duplicate, isNull);
  });

  test(
    'indexed upsertRemote binds equivalent url to preferred local feed',
    () async {
      final repo = FeedRepository(isar!);
      await seedCategorizedFeed(url: 'https://example.com/feed.xml/');
      final index = await repo.createRemoteMirrorIndex();

      final id = await repo.upsertRemote(
        remoteId: '91',
        url: 'https://example.com/feed.xml',
        title: 'Remote Feed',
        preferredLocalFeedId: 1,
        lookupIndex: index,
      );

      final feeds = await isar!.feeds.where().findAll();
      final feed = await isar!.feeds.get(1);

      expect(id, 1);
      expect(feeds, hasLength(1));
      expect(feed?.remoteId, '91');
      expect(feed?.url, 'https://example.com/feed.xml');
      expect(feed?.title, 'Remote Feed');
    },
  );

  test(
    'indexed upsertRemote does not bind exact url with different remote id',
    () async {
      final repo = FeedRepository(isar!);
      await seedCategorizedFeed(remoteId: '77');
      final index = await repo.createRemoteMirrorIndex();

      final result = await repo.upsertRemoteDetailed(
        remoteId: '91',
        url: 'https://example.com/feed.xml',
        title: 'Remote Feed',
        lookupIndex: index,
      );

      final feeds = await isar!.feeds.where().findAll();
      final original = await isar!.feeds.get(1);
      final remote = await repo.getByRemoteId('91');

      expect(result.localId, 1);
      expect(result.status, RemoteMirrorUpsertStatus.identityConflict);
      expect(result.effectiveRemoteId, '77');
      expect(feeds, hasLength(1));
      expect(original?.remoteId, '77');
      expect(original?.title, 'Feed');
      expect(remote, isNull);
    },
  );

  test('indexed upsertRemote keeps article-bearing duplicate feed', () async {
    final repo = FeedRepository(isar!);
    final now = DateTime.utc(2026, 3, 1, 10);
    await isar!.writeTxn(() async {
      await isar!.feeds.putAll([
        Feed()
          ..id = 1
          ..remoteId = '91'
          ..url = 'https://example.com/old.xml'
          ..title = 'Target'
          ..createdAt = now
          ..updatedAt = now,
        Feed()
          ..id = 2
          ..url = 'https://example.com/feed.xml'
          ..title = 'Duplicate'
          ..createdAt = now
          ..updatedAt = now,
      ]);
      await isar!.articles.put(
        Article()
          ..feedId = 2
          ..link = 'https://example.com/articles/duplicate'
          ..title = 'Duplicate Article'
          ..publishedAt = now
          ..fetchedAt = now
          ..updatedAt = now,
      );
    });
    final index = await repo.createRemoteMirrorIndex();

    final result = await repo.upsertRemoteDetailed(
      remoteId: '91',
      url: 'https://example.com/feed.xml',
      title: 'Updated Target',
      lookupIndex: index,
    );

    final feeds = await isar!.feeds.where().findAll();
    final target = await isar!.feeds.get(1);
    final duplicate = await isar!.feeds.get(2);
    final articles = await isar!.articles.where().findAll();

    expect(result.status, RemoteMirrorUpsertStatus.bound);
    expect(feeds, hasLength(2));
    expect(target?.url, 'https://example.com/old.xml');
    expect(duplicate?.url, 'https://example.com/feed.xml');
    expect(articles, hasLength(1));
    expect(articles.single.feedId, 2);
  });

  test('indexed upsertRemote deletes empty unbound duplicate feed', () async {
    final repo = FeedRepository(isar!);
    final now = DateTime.utc(2026, 3, 1, 10);
    await isar!.writeTxn(() async {
      await isar!.feeds.putAll([
        Feed()
          ..id = 1
          ..remoteId = '91'
          ..url = 'https://example.com/old.xml'
          ..title = 'Target'
          ..createdAt = now
          ..updatedAt = now,
        Feed()
          ..id = 2
          ..url = 'https://example.com/feed.xml'
          ..title = 'Duplicate'
          ..createdAt = now
          ..updatedAt = now,
      ]);
    });
    final index = await repo.createRemoteMirrorIndex();

    final result = await repo.upsertRemoteDetailed(
      remoteId: '91',
      url: 'https://example.com/feed.xml',
      title: 'Updated Target',
      lookupIndex: index,
    );

    final feeds = await isar!.feeds.where().findAll();
    final target = await isar!.feeds.get(1);
    final duplicate = await isar!.feeds.get(2);

    expect(result.status, RemoteMirrorUpsertStatus.bound);
    expect(feeds, hasLength(1));
    expect(target?.url, 'https://example.com/feed.xml');
    expect(target?.title, 'Updated Target');
    expect(duplicate, isNull);
  });

  test('indexed upsertRemote does not reread all feeds per upsert', () async {
    final repo = _CountingFeedRepository(isar!);
    await seedCategorizedFeed(url: 'https://example.com/feed.xml/');
    final index = await repo.createRemoteMirrorIndex();

    expect(repo.getAllCalls, 1);

    await repo.upsertRemoteDetailed(
      remoteId: '91',
      url: 'https://example.com/feed.xml',
      title: 'Remote Feed',
      lookupIndex: index,
    );
    await repo.upsertRemoteDetailed(
      remoteId: '92',
      url: 'https://example.com/second.xml',
      title: 'Second Feed',
      lookupIndex: index,
    );

    expect(repo.getAllCalls, 1);
    expect(await repo.getByRemoteId('91'), isNotNull);
    expect(await repo.getByRemoteId('92'), isNotNull);
  });

  test('deleteRemoteMissing keeps protected remote feeds', () async {
    final repo = FeedRepository(isar!);
    final now = DateTime.utc(2026, 3, 1, 10);
    await isar!.writeTxn(() async {
      await isar!.feeds.putAll([
        Feed()
          ..id = 1
          ..remoteId = '10'
          ..url = 'https://example.com/kept.xml'
          ..title = 'Protected'
          ..createdAt = now
          ..updatedAt = now,
        Feed()
          ..id = 2
          ..remoteId = '20'
          ..url = 'https://example.com/seen.xml'
          ..title = 'Seen'
          ..createdAt = now
          ..updatedAt = now,
      ]);
    });

    await repo.deleteRemoteMissing({'20'}, protectedRemoteIds: {'10'});

    expect(await repo.getByRemoteId('10'), isNotNull);
    expect(await repo.getByRemoteId('20'), isNotNull);
  });

  test(
    'deleteRemoteMissing does not prune empty seen with protected feeds by default',
    () async {
      final repo = FeedRepository(isar!);
      final now = DateTime.utc(2026, 3, 1, 10);
      await isar!.writeTxn(() async {
        await isar!.feeds.putAll([
          Feed()
            ..id = 1
            ..remoteId = '10'
            ..url = 'https://example.com/protected.xml'
            ..title = 'Protected'
            ..createdAt = now
            ..updatedAt = now,
          Feed()
            ..id = 2
            ..remoteId = '20'
            ..url = 'https://example.com/missing.xml'
            ..title = 'Missing'
            ..createdAt = now
            ..updatedAt = now,
        ]);
      });

      await repo.deleteRemoteMissing({}, protectedRemoteIds: {'10'});

      expect(await repo.getByRemoteId('10'), isNotNull);
      expect(await repo.getByRemoteId('20'), isNotNull);
    },
  );

  test(
    'deleteRemoteMissing prunes unprotected feeds when empty prune is explicit',
    () async {
      final repo = FeedRepository(isar!);
      final now = DateTime.utc(2026, 3, 1, 10);
      await isar!.writeTxn(() async {
        await isar!.feeds.putAll([
          Feed()
            ..id = 1
            ..remoteId = '10'
            ..url = 'https://example.com/protected.xml'
            ..title = 'Protected'
            ..createdAt = now
            ..updatedAt = now,
          Feed()
            ..id = 2
            ..remoteId = '20'
            ..url = 'https://example.com/missing.xml'
            ..title = 'Missing'
            ..createdAt = now
            ..updatedAt = now,
        ]);
      });

      await repo.deleteRemoteMissing(
        {},
        allowEmptyPrune: true,
        protectedRemoteIds: {'10'},
      );

      expect(await repo.getByRemoteId('10'), isNotNull);
      expect(await repo.getByRemoteId('20'), isNull);
    },
  );
}
