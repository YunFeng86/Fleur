import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';

import '../test_utils/category_query_benchmark_support.dart';
import '../test_utils/isar_test_utils.dart';

/// Performance benchmark test to validate the value of categoryId denormalization.
///
/// This test compares two query strategies:
/// 1. Direct categoryId query (current implementation with denormalization)
/// 2. Two-step query via feedId (alternative without denormalization)
///
/// Canonical retention metric: percentage of time saved versus the slower
/// two-step query.
/// Retention bar: >=30% saved time.
/// Results below the bar keep the denormalization under review rather than
/// treating it as permanently justified.
void main() {
  Isar? isar;
  Directory? tempDir;

  setUpAll(() async {
    await ensureIsarCoreInitialized();

    tempDir = await Directory.systemTemp.createTemp('isar_benchmark_');
    isar = await Isar.open([
      FeedSchema,
      ArticleSchema,
      CategorySchema,
      TagSchema,
    ], directory: tempDir!.path);

    stdout.writeln('\n🏗️  Setting up benchmark database...');
    await seedCategoryQueryBenchmarkData(isar!);
  });

  tearDownAll(() async {
    await isar?.close();
    await tempDir?.delete(recursive: true);
  });

  test('Top-N benchmark slice keeps unique publishedAt ordering', () async {
    final articles = await isar!.articles
        .filter()
        .categoryIdEqualTo(kCategoryQueryBenchmarkDefaultCategoryId)
        .sortByPublishedAtDesc()
        .limit(50)
        .findAll();

    final timestamps = articles
        .map((article) => article.publishedAt.microsecondsSinceEpoch)
        .toSet();

    expect(articles, hasLength(50));
    expect(
      timestamps,
      hasLength(articles.length),
      reason: 'Benchmark top-N should not rely on ambiguous timestamp ties',
    );
  });

  test('Benchmark: categoryId direct query vs feedId two-step query', () async {
    final report = await runCategoryQueryBenchmark(isar!);
    report.writeSummary();

    expect(
      report.avgDirectMicros,
      lessThan(report.avgTwoStepMicros),
      reason: 'Direct categoryId query should be faster than two-step approach',
    );
  });
}
