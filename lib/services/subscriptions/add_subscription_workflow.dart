import 'package:flutter/foundation.dart' hide Category;

import '../../models/category.dart';
import '../../models/feed.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/feed_repository.dart';
import '../accounts/account.dart';
import '../rss/feed_discovery_service.dart';
import '../sync/backend_capabilities.dart';
import '../sync/remote_client_factory.dart';
import '../sync/remote_subscription_structure_executor.dart';
import '../sync/sync_mutex.dart';
import '../sync/sync_service.dart';

const _unset = Object();

enum AddSubscriptionFailureKind {
  unsupported,
  validation,
  noFeedsFound,
  discovery,
  category,
  submit,
  remoteStructure,
}

@immutable
class AddSubscriptionFailure {
  const AddSubscriptionFailure(this.kind, [this.error]);

  final AddSubscriptionFailureKind kind;
  final Object? error;
}

@immutable
class AddSubscriptionCategoryOption {
  const AddSubscriptionCategoryOption({
    required this.id,
    required this.title,
    this.isUncategorized = false,
  });

  const AddSubscriptionCategoryOption.uncategorized(this.title)
    : id = null,
      isUncategorized = true;

  final int? id;
  final String title;
  final bool isUncategorized;
}

@immutable
class AddSubscriptionCandidate {
  const AddSubscriptionCandidate({
    required this.feed,
    this.existingFeedId,
    this.existingCategoryId,
  });

  final DiscoveredFeed feed;
  final int? existingFeedId;
  final int? existingCategoryId;

  bool get isAlreadySubscribed => existingFeedId != null;

  AddSubscriptionCandidate copyWith({
    DiscoveredFeed? feed,
    Object? existingFeedId = _unset,
    Object? existingCategoryId = _unset,
  }) {
    return AddSubscriptionCandidate(
      feed: feed ?? this.feed,
      existingFeedId: identical(existingFeedId, _unset)
          ? this.existingFeedId
          : existingFeedId as int?,
      existingCategoryId: identical(existingCategoryId, _unset)
          ? this.existingCategoryId
          : existingCategoryId as int?,
    );
  }
}

@immutable
class AddSubscriptionCategoryLoadResult {
  const AddSubscriptionCategoryLoadResult({
    required this.categories,
    required this.selectedCategoryId,
    required this.categorySelected,
  });

  final List<AddSubscriptionCategoryOption> categories;
  final int? selectedCategoryId;
  final bool categorySelected;
}

@immutable
class AddSubscriptionSelectionResult {
  const AddSubscriptionSelectionResult({
    required this.selectedFeedUri,
    this.existingFeedId,
    this.existingCategoryId,
  });

  final Uri selectedFeedUri;
  final int? existingFeedId;
  final int? existingCategoryId;
}

@immutable
class AddSubscriptionWorkflowResult {
  const AddSubscriptionWorkflowResult({
    this.feedId,
    this.existingFeedId,
    this.existingCategoryId,
    this.categoryId,
    this.candidate,
    this.refreshWarning,
  });

  final int? feedId;
  final int? existingFeedId;
  final int? existingCategoryId;
  final int? categoryId;
  final AddSubscriptionCandidate? candidate;
  final Object? refreshWarning;
}

class AddSubscriptionWorkflow {
  AddSubscriptionWorkflow({
    required Account account,
    required BackendCapabilities capabilities,
    required FeedDiscoveryService discovery,
    required FeedRepository feeds,
    required CategoryRepository categories,
    required SyncServiceBase Function() readSync,
    required RemoteClientFactory remoteClients,
    required String? webUserAgent,
  }) : _account = account,
       _capabilities = capabilities,
       _discovery = discovery,
       _feeds = feeds,
       _categories = categories,
       _readSync = readSync,
       _remoteClients = remoteClients,
       _webUserAgent = webUserAgent;

  final Account _account;
  final BackendCapabilities _capabilities;
  final FeedDiscoveryService _discovery;
  final FeedRepository _feeds;
  final CategoryRepository _categories;
  final SyncServiceBase Function() _readSync;
  final RemoteClientFactory _remoteClients;
  final String? _webUserAgent;

