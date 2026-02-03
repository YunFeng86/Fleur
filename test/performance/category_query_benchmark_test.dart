import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'package:flutter_reader/models/article.dart';
import 'package:flutter_reader/models/category.dart';
import 'package:flutter_reader/models/feed.dart';
import 'package:flutter_reader/models/tag.dart';

/// Performance benchmark test to validate the value of categoryId denormalization.
///
/// This test compares two query strategies:
/// 1. Direct categoryId query (current implementation with denormalization)
/// 2. Two-step query via feedId (alternative without denormalization)
///
/// Expected result: Method 1 should be significantly faster (>30% improvement)
/// to justify the complexity cost of maintaining denormalized data.
void main() {
  Isar? isar;
  Directory? tempDir;

  setUpAll(() async {
    // This benchmark relies on Isar Core native binaries. In unit tests,
    // Isar Core might be missing from the working directory, so we load it
    // from `isar_flutter_libs` (bundled in pub cache) to keep `flutter test`
    // runnable offline.
    final coreLibName = switch (true) {
      _ when Platform.isWindows => 'isar.dll',
      _ when Platform.isMacOS => 'libisar.dylib',
      _ => 'libisar.so',
    };
    final platformDir = switch (true) {
      _ when Platform.isWindows => 'windows',
      _ when Platform.isMacOS => 'macos',
      _ => 'linux',
    };

    final isarFlutterLibsRoot = await _resolvePackageRoot('isar_flutter_libs');
    if (isarFlutterLibsRoot == null) {
      throw StateError(
        'Failed to locate isar_flutter_libs in the package config. '
        'Add isar_flutter_libs to your dependencies.',
      );
    }
    final isarCorePath =
        '${isarFlutterLibsRoot.path}${Platform.pathSeparator}$platformDir'
        '${Platform.pathSeparator}$coreLibName';
    await Isar.initializeIsarCore(libraries: {Abi.current(): isarCorePath});

    // Create temporary directory for test database
    tempDir = await Directory.systemTemp.createTemp('isar_benchmark_');
    isar = await Isar.open([
      FeedSchema,
      ArticleSchema,
      CategorySchema,
      TagSchema,
    ], directory: tempDir!.path);

    // Seed test data: 50 feeds with 500 articles each = 25000 articles
    // This simulates a moderate RSS reader usage
    await _seedTestData(isar!);
  });

  tearDownAll(() async {
    await isar?.close();
    await tempDir?.delete(recursive: true);
  });

  test('Benchmark: categoryId direct query vs feedId two-step query', () async {
    const categoryId = 5;
    const iterations = 10;

    // Warmup (JIT compilation, cache warming)
    await _queryWithCategoryId(isar!, categoryId);
    await _queryWithFeedIds(isar!, categoryId);

    // Method 1: Direct categoryId query (current implementation)
    final stopwatch1 = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await _queryWithCategoryId(isar!, categoryId);
    }
    stopwatch1.stop();
    final avg1 = stopwatch1.elapsedMicroseconds / iterations;

    // Method 2: Two-step query via feedId (alternative approach)
    final stopwatch2 = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await _queryWithFeedIds(isar!, categoryId);
    }
    stopwatch2.stop();
    final avg2 = stopwatch2.elapsedMicroseconds / iterations;

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

    // We expect at least 30% improvement to justify the denormalization complexity
    // If the improvement is less than 30%, the denormalization might not be worth it
    final improvementThreshold = avg2 * 0.7;
    if (avg1 < improvementThreshold) {
      stdout.writeln(
        '✅ Performance improvement ($speedup%) justifies denormalization',
      );
    } else {
      stdout.writeln(
        '⚠️  Performance improvement ($speedup%) is below 30% threshold',
      );
      stdout.writeln(
        '   Consider removing denormalization if complexity cost is high',
      );
    }
  });
}

Future<Directory?> _resolvePackageRoot(String packageName) async {
  final configFile = File('.dart_tool/package_config.json');
  // ignore: avoid_slow_async_io
  if (!await configFile.exists()) return null;

  final configUri = configFile.uri;
  final raw =
      jsonDecode(await configFile.readAsString()) as Map<String, Object?>;
  final packages = (raw['packages'] as List<Object?>)
      .whereType<Map<String, Object?>>()
      .toList();

  Map<String, Object?>? pkg;
  for (final p in packages) {
    if (p['name'] == packageName) {
      pkg = p;
      break;
    }
  }
  if (pkg == null) return null;

  final rootUriStr = pkg['rootUri'] as String?;
  if (rootUriStr == null) return null;

  // `rootUri` can be relative to the config file, so resolve against it.
  final rootUri = configUri.resolve(rootUriStr);
  return Directory.fromUri(rootUri);
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

  stdout.writeln('📦 Seeded ${await isar.feeds.count()} feeds');
  stdout.writeln('📦 Seeded ${await isar.articles.count()} articles');
  stdout.writeln('📦 Seeded ${await isar.categorys.count()} categories\n');
}
