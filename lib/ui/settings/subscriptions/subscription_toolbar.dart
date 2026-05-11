import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../providers/backend_capabilities_provider.dart';
import '../../../../providers/backend_sync_semantics_provider.dart';
import '../../../../providers/subscription_settings_provider.dart';
import '../../../../services/sync/backend_capabilities.dart';
import '../../../../ui/actions/subscription_object_menus.dart';
import '../../../../utils/platform.dart';
import 'subscription_actions.dart';

class SubscriptionToolbar extends ConsumerWidget {
  const SubscriptionToolbar({super.key, this.showPageTitle = true});

  final bool showPageTitle;

  static const double _kCompactToolbarWidth = 720;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selection = ref.watch(subscriptionSelectionProvider);
    final notifier = ref.read(subscriptionSelectionProvider.notifier);
    final capabilities = ref.watch(backendCapabilitiesProvider);
    final syncSemantics = ref.watch(backendSyncSemanticsProvider);
    final overflowItems = SubscriptionObjectMenus.toolbarOverflowItems(
      l10n,
      capabilities,
      syncSemantics,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isCompact = maxWidth < _kCompactToolbarWidth;
        final showTitle = showPageTitle && maxWidth >= 420;
        final showAddLabel = maxWidth >= 760;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              if (showPageTitle &&
                  isDesktop &&
                  isCompact &&
                  selection.canHandleBack)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (notifier.handleBack()) {
                      unawaited(Navigator.of(context).maybePop());
                    }
                  },
                ),
              if (showTitle)
                Expanded(
                  child: Text(
                    l10n.subscriptions,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 12),
              if (capabilities.isVisible(BackendFeature.addSubscription) &&
                  showAddLabel)
                FilledButton.icon(
                  onPressed: () {
                    unawaited(
                      SubscriptionActions.showAddFeedDialog(context, ref),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addSubscription),
                )
              else if (capabilities.isVisible(BackendFeature.addSubscription))
                IconButton(
                  tooltip: l10n.addSubscription,
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    unawaited(
                      SubscriptionActions.showAddFeedDialog(context, ref),
                    );
                  },
                ),
              const SizedBox(width: 4),
              if (capabilities.isVisible(BackendFeature.addCategory))
                IconButton(
                  tooltip: l10n.newCategory,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  onPressed: () {
                    unawaited(
                      SubscriptionActions.showAddCategoryDialog(context, ref),
                    );
                  },
                ),
              PopupMenuButton<SubscriptionRootMenuAction>(
                tooltip: l10n.manage,
                icon: const Icon(Icons.more_horiz),
                onSelected: (action) => unawaited(
                  SubscriptionObjectMenus.performSettingsManagementAction(
                    context,
                    ref,
                    action,
                  ),
                ),
                itemBuilder: (context) {
                  return [
                    for (final item in overflowItems)
                      PopupMenuItem<SubscriptionRootMenuAction>(
                        value: item.action,
                        child: ListTile(
                          leading: Icon(item.icon),
                          title: Text(item.label),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ];
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