  AddSubscriptionFailureKind get remoteOrCategoryFailureKind {
    return _capabilities.isOnlineRequired(BackendFeature.addSubscription)
        ? AddSubscriptionFailureKind.remoteStructure
        : AddSubscriptionFailureKind.category;
  }

  Future<List<AddSubscriptionCandidate>> discover(String input) async {
    final userAgent = (_webUserAgent ?? '').trim();
    final candidates = await _discovery.discover(
      input,
      userAgent: userAgent.isEmpty ? null : userAgent,
    );
    return decorateCandidates(candidates);
  }

  Future<List<AddSubscriptionCandidate>> decorateCandidates(
    List<DiscoveredFeed> feeds,
  ) async {
    final candidates = <AddSubscriptionCandidate>[];
    for (final feed in feeds) {
      candidates.add(await decorateCandidate(feed));
    }
    return candidates;
  }

  Future<AddSubscriptionCandidate> decorateCandidate(
    DiscoveredFeed feed,
  ) async {
    final existingFeed = await resolveLocalFeedByUrl(feed.url);
    final existingCategoryId = await candidateExistingCategoryId(existingFeed);
    return AddSubscriptionCandidate(
      feed: feed,
      existingFeedId: existingFeed?.id,
      existingCategoryId: existingCategoryId,
    );
  }

  Future<AddSubscriptionSelectionResult> resolveSelection(
    AddSubscriptionCandidate candidate,
  ) async {
    final uri = Uri.tryParse(candidate.feed.url);
    if (uri == null) {
      throw ArgumentError('Invalid feed URL: ${candidate.feed.url}');
    }

    final existingFeed = candidate.existingFeedId == null
        ? await resolveLocalFeedByUrl(uri.toString())
        : null;
    return AddSubscriptionSelectionResult(
      selectedFeedUri: uri,
      existingFeedId: candidate.existingFeedId ?? existingFeed?.id,
      existingCategoryId:
          candidate.existingCategoryId ?? existingFeed?.categoryId,
    );
  }

  Future<AddSubscriptionCategoryOption> createCategory(String name) async {
    final trimmed = name.trim();
    if (_capabilities.isOnlineRequired(BackendFeature.addSubscription)) {
      final executor = await _buildMinifluxStructureExecutor();
      final raw = await executor.createCategory(trimmed);
      final id = raw['id'];
      if (id is! int || id <= 0) {
        throw StateError('Unexpected Miniflux response for create category');
      }
      final title = raw['title'] is String
          ? (raw['title'] as String).trim()
          : trimmed;
      return AddSubscriptionCategoryOption(
        id: id,
        title: title.isEmpty ? trimmed : title,
      );
    }

    final id = await _categories.upsertByName(trimmed);
    final category = await _categories.getById(id);
    return AddSubscriptionCategoryOption(
      id: id,
      title: category?.name ?? trimmed,
    );
  }

  Future<AddSubscriptionWorkflowResult> moveExistingToInitialCategory({
    required int feedId,
    required int targetCategoryId,
  }) async {
    if (_capabilities.isOnlineRequired(
      BackendFeature.moveSubscriptionToCategory,
    )) {
      final feed = await _feeds.getById(feedId);
      final category = await _categories.getById(targetCategoryId);
      final remoteFeedId = int.tryParse((feed?.remoteId ?? '').trim());
      final remoteCategoryId = int.tryParse((category?.remoteId ?? '').trim());
      if (remoteFeedId == null ||
          remoteFeedId <= 0 ||
          remoteCategoryId == null ||
          remoteCategoryId <= 0) {
        throw StateError('Remote feed or category id is missing');
      }
      final executor = await _buildMinifluxStructureExecutor();
      await executor.moveFeedToCategoryByIds(
        feedId: remoteFeedId,
        categoryId: remoteCategoryId,
      );
    }

    await _feeds.setCategory(feedId: feedId, categoryId: targetCategoryId);
    return AddSubscriptionWorkflowResult(
      feedId: feedId,
      categoryId: targetCategoryId,
    );
  }

