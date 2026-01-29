import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Special ID representing the "Uncategorized" pseudo-category.
const kUncategorizedId = -1;

class SubscriptionState {
  /// The currently active category for the middle column (Feed List).
  /// - `null`: No category selected (Layout dependent: might hide middle column or show empty).
  /// - [kUncategorizedId]: The "Uncategorized" folder.
  /// - `> 0`: A valid Category ID.
  final int? activeCategoryId;

  /// The currently selected feed for the right column (Settings/Details).
  /// - `null`: No feed selected.
  final int? selectedFeedId;

  const SubscriptionState({this.activeCategoryId, this.selectedFeedId});

  SubscriptionState copyWith({
    int? activeCategoryId,
    int? selectedFeedId,
    bool clearFeed = false,
  }) {
    return SubscriptionState(
      activeCategoryId: activeCategoryId ?? this.activeCategoryId,
      selectedFeedId: clearFeed
          ? null
          : (selectedFeedId ?? this.selectedFeedId),
    );
  }

  /// Whether we are currently viewing the "Uncategorized" folder.
  bool get isUncategorized => activeCategoryId == kUncategorizedId;

  /// Whether a real, editable category is selected.
  bool get isRealCategory => activeCategoryId != null && activeCategoryId! > 0;
}

class SubscriptionSelectionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionSelectionNotifier() : super(const SubscriptionState());

  void selectCategory(int? id) {
    if (state.activeCategoryId == id && state.selectedFeedId == null) return;
    state = SubscriptionState(activeCategoryId: id, selectedFeedId: null);
  }

  void selectUncategorized() {
    selectCategory(kUncategorizedId);
  }

  void selectFeed(int feedId, [int? categoryId]) {
    // If categoryId is provided, we switch context.
    // Otherwise we keep existing category.
    state = SubscriptionState(
      activeCategoryId: categoryId ?? state.activeCategoryId,
      selectedFeedId: feedId,
    );
  }

  void clearSelection() {
    state = const SubscriptionState();
  }

  void clearFeedSelection() {
    state = state.copyWith(clearFeed: true);
  }
}

final subscriptionSelectionProvider =
    StateNotifierProvider<SubscriptionSelectionNotifier, SubscriptionState>((
      ref,
    ) {
      return SubscriptionSelectionNotifier();
    });
