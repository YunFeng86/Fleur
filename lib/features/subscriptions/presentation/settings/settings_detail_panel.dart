import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../application/subscription_selection.dart';
import '../../../../providers/app_settings_providers.dart';
import '../../../../providers/backend_capabilities_provider.dart';
import '../../../../providers/backend_sync_semantics_provider.dart';
import '../../../../providers/query_providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/feed.dart';
import '../../../../models/category.dart';
import '../../../../services/sync/backend_capabilities.dart';
import '../../../../theme/fleur_icons.dart';
import '../../../../ui/settings/widgets/settings_controls.dart';
import '../../../../utils/timeago_locale.dart';
import '../subscription_refresh_actions.dart';
import '../subscription_structure_actions.dart';
import 'controls/filter_settings_section.dart';
import 'controls/sync_settings_section.dart';
import 'controls/user_agent_settings_section.dart';

class SettingsDetailPanel extends ConsumerWidget {
  const SettingsDetailPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(subscriptionSelectionProvider);
    final l10n = AppLocalizations.of(context)!;

    return switch (selection.detailTarget) {
      SubscriptionGlobalDefaults() => const _GlobalSettings(),
      SubscriptionScopeOverview() => _ScopeOverview(
        scope: selection.categoryScope,
      ),
      SubscriptionCategorySettingsTarget(:final categoryId) =>
        ref
            .watch(categoryProvider(categoryId))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) =>
                  Center(child: Text(l10n.errorMessage(e.toString()))),
              data: (category) {
                if (category == null) return Center(child: Text(l10n.notFound));
                return _CategorySettings(category: category);
              },
            ),
      SubscriptionFeedDetailsTarget(:final feedId) =>
        ref
            .watch(feedProvider(feedId))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) =>
                  Center(child: Text(l10n.errorMessage(e.toString()))),
              data: (feed) {
                if (feed == null) return Center(child: Text(l10n.notFound));
                return _FeedSettings(feed: feed);
              },
            ),
    };
  }
}

class _ScopeOverview extends ConsumerWidget {
  const _ScopeOverview({required this.scope});

  final SubscriptionCategoryScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final feeds = ref.watch(feedsProvider).valueOrNull ?? const <Feed>[];

    final scopedFeeds = feeds.where((feed) {
      return switch (scope) {
        SubscriptionCategoryAll() => true,
        SubscriptionCategoryUncategorized() => feed.categoryId == null,
        SubscriptionCategoryId(:final id) => feed.categoryId == id,
      };
    }).toList();

    final last = () {
      DateTime? out;
      for (final feed in scopedFeeds) {
        final stamp = feed.lastCheckedAt ?? feed.lastSyncedAt;
        if (stamp == null) continue;
        if (out == null || stamp.isAfter(out)) out = stamp;
      }
      return out;
    }();

    final title = switch (scope) {
      SubscriptionCategoryAll() => l10n.allSubscriptions,
      SubscriptionCategoryUncategorized() => l10n.uncategorized,
      SubscriptionCategoryId(:final id) =>
        categories.where((category) => category.id == id).firstOrNull?.name ??
            l10n.subscriptions,
    };

    final description = switch (scope) {
      SubscriptionCategoryAll() => l10n.allSubscriptionsDescription,
      SubscriptionCategoryUncategorized() => l10n.uncategorizedDescription,
      SubscriptionCategoryId() => l10n.allSubscriptionsDescription,
    };

    final lastText = last == null
        ? l10n.never
        : timeago.format(last.toLocal(), locale: timeagoLocale(context));
    final overviewValues = <_OverviewValue>[
      _OverviewValue(label: l10n.subscriptions, value: '${scopedFeeds.length}'),
      if (scope case SubscriptionCategoryAll())
        _OverviewValue(
          label: l10n.categoriesLabel,
          value: '${categories.length}',
        ),
      if (scope case SubscriptionCategoryAll())
        _OverviewValue(
          label: l10n.uncategorized,
          value: '${feeds.where((feed) => feed.categoryId == null).length}',
        ),
      _OverviewValue(label: l10n.lastSynced, value: lastText),
    ];

    return SettingsPageBody(
      maxWidth: 920,
      children: [
        SettingsDetailHeader(title: title, subtitle: description),
        _OverviewSection(values: overviewValues, bottomSpacing: 0),
      ],
    );
  }
}

