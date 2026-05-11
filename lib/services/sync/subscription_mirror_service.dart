import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../repositories/category_repository.dart';
import '../../repositories/feed_repository.dart';
import '../accounts/account.dart';
import '../logging/app_logger.dart';
import '../logging/log_context.dart';
import 'backend_capabilities.dart';
import 'remote_subscription_structure_executor.dart';

typedef RemoteSubscriptionStructureExecutorFactory =
    Future<RemoteSubscriptionStructureExecutor> Function();

class CategoryNameConflictException implements Exception {
  const CategoryNameConflictException();
}

class SubscriptionMirrorService {
  SubscriptionMirrorService({
    required this.capabilities,
    required this.account,
    required this.feeds,
    required this.categories,
    required RemoteSubscriptionStructureExecutorFactory buildExecutor,
  }) : _buildExecutor = buildExecutor;

  final BackendCapabilities capabilities;
  final Account account;
  final FeedRepository feeds;
  final CategoryRepository categories;
  final RemoteSubscriptionStructureExecutorFactory _buildExecutor;

  Future<int?> addCategory(String name) async {
    const feature = BackendFeature.addCategory;
    _ensureVisible(feature, 'Remote category creation is not supported');

    if (!_isOnlineRequired(feature)) {
      return categories.upsertByName(name);
    }

    final executor = await _buildExecutor();
    final created = await executor.createCategory(name);
    final remoteId = _remoteIdString(created['id']);
    final remoteTitle = (created['title'] as String?)?.trim();
    final effectiveTitle = (remoteTitle == null || remoteTitle.isEmpty)
        ? name.trim()
        : remoteTitle;
    if (remoteId != null) {
      final result = await categories.upsertRemoteDetailed(
        remoteId: remoteId,
        name: effectiveTitle,
      );
      return result.isBound ? result.localId : null;
    }
    return categories.upsertByName(effectiveTitle);
  }

  Future<void> renameCategory({
    required int categoryId,
    required String currentName,
    required String nextName,
  }) async {
    const feature = BackendFeature.renameCategory;
    _ensureVisible(feature, 'Remote category rename is not supported');

    final trimmed = nextName.trim();
    if (trimmed.isEmpty) return;

    if (!_isOnlineRequired(feature)) {
      await categories.rename(categoryId, trimmed);
      return;
    }

    if (await _hasCategoryNameConflict(categoryId, trimmed)) {
      throw const CategoryNameConflictException();
    }

    final executor = await _buildExecutor();
    final categoryRemoteId = await _localCategoryRemoteId(categoryId);
    final updated = categoryRemoteId == null
        ? await executor.renameCategoryByTitle(
            currentTitle: await _localCategoryTitle(categoryId),
            title: trimmed,
          )
        : await executor.renameCategoryById(
            categoryId: categoryRemoteId,
            title: trimmed,
          );
    final remoteTitle = (updated['title'] as String?)?.trim();
    final effectiveTitle = remoteTitle == null || remoteTitle.isEmpty
        ? trimmed
        : remoteTitle;
    if (categoryRemoteId == null) {
      await categories.rename(categoryId, effectiveTitle);
    } else {
      await categories.upsertRemoteDetailed(
        remoteId: categoryRemoteId.toString(),
        name: effectiveTitle,
      );
    }
  }

  Future<void> deleteCategory(int categoryId) async {
    const feature = BackendFeature.deleteCategory;
    _ensureVisible(feature, 'Remote category deletion is not supported');

    if (!_isOnlineRequired(feature)) {
      await categories.delete(categoryId);
      return;
    }

    final executor = await _buildExecutor();
    final categoryRemoteId = await _localCategoryRemoteId(categoryId);
    if (categoryRemoteId == null) {
      final categoryTitle = await _localCategoryTitle(categoryId);
      await executor.deleteCategoryByTitle(categoryTitle);
    } else {
      await executor.deleteCategoryById(categoryRemoteId);
    }
    await categories.delete(categoryId);

    await _reconcileAfterCategoryDelete(executor);
  }

  Future<void> deleteFeed(int feedId) async {
    const feature = BackendFeature.deleteSubscription;
    _ensureVisible(feature, 'Remote feed deletion is not supported');

    if (!_isOnlineRequired(feature)) {
      await feeds.delete(feedId);
      return;
    }

    final executor = await _buildExecutor();
    final feedRemoteId = await _localFeedRemoteId(feedId);
    if (feedRemoteId == null) {
      final feedUrl = await _localFeedUrl(feedId);
      await executor.deleteFeedByUrl(feedUrl);
    } else {
      await executor.deleteFeedById(feedRemoteId);
    }
    await feeds.delete(feedId);
  }

