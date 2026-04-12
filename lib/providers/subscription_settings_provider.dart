import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class SubscriptionCategoryScope {
  const SubscriptionCategoryScope();
}

final class SubscriptionCategoryAll extends SubscriptionCategoryScope {
  const SubscriptionCategoryAll();
}

final class SubscriptionCategoryUncategorized
    extends SubscriptionCategoryScope {
  const SubscriptionCategoryUncategorized();
}

final class SubscriptionCategoryId extends SubscriptionCategoryScope {
  const SubscriptionCategoryId(this.id);

  final int id;
}

sealed class SubscriptionDetailTarget {
  const SubscriptionDetailTarget();
}

final class SubscriptionScopeOverview extends SubscriptionDetailTarget {
  const SubscriptionScopeOverview();
}

final class SubscriptionGlobalDefaults extends SubscriptionDetailTarget {
  const SubscriptionGlobalDefaults();
}

final class SubscriptionCategorySettingsTarget
    extends SubscriptionDetailTarget {
  const SubscriptionCategorySettingsTarget(this.categoryId);

  final int categoryId;
}

final class SubscriptionFeedDetailsTarget extends SubscriptionDetailTarget {
  const SubscriptionFeedDetailsTarget(this.feedId);

  final int feedId;
}

class SubscriptionState {
  /// The currently active category scope for the middle column (Feed List).
  ///
  /// This is intentionally *not* an `int?` to avoid sentinel values like `-1`
  /// for "Uncategorized".
  final SubscriptionCategoryScope categoryScope;

  /// The active detail target shown in the detail pane.
  final SubscriptionDetailTarget detailTarget;

  /// Whether stacked layouts should currently show the detail pane instead of
  /// the navigation tree.
  final bool showDetailPane;

  const SubscriptionState({
    this.categoryScope = const SubscriptionCategoryAll(),
    this.detailTarget = const SubscriptionGlobalDefaults(),
    this.showDetailPane = false,
  });

  SubscriptionState copyWith({
    SubscriptionCategoryScope? categoryScope,
    SubscriptionDetailTarget? detailTarget,
    bool? showDetailPane,
  }) {
    return SubscriptionState(
      categoryScope: categoryScope ?? this.categoryScope,
      detailTarget: detailTarget ?? this.detailTarget,
      showDetailPane: showDetailPane ?? this.showDetailPane,
    );
  }

  int? get activeCategoryId => switch (categoryScope) {
    SubscriptionCategoryId(:final id) => id,
    _ => null,
  };

  /// Whether we are currently viewing the "Uncategorized" folder.
  bool get isUncategorized =>
      categoryScope is SubscriptionCategoryUncategorized;

  bool get isAll => categoryScope is SubscriptionCategoryAll;

  /// Whether a real, editable category is selected.
  bool get isRealCategory => categoryScope is SubscriptionCategoryId;

  bool get isScopeOverview => detailTarget is SubscriptionScopeOverview;

  bool get isGlobalDefaults => detailTarget is SubscriptionGlobalDefaults;

  bool get isCategorySettings =>
      detailTarget is SubscriptionCategorySettingsTarget;

  int? get selectedFeedId => switch (detailTarget) {
    SubscriptionFeedDetailsTarget(:final feedId) => feedId,
    _ => null,
  };

  bool get isRootState => isAll && isGlobalDefaults && !showDetailPane;

  bool get canHandleBack => !isRootState;

  bool matchesCategoryId(int? categoryId) => switch (categoryScope) {
    SubscriptionCategoryAll() => true,
    SubscriptionCategoryUncategorized() => categoryId == null,
    SubscriptionCategoryId(:final id) => categoryId == id,
  };

  SubscriptionDetailTarget detailTargetForScope() => switch (categoryScope) {
    SubscriptionCategoryId(:final id) => SubscriptionCategorySettingsTarget(id),
    _ => const SubscriptionGlobalDefaults(),
  };
}

class SubscriptionSelectionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionSelectionNotifier() : super(const SubscriptionState());

  void selectAll({bool showDetailPane = false}) {
    state = SubscriptionState(
      categoryScope: const SubscriptionCategoryAll(),
      detailTarget: const SubscriptionGlobalDefaults(),
      showDetailPane: showDetailPane,
    );
  }

  void selectUncategorized({bool showDetailPane = false}) {
    state = SubscriptionState(
      categoryScope: SubscriptionCategoryUncategorized(),
      detailTarget: const SubscriptionScopeOverview(),
      showDetailPane: showDetailPane,
    );
  }

  void selectCategory(int id, {bool showDetailPane = false}) {
    final isSelectedCategoryDetails =
        state.activeCategoryId == id &&
        state.detailTarget is SubscriptionCategorySettingsTarget &&
        state.selectedFeedId == null;

    if (isSelectedCategoryDetails) {
      selectAll(showDetailPane: showDetailPane);
      return;
    }

    state = SubscriptionState(
      categoryScope: SubscriptionCategoryId(id),
      detailTarget: SubscriptionCategorySettingsTarget(id),
      showDetailPane: showDetailPane,
    );
  }

  void showGlobalDefaults({bool showDetailPane = false}) {
    state = state.copyWith(
      detailTarget: const SubscriptionGlobalDefaults(),
      showDetailPane: showDetailPane,
    );
  }

  void showScopeOverview({bool showDetailPane = false}) {
    state = state.copyWith(
      detailTarget: const SubscriptionScopeOverview(),
      showDetailPane: showDetailPane,
    );
  }

  void returnToScopeDetails({bool? showDetailPane}) {
    state = state.copyWith(
      detailTarget: state.detailTargetForScope(),
      showDetailPane: showDetailPane ?? state.showDetailPane,
    );
  }

  void selectFeed(
    int feedId, {
    SubscriptionCategoryScope? categoryScope,
    bool showDetailPane = false,
  }) {
    state = SubscriptionState(
      categoryScope: categoryScope ?? state.categoryScope,
      detailTarget: SubscriptionFeedDetailsTarget(feedId),
      showDetailPane: showDetailPane,
    );
  }

  bool handleBack() {
    if (state.detailTarget case SubscriptionFeedDetailsTarget()) {
      state = state.copyWith(
        detailTarget: state.detailTargetForScope(),
        showDetailPane: state.showDetailPane,
      );
      return false;
    }

    if (state.showDetailPane) {
      state = state.copyWith(showDetailPane: false);
      return false;
    }

    if (state.detailTarget case SubscriptionGlobalDefaults()) {
      state = state.copyWith(detailTarget: state.detailTargetForScope());
      return false;
    }

    if (!state.isAll) {
      state = const SubscriptionState();
      return false;
    }

    return true;
  }
}

final subscriptionSelectionProvider =
    StateNotifierProvider<SubscriptionSelectionNotifier, SubscriptionState>((
      ref,
    ) {
      return SubscriptionSelectionNotifier();
    });