  Future<AddSubscriptionWorkflowResult> submitCandidate({
    required AddSubscriptionCandidate candidate,
    required Uri feedUri,
    required int? selectedCategoryId,
    required bool categorySelected,
  }) {
    if (candidate.existingFeedId != null) {
      return Future.value(
        AddSubscriptionWorkflowResult(
          feedId: candidate.existingFeedId,
          existingFeedId: candidate.existingFeedId,
          existingCategoryId: candidate.existingCategoryId,
          candidate: candidate,
        ),
      );
    }

    if (_capabilities.isOnlineRequired(BackendFeature.addSubscription)) {
      return _submitCandidateMiniflux(
        candidate: candidate,
        feedUri: feedUri,
        selectedCategoryId: selectedCategoryId,
        categorySelected: categorySelected,
      );
    }

    return _submitCandidateLocal(
      candidate: candidate,
      feedUri: feedUri,
      selectedCategoryId: selectedCategoryId,
      categorySelected: categorySelected,
    );
  }

  Future<AddSubscriptionWorkflowResult> moveCandidateToSelectedCategory({
    required AddSubscriptionCandidate candidate,
    required int? targetCategoryId,
  }) async {
    final feedId = candidate.existingFeedId;
    if (feedId == null) {
      throw const AddSubscriptionFailure(AddSubscriptionFailureKind.validation);
    }

    if (_capabilities.isOnlineRequired(
      BackendFeature.moveSubscriptionToCategory,
    )) {
      if (targetCategoryId == null || targetCategoryId <= 0) {
        throw StateError('Remote category id is missing');
      }
      final feed = await _feeds.getById(feedId);
      final remoteFeedId = int.tryParse((feed?.remoteId ?? '').trim());
      if (remoteFeedId == null || remoteFeedId <= 0) {
        throw StateError('Remote feed id is missing');
      }
      final executor = await _buildMinifluxStructureExecutor();
      await executor.moveFeedToCategoryByIds(
        feedId: remoteFeedId,
        categoryId: targetCategoryId,
      );
      await _readSync().refreshFeedsSafe(const []);
    } else {
      await _feeds.setCategory(feedId: feedId, categoryId: targetCategoryId);
    }

    final updated = candidate.copyWith(existingCategoryId: targetCategoryId);
    return AddSubscriptionWorkflowResult(
      feedId: feedId,
      categoryId: targetCategoryId,
      candidate: updated,
    );
  }

  Future<AddSubscriptionWorkflowResult> submit({
    required Uri feedUri,
    required int? selectedCategoryId,
    required bool categorySelected,
  }) {
    if (_capabilities.isOnlineRequired(BackendFeature.addSubscription)) {
      return _submitMiniflux(
        feedUri: feedUri,
        selectedCategoryId: selectedCategoryId,
        categorySelected: categorySelected,
      );
    }

    return _submitLocal(
      feedUri: feedUri,
      selectedCategoryId: selectedCategoryId,
      categorySelected: categorySelected,
    );
  }

  Future<AddSubscriptionCategoryLoadResult> loadCategories({
    required int? initialCategoryId,
  }) async {
    if (_capabilities.isOnlineRequired(BackendFeature.addSubscription)) {
      final executor = await _buildMinifluxStructureExecutor();
      final rawCategories = await executor.listCategories();
      final categories =
          rawCategories
              .where((c) => c['id'] is int && c['title'] is String)
              .map(
                (c) => AddSubscriptionCategoryOption(
                  id: c['id'] as int,
                  title: (c['title'] as String).trim(),
                ),
              )
              .where((c) => c.id != null && c.id! > 0 && c.title.isNotEmpty)
              .toList(growable: false)
            ..sort((a, b) => a.title.compareTo(b.title));

      final selectedCategoryId = await _initialRemoteCategoryId(
        categories,
        initialCategoryId,
      );
      return AddSubscriptionCategoryLoadResult(
        categories: categories,
        selectedCategoryId: selectedCategoryId,
        categorySelected: selectedCategoryId != null,
      );
    }

    final categories = await _localCategoryOptions();
    final selectedCategoryId = _initialLocalCategoryId(
      categories,
      initialCategoryId,
    );
    return AddSubscriptionCategoryLoadResult(
      categories: categories,
      selectedCategoryId: selectedCategoryId,
      categorySelected: true,
    );
  }

  Future<Object?> refreshAddedLocalFeed(int feedId) async {
    try {
      final result = await _readSync().refreshFeedSafe(feedId);
      return result.ok ? null : result.error;
    } catch (error) {
      return error;
    }
  }

