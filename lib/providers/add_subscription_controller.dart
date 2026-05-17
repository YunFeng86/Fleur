import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../providers/account_providers.dart';
import '../providers/app_settings_providers.dart';
import '../providers/backend_capabilities_provider.dart';
import '../providers/repository_providers.dart';
import '../providers/service_providers.dart';
import '../services/accounts/account.dart';
import '../services/logging/app_logger.dart';
import '../services/rss/feed_discovery_service.dart';
import '../services/sync/backend_capabilities.dart';
import '../services/sync/remote_subscription_structure_executor.dart';
import '../services/sync/sync_mutex.dart';

const _unset = Object();

enum AddSubscriptionPhase {
  idle,
  discovering,
  selectingFeed,
  loadingCategories,
  selectingCategory,
  creatingCategory,
  submitting,
  alreadySubscribed,
  success,
  error,
}

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
class AddSubscriptionState {
  const AddSubscriptionState({
    this.phase = AddSubscriptionPhase.idle,
    this.input = '',
    this.candidates = const <DiscoveredFeed>[],
    this.selectedFeedUri,
    this.categories = const <AddSubscriptionCategoryOption>[],
    this.selectedCategoryId,
    this.categorySelected = false,
    this.initialCategoryId,
    this.completedFeedId,
    this.existingFeedId,
    this.failure,
  });

  final AddSubscriptionPhase phase;
  final String input;
  final List<DiscoveredFeed> candidates;
  final Uri? selectedFeedUri;
  final List<AddSubscriptionCategoryOption> categories;
  final int? selectedCategoryId;
  final bool categorySelected;
  final int? initialCategoryId;
  final int? completedFeedId;
  final int? existingFeedId;
  final AddSubscriptionFailure? failure;

  bool get isBusy {
    return switch (phase) {
      AddSubscriptionPhase.discovering ||
      AddSubscriptionPhase.loadingCategories ||
      AddSubscriptionPhase.creatingCategory ||
      AddSubscriptionPhase.submitting => true,
      AddSubscriptionPhase.idle ||
      AddSubscriptionPhase.selectingFeed ||
      AddSubscriptionPhase.selectingCategory ||
      AddSubscriptionPhase.alreadySubscribed ||
      AddSubscriptionPhase.success ||
      AddSubscriptionPhase.error => false,
    };
  }

  AddSubscriptionState copyWith({
    AddSubscriptionPhase? phase,
    String? input,
    List<DiscoveredFeed>? candidates,
    Object? selectedFeedUri = _unset,
    List<AddSubscriptionCategoryOption>? categories,
    Object? selectedCategoryId = _unset,
    bool? categorySelected,
    Object? initialCategoryId = _unset,
    Object? completedFeedId = _unset,
    Object? existingFeedId = _unset,
    Object? failure = _unset,
  }) {
    return AddSubscriptionState(
      phase: phase ?? this.phase,
      input: input ?? this.input,
      candidates: candidates ?? this.candidates,
      selectedFeedUri: identical(selectedFeedUri, _unset)
          ? this.selectedFeedUri
          : selectedFeedUri as Uri?,
      categories: categories ?? this.categories,
      selectedCategoryId: identical(selectedCategoryId, _unset)
          ? this.selectedCategoryId
          : selectedCategoryId as int?,
      categorySelected: categorySelected ?? this.categorySelected,
      initialCategoryId: identical(initialCategoryId, _unset)
          ? this.initialCategoryId
          : initialCategoryId as int?,
      completedFeedId: identical(completedFeedId, _unset)
          ? this.completedFeedId
          : completedFeedId as int?,
      existingFeedId: identical(existingFeedId, _unset)
          ? this.existingFeedId
          : existingFeedId as int?,
      failure: identical(failure, _unset)
          ? this.failure
          : failure as AddSubscriptionFailure?,
    );
  }
}

