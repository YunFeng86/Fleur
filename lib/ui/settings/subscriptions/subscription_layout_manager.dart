import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/features/subscriptions/subscriptions.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/fleur_theme_extensions.dart';
import 'category_list_component.dart';
import 'feed_list_component.dart';
import 'settings_detail_panel.dart';
import 'subscription_toolbar.dart';
import 'subscription_tree_view.dart';
import '../widgets/settings_controls.dart';

class SubscriptionLayoutManager extends ConsumerWidget {
  const SubscriptionLayoutManager({super.key, this.showPageTitle = true});

  final bool showPageTitle;

  static const double _kThreePaneBreakpoint = 1120;
  static const double _kTwoPaneBreakpoint = 720;
  static const double _kPaneGap = 12;
  static const double _kSidebarWidth = 248;
  static const double _kFeedListWidth = 320;
  static const double _kTreeWidth = 340;
  static const double _kMinDetailWidth = 420;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final selection = ref.watch(subscriptionSelectionProvider);
        final notifier = ref.read(subscriptionSelectionProvider.notifier);
        final l10n = AppLocalizations.of(context)!;
        final surfaces = Theme.of(context).fleurSurface;

        String detailPaneSubtitle() => switch (selection.detailTarget) {
          SubscriptionGlobalDefaults() => l10n.globalDefaults,
          SubscriptionScopeOverview() => switch (selection.categoryScope) {
            SubscriptionCategoryAll() => l10n.subscriptions,
            SubscriptionCategoryUncategorized() => l10n.uncategorized,
            SubscriptionCategoryId() => l10n.overview,
          },
          SubscriptionCategorySettingsTarget() => l10n.subscriptions,
          SubscriptionFeedDetailsTarget() => l10n.subscriptions,
        };

        Widget buildDetailPane({bool showHeader = true}) {
          return SettingsPane(
            color: surfaces.reader,
            title: showHeader ? l10n.settings : null,
            subtitle: showHeader ? detailPaneSubtitle() : null,
            child: const SettingsDetailPanel(),
          );
        }

        final resolvedContent = Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              SubscriptionToolbar(showPageTitle: showPageTitle),
              const SizedBox(height: 12),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (width >= _kThreePaneBreakpoint) {
                      return Row(
                        children: [
                          const SizedBox(
                            width: _kSidebarWidth,
                            child: CategoryListComponent(),
                          ),
                          const SizedBox(width: _kPaneGap),
                          const SizedBox(
                            width: _kFeedListWidth,
                            child: FeedListComponent(),
                          ),
                          const SizedBox(width: _kPaneGap),
                          Expanded(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: _kMinDetailWidth,
                              ),
                              child: buildDetailPane(),
                            ),
                          ),
                        ],
                      );
                    }

                    if (width >= _kTwoPaneBreakpoint) {
                      return Row(
                        children: [
                          SizedBox(
                            width: _kTreeWidth,
                            child: SubscriptionTreeView(
                              showPaneHeader: showPageTitle,
                            ),
                          ),
                          const SizedBox(width: _kPaneGap),
                          Expanded(
                            child: buildDetailPane(showHeader: showPageTitle),
                          ),
                        ],
                      );
                    }

                    return selection.showDetailPane
                        ? buildDetailPane(showHeader: showPageTitle)
                        : SubscriptionTreeView(
                            showDetailPaneOnSelection: true,
                            showPaneHeader: showPageTitle,
                          );
                  },
                ),
              ),
            ],
          ),
        );

        if (!showPageTitle) return resolvedContent;

        return PopScope(
          canPop: !selection.canHandleBack,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (notifier.handleBack()) {
              unawaited(Navigator.of(context).maybePop());
            }
          },
          child: resolvedContent,
        );
      },
    );
  }
}