  Future<int?> resolveLocalFeedIdByUrl(String url) async {
    return (await resolveLocalFeedByUrl(url))?.id;
  }

  Future<Feed?> resolveLocalFeedByUrl(String url) async {
    String normalize(String input) {
      return input.trim().replaceAll(RegExp(r'/+$'), '');
    }

    final direct = await _feeds.getByUrl(url);
    if (direct != null) return direct;

    final target = normalize(url);
    if (target.isNotEmpty && target != url.trim()) {
      final alt = await _feeds.getByUrl(target);
      if (alt != null) return alt;
    }
    if (target.isNotEmpty) {
      final alt = await _feeds.getByUrl('$target/');
      if (alt != null) return alt;
    }

    final all = await _feeds.getAll();
    for (final f in all) {
      if (normalize(f.url) == target) return f;
    }
    return null;
  }

  Future<int?> candidateExistingCategoryId(Feed? feed) async {
    if (feed == null) return null;
    if (!_capabilities.isOnlineRequired(BackendFeature.addSubscription)) {
      return feed.categoryId;
    }
    final localCategoryId = feed.categoryId;
    if (localCategoryId == null) return null;
    final category = await _categories.getById(localCategoryId);
    final remoteId = int.tryParse((category?.remoteId ?? '').trim());
    return remoteId == null || remoteId <= 0 ? null : remoteId;
  }

  Future<AddSubscriptionWorkflowResult> _submitCandidateLocal({
    required AddSubscriptionCandidate candidate,
    required Uri feedUri,
    required int? selectedCategoryId,
    required bool categorySelected,
  }) async {
    final existingFeed = await resolveLocalFeedByUrl(feedUri.toString());
    if (existingFeed != null) {
      final updated = candidate.copyWith(
        existingFeedId: existingFeed.id,
        existingCategoryId: existingFeed.categoryId,
      );
      return AddSubscriptionWorkflowResult(
        feedId: existingFeed.id,
        existingFeedId: existingFeed.id,
        existingCategoryId: existingFeed.categoryId,
        candidate: updated,
      );
    }

    final feedId = await _feeds.upsertUrl(feedUri.toString());
    final categoryId = categorySelected ? selectedCategoryId : null;
    await _feeds.setCategory(feedId: feedId, categoryId: categoryId);
    final updated = candidate.copyWith(
      existingFeedId: feedId,
      existingCategoryId: categoryId,
    );
    return AddSubscriptionWorkflowResult(
      feedId: feedId,
      categoryId: categoryId,
      candidate: updated,
    );
  }

  Future<AddSubscriptionWorkflowResult> _submitCandidateMiniflux({
    required AddSubscriptionCandidate candidate,
    required Uri feedUri,
    required int? selectedCategoryId,
    required bool categorySelected,
  }) async {
    final categoryId = selectedCategoryId;
    if (!categorySelected || categoryId == null || categoryId <= 0) {
      throw const AddSubscriptionFailure(AddSubscriptionFailureKind.validation);
    }

    final existingFeed = await resolveLocalFeedByUrl(feedUri.toString());
    if (existingFeed != null) {
      final existingCategoryId = await candidateExistingCategoryId(
        existingFeed,
      );
      final updated = candidate.copyWith(
        existingFeedId: existingFeed.id,
        existingCategoryId: existingCategoryId,
      );
      return AddSubscriptionWorkflowResult(
        feedId: existingFeed.id,
        existingFeedId: existingFeed.id,
        existingCategoryId: existingCategoryId,
        candidate: updated,
      );
    }

    final executor = await _buildMinifluxStructureExecutor();
    final batch = await SyncMutex.instance.run('sync', () async {
      await executor.createFeed(
        feedUrl: feedUri.toString(),
        categoryId: categoryId,
      );
      return _readSync().refreshFeedsSafe(const []);
    });

    final feedId = await resolveLocalFeedIdByUrl(feedUri.toString());
    if (feedId == null) {
      final error =
          batch.firstError?.error ??
          StateError('Remote feed not found for url: ${feedUri.toString()}');
      throw error;
    }

    final updated = candidate.copyWith(
      existingFeedId: feedId,
      existingCategoryId: categoryId,
    );
    return AddSubscriptionWorkflowResult(
      feedId: feedId,
      categoryId: categoryId,
      candidate: updated,
      refreshWarning: batch.firstError?.error,
    );
  }

