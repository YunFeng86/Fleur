import 'dart:io';

import 'package:isar_community/isar.dart';

import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';

const int kCategoryQueryBenchmarkFeedCount = 50;
const int kCategoryQueryBenchmarkArticlesPerFeed = 500;
const int kCategoryQueryBenchmarkCategoryCount = 10;
const int kCategoryQueryBenchmarkDefaultCategoryId = 5;
const int kCategoryQueryBenchmarkDefaultIterations = 10;
const int kCategoryQueryBenchmarkIntegrationIterations = 20;
const double kCategoryQueryBenchmarkRetentionBarPercent = 30.0;

class CategoryQueryBenchmarkReport {
  const CategoryQueryBenchmarkReport({
    required this.categoryId,
    required this.iterations,
    required this.avgDirectMicros,
    required this.avgTwoStepMicros,
    this.retentionBarPercent = kCategoryQueryBenchmarkRetentionBarPercent,
  });

  final int categoryId;
  final int iterations;
  final double avgDirectMicros;
  final double avgTwoStepMicros;
  final double retentionBarPercent;

  double get savedMicros => avgTwoStepMicros - avgDirectMicros;

  double get savedPercent =>
      avgTwoStepMicros == 0 ? 0 : savedMicros / avgTwoStepMicros * 100;

  double get speedupRatio =>
      avgDirectMicros == 0 ? 0 : avgTwoStepMicros / avgDirectMicros;

  bool get clearsRetentionBar => savedPercent >= retentionBarPercent;

  void writeSummary({void Function(String line)? log}) {
    final void Function(String line) writeLine =
        log ?? (String line) => stdout.writeln(line);
    final savedPercentText = savedPercent.toStringAsFixed(1);
    final diffText = savedMicros.toStringAsFixed(0);
    final speedupRatioText = speedupRatio.toStringAsFixed(2);

    writeLine('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    writeLine('📊 Category Query Performance Benchmark');
    writeLine('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    writeLine(
      'Dataset: $kCategoryQueryBenchmarkFeedCount feeds × '
      '$kCategoryQueryBenchmarkArticlesPerFeed articles = '
      '${kCategoryQueryBenchmarkFeedCount * kCategoryQueryBenchmarkArticlesPerFeed} total articles',
    );
    writeLine('Category: $categoryId (contains 10 feeds)');
    writeLine('Iterations: $iterations');
    writeLine('');
    writeLine(
      'Method 1 (Direct categoryId):  ${avgDirectMicros.toStringAsFixed(0)} μs/query',
    );
    writeLine(
      'Method 2 (Two-step via feedId): ${avgTwoStepMicros.toStringAsFixed(0)} μs/query',
    );
    writeLine('');
    writeLine(
      'Primary retention metric: $savedPercentText% time saved ($diffText μs improvement)',
    );
    writeLine('Speedup ratio (diagnostic only): ${speedupRatioText}x');
    writeLine('Retention bar: >= ${retentionBarPercent.toStringAsFixed(0)}%');
    writeLine('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    writeLine('');

    if (clearsRetentionBar) {
      writeLine('✅ Saved time ($savedPercentText%) clears the retention bar');
    } else {
      writeLine(
        '⚠️  Saved time ($savedPercentText%) is below the retention bar',
      );
      writeLine(
        '   Keep denormalization under review before adding more maintenance complexity',
      );
    }

    writeLine('');
  }
}

Future<void> seedCategoryQueryBenchmarkData(
  Isar isar, {
  void Function(String line)? log,
}) async {
  final void Function(String line) writeLine =
      log ?? (String line) => stdout.writeln(line);

  await isar.writeTxn(() async {
    final now = DateTime.now();

    for (var i = 1; i <= kCategoryQueryBenchmarkCategoryCount; i++) {
      final category = Category()
        ..id = i
        ..name = 'Category $i'
        ..createdAt = now;
      await isar.categorys.put(category);
    }

    for (var i = 1; i <= kCategoryQueryBenchmarkFeedCount; i++) {
      final categoryId = ((i - 1) ~/ 5) + 1;
      final feed = Feed()
        ..id = i
        ..url = 'https://example.com/feed$i.xml'
        ..title = 'Feed $i'
        ..categoryId = categoryId
        ..createdAt = now
        ..updatedAt = now;
      await isar.feeds.put(feed);
    }

    for (var feedId = 1; feedId <= kCategoryQueryBenchmarkFeedCount; feedId++) {
      final feed = await isar.feeds.get(feedId);
      final categoryId = feed!.categoryId;

      for (
        var articleIndex = 1;
        articleIndex <= kCategoryQueryBenchmarkArticlesPerFeed;
        articleIndex++
      ) {
        // Keep articleIndex as the primary recency signal while giving each
        // feed a tiny deterministic offset, so top-N benchmark queries do not
        // collapse onto shared timestamps across feeds.
        final publishedAt = now.subtract(
          Duration(hours: articleIndex, microseconds: feedId),
        );
        final article = Article()
          ..feedId = feedId
          ..categoryId = categoryId
          ..link = 'https://example.com/feed$feedId/article$articleIndex'
          ..title = 'Article $articleIndex from Feed $feedId'
          ..publishedAt = publishedAt
          ..fetchedAt = now
          ..updatedAt = now;
        await isar.articles.put(article);
      }
    }
  });

  writeLine('📦 Seeded ${await isar.feeds.count()} feeds');
  writeLine('📦 Seeded ${await isar.articles.count()} articles');
  writeLine('📦 Seeded ${await isar.categorys.count()} categories\n');
}

Future<CategoryQueryBenchmarkReport> runCategoryQueryBenchmark(
  Isar isar, {
  int categoryId = kCategoryQueryBenchmarkDefaultCategoryId,
  int iterations = kCategoryQueryBenchmarkDefaultIterations,
  Future<void> Function()? afterWarmup,
  Future<void> Function()? afterDirectRun,
  Future<void> Function()? afterTwoStepRun,
}) async {
  await _queryWithCategoryId(isar, categoryId);
  await _queryWithFeedIds(isar, categoryId);
  if (afterWarmup != null) {
    await afterWarmup();
  }

  final directStopwatch = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    await _queryWithCategoryId(isar, categoryId);
  }
  directStopwatch.stop();
  final avgDirectMicros = directStopwatch.elapsedMicroseconds / iterations;

  if (afterDirectRun != null) {
    await afterDirectRun();
  }

  final twoStepStopwatch = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    await _queryWithFeedIds(isar, categoryId);
  }
  twoStepStopwatch.stop();
  final avgTwoStepMicros = twoStepStopwatch.elapsedMicroseconds / iterations;

  if (afterTwoStepRun != null) {
    await afterTwoStepRun();
  }

  return CategoryQueryBenchmarkReport(
    categoryId: categoryId,
    iterations: iterations,
    avgDirectMicros: avgDirectMicros,
    avgTwoStepMicros: avgTwoStepMicros,
  );
}

Future<List<Article>> _queryWithCategoryId(Isar isar, int categoryId) async {
  return isar.articles
      .filter()
      .categoryIdEqualTo(categoryId)
      .sortByPublishedAtDesc()
      .limit(50)
      .findAll();
}

Future<List<Article>> _queryWithFeedIds(Isar isar, int categoryId) async {
  final feedIds = await isar.feeds
      .filter()
      .categoryIdEqualTo(categoryId)
      .idProperty()
      .findAll();

  if (feedIds.isEmpty) return [];

  return isar.articles
      .filter()
      .anyOf(feedIds, (query, id) => query.feedIdEqualTo(id))
      .sortByPublishedAtDesc()
      .limit(50)
      .findAll();
}
