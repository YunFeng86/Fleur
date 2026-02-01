import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/subscription_settings_provider.dart';
import '../../../../providers/query_providers.dart';
import '../../../../providers/app_settings_providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/feed.dart';
import '../../../../models/category.dart';
import '../../../../services/settings/app_settings.dart';
import '../../../../services/network/user_agents.dart';
import '../../../../utils/timeago_locale.dart';
import 'subscription_actions.dart';
import 'settings_inheritance_helper.dart';
import 'package:timeago/timeago.dart' as timeago;

class SettingsDetailPanel extends ConsumerWidget {
  const SettingsDetailPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(subscriptionSelectionProvider);
    final l10n = AppLocalizations.of(context)!;

    // 1. Feed Selected -> Show Feed Settings
    if (selection.selectedFeedId != null) {
      final feedId = selection.selectedFeedId!;
      final feedAsync = ref.watch(feedProvider(feedId));
      return feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (feed) {
          if (feed == null) return Center(child: Text(l10n.notFound));
          return _FeedSettings(feed: feed);
        },
      );
    }
    // 2. Category Selected (and NO Feed selected) -> Show Category Settings
    else if (selection.isRealCategory) {
      final categoryId = selection.activeCategoryId!;
      final categoryAsync = ref.watch(categoryProvider(categoryId));
      return categoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (category) {
          if (category == null) return Center(child: Text(l10n.notFound));
          return _CategorySettings(category: category);
        },
      );
    }
    // 3. Fallback -> Global Settings
    else {
      return const _GlobalSettings();
    }
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
      error: (e, s) => Center(child: Text('Error: $e')),
      data: (appSettings) {
        final last = lastSyncedAt();
        final lastText = last == null
            ? l10n.never
            : timeago.format(last.toLocal(), locale: timeagoLocale(context));
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              l10n.subscriptions,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.addSubscription),
              onTap: () => SubscriptionActions.showAddFeedDialog(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(l10n.newCategory),
              onTap: () =>
                  SubscriptionActions.showAddCategoryDialog(context, ref),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(l10n.refreshAll),
              subtitle: Text('${l10n.lastSynced}: $lastText'),
              onTap: () => SubscriptionActions.refreshAll(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: Text(l10n.importOpml),
              onTap: () => SubscriptionActions.importOpml(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: Text(l10n.exportOpml),
              onTap: () => SubscriptionActions.exportOpml(context, ref),
            ),
            const Divider(),
            _FilterSection(appSettings: appSettings),
            const Divider(),
            _SyncSection(appSettings: appSettings),
            const Divider(),
            _UserAgentSection(appSettings: appSettings),
          ],
        );
      },
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

    if (appSettings == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(category.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.edit),
          title: Text(l10n.rename),
          onTap: () => SubscriptionActions.renameCategory(
            context,
            ref,
            categoryId: category.id,
            currentName: category.name,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.red),
          title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          onTap: () {
            SubscriptionActions.deleteCategory(context, ref, category.id);
            ref
                .read(subscriptionSelectionProvider.notifier)
                .selectCategory(null);
          },
        ),
        const Divider(),
        _FilterSection(category: category, appSettings: appSettings),
        const Divider(),
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
    final category = feed.categoryId != null
        ? categories.where((c) => c.id == feed.categoryId).firstOrNull
        : null;

    if (appSettings == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          feed.userTitle ?? feed.title ?? 'Feed',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SelectableText(feed.url),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.edit),
          title: Text(l10n.rename),
          onTap: () => SubscriptionActions.editFeedTitle(
            context,
            ref,
            feedId: feed.id,
            currentTitle: feed.userTitle ?? feed.title,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.folder_open),
          title: Text(l10n.moveToCategory),
          subtitle: Text(category?.name ?? l10n.uncategorized),
          onTap: () =>
              SubscriptionActions.moveFeedToCategory(context, ref, feed.id),
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: Text(l10n.refresh),
          onTap: () => SubscriptionActions.refreshFeed(context, ref, feed.id),
        ),
        const Divider(),
        _FilterSection(
          feed: feed,
          category: category,
          appSettings: appSettings,
        ),
        const Divider(),
        _SyncSection(feed: feed, category: category, appSettings: appSettings),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.red),
          title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          onTap: () {
            SubscriptionActions.deleteFeed(context, ref, feed.id);
            ref
                .read(subscriptionSelectionProvider.notifier)
                .clearFeedSelection();
          },
        ),
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
    final colorScheme = Theme.of(context).colorScheme;

    final effectiveEnabled = SettingsInheritanceHelper.resolveFilterEnabled(
      feed,
      category,
      appSettings,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.filter,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _TriStateSwitch(
          title: l10n.enableFilter,
          // IMPORTANT: keep `currentValue` as the explicit value at this level.
          // Do not fall back to parent (category/global), otherwise selecting
          // "Auto" will appear to do nothing.
          currentValue:
              feed != null ? feed!.filterEnabled : category?.filterEnabled,
          effectiveValue: effectiveEnabled,
          isGlobal: feed == null && category == null,
          onChanged: (val) {
            if (feed != null) {
              SubscriptionActions.updateFeedSettings(
                context,
                ref,
                feedId: feed!.id,
                filterEnabled: val,
                updateFilterEnabled: true,
              );
            } else if (category != null) {
              SubscriptionActions.updateCategorySettings(
                context,
                ref,
                categoryId: category!.id,
                filterEnabled: val,
                updateFilterEnabled: true,
              );
            } else {
              ref
                  .read(appSettingsProvider.notifier)
                  .setFilterEnabled(val ?? false);
            }
          },
        ),
        if (effectiveEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _FilterKeywordsInput(
              feed: feed,
              category: category,
              appSettings: appSettings,
            ),
          ),
      ],
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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.sync,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _TriStateSwitch(
          title: l10n.enableSync,
          currentValue: feed != null ? feed!.syncEnabled : category?.syncEnabled,
          effectiveValue: SettingsInheritanceHelper.resolveSyncEnabled(
            feed,
            category,
            appSettings,
          ),
          isGlobal: feed == null && category == null,
          onChanged: (val) {
            if (feed != null) {
              SubscriptionActions.updateFeedSettings(
                context,
                ref,
                feedId: feed!.id,
                syncEnabled: val,
                updateSyncEnabled: true,
              );
            } else if (category != null) {
              SubscriptionActions.updateCategorySettings(
                context,
                ref,
                categoryId: category!.id,
                syncEnabled: val,
                updateSyncEnabled: true,
              );
            } else {
              ref
                  .read(appSettingsProvider.notifier)
                  .setSyncEnabled(val ?? true);
            }
          },
        ),
        _TriStateSwitch(
          title: l10n.syncImages,
          currentValue: feed != null ? feed!.syncImages : category?.syncImages,
          effectiveValue: SettingsInheritanceHelper.resolveSyncImages(
            feed,
            category,
            appSettings,
          ),
          isGlobal: feed == null && category == null,
          onChanged: (val) {
            if (feed != null) {
              SubscriptionActions.updateFeedSettings(
                context,
                ref,
                feedId: feed!.id,
                syncImages: val,
                updateSyncImages: true,
              );
            } else if (category != null) {
              SubscriptionActions.updateCategorySettings(
                context,
                ref,
                categoryId: category!.id,
                syncImages: val,
                updateSyncImages: true,
              );
            } else {
              ref.read(appSettingsProvider.notifier).setSyncImages(val ?? true);
            }
          },
        ),
        _TriStateSwitch(
          title: l10n.syncWebPages,
          currentValue:
              feed != null ? feed!.syncWebPages : category?.syncWebPages,
          effectiveValue: SettingsInheritanceHelper.resolveSyncWebPages(
            feed,
            category,
            appSettings,
          ),
          isGlobal: feed == null && category == null,
          onChanged: (val) {
            if (feed != null) {
              SubscriptionActions.updateFeedSettings(
                context,
                ref,
                feedId: feed!.id,
                syncWebPages: val,
                updateSyncWebPages: true,
              );
            } else if (category != null) {
              SubscriptionActions.updateCategorySettings(
                context,
                ref,
                categoryId: category!.id,
                syncWebPages: val,
                updateSyncWebPages: true,
              );
            } else {
              ref
                  .read(appSettingsProvider.notifier)
                  .setSyncWebPages(val ?? false);
            }
          },
        ),
      ],
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
    super.key,
    required this.title,
    required this.currentValue,
    required this.effectiveValue,
    required this.isGlobal,
    required this.onChanged,
  });

  @override
  State<_TriStateSwitch> createState() => _TriStateSwitchState();
}