  Future<void> moveFeedToCategory({
    required int feedId,
    required int? categoryId,
  }) async {
    final feature = categoryId == null
        ? BackendFeature.moveSubscriptionToUncategorized
        : BackendFeature.moveSubscriptionToCategory;
    _ensureVisible(feature, 'Remote feed move is not supported');

    if (!_isOnlineRequired(BackendFeature.moveSubscriptionToCategory)) {
      await feeds.setCategory(feedId: feedId, categoryId: categoryId);
      return;
    }

    final executor = await _buildExecutor();
    final feedRemoteId = await _localFeedRemoteId(feedId);
    final targetCategoryId = categoryId;
    if (targetCategoryId == null) {
      throw UnsupportedError(
        'Remote feed move to uncategorized is not supported',
      );
    }
    final categoryRemoteId = await _localCategoryRemoteId(targetCategoryId);
    final updatedFeed = feedRemoteId == null || categoryRemoteId == null
        ? await executor.moveFeedToCategory(
            feedUrl: await _localFeedUrl(feedId),
            categoryTitle: await _localCategoryTitle(targetCategoryId),
          )
        : await executor.moveFeedToCategoryByIds(
            feedId: feedRemoteId,
            categoryId: categoryRemoteId,
          );
    await reconcileLocalFeedFromRemoteUpdate(
      localFeedId: feedId,
      remoteFeed: updatedFeed,
      fallbackCategoryId: targetCategoryId,
    );
  }

  Future<void> reconcileLocalFeedFromRemoteUpdate({
    required int localFeedId,
    required Map<String, Object?> remoteFeed,
    int? fallbackCategoryId,
  }) async {
    final localCategoryId = await _reconcileLocalCategoryIdFromRemoteFeed(
      remoteFeed,
      fallbackCategoryId: fallbackCategoryId,
    );
    final remoteId = _remoteIdString(remoteFeed['id']);
    final remoteUrl = remoteFeed['feed_url'];
    if (remoteId != null &&
        remoteUrl is String &&
        remoteUrl.trim().isNotEmpty) {
      await feeds.upsertRemoteDetailed(
        remoteId: remoteId,
        url: remoteUrl,
        title: remoteFeed['title'] as String?,
        siteUrl: remoteFeed['site_url'] as String?,
        description: remoteFeed['description'] as String?,
        categoryId: localCategoryId,
        preferredLocalFeedId: localFeedId,
      );
      return;
    }

    await feeds.updateMeta(
      id: localFeedId,
      title: remoteFeed['title'] as String?,
      siteUrl: remoteFeed['site_url'] as String?,
      description: remoteFeed['description'] as String?,
    );
    await feeds.setCategory(feedId: localFeedId, categoryId: localCategoryId);
  }

