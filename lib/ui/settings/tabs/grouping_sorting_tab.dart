import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/app_settings_providers.dart';
import '../../../services/settings/app_settings.dart';
import '../settings_targets.dart';
import '../widgets/section_header.dart';

class GroupingSortingTab extends ConsumerWidget {
  const GroupingSortingTab({
    super.key,
    required this.targetController,
    this.showPageTitle = true,
  });

  final SettingsTargetController targetController;
  final bool showPageTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final appSettings =
        ref.watch(appSettingsProvider).valueOrNull ?? AppSettings.defaults();

    return SettingsPageBody(
      children: [
        if (showPageTitle) ...[
          SectionHeader(title: l10n.groupingAndSorting),
          const SizedBox(height: 8),
        ],
        SettingsSection(
          title: l10n.groupBy,
          child: SettingsCard(
            padding: EdgeInsets.zero,
            child: SettingsTargetAnchor(
              id: 'grouping_sorting.group.mode',
              controller: targetController,
              child: SettingsControlRow(
                title: Text(l10n.groupBy),
                control: SettingsSelectField<ArticleGroupMode>(
                  key: const Key('grouping_sorting_group_mode_select'),
                  value: appSettings.articleGroupMode,
                  options: [
                    SettingsSelectOption(
                      value: ArticleGroupMode.none,
                      label: Text(l10n.groupNone),
                    ),
                    SettingsSelectOption(
                      value: ArticleGroupMode.day,
                      label: Text(l10n.groupByDay),
                    ),
                  ],
                  onChanged: (v) {
                    unawaited(
                      ref
                          .read(appSettingsProvider.notifier)
                          .setArticleGroupMode(v),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        SettingsSection(
          title: l10n.sortOrder,
          bottomSpacing: 0,
          child: SettingsCard(
            padding: EdgeInsets.zero,
            child: SettingsTargetAnchor(
              id: 'grouping_sorting.sort.order',
              controller: targetController,
              child: SettingsControlRow(
                title: Text(l10n.sortOrder),
                control: SettingsSelectField<ArticleSortOrder>(
                  key: const Key('grouping_sorting_sort_order_select'),
                  value: appSettings.articleSortOrder,
                  options: [
                    SettingsSelectOption(
                      value: ArticleSortOrder.newestFirst,
                      label: Text(l10n.sortNewestFirst),
                    ),
                    SettingsSelectOption(
                      value: ArticleSortOrder.oldestFirst,
                      label: Text(l10n.sortOldestFirst),
                    ),
                  ],
                  onChanged: (v) {
                    unawaited(
                      ref
                          .read(appSettingsProvider.notifier)
                          .setArticleSortOrder(v),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
