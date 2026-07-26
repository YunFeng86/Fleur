import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/repositories/tag_repository.dart';
import 'package:fleur/utils/tag_colors.dart';

import '../test_utils/isar_test_utils.dart';

void main() {
  Isar? isar;
  Directory? tempDir;

  setUpAll(() async {
    await ensureIsarCoreInitialized();
    tempDir = await Directory.systemTemp.createTemp('isar_tag_repo_');
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

  Future<Article> seedArticleWithTag(Tag tag, {required String link}) async {
    final now = DateTime.now();
    final article = Article()
      ..feedId = 1
      ..link = link
      ..publishedAt = now.toUtc()
      ..fetchedAt = now
      ..updatedAt = now;
    await isar!.writeTxn(() async {
      await isar!.articles.put(article);
      article.tags.add(tag);
      await article.tags.save();
    });
    return article;
  }

  test('create() trims name and assigns a normalized color', () async {
    final repo = TagRepository(isar!);

    final tag = await repo.create('  Reading  ', color: 'ff00aa');

    expect(tag.name, 'Reading');
    expect(tag.color, '#FF00AA');
    expect(await isar!.tags.get(tag.id), isNotNull);
  });

  test('create() falls back to palette color for invalid input', () async {
    final repo = TagRepository(isar!);

    final tag = await repo.create('Tech', color: 'not-a-color');

    expect(tag.color, pickTagColorForName('Tech'));
  });

  test('create() rejects empty names', () async {
    final repo = TagRepository(isar!);

    expect(() => repo.create('   '), throwsArgumentError);
    expect(await repo.getAll(), isEmpty);
  });

  test('create() reuses existing tag case-insensitively', () async {
    final repo = TagRepository(isar!);

    final first = await repo.create('Reading');
    final second = await repo.create('reading');

    expect(second.id, first.id);
    expect(await isar!.tags.where().findAll(), hasLength(1));
  });

  test('getAll() sorts tags by name', () async {
    final repo = TagRepository(isar!);

    await repo.create('Zeta');
    await repo.create('Alpha');
    await repo.create('Mid');

    final names = (await repo.getAll()).map((t) => t.name).toList();
    expect(names, ['Alpha', 'Mid', 'Zeta']);
  });

  test('watchAll() emits current tags and updates', () async {
    final repo = TagRepository(isar!);
    await repo.create('First');

    final events = <List<String>>[];
    final sub = repo.watchAll().listen(
      (tags) => events.add(tags.map((t) => t.name).toList()),
    );
    addTearDown(sub.cancel);

    await pumpEventQueue();
    expect(events.last, ['First']);

    await repo.create('Second');
    await pumpEventQueue();
    expect(events.last, ['First', 'Second']);
  });

  test('delete() removes tag and unlinks it from articles', () async {
    final repo = TagRepository(isar!);
    final keep = await repo.create('Keep');
    final drop = await repo.create('Drop');

    final tagged = await seedArticleWithTag(drop, link: 'https://e.com/a1');
    await isar!.writeTxn(() async {
      tagged.tags.add(keep);
      await tagged.tags.save();
    });
    final untouched = await seedArticleWithTag(keep, link: 'https://e.com/a2');

    await repo.delete(drop.id);

    expect(await isar!.tags.get(drop.id), isNull);
    expect(await isar!.tags.get(keep.id), isNotNull);

    final reloadedTagged = await isar!.articles.get(tagged.id);
    await reloadedTagged!.tags.load();
    expect(reloadedTagged.tags.map((t) => t.id), [keep.id]);

    final reloadedUntouched = await isar!.articles.get(untouched.id);
    await reloadedUntouched!.tags.load();
    expect(reloadedUntouched.tags.map((t) => t.id), [keep.id]);
  });

  test('delete() unlinks tag across batches of articles', () async {
    final repo = TagRepository(isar!);
    final tag = await repo.create('Bulk');

    // Exceeds the repository's 200-article unlink batch size.
    const total = 250;
    for (var i = 0; i < total; i += 1) {
      await seedArticleWithTag(tag, link: 'https://e.com/bulk-$i');
    }

    await repo.delete(tag.id);

    expect(await isar!.tags.get(tag.id), isNull);
    final stillLinked = await isar!.articles
        .filter()
        .tags((t) => t.idEqualTo(tag.id))
        .count();
    expect(stillLinked, 0);
  });

  test('delete() is a no-op for unknown ids', () async {
    final repo = TagRepository(isar!);
    final tag = await repo.create('Stays');

    await repo.delete(9999);

    expect(await isar!.tags.get(tag.id), isNotNull);
  });
}
