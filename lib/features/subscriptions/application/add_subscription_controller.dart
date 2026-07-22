import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/account_providers.dart';
import '../../../providers/app_settings_providers.dart';
import '../../../providers/backend_capabilities_provider.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../services/accounts/account.dart';
import '../../../services/logging/app_logger.dart';
import '../../../services/rss/feed_discovery_service.dart';
import '../../../services/sync/backend_capabilities.dart';
import 'add_subscription_workflow.dart';

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

@immutable
class AddSubscriptionState {
  const AddSubscriptionState({
    this.phase = AddSubscriptionPhase.idle,
    this.input = '',
    this.candidates = const <AddSubscriptionCandidate>[],
    this.selectedCandidate,
    this.selectedFeedUri,
    this.categories = const <AddSubscriptionCategoryOption>[],
    this.selectedCategoryId,
    this.categorySelected = false,
    this.initialCategoryId,
    this.completedFeedId,
    this.existingFeedId,
    this.existingFeedCategoryId,
    this.activeCandidateUrl,
    this.failure,
    this.refreshWarning,
  });

  final AddSubscriptionPhase phase;
  final String input;
  final List<AddSubscriptionCandidate> candidates;
  final AddSubscriptionCandidate? selectedCandidate;
  final Uri? selectedFeedUri;
  final List<AddSubscriptionCategoryOption> categories;
  final int? selectedCategoryId;
  final bool categorySelected;
  final int? initialCategoryId;
  final int? completedFeedId;
  final int? existingFeedId;
  final int? existingFeedCategoryId;
  final String? activeCandidateUrl;
  final AddSubscriptionFailure? failure;
  final Object? refreshWarning;

