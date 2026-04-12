import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:fleur/models/feed.dart';

import '../test/test_utils/category_query_benchmark_support.dart';
import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/tag.dart';

/// Performance benchmark test to validate the value of categoryId denormalization.
///
/// This integration test runs on a real device/emulator with native Isar libraries.
/// Canonical retention metric: percentage of time saved versus the slower
/// two-step query.
/// Retention bar: >=30% saved time.
/// Results below the bar keep the denormalization under review rather than
/// treating it as permanently justified.
///
/// Run with:
///   flutter test -d macos integration_test/category_query_benchmark_test.dart
///   flutter test -d `deviceId` integration_test/category_query_benchmark_test.dart
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
    await seedCategoryQueryBenchmarkData(isar);
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
    final report = await runCategoryQueryBenchmark(
      isar,
      iterations: kCategoryQueryBenchmarkIntegrationIterations,
      afterWarmup: tester.pumpAndSettle,
      afterDirectRun: tester.pump,
      afterTwoStepRun: tester.pumpAndSettle,
    );
    report.writeSummary();

    expect(
      report.avgDirectMicros,
      lessThan(report.avgTwoStepMicros),
      reason: 'Direct categoryId query should be faster than two-step approach',
    );
  });
}
