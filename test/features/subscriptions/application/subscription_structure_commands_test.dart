import 'dart:io';

import 'package:dio/dio.dart';
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

class _RecordingRemoteStructureExecutor
    implements RemoteSubscriptionStructureExecutor {
  _RecordingRemoteStructureExecutor({
    this.deleteFeedFailure,
    this.deleteCategoryFailure,
    this.moveFeedFailure,
    this.categoryReconciliationFailure,
  });

  final Object? deleteFeedFailure;
  final Object? deleteCategoryFailure;
  final Object? moveFeedFailure;
  final Object? categoryReconciliationFailure;
  final deletedFeedIds = <int>[];
  final deletedCategoryIds = <int>[];
  final moveFeedCalls = <({int feedId, int categoryId})>[];

  @override
  Future<Map<String, Object?>> createCategory(String title) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, Object?>> createFeed({
    required String feedUrl,
    required int categoryId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCategoryById(int categoryId) async {
    deletedCategoryIds.add(categoryId);
    final failure = deleteCategoryFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> deleteCategoryByTitle(String title) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteFeedById(int feedId) async {
    deletedFeedIds.add(feedId);
    final failure = deleteFeedFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> deleteFeedByUrl(String feedUrl) {
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, Object?>>> listCategories() async {
    final failure = categoryReconciliationFailure;
    if (failure != null) throw failure;
    return const <Map<String, Object?>>[];
  }

  @override
  Future<List<Map<String, Object?>>> listFeeds() async {
    return const <Map<String, Object?>>[];
  }

  @override
  Future<Map<String, Object?>> moveFeedToCategory({
    required String feedUrl,
    required String categoryTitle,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, Object?>> moveFeedToCategoryByIds({
    required int feedId,
    required int categoryId,
  }) async {
    moveFeedCalls.add((feedId: feedId, categoryId: categoryId));
    final failure = moveFeedFailure;
    if (failure != null) throw failure;
    throw UnimplementedError();
  }

  @override
  Future<void> refreshAllFeeds() {
    throw UnimplementedError();
  }

  @override
  Future<void> refreshFeedById(int feedId) {
    throw UnimplementedError();
  }

  @override
  Future<void> refreshFeedByUrl(String feedUrl) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, Object?>> renameCategoryById({
    required int categoryId,
    required String title,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, Object?>> renameCategoryByTitle({
    required String currentTitle,
    required String title,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<({int remoteId, String title})> resolveCategoryByTitle(String title) {
    throw UnimplementedError();
  }

  @override
  Future<int> resolveFeedIdByUrl(String feedUrl) {
    throw UnimplementedError();
  }
}

void main() {
  late Isar isar;
  late Directory tempDir;

  setUpAll(ensureIsarCoreInitialized);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'fleur_subscription_structure_commands_',
    );
    isar = await Isar.open(
      [FeedSchema, ArticleSchema, CategorySchema, TagSchema],
      directory: tempDir.path,
      name: 'subscription_structure_commands_test',
    );
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('remote feed deletion failure leaves the local feed intact', () async {
    final now = DateTime.utc(2026, 3, 1, 10);
    await isar.writeTxn(() async {
      await isar.feeds.put(
        Feed()
          ..id = 1
          ..remoteId = '91'
          ..url = 'https://example.com/feed.xml'
          ..title = 'Feed'
          ..createdAt = now
          ..updatedAt = now,
      );
    });
    final failure = DioException(
      requestOptions: RequestOptions(path: '/v1/feeds/91'),
      type: DioExceptionType.connectionError,
      error: const SocketException('offline'),
    );
    final executor = _RecordingRemoteStructureExecutor(
      deleteFeedFailure: failure,
    );

    await expectLater(
      _commands(isar, executor).deleteFeed(1),
      throwsA(same(failure)),
    );

    expect(executor.deletedFeedIds, [91]);
    expect(await FeedRepository(isar).getById(1), isNotNull);
  });

  test(
    'remote category deletion failure leaves the local category intact',
    () async {
      final now = DateTime.utc(2026, 3, 1, 11);
      await isar.writeTxn(() async {
        await isar.categorys.put(
          Category()
            ..id = 7
            ..remoteId = '22'
            ..name = 'Remote Category'
            ..createdAt = now
            ..updatedAt = now,
        );
      });
      final failure = DioException(
        requestOptions: RequestOptions(path: '/v1/categories/22'),
        type: DioExceptionType.connectionError,
        error: const SocketException('offline'),
      );
      final executor = _RecordingRemoteStructureExecutor(
        deleteCategoryFailure: failure,
      );

      await expectLater(
        _commands(isar, executor).deleteCategory(7),
        throwsA(same(failure)),
      );

      expect(executor.deletedCategoryIds, [22]);
      expect(await CategoryRepository(isar).getById(7), isNotNull);
    },
  );

  test(
    'category deletion keeps local deletion after remote success and reconciliation failure',
    () async {
      final now = DateTime.utc(2026, 3, 1, 11, 30);
      await isar.writeTxn(() async {
        await isar.categorys.put(
          Category()
            ..id = 7
            ..remoteId = '22'
            ..name = 'Remote Category'
            ..createdAt = now
            ..updatedAt = now,
        );
        await isar.feeds.put(
          Feed()
            ..id = 3
            ..url = 'https://example.com/feed.xml'
            ..title = 'Feed'
            ..categoryId = 7
            ..createdAt = now
            ..updatedAt = now,
        );
      });
      final executor = _RecordingRemoteStructureExecutor(
        categoryReconciliationFailure: StateError('remote list is unavailable'),
      );

      await _commands(isar, executor).deleteCategory(7);

      expect(executor.deletedCategoryIds, [22]);
      expect(await CategoryRepository(isar).getById(7), isNull);
      expect((await FeedRepository(isar).getById(3))?.categoryId, isNull);
    },
  );

  test(
    'remote feed move failure leaves the local feed category unchanged',
    () async {
      final now = DateTime.utc(2026, 3, 1, 12);
      await isar.writeTxn(() async {
        await isar.categorys.putAll([
          Category()
            ..id = 4
            ..remoteId = '20'
            ..name = 'Current Category'
            ..createdAt = now
            ..updatedAt = now,
          Category()
            ..id = 7
            ..remoteId = '22'
            ..name = 'Target Category'
            ..createdAt = now
            ..updatedAt = now,
        ]);
        await isar.feeds.put(
          Feed()
            ..id = 1
            ..remoteId = '91'
            ..url = 'https://example.com/feed.xml'
            ..title = 'Feed'
            ..categoryId = 4
            ..createdAt = now
            ..updatedAt = now,
        );
      });
      final failure = DioException(
        requestOptions: RequestOptions(path: '/v1/feeds/91'),
        type: DioExceptionType.connectionError,
        error: const SocketException('offline'),
      );
      final executor = _RecordingRemoteStructureExecutor(
        moveFeedFailure: failure,
      );

      await expectLater(
        _commands(isar, executor).moveFeedToCategory(feedId: 1, categoryId: 7),
        throwsA(same(failure)),
      );

      expect(executor.moveFeedCalls, [(feedId: 91, categoryId: 22)]);
      expect((await FeedRepository(isar).getById(1))?.categoryId, 4);
    },
  );
}

SubscriptionStructureCommands _commands(
  Isar isar,
  RemoteSubscriptionStructureExecutor executor,
) {
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
    buildExecutor: () async => executor,
  );
}
