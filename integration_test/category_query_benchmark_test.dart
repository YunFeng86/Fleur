import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_reader/models/article.dart';
import 'package:flutter_reader/models/category.dart';
import 'package:flutter_reader/models/feed.dart';
import 'package:flutter_reader/models/tag.dart';

/// Performance benchmark test to validate the value of categoryId denormalization.
///
/// This integration test runs on a real device/emulator with native Isar libraries.
///
/// Run with: flutter test integration_test/category_query_benchmark_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Isar isar;
  late Directory tempDir;

  setUpAll(() async {
    // Create temporary directory for test database
    final appDir = await getApplicationDocumentsDirectory();
    tempDir = Directory(
      '${appDir.path}/isar_benchmark_${DateTime.now().millisecondsSinceEpoch}',
    );
    await tempDir.create(recursive: true);

    isar = await Isar.open([
      FeedSchema,
      ArticleSchema,
      CategorySchema,
      TagSchema,
    ], directory: tempDir.path);

    stdout.writeln('\n🏗️  Setting up benchmark database...');
    await _seedTestData(isar);
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('Benchmark: categoryId direct query vs feedId two-step query', (
    WidgetTester tester,
  ) async {
    const categoryId = 5;
    const iterations = 20;

    // Warmup (JIT compilation, cache warming)
    await _queryWithCategoryId(isar, categoryId);
    await _queryWithFeedIds(isar, categoryId);
    await tester.pumpAndSettle();

    // Method 1: Direct categoryId query (current implementation)
    final stopwatch1 = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await _queryWithCategoryId(isar, categoryId);
    }
    stopwatch1.stop();
    final avg1 = stopwatch1.elapsedMicroseconds / iterations;

    await tester.pump();

    // Method 2: Two-step query via feedId (alternative approach)
    final stopwatch2 = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await _queryWithFeedIds(isar, categoryId);
    }
    stopwatch2.stop();
    final avg2 = stopwatch2.elapsedMicroseconds / iterations;

    await tester.pumpAndSettle();

    // Calculate performance difference
    final speedup = ((avg2 - avg1) / avg2 * 100).toStringAsFixed(1);
    final diff = (avg2 - avg1).toStringAsFixed(0);

    stdout.writeln('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    stdout.writeln('📊 Category Query Performance Benchmark');
    stdout.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    stdout.writeln('Dataset: 50 feeds × 500 articles = 25,000 total articles');
    stdout.writeln('Category: $categoryId (contains 10 feeds)');
    stdout.writeln('Iterations: $iterations');
    stdout.writeln();
    stdout.writeln(
      'Method 1 (Direct categoryId):  ${avg1.toStringAsFixed(0)} μs/query',
    );
    stdout.writeln(
      'Method 2 (Two-step via feedId): ${avg2.toStringAsFixed(0)} μs/query',
    );
    stdout.writeln();
    stdout.writeln(
      'Result: Method 1 is $speedup% faster ($diff μs improvement)',
    );
    stdout.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    // Assert that Method 1 is faster
    expect(
      avg1,
      lessThan(avg2),
      reason: 'Direct categoryId query should be faster than two-step approach',
    );

    // Performance analysis
    final improvementRatio = avg2 / avg1;
    if (improvementRatio >= 1.3) {
      stdout.writeln(
        '✅ Performance improvement ($speedup%) justifies denormalization',
      );
      stdout.writeln(
        '   Speedup ratio: ${improvementRatio.toStringAsFixed(2)}x\n',
      );
    } else if (improvementRatio >= 1.15) {
      stdout.writeln('⚠️  Moderate improvement ($speedup%)');
      stdout.writeln(
        '   Speedup ratio: ${improvementRatio.toStringAsFixed(2)}x',
      );
      stdout.writeln(
        '   Denormalization may still be worth it for UX responsiveness\n',
      );
    } else {
      stdout.writeln('❌ Low improvement ($speedup%)');
      stdout.writeln(
        '   Speedup ratio: ${improvementRatio.toStringAsFixed(2)}x',
      );
      stdout.writeln(
        '   Consider removing denormalization - complexity cost may not justify gains\n',
      );
    }
  });
}

/// Method 1: Query articles directly by categoryId (current implementation)
Future<List<Article>> _queryWithCategoryId(Isar isar, int categoryId) async {
  return isar.articles
      .filter()
      .categoryIdEqualTo(categoryId)
      .sortByPublishedAtDesc()
      .limit(50)
      .findAll();
}

/// Method 2: Query articles via two-step process (alternative without denormalization)
Future<List<Article>> _queryWithFeedIds(Isar isar, int categoryId) async {
  // Step 1: Get feed IDs in this category
  final feedIds = await isar.feeds
      .filter()
      .categoryIdEqualTo(categoryId)
      .idProperty()
      .findAll();

  if (feedIds.isEmpty) return [];

  // Step 2: Query articles using feedId IN (...)
  return isar.articles
      .filter()
      .anyOf(feedIds, (q, id) => q.feedIdEqualTo(id))
      .sortByPublishedAtDesc()
      .limit(50)
      .findAll();
}

/// Seed test data: 50 feeds with 500 articles each
Future<void> _seedTestData(Isar isar) async {
  await isar.writeTxn(() async {
    // Create 10 categories
    for (var i = 1; i <= 10; i++) {
      final category = Category()
        ..id = i
        ..name = 'Category $i'
        ..createdAt = DateTime.now();
      await isar.categorys.put(category);
    }

    // Create 50 feeds (5 feeds per category)
    for (var i = 1; i <= 50; i++) {
      final categoryId = ((i - 1) ~/ 5) + 1; // Distribute evenly
      final feed = Feed()
        ..id = i
        ..url = 'https://example.com/feed$i.xml'
        ..title = 'Feed $i'
        ..categoryId = categoryId
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();
      await isar.feeds.put(feed);
    }

    // Create 500 articles per feed (25000 total)
    for (var feedId = 1; feedId <= 50; feedId++) {
      final feed = await isar.feeds.get(feedId);
      final categoryId = feed!.categoryId;

      for (var j = 1; j <= 500; j++) {
        final article = Article()
          ..feedId = feedId
          ..categoryId =
              categoryId // Denormalized field
          ..link = 'https://example.com/feed$feedId/article$j'
          ..title = 'Article $j from Feed $feedId'
          ..publishedAt = DateTime.now().subtract(Duration(hours: j))
          ..fetchedAt = DateTime.now()
          ..updatedAt = DateTime.now();
        await isar.articles.put(article);
      }
    }
  });

  final feedCount = await isar.feeds.count();
  final articleCount = await isar.articles.count();
  final categoryCount = await isar.categorys.count();

  stdout.writeln('📦 Seeded $feedCount feeds');
  stdout.writeln('📦 Seeded $articleCount articles');
  stdout.writeln('📦 Seeded $categoryCount categories\n');
}