class AddSubscriptionController
    extends AutoDisposeNotifier<AddSubscriptionState> {
  @override
  AddSubscriptionState build() {
    ref.watch(activeAccountProvider);
    ref.watch(backendCapabilitiesProvider);
    return const AddSubscriptionState();
  }

  void reset() {
    state = const AddSubscriptionState();
  }

  Future<void> discover(String input, {int? initialCategoryId}) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      _setFailure(
        const AddSubscriptionFailure(AddSubscriptionFailureKind.validation),
        input: input,
      );
      return;
    }

    final capabilities = ref.read(backendCapabilitiesProvider);
    if (!capabilities.isVisible(BackendFeature.addSubscription)) {
      _setFailure(
        const AddSubscriptionFailure(AddSubscriptionFailureKind.unsupported),
        input: trimmed,
      );
      return;
    }

    state = AddSubscriptionState(
      phase: AddSubscriptionPhase.discovering,
      input: trimmed,
      initialCategoryId: initialCategoryId,
    );

    try {
      final appSettings = ref.read(appSettingsProvider).valueOrNull;
      final userAgent = (appSettings?.webUserAgent ?? '').trim();
      final candidates = await ref
          .read(feedDiscoveryServiceProvider)
          .discover(trimmed, userAgent: userAgent.isEmpty ? null : userAgent);

      if (candidates.isEmpty) {
        _setFailure(
          const AddSubscriptionFailure(AddSubscriptionFailureKind.noFeedsFound),
          input: trimmed,
        );
        return;
      }

      if (candidates.length == 1) {
        await selectFeed(
          candidates.first,
          candidates: candidates,
          initialCategoryId: initialCategoryId,
        );
        return;
      }

      state = AddSubscriptionState(
        phase: AddSubscriptionPhase.selectingFeed,
        input: trimmed,
        candidates: candidates,
        initialCategoryId: initialCategoryId,
      );
    } catch (error, stackTrace) {
      _logFailure('discoverFeed', error, stackTrace);
      _setFailure(
        AddSubscriptionFailure(AddSubscriptionFailureKind.discovery, error),
        input: trimmed,
      );
    }
  }

  Future<void> selectFeed(
    DiscoveredFeed feed, {
    List<DiscoveredFeed>? candidates,
    int? initialCategoryId,
  }) async {
    final uri = Uri.tryParse(feed.url);
    if (uri == null) {
      _setFailure(
        AddSubscriptionFailure(
          AddSubscriptionFailureKind.discovery,
          ArgumentError('Invalid feed URL: ${feed.url}'),
        ),
      );
      return;
    }

    final effectiveInitialCategoryId =
        initialCategoryId ?? state.initialCategoryId;
    state = state.copyWith(
      phase: AddSubscriptionPhase.loadingCategories,
      candidates: candidates ?? state.candidates,
      selectedFeedUri: uri,
      categories: const <AddSubscriptionCategoryOption>[],
      selectedCategoryId: null,
      categorySelected: false,
      initialCategoryId: effectiveInitialCategoryId,
      completedFeedId: null,
      existingFeedId: null,
      failure: null,
    );
    final existingFeedId = await _resolveLocalFeedIdByUrl(uri.toString());
    if (existingFeedId != null) {
      state = state.copyWith(
        phase: AddSubscriptionPhase.alreadySubscribed,
        selectedFeedUri: uri,
        existingFeedId: existingFeedId,
        failure: null,
      );
      return;
    }
    await _loadCategories();
  }

  Future<void> createCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        failure: const AddSubscriptionFailure(
          AddSubscriptionFailureKind.validation,
        ),
      );
      return;
    }

    final selectedFeedUri = state.selectedFeedUri;
    if (selectedFeedUri == null) {
      state = state.copyWith(
        phase: AddSubscriptionPhase.error,
        failure: const AddSubscriptionFailure(
          AddSubscriptionFailureKind.validation,
        ),
      );
      return;
    }

    final previous = state;
    state = state.copyWith(
      phase: AddSubscriptionPhase.creatingCategory,
      failure: null,
    );

    try {
      final capabilities = ref.read(backendCapabilitiesProvider);
      final AddSubscriptionCategoryOption created;
      if (capabilities.isOnlineRequired(BackendFeature.addSubscription)) {
        final executor = await _buildMinifluxStructureExecutor();
        final raw = await executor.createCategory(trimmed);
        final id = raw['id'];
        if (id is! int || id <= 0) {
          throw StateError('Unexpected Miniflux response for create category');
        }
        final title = raw['title'] is String
            ? (raw['title'] as String).trim()
            : trimmed;
        created = AddSubscriptionCategoryOption(
          id: id,
          title: title.isEmpty ? trimmed : title,
        );
      } else {
        final id = await ref
            .read(categoryRepositoryProvider)
            .upsertByName(trimmed);
        final category = await ref.read(categoryRepositoryProvider).getById(id);
        created = AddSubscriptionCategoryOption(
          id: id,
          title: category?.name ?? trimmed,
        );
      }

      final categories = _mergeCategoryOption(previous.categories, created);
      state = previous.copyWith(
        phase: AddSubscriptionPhase.selectingCategory,
        selectedFeedUri: selectedFeedUri,
        categories: categories,
        selectedCategoryId: created.id,
        categorySelected: true,
        failure: null,
      );
    } catch (error, stackTrace) {
      _logFailure('createCategoryForSubscription', error, stackTrace);
      state = previous.copyWith(
        phase: AddSubscriptionPhase.error,
        failure: AddSubscriptionFailure(_remoteOrCategoryFailureKind, error),
      );
    }
  }

  void selectCategory(AddSubscriptionCategoryOption option) {
    state = state.copyWith(
      phase: AddSubscriptionPhase.selectingCategory,
      selectedCategoryId: option.id,
      categorySelected: true,
      failure: null,
    );
  }

  Future<int?> submit() async {
    final selectedFeedUri = state.selectedFeedUri;
    if (selectedFeedUri == null) {
      _setFailure(
        const AddSubscriptionFailure(AddSubscriptionFailureKind.validation),
      );
      return null;
    }

    final capabilities = ref.read(backendCapabilitiesProvider);
    if (!capabilities.isVisible(BackendFeature.addSubscription)) {
      _setFailure(
        const AddSubscriptionFailure(AddSubscriptionFailureKind.unsupported),
      );
      return null;
    }

    if (capabilities.isOnlineRequired(BackendFeature.addSubscription)) {
      return _submitMiniflux(selectedFeedUri);
    }

    return _submitLocal(selectedFeedUri);
  }

  Future<void> _loadCategories() async {
    final selectedFeedUri = state.selectedFeedUri;
    if (selectedFeedUri == null) return;

    final capabilities = ref.read(backendCapabilitiesProvider);
    try {
      if (capabilities.isOnlineRequired(BackendFeature.addSubscription)) {
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

        final selectedCategoryId = await _initialRemoteCategoryId(categories);
        state = state.copyWith(
          phase: AddSubscriptionPhase.selectingCategory,
          selectedFeedUri: selectedFeedUri,
          categories: categories,
          selectedCategoryId: selectedCategoryId,
          categorySelected: selectedCategoryId != null,
          failure: null,
        );
        return;
      }

      final categories = await _localCategoryOptions();
      final selectedCategoryId = _initialLocalCategoryId(categories);
      state = state.copyWith(
        phase: AddSubscriptionPhase.selectingCategory,
        selectedFeedUri: selectedFeedUri,
        categories: categories,
        selectedCategoryId: selectedCategoryId,
        categorySelected: true,
        failure: null,
      );
    } catch (error, stackTrace) {
      _logFailure('loadCategoriesForSubscription', error, stackTrace);
      state = state.copyWith(
        phase: AddSubscriptionPhase.error,
        selectedFeedUri: selectedFeedUri,
        failure: AddSubscriptionFailure(_remoteOrCategoryFailureKind, error),
      );
    }
  }

  Future<int?> _submitLocal(Uri feedUri) async {
    final previous = state;
    state = state.copyWith(
      phase: AddSubscriptionPhase.submitting,
      failure: null,
    );
    try {
      final existingFeedId = await _resolveLocalFeedIdByUrl(feedUri.toString());
      if (existingFeedId != null) {
        state = previous.copyWith(
          phase: AddSubscriptionPhase.alreadySubscribed,
          existingFeedId: existingFeedId,
          failure: null,
        );
        return existingFeedId;
      }
      final feedId = await ref
          .read(feedRepositoryProvider)
          .upsertUrl(feedUri.toString());
      await ref
          .read(feedRepositoryProvider)
          .setCategory(
            feedId: feedId,
            categoryId: previous.categorySelected
                ? previous.selectedCategoryId
                : null,
          );
      final result = await ref
          .read(syncServiceProvider)
          .refreshFeedSafe(feedId);
      state = previous.copyWith(
        phase: AddSubscriptionPhase.success,
        completedFeedId: feedId,
        failure: result.ok
            ? null
            : AddSubscriptionFailure(
                AddSubscriptionFailureKind.submit,
                result.error,
              ),
      );
      return feedId;
    } catch (error, stackTrace) {
      _logFailure('addLocalSubscription', error, stackTrace);
      state = previous.copyWith(
        phase: AddSubscriptionPhase.error,
        failure: AddSubscriptionFailure(
          AddSubscriptionFailureKind.submit,
          error,
        ),
      );
      return null;
    }
  }

  Future<int?> _submitMiniflux(Uri feedUri) async {
    final previous = state;
    final existingFeedId = await _resolveLocalFeedIdByUrl(feedUri.toString());
    if (existingFeedId != null) {
      state = previous.copyWith(
        phase: AddSubscriptionPhase.alreadySubscribed,
        existingFeedId: existingFeedId,
        failure: null,
      );
      return existingFeedId;
    }
    final categoryId = previous.selectedCategoryId;
    if (!previous.categorySelected || categoryId == null || categoryId <= 0) {
      state = previous.copyWith(
        failure: const AddSubscriptionFailure(
          AddSubscriptionFailureKind.validation,
        ),
      );
      return null;
    }

    state = state.copyWith(
      phase: AddSubscriptionPhase.submitting,
      failure: null,
    );
    try {
      final executor = await _buildMinifluxStructureExecutor();
      final batch = await SyncMutex.instance.run('sync', () async {
        await executor.createFeed(
          feedUrl: feedUri.toString(),
          categoryId: categoryId,
        );
        return ref.read(syncServiceProvider).refreshFeedsSafe(const []);
      });

      final feedId = await _resolveLocalFeedIdByUrl(feedUri.toString());
      if (feedId == null) {
        final error =
            batch.firstError?.error ??
            StateError('Remote feed not found for url: ${feedUri.toString()}');
        throw error;
      }

      state = previous.copyWith(
        phase: AddSubscriptionPhase.success,
        completedFeedId: feedId,
        failure: batch.firstError == null
            ? null
            : AddSubscriptionFailure(
                AddSubscriptionFailureKind.submit,
                batch.firstError!.error,
              ),
      );
      return feedId;
    } catch (error, stackTrace) {
      _logFailure('addRemoteSubscription', error, stackTrace);
      state = previous.copyWith(
        phase: AddSubscriptionPhase.error,
        failure: AddSubscriptionFailure(
          AddSubscriptionFailureKind.remoteStructure,
          error,
        ),
      );
      return null;
    }
  }

  Future<MinifluxRemoteSubscriptionStructureExecutor>
  _buildMinifluxStructureExecutor() async {
    final account = ref.read(activeAccountProvider);
    if (account.type != AccountType.miniflux) {
      throw StateError('Remote add subscription requires Miniflux');
    }
    final client = await ref
        .read(remoteClientFactoryProvider)
        .miniflux(account);
    return MinifluxRemoteSubscriptionStructureExecutor(client);
  }

  Future<List<AddSubscriptionCategoryOption>> _localCategoryOptions() async {
    final categories = await ref.read(categoryRepositoryProvider).getAll();
    categories.sort((a, b) => a.name.compareTo(b.name));
    return <AddSubscriptionCategoryOption>[
      const AddSubscriptionCategoryOption.uncategorized(''),
      for (final c in categories) _categoryOption(c),
    ];
  }

  AddSubscriptionCategoryOption _categoryOption(Category category) {
    return AddSubscriptionCategoryOption(id: category.id, title: category.name);
  }

  int? _initialLocalCategoryId(List<AddSubscriptionCategoryOption> categories) {
    final id = state.initialCategoryId;
    if (id == null) return null;
    for (final option in categories) {
      if (!option.isUncategorized && option.id == id) return id;
    }
    return null;
  }

  Future<int?> _initialRemoteCategoryId(
    List<AddSubscriptionCategoryOption> categories,
  ) async {
    final localCategoryId = state.initialCategoryId;
    if (localCategoryId == null) return null;
    final category = await ref
        .read(categoryRepositoryProvider)
        .getById(localCategoryId);
    final remoteId = int.tryParse((category?.remoteId ?? '').trim());
    if (remoteId == null || remoteId <= 0) return null;
    for (final option in categories) {
      if (option.id == remoteId) return remoteId;
    }
    return null;
  }

  List<AddSubscriptionCategoryOption> _mergeCategoryOption(
    List<AddSubscriptionCategoryOption> options,
    AddSubscriptionCategoryOption created,
  ) {
    final merged = <AddSubscriptionCategoryOption>[
      for (final option in options)
        if (option.id != created.id) option,
      created,
    ];
    final leading = merged
        .where((option) => option.isUncategorized)
        .toList(growable: false);
    final rest = merged.where((option) => !option.isUncategorized).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return [...leading, ...rest];
  }

  Future<int?> _resolveLocalFeedIdByUrl(String url) async {
    String normalize(String input) {
      return input.trim().replaceAll(RegExp(r'/+$'), '');
    }

    final feeds = ref.read(feedRepositoryProvider);
    final direct = await feeds.getByUrl(url);
    if (direct != null) return direct.id;

    final target = normalize(url);
    if (target.isNotEmpty && target != url.trim()) {
      final alt = await feeds.getByUrl(target);
      if (alt != null) return alt.id;
    }
    if (target.isNotEmpty) {
      final alt = await feeds.getByUrl('$target/');
      if (alt != null) return alt.id;
    }

    final all = await feeds.getAll();
    for (final f in all) {
      if (normalize(f.url) == target) return f.id;
    }
    return null;
  }

  AddSubscriptionFailureKind get _remoteOrCategoryFailureKind {
    final capabilities = ref.read(backendCapabilitiesProvider);
    return capabilities.isOnlineRequired(BackendFeature.addSubscription)
        ? AddSubscriptionFailureKind.remoteStructure
        : AddSubscriptionFailureKind.category;
  }

  void _setFailure(AddSubscriptionFailure failure, {String? input}) {
    state = state.copyWith(
      phase: AddSubscriptionPhase.error,
      input: input,
      failure: failure,
      completedFeedId: null,
      existingFeedId: null,
    );
  }

  void _logFailure(String operation, Object error, [StackTrace? stackTrace]) {
    final account = ref.read(activeAccountProvider);
    AppLogger.w(
      'Add subscription page operation failed',
      tag: 'subscription',
      error: error,
      stackTrace: stackTrace,
      context: <String, Object?>{
        'operation': operation,
        'accountId': account.id,
        'accountType': account.type.wire,
      },
    );
  }
}

final addSubscriptionControllerProvider =
    AutoDisposeNotifierProvider<
      AddSubscriptionController,
      AddSubscriptionState
    >(AddSubscriptionController.new);
