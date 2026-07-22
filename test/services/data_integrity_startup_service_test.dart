import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/services/data_integrity_startup_service.dart';

import '../test_utils/isar_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Isar? isar;
  Directory? tempDir;

  setUpAll(ensureIsarCoreInitialized);

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('fleur_integrity_startup_');
    isar = await Isar.open(
      [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
      directory: tempDir!.path,
      name: 'integrity_startup_test',
    );
  });

  tearDown(() async {
    final db = isar;
    isar = null;
    if (db != null && db.isOpen) await db.close();
    final dir = tempDir;
    tempDir = null;
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  test(
    'records the throttle timestamp only after successful maintenance',
    () async {
      final db = isar!;
      final feed = Feed()
        ..id = 1
        ..url = 'https://example.com/feed.xml'
        ..categoryId = 7;
      final article = Article()
        ..id = 1
        ..feedId = feed.id
        ..link = 'https://example.com/article'
        ..categoryId = 3;
      await db.writeTxn(() async {
        await db.feeds.put(feed);
        await db.articles.put(article);
      });

      await const DataIntegrityStartupService().runIfNeeded(db);

      final repaired = await db.articles.get(article.id);
      final prefs = await SharedPreferences.getInstance();
      expect(repaired?.categoryId, feed.categoryId);
      expect(prefs.getInt('integrity:last_run:${db.name}'), isNotNull);
    },
  );

  test(
    'does not throttle a maintenance run that used a closed database',
    () async {
      final db = isar!;
      final name = db.name;
      await db.close();

      await const DataIntegrityStartupService().runIfNeeded(db);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('integrity:last_run:$name'), isNull);
    },
  );
}
