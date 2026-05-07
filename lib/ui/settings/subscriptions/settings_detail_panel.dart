import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_settings_providers.dart';
import '../../../../providers/backend_capabilities_provider.dart';
import '../../../../providers/query_providers.dart';
import '../../../../providers/subscription_settings_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/feed.dart';
import '../../../../models/category.dart';
import '../../../../services/settings/app_settings.dart';
import '../../../../services/sync/backend_capabilities.dart';
import '../../../../services/network/user_agents.dart';
import '../../../../utils/timeago_locale.dart';
import '../widgets/section_header.dart';
import 'subscription_actions.dart';
import 'settings_inheritance_helper.dart';
import 'package:timeago/timeago.dart' as timeago;

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
            _FilterSection(appSettings: appSettings),
            _SyncSection(appSettings: appSettings),
            _UserAgentSection(appSettings: appSettings),
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
        if (hasActions)
          SettingsCard(
            padding: EdgeInsets.zero,
            child: SettingsTileGroup(
              children: [
                if (capabilities.isVisible(BackendFeature.renameCategory))
                  SettingsTile(
                    leading: const Icon(Icons.edit),
                    title: Text(l10n.rename),
                    onTap: () => SubscriptionActions.renameCategory(
                      context,
                      ref,
                      categoryId: category.id,
                      currentName: category.name,
                    ),
                  ),
                if (capabilities.isVisible(BackendFeature.deleteCategory))
                  SettingsTile(
                    destructive: true,
                    leading: const Icon(Icons.delete_outline),
                    title: Text(l10n.delete),
                    onTap: () async {
                      final deleted = await SubscriptionActions.deleteCategory(
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
        _FilterSection(category: category, appSettings: appSettings),
        _SyncSection(category: category, appSettings: appSettings),
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
                  leading: const Icon(Icons.edit),
                  title: Text(l10n.rename),
                  onTap: () => SubscriptionActions.editFeedTitle(
                    context,
                    ref,
                    feedId: feed.id,
                    currentTitle: feed.userTitle ?? feed.title,
                  ),
                ),
              if (canMove)
                SettingsTile(
                  leading: const Icon(Icons.folder_open),
                  title: Text(l10n.moveToCategory),
                  subtitle: Text(category?.name ?? l10n.uncategorized),
                  onTap: () => SubscriptionActions.moveFeedToCategory(
                    context,
                    ref,
                    feedId: feed.id,
                  ),
                ),
              if (capabilities.isVisible(
                BackendFeature.refreshSubscriptionSource,
              ))
                SettingsTile(
                  leading: const Icon(Icons.refresh),
                  title: Text(l10n.refresh),
                  onTap: () =>
                      SubscriptionActions.refreshFeed(context, ref, feed.id),
                ),
              if (capabilities.isVisible(BackendFeature.deleteSubscription))
                SettingsTile(
                  destructive: true,
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.delete),
                  onTap: () async {
                    final deleted = await SubscriptionActions.deleteFeed(
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
        _FilterSection(
          feed: feed,
          category: category,
          appSettings: appSettings,
        ),
        _SyncSection(feed: feed, category: category, appSettings: appSettings),
      ],
    );
  }
}

class _FilterSection extends ConsumerWidget {
  final Feed? feed;
  final Category? category;
  final AppSettings appSettings;

  const _FilterSection({this.feed, this.category, required this.appSettings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final effectiveEnabled = SettingsInheritanceHelper.resolveFilterEnabled(
      feed,
      category,
      appSettings,
    );

    return SettingsSection(
      title: l10n.filter,
      child: SettingsCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TriStateSwitch(
              title: l10n.enableFilter,
              currentValue: feed != null
                  ? feed!.filterEnabled
                  : category?.filterEnabled,
              effectiveValue: effectiveEnabled,
              isGlobal: feed == null && category == null,
              onChanged: (val) {
                if (feed != null) {
                  unawaited(
                    SubscriptionActions.updateFeedSettings(
                      context,
                      ref,
                      feedId: feed!.id,
                      filterEnabled: val,
                      updateFilterEnabled: true,
                    ),
                  );
                } else if (category != null) {
                  unawaited(
                    SubscriptionActions.updateCategorySettings(
                      context,
                      ref,
                      categoryId: category!.id,
                      filterEnabled: val,
                      updateFilterEnabled: true,
                    ),
                  );
                } else {
                  unawaited(
                    ref
                        .read(appSettingsProvider.notifier)
                        .setFilterEnabled(val ?? false),
                  );
                }
              },
            ),
            if (effectiveEnabled) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: _FilterKeywordsInput(
                  feed: feed,
                  category: category,
                  appSettings: appSettings,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncSection extends ConsumerWidget {
  final Feed? feed;
  final Category? category;
  final AppSettings appSettings;

  const _SyncSection({this.feed, this.category, required this.appSettings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = ref.watch(backendCapabilitiesProvider);
    final canSyncImages = capabilities.isVisible(
      BackendFeature.syncImagePrefetch,
    );
    final canSyncWebPages =
        capabilities.isVisible(BackendFeature.clientWebPageFetch) ||
        capabilities.isVisible(BackendFeature.serverArticleContentFetch);

    return SettingsSection(
      title: l10n.sync,
      child: SettingsCard(
        padding: EdgeInsets.zero,
        child: SettingsTileGroup(
          children: [
            _TriStateSwitch(
              title: l10n.enableSync,
              currentValue: feed != null
                  ? feed!.syncEnabled
                  : category?.syncEnabled,
              effectiveValue: SettingsInheritanceHelper.resolveSyncEnabled(
                feed,
                category,
                appSettings,
              ),
              isGlobal: feed == null && category == null,
              onChanged: (val) {
                if (feed != null) {
                  unawaited(
                    SubscriptionActions.updateFeedSettings(
                      context,
                      ref,
                      feedId: feed!.id,
                      syncEnabled: val,
                      updateSyncEnabled: true,
                    ),
                  );
                } else if (category != null) {
                  unawaited(
                    SubscriptionActions.updateCategorySettings(
                      context,
                      ref,
                      categoryId: category!.id,
                      syncEnabled: val,
                      updateSyncEnabled: true,
                    ),
                  );
                } else {
                  unawaited(
                    ref
                        .read(appSettingsProvider.notifier)
                        .setSyncEnabled(val ?? true),
                  );
                }
              },
            ),
            if (canSyncImages)
              _TriStateSwitch(
                title: l10n.syncImages,
                currentValue: feed != null
                    ? feed!.syncImages
                    : category?.syncImages,
                effectiveValue: SettingsInheritanceHelper.resolveSyncImages(
                  feed,
                  category,
                  appSettings,
                ),
                isGlobal: feed == null && category == null,
                onChanged: (val) {
                  if (feed != null) {
                    unawaited(
                      SubscriptionActions.updateFeedSettings(
                        context,
                        ref,
                        feedId: feed!.id,
                        syncImages: val,
                        updateSyncImages: true,
                      ),
                    );
                  } else if (category != null) {
                    unawaited(
                      SubscriptionActions.updateCategorySettings(
                        context,
                        ref,
                        categoryId: category!.id,
                        syncImages: val,
                        updateSyncImages: true,
                      ),
                    );
                  } else {
                    unawaited(
                      ref
                          .read(appSettingsProvider.notifier)
                          .setSyncImages(val ?? true),
                    );
                  }
                },
              ),
            if (canSyncWebPages)
              _TriStateSwitch(
                title: l10n.syncWebPages,
                currentValue: feed != null
                    ? feed!.syncWebPages
                    : category?.syncWebPages,
                effectiveValue: SettingsInheritanceHelper.resolveSyncWebPages(
                  feed,
                  category,
                  appSettings,
                ),
                isGlobal: feed == null && category == null,
                onChanged: (val) {
                  if (feed != null) {
                    unawaited(
                      SubscriptionActions.updateFeedSettings(
                        context,
                        ref,
                        feedId: feed!.id,
                        syncWebPages: val,
                        updateSyncWebPages: true,
                      ),
                    );
                  } else if (category != null) {
                    unawaited(
                      SubscriptionActions.updateCategorySettings(
                        context,
                        ref,
                        categoryId: category!.id,
                        syncWebPages: val,
                        updateSyncWebPages: true,
                      ),
                    );
                  } else {
                    unawaited(
                      ref
                          .read(appSettingsProvider.notifier)
                          .setSyncWebPages(val ?? false),
                    );
                  }
                },
              ),
            _TriStateSwitch(
              title: l10n.autoAiSummary,
              currentValue: feed != null
                  ? feed!.showAiSummary
                  : category?.showAiSummary,
              effectiveValue: SettingsInheritanceHelper.resolveShowAiSummary(
                feed,
                category,
                appSettings,
              ),
              isGlobal: feed == null && category == null,
              onChanged: (val) {
                if (feed != null) {
                  unawaited(
                    SubscriptionActions.updateFeedSettings(
                      context,
                      ref,
                      feedId: feed!.id,
                      showAiSummary: val,
                      updateShowAiSummary: true,
                    ),
                  );
                } else if (category != null) {
                  unawaited(
                    SubscriptionActions.updateCategorySettings(
                      context,
                      ref,
                      categoryId: category!.id,
                      showAiSummary: val,
                      updateShowAiSummary: true,
                    ),
                  );
                } else {
                  unawaited(
                    ref
                        .read(appSettingsProvider.notifier)
                        .setShowAiSummary(val ?? false),
                  );
                }
              },
            ),
            _TriStateSwitch(
              title: l10n.autoTranslate,
              currentValue: feed != null
                  ? feed!.autoTranslate
                  : category?.autoTranslate,
              effectiveValue: SettingsInheritanceHelper.resolveAutoTranslate(
                feed,
                category,
                appSettings,
              ),
              isGlobal: feed == null && category == null,
              onChanged: (val) {
                if (feed != null) {
                  unawaited(
                    SubscriptionActions.updateFeedSettings(
                      context,
                      ref,
                      feedId: feed!.id,
                      autoTranslate: val,
                      updateAutoTranslate: true,
                    ),
                  );
                } else if (category != null) {
                  unawaited(
                    SubscriptionActions.updateCategorySettings(
                      context,
                      ref,
                      categoryId: category!.id,
                      autoTranslate: val,
                      updateAutoTranslate: true,
                    ),
                  );
                } else {
                  unawaited(
                    ref
                        .read(appSettingsProvider.notifier)
                        .setAutoTranslate(val ?? false),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TriStateSwitch extends StatefulWidget {
  final String title;
  final bool? currentValue;
  final bool effectiveValue;
  final bool isGlobal;
  final ValueChanged<bool?> onChanged;

  const _TriStateSwitch({
    required this.title,
    required this.currentValue,
    required this.effectiveValue,
    required this.isGlobal,
    required this.onChanged,
  });

  @override
  State<_TriStateSwitch> createState() => _TriStateSwitchState();
}

enum _TriStateMenuAction { auto, on, off }

class _TriStateSwitchState extends State<_TriStateSwitch> {
  _TriStateMenuAction _actionForValue(bool? value) {
    if (value == null) return _TriStateMenuAction.auto;
    return value ? _TriStateMenuAction.on : _TriStateMenuAction.off;
  }

  bool? _valueForAction(_TriStateMenuAction action) {
    return switch (action) {
      _TriStateMenuAction.auto => null,
      _TriStateMenuAction.on => true,
      _TriStateMenuAction.off => false,
    };
  }

  Future<void> _showMenu(BuildContext context) async {
    final overlay = Overlay.of(context).context.findRenderObject();
    final box = context.findRenderObject();
    if (overlay is! RenderBox || box is! RenderBox) return;
    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    final l10n = AppLocalizations.of(context)!;
    final selected = await showMenu<_TriStateMenuAction>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      initialValue: _actionForValue(widget.currentValue),
      items: [
        PopupMenuItem(
          value: _TriStateMenuAction.auto,
          child: Text(
            '${l10n.auto} (${widget.effectiveValue ? l10n.autoOn : l10n.autoOff})',
          ),
        ),
        PopupMenuItem(value: _TriStateMenuAction.on, child: Text(l10n.enabled)),
        PopupMenuItem(value: _TriStateMenuAction.off, child: Text(l10n.off)),
      ],
    );
    if (!mounted || selected == null) return;
    widget.onChanged(_valueForAction(selected));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.isGlobal) {
      return SettingsSwitchTile(
        title: Text(widget.title),
        value: widget.currentValue ?? widget.effectiveValue,
        onChanged: widget.onChanged,
      );
    }

    final bool isSpecific = widget.currentValue != null;
    final bool isOn = isSpecific ? widget.currentValue! : widget.effectiveValue;

    // Style for the state text (Enabled/Off)
    final stateColor = isOn ? colorScheme.primary : colorScheme.error;
    final stateText = isOn ? l10n.enabled : l10n.off;

    // Suffix text: (Default Value) or empty if specific
    final suffixText = isSpecific ? '' : '  ${l10n.defaultValue}';

    return SettingsTile(
      title: Text(widget.title),
      subtitle: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: stateText,
              style: TextStyle(color: stateColor, fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: suffixText,
              style: TextStyle(color: colorScheme.outline),
            ),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSpecific)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.inherit,
              onPressed: () => widget.onChanged(null),
            ),
          IconButton(
            icon: const Icon(Icons.arrow_drop_down),
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
      onTap: () => _showMenu(context),
    );
  }
}

class _FilterKeywordsInput extends ConsumerStatefulWidget {
  final Feed? feed;
  final Category? category;
  final AppSettings appSettings;

  const _FilterKeywordsInput({
    this.feed,
    this.category,
    required this.appSettings,
  });

  @override
  ConsumerState<_FilterKeywordsInput> createState() =>
      _FilterKeywordsInputState();
}

class _FilterKeywordsInputState extends ConsumerState<_FilterKeywordsInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  // Calculate effective value for placeholder
  String get _effectiveValue => SettingsInheritanceHelper.resolveFilterKeywords(
    widget.feed,
    widget.category,
    widget.appSettings,
  );

  // Explicit value at this level only (feed or category). No parent fallback.
  String? get _currentValue => widget.feed != null
      ? widget.feed!.filterKeywords
      : widget.category?.filterKeywords;

  bool get _isGlobal => widget.feed == null && widget.category == null;

  bool get _isInherit =>
      !_isGlobal && (_currentValue == null || _currentValue!.trim().isEmpty);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // If global, we just use the value directly.
    // If category/feed, we prefer the explicit value, else empty (showing placeholder).
    if (_isGlobal) {
      _controller = TextEditingController(
        text: widget.appSettings.filterKeywords,
      );
    } else {
      // In inherit mode, show the effective value but keep it read-only.
      _controller = TextEditingController(
        text: _isInherit ? _effectiveValue : _currentValue,
      );
    }
  }

  @override
  void didUpdateWidget(covariant _FilterKeywordsInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isGlobal) {
      if (widget.appSettings.filterKeywords != _controller.text) {
        _controller.text = widget.appSettings.filterKeywords;
      }
    } else {
      // Logic for feed/category updates.
      // - If inheriting, show effective value (read-only).
      // - If overridden, show explicit value.
      final nextText = _isInherit ? _effectiveValue : (_currentValue ?? '');
      if (_controller.text != nextText) {
        _controller.text = nextText;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          readOnly: _isInherit,
          decoration: InputDecoration(
            hintText: _isInherit && _effectiveValue.trim().isEmpty
                ? l10n.defaultValue
                : null,
            helperText: l10n.filterKeywordsHint,
            helperMaxLines: 2,
            suffixIcon: _isGlobal
                ? null
                : (_isInherit
                      ? IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: l10n.edit,
                          onPressed: () {
                            // Create an explicit override based on the current effective value,
                            // then let user edit.
                            final seed = _effectiveValue;
                            _controller.text = seed;
                            _save(seed);
                            _focusNode.requestFocus();
                            _controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: _controller.text.length),
                            );
                          },
                        )
                      : ((_currentValue != null &&
                                _currentValue!.trim().isNotEmpty)
                            ? IconButton(
                                icon: const Icon(Icons.undo),
                                tooltip: l10n.inherit,
                                onPressed: () {
                                  _controller.text = _effectiveValue;
                                  _save(null);
                                },
                              )
                            : null)),
          ),
          minLines: 1,
          maxLines: 3,
          onChanged: _isInherit ? null : (value) => _save(value),
        ),
      ],
    );
  }

  void _save(String? value) {
    final v = value?.trim();
    final next = (v == null || v.isEmpty) ? null : v;
    if (_isGlobal) {
      unawaited(
        ref.read(appSettingsProvider.notifier).setFilterKeywords(next ?? ''),
      );
    } else if (widget.feed != null) {
      unawaited(
        SubscriptionActions.updateFeedSettings(
          context,
          ref,
          feedId: widget.feed!.id,
          filterKeywords: next,
          updateFilterKeywords: true,
        ),
      );
    } else if (widget.category != null) {
      unawaited(
        SubscriptionActions.updateCategorySettings(
          context,
          ref,
          categoryId: widget.category!.id,
          filterKeywords: next,
          updateFilterKeywords: true,
        ),
      );
    }
  }
}

class _UserAgentSection extends ConsumerStatefulWidget {
  const _UserAgentSection({required this.appSettings});

  final AppSettings appSettings;

  @override
  ConsumerState<_UserAgentSection> createState() => _UserAgentSectionState();
}

class _UserAgentSectionState extends ConsumerState<_UserAgentSection> {
  late TextEditingController _rssController;
  late TextEditingController _webController;

  @override
  void initState() {
    super.initState();
    _rssController = TextEditingController(
      text: widget.appSettings.rssUserAgent,
    );
    _webController = TextEditingController(
      text: widget.appSettings.webUserAgent,
    );
  }

  @override
  void didUpdateWidget(covariant _UserAgentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appSettings.rssUserAgent != widget.appSettings.rssUserAgent &&
        _rssController.text != widget.appSettings.rssUserAgent) {
      _rssController.text = widget.appSettings.rssUserAgent;
    }
    if (oldWidget.appSettings.webUserAgent != widget.appSettings.webUserAgent &&
        _webController.text != widget.appSettings.webUserAgent) {
      _webController.text = widget.appSettings.webUserAgent;
    }
  }

  @override
  void dispose() {
    _rssController.dispose();
    _webController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsSection(
      title: l10n.userAgent,
      bottomSpacing: 0,
      child: SettingsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _rssController,
              decoration: InputDecoration(
                labelText: l10n.rssUserAgent,
                helperText: l10n.userAgentRssHint,
                helperMaxLines: 2,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.resetToDefault,
                  onPressed: () {
                    _rssController.text = UserAgents.rss;
                    unawaited(
                      ref
                          .read(appSettingsProvider.notifier)
                          .setRssUserAgent(UserAgents.rss),
                    );
                  },
                ),
              ),
              minLines: 1,
              maxLines: 3,
              onChanged: (value) => unawaited(
                ref.read(appSettingsProvider.notifier).setRssUserAgent(value),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _webController,
              decoration: InputDecoration(
                labelText: l10n.webUserAgent,
                helperText: l10n.userAgentWebHint,
                helperMaxLines: 2,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.resetToDefault,
                  onPressed: () {
                    _webController.text = UserAgents.webForCurrentPlatform();
                    unawaited(
                      ref
                          .read(appSettingsProvider.notifier)
                          .setWebUserAgent(UserAgents.webForCurrentPlatform()),
                    );
                  },
                ),
              ),
              minLines: 1,
              maxLines: 3,
              onChanged: (value) => unawaited(
                ref.read(appSettingsProvider.notifier).setWebUserAgent(value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
