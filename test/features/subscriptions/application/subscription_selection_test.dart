import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/features/subscriptions/subscriptions.dart';

void main() {
  late SubscriptionSelectionNotifier notifier;

  setUp(() {
    notifier = SubscriptionSelectionNotifier();
  });

  test('selecting scopes exposes typed category semantics', () {
    notifier.selectUncategorized(showDetailPane: true);

    expect(notifier.state.isUncategorized, isTrue);
    expect(notifier.state.matchesCategoryId(null), isTrue);
    expect(notifier.state.matchesCategoryId(4), isFalse);
    expect(notifier.state.isScopeOverview, isTrue);
    expect(notifier.state.showDetailPane, isTrue);

    notifier.selectCategory(4);
    expect(notifier.state.activeCategoryId, 4);
    expect(notifier.state.isCategorySettings, isTrue);
    expect(
      notifier.state.detailTargetForScope(),
      isA<SubscriptionCategorySettingsTarget>(),
    );
  });

  test('selecting the active category toggles back to all', () {
    notifier.selectCategory(7);
    notifier.selectCategory(7, showDetailPane: true);

    expect(notifier.state.isAll, isTrue);
    expect(notifier.state.isGlobalDefaults, isTrue);
    expect(notifier.state.showDetailPane, isTrue);
  });

  test('back handling follows feed, pane, scope, and root order', () {
    notifier.selectCategory(7, showDetailPane: true);
    notifier.selectFeed(12, showDetailPane: true);

    expect(notifier.handleBack(), isFalse);
    expect(notifier.state.isCategorySettings, isTrue);
    expect(notifier.state.showDetailPane, isTrue);

    expect(notifier.handleBack(), isFalse);
    expect(notifier.state.showDetailPane, isFalse);

    notifier.showGlobalDefaults();
    expect(notifier.handleBack(), isFalse);
    expect(notifier.state.isCategorySettings, isTrue);

    expect(notifier.handleBack(), isFalse);
    expect(notifier.state.isRootState, isTrue);
    expect(notifier.handleBack(), isTrue);
  });

  test('feed selection preserves the current scope unless overridden', () {
    notifier.selectCategory(3);
    notifier.selectFeed(9);
    expect(notifier.state.activeCategoryId, 3);
    expect(notifier.state.selectedFeedId, 9);

    notifier.selectFeed(
      10,
      categoryScope: const SubscriptionCategoryUncategorized(),
    );
    expect(notifier.state.isUncategorized, isTrue);
    expect(notifier.state.selectedFeedId, 10);
  });
}