  bool get canMoveExistingToInitialCategory {
    return phase == AddSubscriptionPhase.alreadySubscribed &&
        existingFeedId != null &&
        initialCategoryId != null &&
        existingFeedCategoryId != initialCategoryId;
  }

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
    List<AddSubscriptionCandidate>? candidates,
    Object? selectedCandidate = _unset,
    Object? selectedFeedUri = _unset,
    List<AddSubscriptionCategoryOption>? categories,
    Object? selectedCategoryId = _unset,
    bool? categorySelected,
    Object? initialCategoryId = _unset,
    Object? completedFeedId = _unset,
    Object? existingFeedId = _unset,
    Object? existingFeedCategoryId = _unset,
    Object? activeCandidateUrl = _unset,
    Object? failure = _unset,
    Object? refreshWarning = _unset,
  }) {
    return AddSubscriptionState(
      phase: phase ?? this.phase,
      input: input ?? this.input,
      candidates: candidates ?? this.candidates,
      selectedCandidate: identical(selectedCandidate, _unset)
          ? this.selectedCandidate
          : selectedCandidate as AddSubscriptionCandidate?,
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
      existingFeedCategoryId: identical(existingFeedCategoryId, _unset)
          ? this.existingFeedCategoryId
          : existingFeedCategoryId as int?,
      activeCandidateUrl: identical(activeCandidateUrl, _unset)
          ? this.activeCandidateUrl
          : activeCandidateUrl as String?,
      failure: identical(failure, _unset)
          ? this.failure
          : failure as AddSubscriptionFailure?,
      refreshWarning: identical(refreshWarning, _unset)
          ? this.refreshWarning
          : refreshWarning,
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

  AddSubscriptionWorkflow get _workflow =>
      ref.read(addSubscriptionWorkflowProvider);

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

    final AddSubscriptionWorkflow workflow;
    final List<AddSubscriptionCandidate> decoratedCandidates;
    try {
      workflow = _workflow;
      decoratedCandidates = await workflow.discover(trimmed);

      if (decoratedCandidates.isEmpty) {
        _setFailure(
          const AddSubscriptionFailure(AddSubscriptionFailureKind.noFeedsFound),
          input: trimmed,
        );
        return;
      }
    } catch (error, stackTrace) {
      _logFailure('discoverFeed', error, stackTrace);
      _setFailure(
        AddSubscriptionFailure(AddSubscriptionFailureKind.discovery, error),
        input: trimmed,
      );
      return;
    }

    state = AddSubscriptionState(
      phase: AddSubscriptionPhase.loadingCategories,
      input: trimmed,
      candidates: decoratedCandidates,
      initialCategoryId: initialCategoryId,
    );

    try {
      final categories = await workflow.loadCategories(
        initialCategoryId: initialCategoryId,
      );
      state = state.copyWith(
        phase: AddSubscriptionPhase.selectingCategory,
        categories: categories.categories,
        selectedCategoryId: categories.selectedCategoryId,
        categorySelected: categories.categorySelected,
        selectedCandidate: null,
        selectedFeedUri: null,
        failure: null,
      );
    } catch (error, stackTrace) {
      _logFailure('loadCategoriesForSubscriptionResults', error, stackTrace);
      state = state.copyWith(
        phase: AddSubscriptionPhase.error,
        failure: AddSubscriptionFailure(
          workflow.remoteOrCategoryFailureKind,
          error,
        ),
      );
    }
  }

  Future<void> selectFeed(
    DiscoveredFeed feed, {
    List<DiscoveredFeed>? candidates,
    int? initialCategoryId,
  }) async {
    final decoratedCandidates = candidates == null
        ? null
        : await _workflow.decorateCandidates(candidates);
    final candidate = decoratedCandidates?.firstWhere(
      (candidate) => candidate.feed.url == feed.url,
      orElse: () => AddSubscriptionCandidate(feed: feed),
    );
    await selectCandidate(
      candidate ?? await _workflow.decorateCandidate(feed),
      candidates: decoratedCandidates,
      initialCategoryId: initialCategoryId,
    );
  }

  Future<void> selectCandidate(
    AddSubscriptionCandidate candidate, {
    List<AddSubscriptionCandidate>? candidates,
    int? initialCategoryId,
  }) async {
    final feed = candidate.feed;
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
      selectedCandidate: candidate,
      selectedFeedUri: uri,
      categories: const <AddSubscriptionCategoryOption>[],
      selectedCategoryId: null,
      categorySelected: false,
      initialCategoryId: effectiveInitialCategoryId,
      completedFeedId: null,
      existingFeedId: null,
      existingFeedCategoryId: null,
      failure: null,
      refreshWarning: null,
    );
    final selection = await _workflow.resolveSelection(candidate);
    if (selection.existingFeedId != null) {
      state = state.copyWith(
        phase: AddSubscriptionPhase.alreadySubscribed,
        selectedFeedUri: selection.selectedFeedUri,
        existingFeedId: selection.existingFeedId,
        existingFeedCategoryId: selection.existingCategoryId,
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

    final previous = state;
    final selectedFeedUri = previous.selectedFeedUri;
    if (selectedFeedUri == null && previous.candidates.isEmpty) {
      state = state.copyWith(
        phase: AddSubscriptionPhase.error,
        failure: const AddSubscriptionFailure(
          AddSubscriptionFailureKind.validation,
        ),
      );
      return;
    }

    state = state.copyWith(
      phase: AddSubscriptionPhase.creatingCategory,
      failure: null,
    );

    try {
      final created = await _workflow.createCategory(trimmed);

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

  Future<void> moveExistingToInitialCategory() async {
    final feedId = state.existingFeedId;
    final targetCategoryId = state.initialCategoryId;
    if (feedId == null || targetCategoryId == null) {
      _setFailure(
        const AddSubscriptionFailure(AddSubscriptionFailureKind.validation),
      );
      return;
    }

    final capabilities = ref.read(backendCapabilitiesProvider);
    if (!capabilities.isVisible(BackendFeature.moveSubscriptionToCategory)) {
      _setFailure(
        const AddSubscriptionFailure(AddSubscriptionFailureKind.unsupported),
      );
      return;
    }

    final previous = state;
    state = state.copyWith(
      phase: AddSubscriptionPhase.submitting,
      failure: null,
      refreshWarning: null,
    );

    try {
      await _workflow.moveExistingToInitialCategory(
        feedId: feedId,
        targetCategoryId: targetCategoryId,
      );
      state = previous.copyWith(
        phase: AddSubscriptionPhase.alreadySubscribed,
        existingFeedCategoryId: targetCategoryId,
        failure: null,
        refreshWarning: null,
      );
    } catch (error, stackTrace) {
      _logFailure(
        'moveExistingSubscriptionToInitialCategory',
        error,
        stackTrace,
      );
      state = previous.copyWith(
        phase: AddSubscriptionPhase.error,
        failure: AddSubscriptionFailure(_remoteOrCategoryFailureKind, error),
      );
    }
  }

  bool canMoveCandidateToSelectedCategory(AddSubscriptionCandidate candidate) {
    if (!candidate.isAlreadySubscribed ||
        state.initialCategoryId == null ||
        !state.categorySelected) {
      return false;
    }
    return candidate.existingCategoryId != state.selectedCategoryId;
  }

  Future<int?> submitCandidate(AddSubscriptionCandidate candidate) async {
    final uri = Uri.tryParse(candidate.feed.url);
    if (uri == null) {
      _setFailure(
        AddSubscriptionFailure(
          AddSubscriptionFailureKind.discovery,
          ArgumentError('Invalid feed URL: ${candidate.feed.url}'),
        ),
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

    if (candidate.existingFeedId != null) return candidate.existingFeedId;

    if (capabilities.isOnlineRequired(BackendFeature.addSubscription)) {
      final categoryId = state.selectedCategoryId;
      if (!state.categorySelected || categoryId == null || categoryId <= 0) {
        state = state.copyWith(
          failure: const AddSubscriptionFailure(
            AddSubscriptionFailureKind.validation,
          ),
        );
        return null;
      }
    }

    final previous = state;
    state = state.copyWith(
      phase: AddSubscriptionPhase.submitting,
      activeCandidateUrl: candidate.feed.url,
      failure: null,
      refreshWarning: null,
    );

    try {
      final result = await _workflow.submitCandidate(
        candidate: candidate,
        feedUri: uri,
        selectedCategoryId: previous.selectedCategoryId,
        categorySelected: previous.categorySelected,
      );
      final updated = result.candidate ?? candidate;
      if (result.existingFeedId != null) {
        state = previous.copyWith(
          phase: AddSubscriptionPhase.selectingCategory,
          candidates: _replaceCandidate(updated),
          activeCandidateUrl: null,
          failure: null,
        );
        return result.existingFeedId;
      }

      final feedId = result.feedId;
      state = previous.copyWith(
        phase: AddSubscriptionPhase.selectingCategory,
        candidates: _replaceCandidate(updated),
        completedFeedId: feedId,
        activeCandidateUrl: null,
        failure: null,
        refreshWarning: result.refreshWarning,
      );
      if (feedId != null) {
        unawaited(_refreshAddedLocalFeed(feedId));
      }
      return feedId;
    } catch (error, stackTrace) {
      final failureKind =
          capabilities.isOnlineRequired(BackendFeature.addSubscription)
          ? AddSubscriptionFailureKind.remoteStructure
          : AddSubscriptionFailureKind.submit;
      _logFailure(
        capabilities.isOnlineRequired(BackendFeature.addSubscription)
            ? 'addRemoteSubscriptionCandidate'
            : 'addLocalSubscriptionCandidate',
        error,
        stackTrace,
      );
      state = previous.copyWith(
        phase: AddSubscriptionPhase.selectingCategory,
        activeCandidateUrl: null,
        failure: _failureFromError(error, fallback: failureKind),
      );
      return null;
    }
  }

  Future<void> moveCandidateToSelectedCategory(
    AddSubscriptionCandidate candidate,
  ) async {
    if (candidate.existingFeedId == null || !state.categorySelected) {
      _setFailure(
        const AddSubscriptionFailure(AddSubscriptionFailureKind.validation),
      );
      return;
    }

    final capabilities = ref.read(backendCapabilitiesProvider);
    if (!capabilities.isVisible(BackendFeature.moveSubscriptionToCategory)) {
      _setFailure(
        const AddSubscriptionFailure(AddSubscriptionFailureKind.unsupported),
      );
      return;
    }

    final targetCategoryId = state.selectedCategoryId;
    final previous = state;
    state = state.copyWith(
      phase: AddSubscriptionPhase.submitting,
      activeCandidateUrl: candidate.feed.url,
      failure: null,
      refreshWarning: null,
    );

    try {
      final result = await _workflow.moveCandidateToSelectedCategory(
        candidate: candidate,
        targetCategoryId: targetCategoryId,
      );
      final updated = result.candidate ?? candidate;
      state = previous.copyWith(
        phase: AddSubscriptionPhase.selectingCategory,
        candidates: _replaceCandidate(updated),
        activeCandidateUrl: null,
        failure: null,
        refreshWarning: null,
      );
    } catch (error, stackTrace) {
      _logFailure(
        'moveSubscriptionCandidateToSelectedCategory',
        error,
        stackTrace,
      );
      state = previous.copyWith(
        phase: AddSubscriptionPhase.selectingCategory,
        activeCandidateUrl: null,
        failure: AddSubscriptionFailure(_remoteOrCategoryFailureKind, error),
      );
    }
  }

  Future<int?> submit() async {
    final selectedFeedUri = state.selectedFeedUri;
    if (selectedFeedUri == null && state.candidates.length == 1) {
      return submitCandidate(state.candidates.single);
    }
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
      final categoryId = state.selectedCategoryId;
      if (!state.categorySelected || categoryId == null || categoryId <= 0) {
        state = state.copyWith(
          failure: const AddSubscriptionFailure(
            AddSubscriptionFailureKind.validation,
          ),
        );
        return null;
      }
    }

    final previous = state;
    state = state.copyWith(
      phase: AddSubscriptionPhase.submitting,
      failure: null,
    );

    try {
      final result = await _workflow.submit(
        feedUri: selectedFeedUri,
        selectedCategoryId: previous.selectedCategoryId,
        categorySelected: previous.categorySelected,
      );
      if (result.existingFeedId != null) {
        state = previous.copyWith(
          phase: AddSubscriptionPhase.alreadySubscribed,
          existingFeedId: result.existingFeedId,
          existingFeedCategoryId: result.existingCategoryId,
          failure: null,
        );
        return result.existingFeedId;
      }

      final feedId = result.feedId;
      state = previous.copyWith(
        phase: AddSubscriptionPhase.success,
        completedFeedId: feedId,
        failure: null,
        refreshWarning: result.refreshWarning,
      );
      if (feedId != null) {
        unawaited(_refreshAddedLocalFeed(feedId));
      }
      return feedId;
    } catch (error, stackTrace) {
      final failureKind =
          capabilities.isOnlineRequired(BackendFeature.addSubscription)
          ? AddSubscriptionFailureKind.remoteStructure
          : AddSubscriptionFailureKind.submit;
      _logFailure(
        capabilities.isOnlineRequired(BackendFeature.addSubscription)
            ? 'addRemoteSubscription'
            : 'addLocalSubscription',
        error,
        stackTrace,
      );
      state = previous.copyWith(
        phase: AddSubscriptionPhase.error,
        failure: _failureFromError(error, fallback: failureKind),
      );
      return null;
    }
  }

  Future<void> _loadCategories() async {
    final selectedFeedUri = state.selectedFeedUri;
    if (selectedFeedUri == null) return;

    try {
      final result = await _workflow.loadCategories(
        initialCategoryId: state.initialCategoryId,
      );
      state = state.copyWith(
        phase: AddSubscriptionPhase.selectingCategory,
        selectedFeedUri: selectedFeedUri,
        categories: result.categories,
        selectedCategoryId: result.selectedCategoryId,
        categorySelected: result.categorySelected,
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

  List<AddSubscriptionCandidate> _replaceCandidate(
    AddSubscriptionCandidate updated,
  ) {
    return [
      for (final candidate in state.candidates)
        if (candidate.feed.url == updated.feed.url) updated else candidate,
    ];
  }

  Future<void> _refreshAddedLocalFeed(int feedId) async {
    try {
      final warning = await _workflow.refreshAddedLocalFeed(feedId);
      if (warning == null) return;
      if (state.completedFeedId != feedId) {
        return;
      }
      state = state.copyWith(refreshWarning: warning);
    } catch (error, stackTrace) {
      _logFailure('refreshAddedLocalSubscription', error, stackTrace);
      if (state.completedFeedId != feedId) {
        return;
      }
      state = state.copyWith(refreshWarning: error);
    }
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

  AddSubscriptionFailureKind get _remoteOrCategoryFailureKind {
    return _workflow.remoteOrCategoryFailureKind;
  }

  AddSubscriptionFailure _failureFromError(
    Object error, {
    required AddSubscriptionFailureKind fallback,
  }) {
    return error is AddSubscriptionFailure
        ? error
        : AddSubscriptionFailure(fallback, error);
  }

  void _setFailure(AddSubscriptionFailure failure, {String? input}) {
    state = state.copyWith(
      phase: AddSubscriptionPhase.error,
      input: input,
      failure: failure,
      completedFeedId: null,
      existingFeedId: null,
      existingFeedCategoryId: null,
      activeCandidateUrl: null,
      refreshWarning: null,
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

final addSubscriptionWorkflowProvider = Provider<AddSubscriptionWorkflow>(
  (ref) {
    final appSettings = ref.watch(appSettingsProvider).valueOrNull;
    return AddSubscriptionWorkflow(
      account: ref.watch(activeAccountProvider),
      capabilities: ref.watch(backendCapabilitiesProvider),
      discovery: ref.watch(feedDiscoveryServiceProvider),
      feeds: ref.watch(feedRepositoryProvider),
      categories: ref.watch(categoryRepositoryProvider),
      readSync: () => ref.read(syncServiceProvider),
      remoteClients: ref.watch(remoteClientFactoryProvider),
      webUserAgent: appSettings?.webUserAgent,
    );
  },
  dependencies: [
    activeAccountProvider,
    backendCapabilitiesProvider,
    appSettingsProvider,
    feedDiscoveryServiceProvider,
    feedRepositoryProvider,
    categoryRepositoryProvider,
    syncServiceProvider,
    remoteClientFactoryProvider,
  ],
);

final addSubscriptionControllerProvider =
    AutoDisposeNotifierProvider<
      AddSubscriptionController,
      AddSubscriptionState
    >(
      AddSubscriptionController.new,
      dependencies: [
        activeAccountProvider,
        backendCapabilitiesProvider,
        addSubscriptionWorkflowProvider,
      ],
    );
