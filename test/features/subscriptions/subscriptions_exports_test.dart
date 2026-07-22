import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fleur/features/subscriptions/subscriptions.dart';

void main() {
  test('facade exposes one canonical selection provider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(subscriptionSelectionProvider);
    final notifier = container.read(subscriptionSelectionProvider.notifier);

    expect(state, isA<SubscriptionState>());
    expect(notifier, isA<SubscriptionSelectionNotifier>());
  });
}