class _TriStateSwitchState extends State<_TriStateSwitch> {
  final _menuKey = GlobalKey<PopupMenuButtonState<bool?>>();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.isGlobal) {
      return SwitchListTile(
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

    return ListTile(
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
              tooltip:
                  l10n.inherit, // "Inherit" effectively means reset to default
              onPressed: () => widget.onChanged(null),
            ),
          // We use a PopupMenuButton for selection
          PopupMenuButton<bool?>(
            key: _menuKey,
            icon: const Icon(Icons.arrow_drop_down),
            onSelected: widget.onChanged,
            initialValue: widget.currentValue,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: null,
                child: Text(
                  '${l10n.auto} (${widget.effectiveValue ? l10n.autoOn : l10n.autoOff})',
                ),
              ),
              PopupMenuItem(value: true, child: Text(l10n.enabled)),
              PopupMenuItem(value: false, child: Text(l10n.off)),
            ],
          ),
        ],
      ),
      onTap: () => _menuKey.currentState?.showButtonMenu(),
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
  String? get _currentValue =>
      widget.feed != null
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
            // When inheriting, don't show "inherit:" text; show effective value
            // directly (read-only) to match global/category-global behavior.
            hintText:
                _isInherit && _effectiveValue.trim().isEmpty
                    ? l10n.defaultValue
                    : null,
            border: const OutlineInputBorder(),
            filled: true,
            helperText: l10n.filterKeywordsHint,
            helperMaxLines: 2,
            suffixIcon:
                _isGlobal
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
      ref.read(appSettingsProvider.notifier).setFilterKeywords(next ?? '');
    } else if (widget.feed != null) {
      SubscriptionActions.updateFeedSettings(
        context,
        ref,
        feedId: widget.feed!.id,
        filterKeywords: next,
        updateFilterKeywords: true,
      );
    } else if (widget.category != null) {
      SubscriptionActions.updateCategorySettings(
        context,
        ref,
        categoryId: widget.category!.id,
        filterKeywords: next,
        updateFilterKeywords: true,
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
    _rssController = TextEditingController(text: widget.appSettings.rssUserAgent);
    _webController = TextEditingController(text: widget.appSettings.webUserAgent);
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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l10n.userAgent,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _rssController,
            decoration: InputDecoration(
              labelText: l10n.rssUserAgent,
              border: const OutlineInputBorder(),
              filled: true,
              helperText: l10n.userAgentRssHint,
              helperMaxLines: 2,
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: l10n.resetToDefault,
                onPressed: () {
                  _rssController.text = UserAgents.rss;
                  ref
                      .read(appSettingsProvider.notifier)
                      .setRssUserAgent(UserAgents.rss);
                },
              ),
            ),
            minLines: 1,
            maxLines: 3,
            onChanged: (value) =>
                ref.read(appSettingsProvider.notifier).setRssUserAgent(value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: TextField(
            controller: _webController,
            decoration: InputDecoration(
              labelText: l10n.webUserAgent,
              border: const OutlineInputBorder(),
              filled: true,
              helperText: l10n.userAgentWebHint,
              helperMaxLines: 2,
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: l10n.resetToDefault,
                onPressed: () {
                  _webController.text = UserAgents.web;
                  ref
                      .read(appSettingsProvider.notifier)
                      .setWebUserAgent(UserAgents.web);
                },
              ),
            ),
            minLines: 1,
            maxLines: 3,
            onChanged: (value) =>
                ref.read(appSettingsProvider.notifier).setWebUserAgent(value),
          ),
        ),
      ],
    );
  }
}
