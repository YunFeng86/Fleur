import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'subscription_layout_manager.dart';

class SubscriptionsSettingsTab extends ConsumerWidget {
  const SubscriptionsSettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Just wrap the layout manager.
    // We can add any high-level providers here if needed in future.
    return const SubscriptionLayoutManager();
  }
}
