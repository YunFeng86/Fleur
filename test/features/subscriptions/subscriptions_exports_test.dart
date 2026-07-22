import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fleur/features/subscriptions/subscriptions.dart';
import 'package:fleur/providers/add_subscription_controller.dart'
    as legacy_controller;
import 'package:fleur/services/subscriptions/add_subscription_workflow.dart'
    as legacy_workflow;

void main() {
  test('facade exposes one canonical selection provider', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(subscriptionSelectionProvider);
    final notifier = container.read(subscriptionSelectionProvider.notifier);

    expect(state, isA<SubscriptionState>());
    expect(notifier, isA<SubscriptionSelectionNotifier>());
  });

  test('facade and legacy shims expose one add-subscription interface', () {
    expect(
      legacy_controller.addSubscriptionControllerProvider,
      same(addSubscriptionControllerProvider),
    );
    expect(
      legacy_controller.addSubscriptionWorkflowProvider,
      same(addSubscriptionWorkflowProvider),
    );
    expect(
      const legacy_workflow.AddSubscriptionFailure(
        legacy_workflow.AddSubscriptionFailureKind.validation,
      ),
      isA<AddSubscriptionFailure>(),
    );
    expect(const AddSubscriptionState(), isA<AddSubscriptionState>());
  });
}
