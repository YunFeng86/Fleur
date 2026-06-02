import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/article.dart';
import '../models/feed.dart';
import '../services/logging/app_logger.dart';

/// Migration definition.
class Migration {
  const Migration({
    required this.id,
    required this.description,
    required this.run,
  });

  /// Unique migration identifier (e.g., '2024-01-29_add_author_field').
  /// Once executed, this ID is stored to prevent re-execution.
  final String id;

  /// Human-readable description of what this migration does.
  final String description;

  /// Migration function. Must be idempotent (safe to run multiple times).
  final Future<void> Function(Isar isar) run;
}

/// Executes all pending migrations that haven't been run yet.
///
/// Isar handles most schema changes automatically (adding/removing fields, indexes).
/// Only use manual migrations for edge cases:
/// - Field renaming (old_field → new_field)
/// - Type changes (String → int)
/// - Complex data transformations
///
/// IMPORTANT:
/// - Migrations are executed ONCE per installation
/// - Migration IDs are stored in SharedPreferences
/// - Each migration must be idempotent (safe to run multiple times)
Future<void> runPendingMigrations(Isar isar) async {
  final prefs = await SharedPreferences.getInstance();
  final key = _executedMigrationsPrefsKey(isar);
  await _migrateLegacyExecutedMigrationsKeyIfNeeded(
    prefs,
    isar: isar,
    key: key,
  );
  final executed = prefs.getStringList(key) ?? <String>[];

  // Define migrations here - only add when truly needed!
  final migrations = <Migration>[
    Migration(
      id: '2026-02-16_backfill_article_category_id',
      description:
          'Backfill Article.categoryId from Feed.categoryId (denormalized field).',
      run: _backfillArticleCategoryId,
    ),
    // Example migration (commented out):
    // Migration(
    //   id: '2024-01-29_rename_content_field',
    //   description: 'Rename Article.content to Article.contentHtml',
    //   run: (isar) => _renameContentField(isar),
    // ),
  ];

  // Execute pending migrations
  for (final migration in migrations) {
    if (!executed.contains(migration.id)) {
      AppLogger.i(
        'Running migration: ${migration.id}\n${migration.description}',
        tag: 'migration',
      );

      try {
        await migration.run(isar);
        executed.add(migration.id);
        await prefs.setStringList(key, executed);
        AppLogger.i('Migration completed: ${migration.id}', tag: 'migration');
      } catch (e, stackTrace) {
        AppLogger.e(
          'Migration failed: ${migration.id}',
          tag: 'migration',
          error: e,
          stackTrace: stackTrace,
        );
        // Don't rethrow - allow app to start even if migration fails
        // Users can still use the app with potentially stale data
      }
    }
  }
}

String _executedMigrationsPrefsKey(Isar isar) {
  // Migrations must run per database instance (multi-account support).
  // Use the Isar instance name as a stable key suffix.
  final name = isar.name.trim().isEmpty ? 'default' : isar.name.trim();
  return 'executed_migrations:$name';
}

Future<void> _migrateLegacyExecutedMigrationsKeyIfNeeded(
  SharedPreferences prefs, {
  required Isar isar,
  required String key,
}) async {
  // Legacy builds used a global key shared by all Isar instances.
  // Newer builds store migration state per instance name.
  //
  // Only migrate for the primary DB instance names to avoid "leaking" a global
  // executed list into per-account databases (multi-account correctness).
  const primaryInstanceNames = <String>{'default', 'fleur', 'flutter_reader'};
  final instanceName = isar.name.trim().isEmpty ? 'default' : isar.name.trim();
  if (!primaryInstanceNames.contains(instanceName)) return;

  if (prefs.containsKey(key)) return;

  const legacyKey = 'executed_migrations';
  if (!prefs.containsKey(legacyKey)) return;

  final legacyExecuted = prefs.getStringList(legacyKey) ?? const <String>[];
  if (legacyExecuted.isEmpty) return;

  await prefs.setStringList(key, legacyExecuted);
  AppLogger.i('Migrated legacy migration records to $key', tag: 'migration');
}

Future<void> _backfillArticleCategoryId(Isar isar) async {
  final feeds = await isar.feeds.where().findAll();
  if (feeds.isEmpty) return;

  var fixed = 0;
  var processedFeeds = 0;
  for (final feed in feeds) {
    // Find articles where categoryId doesn't match the feed's categoryId
    // (covers both null backfill and mismatch repair).
    final ids = await isar.articles
        .filter()
        .feedIdEqualTo(feed.id)
        .not()
        .group((q) {
          return feed.categoryId == null
              ? q.categoryIdIsNull()
              : q.categoryIdEqualTo(feed.categoryId);
        })
        .idProperty()
        .findAll();
    if (ids.isEmpty) continue;

    const batchSize = 200;
    var batchCount = 0;
    for (var i = 0; i < ids.length; i += batchSize) {
      final end = (i + batchSize > ids.length) ? ids.length : i + batchSize;
      final batchIds = ids.sublist(i, end);

      await isar.writeTxn(() async {
        final items = await isar.articles.getAll(batchIds);
        final now = DateTime.now();
        final updates = <Article>[];
        for (final a in items) {
          if (a == null) continue;
          a.categoryId = feed.categoryId;
          a.updatedAt = now;
          updates.add(a);
        }
        if (updates.isNotEmpty) {
          await isar.articles.putAll(updates);
        }
      });

      batchCount++;
      // Yield periodically to keep the event loop responsive when migrations run
      // while the UI is active (e.g., opening a secondary account).
      if (batchCount % 10 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    fixed += ids.length;
    processedFeeds++;
    if (processedFeeds % 25 == 0) {
      AppLogger.i(
        'Backfill progress: $processedFeeds/${feeds.length} feeds',
        tag: 'migration',
      );
      await Future<void>.delayed(Duration.zero);
    }
  }

  AppLogger.i('Backfilled $fixed articles', tag: 'migration');
}

// ============================================================================
// Migration Functions
// ============================================================================
// Each migration function should:
// 1. Be idempotent (safe to run multiple times)
// 2. Handle missing/null data gracefully
// 3. Use batch operations for performance
// 4. Log progress with AppLogger
//
// Example migration template:
//
// Future<void> _renameContentField(Isar isar) async {
//   await isar.writeTxn(() async {
//     final articles = await isar.articles.where().findAll();
//     int count = 0;
//
//     for (final article in articles) {
//       // Read old field, write to new field
//       // if (article.oldField != null && article.newField == null) {
//       //   article.newField = article.oldField;
//       //   count++;
//       // }
//     }
//
//     await isar.articles.putAll(articles);
//     AppLogger.i('Migrated $count articles', tag: 'migration');
//   });
// }
