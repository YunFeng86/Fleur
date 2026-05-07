import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../providers/backend_capabilities_provider.dart';
import '../../../../providers/subscription_settings_provider.dart';
import '../../../../services/sync/backend_capabilities.dart';
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
              PopupMenuButton<_ManageAction>(
                tooltip: l10n.manage,
                icon: const Icon(Icons.more_horiz),
                onSelected: (value) {
                  switch (value) {
                    case _ManageAction.refreshAll:
                      unawaited(SubscriptionActions.refreshAll(context, ref));
                      return;
                    case _ManageAction.importOpml:
                      unawaited(SubscriptionActions.importOpml(context, ref));
                      return;
                    case _ManageAction.exportOpml:
                      unawaited(SubscriptionActions.exportOpml(context, ref));
                      return;
                  }
                },
                itemBuilder: (context) {
                  return [
                    if (capabilities.isVisible(BackendFeature.syncNow))
                      PopupMenuItem<_ManageAction>(
                        value: _ManageAction.refreshAll,
                        child: ListTile(
                          leading: const Icon(Icons.refresh),
                          title: Text(l10n.refreshAll),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (capabilities.isVisible(BackendFeature.importOpml))
                      PopupMenuItem<_ManageAction>(
                        value: _ManageAction.importOpml,
                        child: ListTile(
                          leading: const Icon(Icons.file_upload_outlined),
                          title: Text(l10n.importOpml),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (capabilities.isVisible(BackendFeature.exportOpml))
                      PopupMenuItem<_ManageAction>(
                        value: _ManageAction.exportOpml,
                        child: ListTile(
                          leading: const Icon(Icons.file_download_outlined),
                          title: Text(l10n.exportOpml),
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

enum _ManageAction { refreshAll, importOpml, exportOpml }
