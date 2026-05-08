import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/repositories/category_repository.dart';
import 'package:fleur/repositories/remote_mirror_upsert_result.dart';

import '../test_utils/isar_test_utils.dart';

void main() {
  Isar? isar;
  Directory? tempDir;

  setUpAll(() async {
    await ensureIsarCoreInitialized();
    tempDir = await Directory.systemTemp.createTemp('isar_category_repo_');
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

  test('delete() unassigns feeds and updates Article.categoryId', () async {
    final now = DateTime.now();
    final repo = CategoryRepository(isar!);

    await isar!.writeTxn(() async {
      final category = Category()
        ..id = 1
        ..name = 'Cat 1'
        ..createdAt = now
        ..updatedAt = now;
      await isar!.categorys.put(category);

      final feed = Feed()
        ..id = 1
        ..url = 'https://example.com/feed.xml'
        ..title = 'Feed 1'
        ..categoryId = 1
        ..createdAt = now
        ..updatedAt = now;
      await isar!.feeds.put(feed);

      final a1 = Article()
        ..feedId = 1
        ..categoryId = 1
        ..link = 'https://example.com/a1'
        ..publishedAt = now.toUtc()
        ..fetchedAt = now
        ..updatedAt = now;
      final a2 = Article()
        ..feedId = 1
        ..categoryId = 1
        ..link = 'https://example.com/a2'
        ..publishedAt = now.toUtc()
        ..fetchedAt = now
        ..updatedAt = now;
      await isar!.articles.putAll([a1, a2]);
    });

    await repo.delete(1);

    expect(await isar!.categorys.get(1), isNull);

    final feed = await isar!.feeds.get(1);
    expect(feed, isNotNull);
    expect(feed!.categoryId, isNull);

    final articles = await isar!.articles.filter().feedIdEqualTo(1).findAll();
    expect(articles, isNotEmpty);
    expect(articles.every((a) => a.categoryId == null), isTrue);
  });

  test('deleteRemoteMissing skips empty seen list by default', () async {
    final now = DateTime.now();
    final repo = CategoryRepository(isar!);

    await isar!.writeTxn(() async {
      await isar!.categorys.put(
        Category()
          ..id = 1
          ..remoteId = '10'
          ..name = 'Remote Cat'
          ..createdAt = now
          ..updatedAt = now,
      );
    });

    await repo.deleteRemoteMissing({});

    final category = await isar!.categorys.get(1);
    expect(category, isNotNull);
    expect(category?.remoteId, '10');
  });

  test('deleteRemoteMissing still prunes missing remote categories', () async {
    final now = DateTime.now();
    final repo = CategoryRepository(isar!);

    await isar!.writeTxn(() async {
      await isar!.categorys.putAll([
        Category()
          ..id = 1
          ..remoteId = '10'
          ..name = 'Kept Cat'
          ..createdAt = now
          ..updatedAt = now,
        Category()
          ..id = 2
          ..remoteId = '20'
          ..name = 'Removed Cat'
          ..createdAt = now
          ..updatedAt = now,
      ]);
    });

    await repo.deleteRemoteMissing({'10'});

    expect(await isar!.categorys.get(1), isNotNull);
    expect(await isar!.categorys.get(2), isNull);
  });

  test(
    'upsertRemoteDetailed binds same-name category without remote id',
    () async {
      final now = DateTime.now();
      final repo = CategoryRepository(isar!);

      await isar!.writeTxn(() async {
        await isar!.categorys.put(
          Category()
            ..id = 1
            ..name = 'Tech'
            ..createdAt = now
            ..updatedAt = now,
        );
      });

      final result = await repo.upsertRemoteDetailed(
        remoteId: '10',
        name: 'Tech',
      );

      final category = await isar!.categorys.get(1);
      expect(result.status, RemoteMirrorUpsertStatus.bound);
      expect(result.localId, 1);
      expect(category?.remoteId, '10');
      expect(category?.name, 'Tech');
    },
  );

  test(
    'upsertRemoteDetailed does not rebind same-name remote category',
    () async {
      final now = DateTime.now();
      final repo = CategoryRepository(isar!);

      await isar!.writeTxn(() async {
        await isar!.categorys.put(
          Category()
            ..id = 1
            ..remoteId = '10'
            ..name = 'Tech'
            ..createdAt = now
            ..updatedAt = now,
        );
      });

      final result = await repo.upsertRemoteDetailed(
        remoteId: '20',
        name: 'Tech',
      );

      final categories = await isar!.categorys.where().findAll();
      final original = await isar!.categorys.get(1);
      final remote = await repo.getByRemoteId('20');

      expect(result.status, RemoteMirrorUpsertStatus.identityConflict);
      expect(result.localId, 1);
      expect(result.effectiveRemoteId, '10');
      expect(categories, hasLength(1));
      expect(original?.remoteId, '10');
      expect(original?.name, 'Tech');
      expect(remote, isNull);
    },
  );

  test(
    'upsertRemoteDetailed preserves name when remote rename conflicts',
    () async {
      final now = DateTime.now();
      final repo = CategoryRepository(isar!);

      await isar!.writeTxn(() async {
        await isar!.categorys.putAll([
          Category()
            ..id = 1
            ..remoteId = '10'
            ..name = 'Tech'
            ..createdAt = now
            ..updatedAt = now,
          Category()
            ..id = 2
            ..remoteId = '20'
            ..name = 'Science'
            ..createdAt = now
            ..updatedAt = now,
        ]);
      });

      final result = await repo.upsertRemoteDetailed(
        remoteId: '10',
        name: 'Science',
      );

      final target = await isar!.categorys.get(1);
      final conflicting = await isar!.categorys.get(2);

      expect(result.status, RemoteMirrorUpsertStatus.bound);
      expect(result.localId, 1);
      expect(target?.remoteId, '10');
      expect(target?.name, 'Tech');
      expect(conflicting?.remoteId, '20');
      expect(conflicting?.name, 'Science');
    },
  );

  test('deleteRemoteMissing keeps protected remote categories', () async {
    final now = DateTime.now();
    final repo = CategoryRepository(isar!);

    await isar!.writeTxn(() async {
      await isar!.categorys.putAll([
        Category()
          ..id = 1
          ..remoteId = '10'
          ..name = 'Protected Cat'
          ..createdAt = now
          ..updatedAt = now,
        Category()
          ..id = 2
          ..remoteId = '20'
          ..name = 'Seen Cat'
          ..createdAt = now
          ..updatedAt = now,
      ]);
    });

    await repo.deleteRemoteMissing({'20'}, protectedRemoteIds: {'10'});

    expect(await repo.getByRemoteId('10'), isNotNull);
    expect(await repo.getByRemoteId('20'), isNotNull);
  });
}