class _GlobalSettings extends ConsumerWidget {
  const _GlobalSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final appSettingsAsync = ref.watch(appSettingsProvider);
    final feeds = ref.watch(feedsProvider).valueOrNull ?? const <Feed>[];

    DateTime? lastSyncedAt() {
      DateTime? out;
      for (final f in feeds) {
        final t = f.lastCheckedAt ?? f.lastSyncedAt;
        if (t == null) continue;
        if (out == null || t.isAfter(out)) out = t;
      }
      return out;
    }

    return appSettingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text(l10n.errorMessage(e.toString()))),
      data: (appSettings) {
        final last = lastSyncedAt();

        return SettingsPageBody(
          maxWidth: 920,
          children: [
            SettingsDetailHeader(
              title: l10n.globalDefaults,
              subtitle: l10n.globalDefaultsDescription,
            ),
            _OverviewSection(
              values: [
                _OverviewValue(
                  label: l10n.subscriptions,
                  value: '${feeds.length}',
                ),
                _OverviewValue(
                  label: l10n.lastSynced,
                  value: last == null
                      ? l10n.never
                      : timeago.format(
                          last.toLocal(),
                          locale: timeagoLocale(context),
                        ),
                ),
              ],
            ),
            SubscriptionFilterSettingsSection(appSettings: appSettings),
            SubscriptionSyncSettingsSection(appSettings: appSettings),
            SubscriptionUserAgentSettingsSection(appSettings: appSettings),
          ],
        );
      },
    );
  }
}

class _OverviewValue {
  const _OverviewValue({required this.label, required this.value});

  final String label;
  final String value;
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.values, this.bottomSpacing = 24});

  final List<_OverviewValue> values;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SettingsSection(
      title: l10n.overview,
      bottomSpacing: bottomSpacing,
      child: SettingsCard(
        padding: EdgeInsets.zero,
        child: SettingsTileGroup(
          children: [
            for (final value in values)
              _OverviewValueRow(label: value.label, value: value.value),
          ],
        ),
      ),
    );
  }
}

