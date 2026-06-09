import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/providers/core_providers.dart';
import 'package:fleur/providers/query_providers.dart';
import 'package:fleur/repositories/article_repository.dart';

import '../test_utils/isar_test_utils.dart';

void main() {
  Isar? isar;
  Directory? tempDir;

  setUpAll(() async {
    await ensureIsarCoreInitialized();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'article_provider_watcher_',
    );
    isar = await Isar.open(
      [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
      directory: tempDir!.path,
      name: 'article_provider_watcher_diagnostic',
    );
    await _seedArticles(isar!, count: 500);
  });

  tearDown(() async {
    await isar?.close();
    final dir = tempDir;
    isar = null;
    tempDir = null;
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  test(
    'diagnoses articleProvider watcher fan-out during bulk mark-read',
    () async {
      final container = ProviderContainer(
        overrides: [isarProvider.overrideWithValue(isar!)],
      );
      addTearDown(container.dispose);

      var providerUpdates = 0;
      final subscriptions = <ProviderSubscription<AsyncValue<Article?>>>[
        for (var id = 1; id <= 500; id++)
          container.listen<AsyncValue<Article?>>(articleProvider(id), (
            _,
            next,
          ) {
            if (next.hasValue) providerUpdates++;
          }, fireImmediately: true),
      ];
      addTearDown(() {
        for (final subscription in subscriptions) {
          subscription.close();
        }
      });

      await Future<void>.delayed(const Duration(milliseconds: 100));
      providerUpdates = 0;

      final markStopwatch = Stopwatch()..start();
      final marked = await ArticleRepository(isar!).markAllRead();
      markStopwatch.stop();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final frameElapsedMicros = await _recordDiagnosticFrameMicros();

      stdout.writeln(
        'articleProvider watcher diagnostic: '
        'window=500 marked=$marked providerUpdates=$providerUpdates '
        'markElapsedMicros=${markStopwatch.elapsedMicroseconds} '
        'frameElapsedMicros=$frameElapsedMicros',
      );

      expect(marked, 500);
      expect(providerUpdates, greaterThan(0));
      expect(markStopwatch.elapsedMicroseconds, greaterThan(0));
      expect(frameElapsedMicros, greaterThanOrEqualTo(0));
    },
  );
}

Future<int> _recordDiagnosticFrameMicros() async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final stopwatch = Stopwatch()..start();
  binding.scheduleFrame();
  await binding.endOfFrame.timeout(
    const Duration(milliseconds: 100),
    onTimeout: () {},
  );
  stopwatch.stop();
  return stopwatch.elapsedMicroseconds;
}

Future<void> _seedArticles(Isar isar, {required int count}) async {
  final now = DateTime.utc(2026, 1, 1);
  await isar.writeTxn(() async {
    await isar.articles.putAll([
      for (var i = 0; i < count; i++)
        Article()
          ..id = i + 1
          ..feedId = 1
          ..categoryId = 1
          ..link = 'https://example.com/articles/$i'
          ..title = 'Article $i'
          ..contentHtml = '<p>Article $i</p>'
          ..publishedAt = now.add(Duration(minutes: i))
          ..updatedAt = now
          ..isRead = false,
    ]);
  });
}
