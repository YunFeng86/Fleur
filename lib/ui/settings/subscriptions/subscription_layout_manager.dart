import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/subscription_settings_provider.dart';
import 'category_list_component.dart';
import 'feed_list_component.dart';
import 'settings_detail_panel.dart';
import 'subscription_tree_view.dart';
import 'subscription_toolbar.dart';

class SubscriptionLayoutManager extends ConsumerWidget {
  const SubscriptionLayoutManager({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Breakpoints
    // Wide: > 1000
    // Medium: 600 - 1000
    // Narrow: < 600

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final selection = ref.watch(subscriptionSelectionProvider);
        final notifier = ref.read(subscriptionSelectionProvider.notifier);

        // Handle Back Button in Narrow Mode
        // If selection exists, PopScope should prevent backing out of app and instead go up a level.
        final canPopInternal =
            selection.selectedFeedId != null ||
            selection.activeCategoryId != null;

        // Callback to handle back navigation
        void handleBack() {
          if (selection.selectedFeedId != null) {
            notifier.clearFeedSelection();
          } else if (selection.activeCategoryId != null) {
            notifier.selectCategory(null);
          }
        }

        return PopScope(
          canPop: !canPopInternal,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            handleBack();
          },
          child: Builder(
            builder: (context) {
              if (width >= 1000) {
                // 3 Columns
                return Column(
                  children: [
                    const SubscriptionToolbar(),
                    const Divider(height: 1),
                    Expanded(
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 280,
                            child: CategoryListComponent(),
                          ),
                          const VerticalDivider(width: 1),
                          const SizedBox(
                            width: 320,
                            child: FeedListComponent(),
                          ),
                          const VerticalDivider(width: 1),
                          const Expanded(child: SettingsDetailPanel()),
                        ],
                      ),
                    ),
                  ],
                );
              } else if (width >= 600) {
                // 2 Columns: Nav (Tree) | Details
                // User requested Tree View for Medium
                // 2 Columns: Nav (Tree) | Details
                // User requested Tree View for Medium
                return Column(
                  children: [
                    const SubscriptionToolbar(),
                    const Divider(height: 1),
                    Expanded(
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 320,
                            child: SubscriptionTreeView(),
                          ),
                          const VerticalDivider(width: 1),
                          const Expanded(child: SettingsDetailPanel()),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                // Narrow: 1 Column (Stack)
                if (selection.selectedFeedId != null) {
                  return const SettingsDetailPanel();
                }

                if (selection.activeCategoryId != null) {
                  return const FeedListComponent();
                }

                return const CategoryListComponent();
              }
            },
          ),
        );
      },
    );
  }
}