class _OverviewValueRow extends StatelessWidget {
  const _OverviewValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySettings extends ConsumerWidget {
  final Category category;

  const _CategorySettings({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final appSettings = ref.watch(appSettingsProvider).valueOrNull;
    final capabilities = ref.watch(backendCapabilitiesProvider);
    final syncSemantics = ref.watch(backendSyncSemanticsProvider);

    if (appSettings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final hasActions =
        capabilities.isVisible(BackendFeature.renameCategory) ||
        capabilities.isVisible(BackendFeature.deleteCategory);

    return SettingsPageBody(
      maxWidth: 920,
      children: [
        SettingsDetailHeader(
          title: category.name,
          subtitle:
              '${ref.watch(feedsProvider).valueOrNull?.where((feed) => feed.categoryId == category.id).length ?? 0} ${l10n.subscriptions}',
        ),
        if (syncSemantics.isRemoteWritableTaxonomy)
          SettingsCard(
            padding: EdgeInsets.zero,
            child: SettingsTile(
              leading: const Icon(FleurIcons.services),
              title: Text(l10n.remoteWritableTaxonomyTitle),
              subtitle: Text(l10n.remoteWritableTaxonomyDescription),
            ),
          ),
        if (syncSemantics.isRemoteReadOnlyTaxonomy)
          SettingsCard(
            padding: EdgeInsets.zero,
            child: SettingsTile(
              leading: const Icon(FleurIcons.lock),
              title: Text(l10n.remoteReadOnlyTaxonomyTitle),
              subtitle: Text(l10n.remoteReadOnlyTaxonomyDescription),
            ),
          ),
        if (syncSemantics.mirrorsRemoteTaxonomy) const SizedBox(height: 24),
        if (hasActions)
          SettingsCard(
            padding: EdgeInsets.zero,
            child: SettingsTileGroup(
              children: [
                if (capabilities.isVisible(BackendFeature.renameCategory))
                  SettingsTile(
                    leading: const Icon(FleurIcons.rename),
                    title: Text(l10n.rename),
                    onTap: () => SubscriptionStructureActions.renameCategory(
                      context,
                      ref,
                      categoryId: category.id,
                      currentName: category.name,
                    ),
                  ),
                if (capabilities.isVisible(BackendFeature.deleteCategory))
                  SettingsTile(
                    destructive: true,
                    leading: const Icon(FleurIcons.delete),
                    title: Text(l10n.delete),
                    onTap: () async {
                      final deleted =
                          await SubscriptionStructureActions.deleteCategory(
                            context,
                            ref,
                            categoryId: category.id,
                          );
                      if (!deleted || !context.mounted) return;
                      ref
                          .read(subscriptionSelectionProvider.notifier)
                          .selectAll();
                    },
                  ),
              ],
            ),
          ),
        if (hasActions) const SizedBox(height: 24),
        SubscriptionFilterSettingsSection(
          category: category,
          appSettings: appSettings,
        ),
        SubscriptionSyncSettingsSection(
          category: category,
          appSettings: appSettings,
        ),
      ],
    );
  }
}

class _FeedSettings extends ConsumerWidget {
  final Feed feed;

  const _FeedSettings({required this.feed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final appSettings = ref.watch(appSettingsProvider).valueOrNull;
    final capabilities = ref.watch(backendCapabilitiesProvider);
    final syncSemantics = ref.watch(backendSyncSemanticsProvider);
    final category = feed.categoryId != null
        ? categories.where((c) => c.id == feed.categoryId).firstOrNull
        : null;

    if (appSettings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final canMove =
        capabilities.isVisible(BackendFeature.moveSubscriptionToCategory) ||
        capabilities.isVisible(BackendFeature.moveSubscriptionToUncategorized);

    return SettingsPageBody(
      maxWidth: 920,
      children: [
        SettingsDetailHeader(
          title: feed.userTitle ?? feed.title ?? 'Feed',
          subtitleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                feed.url,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                category?.name ?? l10n.uncategorized,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SettingsCard(
          padding: EdgeInsets.zero,
          child: SettingsTileGroup(
            children: [
              if (capabilities.isVisible(BackendFeature.clientFeedSettings))
                SettingsTile(
                  leading: const Icon(FleurIcons.rename),
                  title: Text(l10n.rename),
                  onTap: () => SubscriptionStructureActions.editFeedTitle(
                    context,
                    ref,
                    feedId: feed.id,
                    currentTitle: feed.userTitle ?? feed.title,
                  ),
                ),
              if (canMove)
                SettingsTile(
                  leading: const Icon(FleurIcons.moveToCategory),
                  title: Text(l10n.moveToCategory),
                  subtitle: Text(category?.name ?? l10n.uncategorized),
                  onTap: () => SubscriptionStructureActions.moveFeedToCategory(
                    context,
                    ref,
                    feedId: feed.id,
                  ),
                ),
              if (!canMove && syncSemantics.isRemoteReadOnlyTaxonomy)
                SettingsTile(
                  leading: const Icon(FleurIcons.lock),
                  title: Text(l10n.feedCategoryReadOnlyTaxonomyTitle),
                  subtitle: Text(l10n.feedCategoryReadOnlyTaxonomyDescription),
                ),
              if (capabilities.isVisible(
                BackendFeature.refreshSubscriptionSource,
              ))
                SettingsTile(
                  leading: const Icon(FleurIcons.refresh),
                  title: Text(l10n.refresh),
                  onTap: () => SubscriptionRefreshActions.refreshFeed(
                    context,
                    ref,
                    feed.id,
                  ),
                ),
              if (capabilities.isVisible(BackendFeature.deleteSubscription))
                SettingsTile(
                  destructive: true,
                  leading: const Icon(FleurIcons.delete),
                  title: Text(l10n.delete),
                  onTap: () async {
                    final deleted =
                        await SubscriptionStructureActions.deleteFeed(
                          context,
                          ref,
                          feedId: feed.id,
                        );
                    if (!deleted || !context.mounted) return;
                    final selection = ref.read(subscriptionSelectionProvider);
                    ref
                        .read(subscriptionSelectionProvider.notifier)
                        .returnToScopeDetails(
                          showDetailPane: selection.showDetailPane,
                        );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SubscriptionFilterSettingsSection(
          feed: feed,
          category: category,
          appSettings: appSettings,
        ),
        SubscriptionSyncSettingsSection(
          feed: feed,
          category: category,
          appSettings: appSettings,
        ),
      ],
    );
  }
}
