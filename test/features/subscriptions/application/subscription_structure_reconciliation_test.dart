import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/features/subscriptions/application/subscription_structure_commands.dart';
import 'package:fleur/models/article.dart';
import 'package:fleur/models/category.dart';
import 'package:fleur/models/feed.dart';
import 'package:fleur/models/tag.dart';
import 'package:fleur/repositories/category_repository.dart';
import 'package:fleur/repositories/feed_repository.dart';
import 'package:fleur/services/sync/backend_capabilities.dart';
import 'package:fleur/services/sync/remote_subscription_structure_executor.dart';

import '../../../test_utils/isar_test_utils.dart';

void main() {
  late Isar isar;
  late Directory tempDir;

  setUpAll(ensureIsarCoreInitialized);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'fleur_subscription_structure_reconciliation_',
    );
    isar = await Isar.open(
      [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
      directory: tempDir.path,
      name: 'subscription_structure_reconciliation_test',
    );
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'remote feed reconciliation uses the accepted remote category and metadata',
    () async {
      final now = DateTime.utc(2026, 3, 1, 13);
      await isar.writeTxn(() async {
        await isar.categorys.put(
          Category()
            ..id = 7
            ..name = 'Chosen Local Category'
            ..createdAt = now
            ..updatedAt = now,
        );
        await isar.feeds.put(
          Feed()
            ..id = 1
            ..url = 'https://example.com/feed.xml'
            ..title = 'Feed'
            ..createdAt = now
            ..updatedAt = now,
        );
      });

      await _commands(isar).reconcileLocalFeedFromRemoteUpdate(
        localFeedId: 1,
        remoteFeed: const <String, Object?>{
          'id': 91,
          'feed_url': 'https://example.com/feed.xml',
          'title': 'Server Feed Title',
          'site_url': 'https://example.com',
          'description': 'Remote description',
          'category': <String, Object?>{
            'id': 23,
            'title': 'Server Accepted Category',
          },
        },
        fallbackCategoryId: 7,
      );

      final categories = await CategoryRepository(isar).getAll();
      final reconciledCategory = categories.firstWhere(
        (category) => category.name == 'Server Accepted Category',
      );
      final updatedFeed = await FeedRepository(isar).getById(1);
      final feeds = await FeedRepository(isar).getAll();

      expect(feeds, hasLength(1));
      expect(updatedFeed?.remoteId, '91');
      expect(updatedFeed?.categoryId, reconciledCategory.id);
      expect(updatedFeed?.title, 'Server Feed Title');
      expect(updatedFeed?.siteUrl, 'https://example.com');
      expect(updatedFeed?.description, 'Remote description');
    },
  );

  test('remote feed reconciliation skips non-finite remote ids', () async {
    final now = DateTime.utc(2026, 3, 1, 13, 15);
    await isar.writeTxn(() async {
      await isar.categorys.put(
        Category()
          ..id = 7
          ..name = 'Chosen Local Category'
          ..createdAt = now
          ..updatedAt = now,
      );
      await isar.feeds.put(
        Feed()
          ..id = 1
          ..url = 'https://example.com/feed.xml'
          ..title = 'Feed'
          ..createdAt = now
          ..updatedAt = now,
      );
    });

    await _commands(isar).reconcileLocalFeedFromRemoteUpdate(
      localFeedId: 1,
      remoteFeed: <String, Object?>{
        'id': double.infinity,
        'feed_url': 'https://example.com/feed.xml',
        'title': 'Server Feed Title',
        'category': <String, Object?>{
          'id': double.infinity,
          'title': 'Server Accepted Category',
        },
      },
      fallbackCategoryId: 7,
    );

    final categories = await CategoryRepository(isar).getAll();
    final reconciledCategory = categories.firstWhere(
      (category) => category.name == 'Server Accepted Category',
    );
    final updatedFeed = await FeedRepository(isar).getById(1);

    expect(updatedFeed?.remoteId, isNull);
    expect(updatedFeed?.categoryId, reconciledCategory.id);
    expect(updatedFeed?.title, 'Server Feed Title');
    expect(await FeedRepository(isar).getByRemoteId('Infinity'), isNull);
    expect(await CategoryRepository(isar).getByRemoteId('Infinity'), isNull);
  });

  test(
    'remote feed reconciliation binds equivalent url to the current local feed',
    () async {
      final now = DateTime.utc(2026, 3, 1, 13, 30);
      await isar.writeTxn(() async {
        await isar.categorys.put(
          Category()
            ..id = 7
            ..name = 'Chosen Local Category'
            ..createdAt = now
            ..updatedAt = now,
        );
        await isar.feeds.put(
          Feed()
            ..id = 1
            ..url = 'https://example.com/feed.xml/'
            ..title = 'Feed'
            ..createdAt = now
            ..updatedAt = now,
        );
      });

      await _commands(isar).reconcileLocalFeedFromRemoteUpdate(
        localFeedId: 1,
        remoteFeed: const <String, Object?>{
          'id': 91,
          'feed_url': 'https://example.com/feed.xml',
          'title': 'Server Feed Title',
          'site_url': 'https://example.com',
          'description': 'Remote description',
          'category': <String, Object?>{
            'id': 23,
            'title': 'Server Accepted Category',
          },
        },
        fallbackCategoryId: 7,
      );

      final categories = await CategoryRepository(isar).getAll();
      final reconciledCategory = categories.firstWhere(
        (category) => category.name == 'Server Accepted Category',
      );
      final feeds = await FeedRepository(isar).getAll();
      final updatedFeed = await FeedRepository(isar).getById(1);

      expect(feeds, hasLength(1));
      expect(updatedFeed?.remoteId, '91');
      expect(updatedFeed?.url, 'https://example.com/feed.xml');
      expect(updatedFeed?.categoryId, reconciledCategory.id);
      expect(updatedFeed?.title, 'Server Feed Title');
      expect(updatedFeed?.siteUrl, 'https://example.com');
      expect(updatedFeed?.description, 'Remote description');
    },
  );

  test(
    'remote feed reconciliation does not rebind a same-name remote category',
    () async {
      final now = DateTime.utc(2026, 3, 1, 14);
      await isar.writeTxn(() async {
        await isar.categorys.putAll([
          Category()
            ..id = 7
            ..name = 'Chosen Local Category'
            ..createdAt = now
            ..updatedAt = now,
          Category()
            ..id = 8
            ..remoteId = '77'
            ..name = 'Server Accepted Category'
            ..createdAt = now
            ..updatedAt = now,
        ]);
        await isar.feeds.put(
          Feed()
            ..id = 1
            ..url = 'https://example.com/feed.xml'
            ..title = 'Feed'
            ..categoryId = 7
            ..createdAt = now
            ..updatedAt = now,
        );
      });

      await _commands(isar).reconcileLocalFeedFromRemoteUpdate(
        localFeedId: 1,
        remoteFeed: const <String, Object?>{
          'id': 91,
          'feed_url': 'https://example.com/feed.xml',
          'title': 'Server Feed Title',
          'category': <String, Object?>{
            'id': 23,
            'title': 'Server Accepted Category',
          },
        },
        fallbackCategoryId: 7,
      );

      final categories = await CategoryRepository(isar).getAll();
      final updatedFeed = await FeedRepository(isar).getById(1);
      final existingRemoteCategory = await CategoryRepository(
        isar,
      ).getByRemoteId('77');
      final conflictingRemoteCategory = await CategoryRepository(
        isar,
      ).getByRemoteId('23');

      expect(categories, hasLength(2));
      expect(updatedFeed?.remoteId, '91');
      expect(updatedFeed?.categoryId, 7);
      expect(existingRemoteCategory?.id, 8);
      expect(existingRemoteCategory?.name, 'Server Accepted Category');
      expect(conflictingRemoteCategory, isNull);
    },
  );
}

SubscriptionStructureCommands _commands(Isar isar) {
  final now = DateTime.utc(2026, 3, 1);
  final account = Account(
    id: 'miniflux-test-account',
    type: AccountType.miniflux,
    name: 'Miniflux',
    baseUrl: 'https://miniflux.example.com',
    createdAt: now,
    updatedAt: now,
  );
  return SubscriptionStructureCommands(
    capabilities: BackendCapabilities.forAccount(account),
    account: account,
    feeds: FeedRepository(isar),
    categories: CategoryRepository(isar),
    buildExecutor: _unusedExecutor,
  );
}

Future<RemoteSubscriptionStructureExecutor> _unusedExecutor() async {
  throw UnimplementedError('The reconciliation tests do not create executors.');
}