  Future<AddSubscriptionWorkflowResult> _submitLocal({
    required Uri feedUri,
    required int? selectedCategoryId,
    required bool categorySelected,
  }) async {
    final existingFeed = await resolveLocalFeedByUrl(feedUri.toString());
    if (existingFeed != null) {
      return AddSubscriptionWorkflowResult(
        feedId: existingFeed.id,
        existingFeedId: existingFeed.id,
        existingCategoryId: existingFeed.categoryId,
      );
    }

    final feedId = await _feeds.upsertUrl(feedUri.toString());
    await _feeds.setCategory(
      feedId: feedId,
      categoryId: categorySelected ? selectedCategoryId : null,
    );
    return AddSubscriptionWorkflowResult(
      feedId: feedId,
      categoryId: categorySelected ? selectedCategoryId : null,
    );
  }

  Future<AddSubscriptionWorkflowResult> _submitMiniflux({
    required Uri feedUri,
    required int? selectedCategoryId,
    required bool categorySelected,
  }) async {
    final existingFeed = await resolveLocalFeedByUrl(feedUri.toString());
    if (existingFeed != null) {
      return AddSubscriptionWorkflowResult(
        feedId: existingFeed.id,
        existingFeedId: existingFeed.id,
        existingCategoryId: existingFeed.categoryId,
      );
    }

    final categoryId = selectedCategoryId;
    if (!categorySelected || categoryId == null || categoryId <= 0) {
      throw const AddSubscriptionFailure(AddSubscriptionFailureKind.validation);
    }

    final executor = await _buildMinifluxStructureExecutor();
    final batch = await SyncMutex.instance.run('sync', () async {
      await executor.createFeed(
        feedUrl: feedUri.toString(),
        categoryId: categoryId,
      );
      return _readSync().refreshFeedsSafe(const []);
    });

    final feedId = await resolveLocalFeedIdByUrl(feedUri.toString());
    if (feedId == null) {
      final error =
          batch.firstError?.error ??
          StateError('Remote feed not found for url: ${feedUri.toString()}');
      throw error;
    }

    return AddSubscriptionWorkflowResult(
      feedId: feedId,
      categoryId: categoryId,
      refreshWarning: batch.firstError?.error,
    );
  }

  Future<MinifluxRemoteSubscriptionStructureExecutor>
  _buildMinifluxStructureExecutor() async {
    if (_account.type != AccountType.miniflux) {
      throw StateError('Remote add subscription requires Miniflux');
    }
    final client = await _remoteClients.miniflux(_account);
    return MinifluxRemoteSubscriptionStructureExecutor(client);
  }

  Future<List<AddSubscriptionCategoryOption>> _localCategoryOptions() async {
    final categories = await _categories.getAll();
    categories.sort((a, b) => a.name.compareTo(b.name));
    return <AddSubscriptionCategoryOption>[
      const AddSubscriptionCategoryOption.uncategorized(''),
      for (final c in categories) _categoryOption(c),
    ];
  }

  AddSubscriptionCategoryOption _categoryOption(Category category) {
    return AddSubscriptionCategoryOption(id: category.id, title: category.name);
  }

  int? _initialLocalCategoryId(
    List<AddSubscriptionCategoryOption> categories,
    int? initialCategoryId,
  ) {
    if (initialCategoryId == null) return null;
    for (final option in categories) {
      if (!option.isUncategorized && option.id == initialCategoryId) {
        return initialCategoryId;
      }
    }
    return null;
  }

  Future<int?> _initialRemoteCategoryId(
    List<AddSubscriptionCategoryOption> categories,
    int? initialCategoryId,
  ) async {
    if (initialCategoryId == null) return null;
    final category = await _categories.getById(initialCategoryId);
    final remoteId = int.tryParse((category?.remoteId ?? '').trim());
    if (remoteId == null || remoteId <= 0) return null;
    for (final option in categories) {
      if (option.id == remoteId) return remoteId;
    }
    return null;
  }
}