  Future<void> _reconcileAfterCategoryDelete(
    RemoteSubscriptionStructureExecutor executor,
  ) async {
    try {
      final remoteCatIdToLocalId = <int, int>{};
      final seenCategoryRemoteIds = <String>{};
      final protectedCategoryRemoteIds = <String>{};
      final remoteCategories = await executor.listCategories();
      for (final remoteCategory in remoteCategories) {
        final remoteId = remoteCategory['id'];
        final remoteTitle = remoteCategory['title'];
        if (remoteId is! int || remoteTitle is! String) continue;
        final trimmedTitle = remoteTitle.trim();
        if (trimmedTitle.isEmpty) continue;
        final remoteIdString = remoteId.toString();
        final result = await categories.upsertRemoteDetailed(
          remoteId: remoteIdString,
          name: trimmedTitle,
        );
        if (result.isBound) {
          seenCategoryRemoteIds.add(remoteIdString);
          remoteCatIdToLocalId[remoteId] = result.localId;
        } else {
          final protectedId = result.effectiveRemoteId;
          if (protectedId != null && protectedId.isNotEmpty) {
            protectedCategoryRemoteIds.add(protectedId);
          }
        }
      }
      final seenFeedRemoteIds = <String>{};
      final protectedFeedRemoteIds = <String>{};
      final remoteFeeds = await executor.listFeeds();
      final feedMirrorIndex = await feeds.createRemoteMirrorIndex();
      for (final remoteFeed in remoteFeeds) {
        final remoteFeedId = remoteFeed['id'];
        final remoteUrl = remoteFeed['feed_url'];
        if (remoteFeedId is! int || remoteUrl is! String) continue;
        final remoteCategoryId = remoteFeed['category'] is Map
            ? (remoteFeed['category'] as Map)['id']
            : remoteFeed['category_id'];
        final localCategoryId = remoteCategoryId is int
            ? remoteCatIdToLocalId[remoteCategoryId]
            : null;
        final remoteFeedIdString = remoteFeedId.toString();
        final updateCategory =
            remoteCategoryId is! int || localCategoryId != null;
        final result = await feeds.upsertRemoteDetailed(
          remoteId: remoteFeedIdString,
          url: remoteUrl,
          title: remoteFeed['title'] as String?,
          siteUrl: remoteFeed['site_url'] as String?,
          description: remoteFeed['description'] as String?,
          categoryId: localCategoryId,
          updateCategory: updateCategory,
          lookupIndex: feedMirrorIndex,
        );
        if (result.isBound) {
          seenFeedRemoteIds.add(remoteFeedIdString);
        } else {
          final protectedId = result.effectiveRemoteId;
          if (protectedId != null && protectedId.isNotEmpty) {
            protectedFeedRemoteIds.add(protectedId);
          }
        }
      }
      final allowFeedProtectedOnlyPrune =
          remoteFeeds.isNotEmpty &&
          seenFeedRemoteIds.isEmpty &&
          protectedFeedRemoteIds.isNotEmpty;
      final allowCategoryProtectedOnlyPrune =
          remoteCategories.isNotEmpty &&
          seenCategoryRemoteIds.isEmpty &&
          protectedCategoryRemoteIds.isNotEmpty;
      await feeds.deleteRemoteMissing(
        seenFeedRemoteIds,
        allowEmptyPrune: allowFeedProtectedOnlyPrune,
        protectedRemoteIds: protectedFeedRemoteIds,
      );
      await categories.deleteRemoteMissing(
        seenCategoryRemoteIds,
        allowEmptyPrune: allowCategoryProtectedOnlyPrune,
        protectedRemoteIds: protectedCategoryRemoteIds,
      );
    } catch (error, stackTrace) {
      AppLogger.w(
        'Subscription mirror reconciliation failed',
        tag: 'subscription',
        error: error,
        stackTrace: stackTrace,
        context: subscriptionMirrorFailureContext(
          account,
          capabilities,
          error,
          'reconcileAfterDeleteCategory',
        ),
      );
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'subscription_actions',
          context: ErrorDescription(
            'while reconciling local mirror after remote category deletion',
          ),
        ),
      );
    }
  }

  Future<int?> _reconcileLocalCategoryIdFromRemoteFeed(
    Map<String, Object?> remoteFeed, {
    int? fallbackCategoryId,
  }) async {
    final remoteCategory = remoteFeed['category'];
    if (remoteCategory is Map) {
      final remoteId = _remoteIdString(remoteCategory['id']);
      final title = (remoteCategory['title'] as String?)?.trim();
      if (title != null && title.isNotEmpty) {
        if (remoteId != null) {
          final result = await categories.upsertRemoteDetailed(
            remoteId: remoteId,
            name: title,
          );
          return result.isBound ? result.localId : fallbackCategoryId;
        }
        return categories.upsertByName(title);
      }
    }
    return fallbackCategoryId;
  }

  Future<String> _localFeedUrl(int localFeedId) async {
    final feed = await feeds.getById(localFeedId);
    if (feed == null) {
      throw StateError('Local feed not found: $localFeedId');
    }

    final target = _normalizeFeedUrl(feed.url);
    if (target.isEmpty) {
      throw StateError('Local feed url is empty: $localFeedId');
    }
    return feed.url;
  }

  Future<int?> _localFeedRemoteId(int localFeedId) async {
    final feed = await feeds.getById(localFeedId);
    if (feed == null) {
      throw StateError('Local feed not found: $localFeedId');
    }
    return _remoteIdAsInt(feed.remoteId);
  }

  Future<String> _localCategoryTitle(int localCategoryId) async {
    final category = await categories.getById(localCategoryId);
    if (category == null) {
      throw StateError('Local category not found: $localCategoryId');
    }
    return category.name;
  }

  Future<int?> _localCategoryRemoteId(int localCategoryId) async {
    final category = await categories.getById(localCategoryId);
    if (category == null) {
      throw StateError('Local category not found: $localCategoryId');
    }
    return _remoteIdAsInt(category.remoteId);
  }

  Future<bool> _hasCategoryNameConflict(int categoryId, String nextName) async {
    final trimmed = nextName.trim();
    if (trimmed.isEmpty) return false;
    final allCategories = await categories.getAll();
    for (final category in allCategories) {
      if (category.id == categoryId) continue;
      if (category.name == trimmed) return true;
    }
    return false;
  }

  void _ensureVisible(BackendFeature feature, String message) {
    if (!capabilities.isVisible(feature)) {
      throw UnsupportedError(message);
    }
  }

  bool _isOnlineRequired(BackendFeature feature) {
    return capabilities.availability(feature) ==
        FeatureAvailability.onlineRequired;
  }
}

Map<String, Object?> subscriptionMirrorFailureContext(
  Account account,
  BackendCapabilities capabilities,
  Object error,
  String operation,
) {
  final extra = <String, Object?>{
    'accountId': account.id,
    'accountType': capabilities.diagnosticAccountType,
    'operation': operation,
  };
  if (error is DioException) {
    return logContextForDioException(error, extra: extra);
  }
  final baseUrl = account.baseUrl?.trim();
  final uri = baseUrl == null || baseUrl.isEmpty ? null : Uri.tryParse(baseUrl);
  if (uri == null) return extra;
  return logContextForUri(uri, extra: extra);
}

String _normalizeFeedUrl(String url) {
  return url.trim().replaceAll(RegExp(r'/+$'), '');
}

int? _remoteIdAsInt(String? remoteId) {
  final trimmed = remoteId?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final value = int.tryParse(trimmed);
  return value != null && value > 0 ? value : null;
}

String? _remoteIdString(Object? value) {
  if (value is int && value > 0) return value.toString();
  if (value is num && value.isFinite && value > 0) {
    return value.toInt().toString();
  }
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}
