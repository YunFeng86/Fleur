import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/category.dart';
import '../models/feed.dart';
import '../models/rule.dart';
import '../providers/app_settings_providers.dart';
import '../providers/opml_providers.dart';
import '../providers/query_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/service_providers.dart';
import '../providers/settings_providers.dart';
import '../services/settings/app_settings.dart';
import '../services/settings/reader_settings.dart';
import '../services/opml/opml_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedIndex = 0;

  List<_SettingsPageItem> _buildItems(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      _SettingsPageItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: l10n.appPreferences,
        content: const _AppPreferencesTab(),
      ),
      _SettingsPageItem(
        icon: Icons.rss_feed_outlined,
        selectedIcon: Icons.rss_feed,
        label: l10n.subscriptions,
        content: const _SubscriptionsTab(),
      ),
      _SettingsPageItem(
        icon: Icons.format_list_bulleted,
        selectedIcon: Icons.format_list_bulleted,
        label: l10n.groupingAndSorting,
        content: const _GroupingSortingTab(),
      ),
      _SettingsPageItem(
        icon: Icons.filter_alt_outlined,
        selectedIcon: Icons.filter_alt,
        label: l10n.rules,
        content: const _RulesTab(),
      ),
      _SettingsPageItem(
        icon: Icons.cloud_outlined,
        selectedIcon: Icons.cloud,
        label: l10n.services,
        content: const _ServicesTab(),
      ),
      _SettingsPageItem(
        icon: Icons.info_outline,
        selectedIcon: Icons.info,
        label: l10n.about,
        content: const _AboutTab(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final items = _buildItems(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 700) {
            // Mobile / Narrow Layout
            return Scaffold(
              appBar: AppBar(
                leading: const BackButton(),
                title: Text(l10n.settings),
              ),
              body: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  // Match desktop sidebar style
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: Icon(item.icon, size: 20),
                      title: Text(item.label),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(title: Text(item.label)),
                              body: item.content,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            );
          } else {
            // Desktop / Wide Layout
            if (_selectedIndex >= items.length) {
              _selectedIndex = 0;
            }
            final selectedItem = items[_selectedIndex];

            return Column(
              children: [
                AppBar(
                  leading: const BackButton(),
                  title: Text(l10n.settings),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Sidebar
                      Material(
                        color: theme.colorScheme.surfaceContainerLow,
                        child: SizedBox(
                          width: 260,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            itemCount: items.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final isSelected = index == _selectedIndex;

                              // Mimic existing Sidebar style
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  selected: isSelected,
                                  leading: Icon(
                                    isSelected ? item.selectedIcon : item.icon,
                                    size: 20,
                                  ),
                                  title: Text(item.label),
                                  onTap: () {
                                    setState(() {
                                      _selectedIndex = index;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      // Right Content Area
                      Expanded(
                        child: FocusTraversalGroup(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            child: KeyedSubtree(
                              key: ValueKey(_selectedIndex),
                              child: Scaffold(
                                // Inner Scaffold for scrolling body
                                backgroundColor: Colors.transparent,
                                body: selectedItem.content,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}

class _SettingsPageItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget content;

  const _SettingsPageItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.content,
  });
}

class _GroupingSortingTab extends ConsumerWidget {
  const _GroupingSortingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final appSettings =
        ref.watch(appSettingsProvider).valueOrNull ?? const AppSettings();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _SectionHeader(title: l10n.groupingAndSorting),
            const SizedBox(height: 8),

            // Group by
            Text(l10n.groupBy, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ArticleGroupMode>(
                  value: appSettings.articleGroupMode,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: ArticleGroupMode.none,
                      child: Text(l10n.groupNone),
                    ),
                    DropdownMenuItem(
                      value: ArticleGroupMode.day,
                      child: Text(l10n.groupByDay),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    ref
                        .read(appSettingsProvider.notifier)
                        .setArticleGroupMode(v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Sort order
            Text(l10n.sortOrder, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ArticleSortOrder>(
                  value: appSettings.articleSortOrder,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: ArticleSortOrder.newestFirst,
                      child: Text(l10n.sortNewestFirst),
                    ),
                    DropdownMenuItem(
                      value: ArticleSortOrder.oldestFirst,
                      child: Text(l10n.sortOldestFirst),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    ref
                        .read(appSettingsProvider.notifier)
                        .setArticleSortOrder(v);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RulesTab extends ConsumerWidget {
  const _RulesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.watch(ruleRepositoryProvider);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _SectionHeader(title: l10n.rules)),
                  FilledButton.icon(
                    onPressed: () => _showRuleEditor(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addRule),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final rulesAsync = ref.watch(ruleListProvider);

                    return rulesAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) =>
                          Center(child: Text(l10n.errorMessage(e.toString()))),
                      data: (rules) {
                        if (rules.isEmpty) {
                          return Center(child: Text(l10n.notFound));
                        }
                        return ListView.separated(
                          itemCount: rules.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final r = rules[index];
                            return ListTile(
                              title: Text(r.name),
                              subtitle: Text(
                                r.keyword,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              leading: Switch(
                                value: r.enabled,
                                onChanged: (v) => repo.setEnabled(r.id, v),
                              ),
                              trailing: PopupMenuButton<_RuleMenuAction>(
                                onSelected: (v) async {
                                  switch (v) {
                                    case _RuleMenuAction.edit:
                                      await _showRuleEditor(
                                        context,
                                        ref,
                                        existing: r,
                                      );
                                      return;
                                    case _RuleMenuAction.delete:
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: Text(l10n.delete),
                                            content: Text(r.name),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(false),
                                                child: Text(l10n.cancel),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                                child: Text(l10n.delete),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      if (ok == true) {
                                        await repo.delete(r.id);
                                      }
                                      return;
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: _RuleMenuAction.edit,
                                    child: Text(l10n.editRule),
                                  ),
                                  PopupMenuItem(
                                    value: _RuleMenuAction.delete,
                                    child: Text(l10n.delete),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRuleEditor(
    BuildContext context,
    WidgetRef ref, {
    Rule? existing,
  }) async {
    final draft = await showDialog<_RuleDraft>(
      context: context,
      builder: (context) => _RuleEditorDialog(existing: existing),
    );
    if (draft == null) return;
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;

    if (!draft.hasMatchField) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorMessage(l10n.matchIn))));
      return;
    }
    if (!draft.hasAction) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorMessage(l10n.actions))));
      return;
    }

    try {
      await ref
          .read(ruleRepositoryProvider)
          .upsert(
            id: existing?.id,
            name: draft.name,
            keyword: draft.keyword,
            enabled: draft.enabled,
            matchTitle: draft.matchTitle,
            matchAuthor: draft.matchAuthor,
            matchLink: draft.matchLink,
            matchContent: draft.matchContent,
            autoStar: draft.autoStar,
            autoMarkRead: draft.autoMarkRead,
            notify: draft.notify,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorMessage(e.toString()))));
    }
  }
}

enum _RuleMenuAction { edit, delete }

class _RuleDraft {
  _RuleDraft({
    required this.enabled,
    required this.name,
    required this.keyword,
    required this.matchTitle,
    required this.matchAuthor,
    required this.matchLink,
    required this.matchContent,
    required this.autoStar,
    required this.autoMarkRead,
    required this.notify,
  });

  final bool enabled;
  final String name;
  final String keyword;
  final bool matchTitle;
  final bool matchAuthor;
  final bool matchLink;
  final bool matchContent;
  final bool autoStar;
  final bool autoMarkRead;
  final bool notify;

  bool get hasMatchField =>
      matchTitle || matchAuthor || matchLink || matchContent;
  bool get hasAction => autoStar || autoMarkRead || notify;
}

class _RuleEditorDialog extends StatefulWidget {
  const _RuleEditorDialog({this.existing});

  final Rule? existing;

  @override
  State<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<_RuleEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _keyword;
  bool _enabled = true;
  bool _matchTitle = true;
  bool _matchAuthor = false;
  bool _matchLink = false;
  bool _matchContent = false;
  bool _autoStar = false;
  bool _autoMarkRead = false;
  bool _notify = false;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _name = TextEditingController(text: r?.name ?? '');
    _keyword = TextEditingController(text: r?.keyword ?? '');
    _enabled = r?.enabled ?? true;
    _matchTitle = r?.matchTitle ?? true;
    _matchAuthor = r?.matchAuthor ?? false;
    _matchLink = r?.matchLink ?? false;
    _matchContent = r?.matchContent ?? false;
    _autoStar = r?.autoStar ?? false;
    _autoMarkRead = r?.autoMarkRead ?? false;
    _notify = r?.notify ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _keyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.existing == null ? l10n.addRule : l10n.editRule),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: l10n.ruleName),
                autofocus: widget.existing == null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _keyword,
                decoration: InputDecoration(labelText: l10n.keyword),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.enabled),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              const Divider(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.matchIn,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.matchTitle),
                value: _matchTitle,
                onChanged: (v) => setState(() => _matchTitle = v ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.matchAuthor),
                value: _matchAuthor,
                onChanged: (v) => setState(() => _matchAuthor = v ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.matchLink),
                value: _matchLink,
                onChanged: (v) => setState(() => _matchLink = v ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.matchContent),
                value: _matchContent,
                onChanged: (v) => setState(() => _matchContent = v ?? false),
              ),
              const Divider(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.actions,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.autoStar),
                value: _autoStar,
                onChanged: (v) => setState(() => _autoStar = v ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.autoMarkReadAction),
                value: _autoMarkRead,
                onChanged: (v) => setState(() => _autoMarkRead = v ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.showNotification),
                value: _notify,
                onChanged: (v) => setState(() => _notify = v ?? false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _RuleDraft(
                enabled: _enabled,
                name: _name.text,
                keyword: _keyword.text,
                matchTitle: _matchTitle,
                matchAuthor: _matchAuthor,
                matchLink: _matchLink,
                matchContent: _matchContent,
                autoStar: _autoStar,
                autoMarkRead: _autoMarkRead,
                notify: _notify,
              ),
            );
          },
          child: Text(l10n.done),
        ),
      ],
    );
  }
}

class _AppPreferencesTab extends ConsumerWidget {
  const _AppPreferencesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final appSettings =
        ref.watch(appSettingsProvider).valueOrNull ?? const AppSettings();
    final readerSettings =
        ref.watch(readerSettingsProvider).valueOrNull ?? const ReaderSettings();

    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Language
                _SectionHeader(title: l10n.language),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: appSettings.localeTag,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l10n.systemLanguage),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'en',
                          child: Text(l10n.english),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'zh',
                          child: Text(l10n.chineseSimplified),
                        ),
                        DropdownMenuItem<String?>(
                          value: 'zh-Hant',
                          child: Text(l10n.chineseTraditional),
                        ),
                      ],
                      onChanged: (v) => ref
                          .read(appSettingsProvider.notifier)
                          .setLocaleTag(v),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Theme
                _SectionHeader(title: l10n.theme),
                RadioGroup<ThemeMode>(
                  groupValue: appSettings.themeMode,
                  onChanged: (v) {
                    if (v == null) return;
                    ref.read(appSettingsProvider.notifier).setThemeMode(v);
                  },
                  child: Column(
                    children: [
                      _ThemeRadioItem(
                        label: l10n.system,
                        value: ThemeMode.system,
                      ),
                      _ThemeRadioItem(
                        label: l10n.light,
                        value: ThemeMode.light,
                      ),
                      _ThemeRadioItem(label: l10n.dark, value: ThemeMode.dark),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Reader Settings (Font Size, etc.)
                // Kept here to maintain functionality even though not strictly in reference image
                _SectionHeader(title: l10n.readerSettings),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.autoMarkRead),
                  value: appSettings.autoMarkRead,
                  onChanged: (v) =>
                      ref.read(appSettingsProvider.notifier).setAutoMarkRead(v),
                ),
                _SliderTile(
                  title: l10n.fontSize,
                  value: readerSettings.fontSize,
                  min: 12,
                  max: 28,
                  format: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => ref
                      .read(readerSettingsProvider.notifier)
                      .save(readerSettings.copyWith(fontSize: v)),
                ),
                _SliderTile(
                  title: l10n.lineHeight,
                  value: readerSettings.lineHeight,
                  min: 1.1,
                  max: 2.2,
                  format: (v) => v.toStringAsFixed(1),
                  onChanged: (v) => ref
                      .read(readerSettingsProvider.notifier)
                      .save(readerSettings.copyWith(lineHeight: v)),
                ),
                _SliderTile(
                  title: l10n.horizontalPadding,
                  value: readerSettings.horizontalPadding,
                  min: 8,
                  max: 32,
                  format: (v) => v.toStringAsFixed(0),
                  onChanged: (v) => ref
                      .read(readerSettingsProvider.notifier)
                      .save(readerSettings.copyWith(horizontalPadding: v)),
                ),
                const SizedBox(height: 24),

                // Cleanup
                _SectionHeader(title: l10n.storage),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(l10n.clearImageCacheSubtitle)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () async {
                          await ref.read(cacheManagerProvider).emptyCache();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.cacheCleared)),
                          );
                        },
                        child: Text(l10n.clearImageCache),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.cleanupReadArticles,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<int?>(
                              value: appSettings.cleanupReadOlderThanDays,
                              isExpanded: true,
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(l10n.off),
                                ),
                                for (final d in const [7, 30, 90, 180])
                                  DropdownMenuItem<int?>(
                                    value: d,
                                    child: Text(l10n.days(d)),
                                  ),
                              ],
                              onChanged: (v) => ref
                                  .read(appSettingsProvider.notifier)
                                  .setCleanupReadOlderThanDays(v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed:
                                appSettings.cleanupReadOlderThanDays == null
                                ? null
                                : () async {
                                    final days =
                                        appSettings.cleanupReadOlderThanDays!;
                                    final cutoff = DateTime.now()
                                        .toUtc()
                                        .subtract(Duration(days: days));
                                    final n = await ref
                                        .read(articleRepositoryProvider)
                                        .deleteReadUnstarredOlderThan(cutoff);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.cleanedArticles(n)),
                                      ),
                                    );
                                  },
                            child: Text(l10n.cleanupNow),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubscriptionsTab extends ConsumerStatefulWidget {
  const _SubscriptionsTab();

  @override
  ConsumerState<_SubscriptionsTab> createState() => _SubscriptionsTabState();
}

class _SubscriptionsTabState extends ConsumerState<_SubscriptionsTab> {
  final _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final feedsAsync = ref.watch(feedsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: l10n.search,
                              prefixIcon: const Icon(Icons.search),
                              isDense: true,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: l10n.refreshAll,
                          onPressed: () => _refreshAll(context),
                          icon: const Icon(Icons.refresh),
                        ),
                        IconButton(
                          tooltip: l10n.importOpml,
                          onPressed: () => _importOpml(context),
                          icon: const Icon(Icons.file_upload_outlined),
                        ),
                        IconButton(
                          tooltip: l10n.exportOpml,
                          onPressed: () => _exportOpml(context),
                          icon: const Icon(Icons.file_download_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: () => _showAddFeedDialog(context),
                          icon: const Icon(Icons.add),
                          label: Text(l10n.addSubscription),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _showAddCategoryDialog(context),
                          icon: const Icon(Icons.create_new_folder_outlined),
                          label: Text(l10n.newCategory),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(title: l10n.subscriptions),
                  ],
                ),
              ),
            ),
          ),
        ),
        feedsAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Center(child: LinearProgressIndicator()),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Center(child: Text(l10n.errorMessage(e.toString()))),
          ),
          data: (feeds) {
            final filteredFeeds = _searchText.isEmpty
                ? feeds
                : feeds.where((f) {
                    final t = (f.userTitle ?? f.title ?? '').toLowerCase();
                    return t.contains(_searchText) ||
                        f.url.toLowerCase().contains(_searchText);
                  }).toList();

            return categoriesAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(child: LinearProgressIndicator()),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(child: Text(l10n.errorMessage(e.toString()))),
              ),
              data: (cats) {
                final byCat = <int?, List<Feed>>{};
                for (final f in filteredFeeds) {
                  byCat.putIfAbsent(f.categoryId, () => <Feed>[]).add(f);
                }

                final items = <_SubscriptionItem>[];

                // Sorted categories
                for (final c in cats) {
                  final catFeeds = byCat[c.id] ?? const <Feed>[];
                  if (_searchText.isNotEmpty && catFeeds.isEmpty) {
                    continue;
                  }
                  items.add(_HeaderItem(c, c.name));
                  for (final f in catFeeds) {
                    items.add(_FeedItem(f));
                  }
                }

                // Uncategorized
                final uncategorized = byCat[null] ?? const <Feed>[];
                if (_searchText.isEmpty || uncategorized.isNotEmpty) {
                  items.add(_HeaderItem(null, l10n.uncategorized));
                  for (final f in uncategorized) {
                    items.add(_FeedItem(f));
                  }
                }

                if (items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l10n.notFound),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  sliver: SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Builder(
                            builder: (context) {
                              if (item is _HeaderItem) {
                                return _CategoryHeaderWidget(
                                  name: item.name,
                                  onRename: item.category == null
                                      ? null
                                      : () => _renameCategory(
                                          context,
                                          categoryId: item.category!.id,
                                          currentName: item.category!.name,
                                        ),
                                  onDelete: item.category == null
                                      ? null
                                      : () => _deleteCategory(
                                          context,
                                          item.category!.id,
                                        ),
                                );
                              } else if (item is _FeedItem) {
                                final f = item.feed;
                                return _FeedTile(
                                  title:
                                      (f.userTitle?.trim().isNotEmpty == true)
                                      ? f.userTitle!
                                      : (f.title?.trim().isNotEmpty == true)
                                      ? f.title!
                                      : f.url,
                                  url: f.url,
                                  lastCheckedAt: f.lastCheckedAt,
                                  lastSyncedAt: f.lastSyncedAt,
                                  lastStatusCode: f.lastStatusCode,
                                  lastError: f.lastError,
                                  onEdit: () => _editFeedTitle(
                                    context,
                                    feedId: f.id,
                                    currentTitle: f.userTitle,
                                  ),
                                  onRefresh: () => _refreshFeed(context, f.id),
                                  onMove: () =>
                                      _moveFeedToCategory(context, f.id),
                                  onDelete: () => _deleteFeed(context, f.id),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _showAddFeedDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.addSubscription),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.rssAtomUrl,
              hintText: 'https://example.com/feed.xml',
            ),
            autofocus: true,
            keyboardType: TextInputType.url,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(l10n.add),
            ),
          ],
        );
      },
    );
    if (url == null || url.trim().isEmpty) return;

    final id = await ref.read(feedRepositoryProvider).upsertUrl(url);
    final r = await ref.read(syncServiceProvider).refreshFeedSafe(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.ok ? l10n.addedAndSynced : l10n.errorMessage(r.error.toString()),
        ),
      ),
    );
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.newCategory),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: l10n.name),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(l10n.create),
            ),
          ],
        );
      },
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(categoryRepositoryProvider).upsertByName(name);
  }

  Future<void> _refreshFeed(BuildContext context, int feedId) async {
    final l10n = AppLocalizations.of(context)!;
    final r = await ref.read(syncServiceProvider).refreshFeedSafe(feedId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.ok ? l10n.refreshed : l10n.errorMessage(r.error.toString()),
        ),
      ),
    );
  }

  Future<void> _refreshAll(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final feeds = await ref.read(feedRepositoryProvider).getAll();
    if (feeds.isEmpty) return;

    final appSettings = ref.read(appSettingsProvider).valueOrNull;
    final concurrency = appSettings?.autoRefreshConcurrency ?? 2;

    if (!context.mounted) return;

    // Show progress dialog
    final progressNotifier = ValueNotifier<String>('0/${feeds.length}');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 24),
                ValueListenableBuilder<String>(
                  valueListenable: progressNotifier,
                  builder: (context, value, _) {
                    return Text(
                      l10n.refreshingProgress(
                        int.tryParse(value.split('/')[0]) ?? 0,
                        int.tryParse(value.split('/')[1]) ?? feeds.length,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    final batch = await ref
        .read(syncServiceProvider)
        .refreshFeedsSafe(
          feeds.map((f) => f.id),
          maxConcurrent: concurrency,
          onProgress: (current, total) {
            progressNotifier.value = '$current/$total';
          },
        );

    if (!context.mounted) return;
    Navigator.of(context).pop(); // Close progress dialog

    final err = batch.firstError?.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err == null ? l10n.refreshedAll : l10n.errorMessage(err.toString()),
        ),
      ),
    );
  }

  Future<void> _moveFeedToCategory(BuildContext context, int feedId) async {
    final l10n = AppLocalizations.of(context)!;
    final cats = await ref.read(categoryRepositoryProvider).getAll();
    if (!context.mounted) return;
    final selected = await showDialog<int?>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(l10n.moveToCategory),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(l10n.uncategorized),
            ),
            for (final c in cats)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(c.id),
                child: Text(c.name),
              ),
          ],
        );
      },
    );
    await ref
        .read(feedRepositoryProvider)
        .setCategory(feedId: feedId, categoryId: selected);
  }

  Future<void> _deleteFeed(BuildContext context, int feedId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteSubscriptionConfirmTitle),
          content: Text(l10n.deleteSubscriptionConfirmContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await ref.read(feedRepositoryProvider).delete(feedId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.deleted)));
  }

  Future<void> _deleteCategory(BuildContext context, int categoryId) async {
    await ref.read(categoryRepositoryProvider).delete(categoryId);
  }

  Future<void> _renameCategory(
    BuildContext context, {
    required int categoryId,
    required String currentName,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentName);
    final next = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.rename),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: l10n.name),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(l10n.done),
            ),
          ],
        );
      },
    );
    if (next == null) return;
    try {
      await ref.read(categoryRepositoryProvider).rename(categoryId, next);
    } catch (e) {
      if (!context.mounted) return;
      final msg = e.toString().contains('already exists')
          ? l10n.nameAlreadyExists
          : e.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorMessage(msg))));
    }
  }

  Future<void> _editFeedTitle(
    BuildContext context, {
    required int feedId,
    required String? currentTitle,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentTitle ?? '');
    final next = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.edit),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: l10n.name),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: Text(l10n.delete),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(l10n.done),
            ),
          ],
        );
      },
    );
    if (next == null) return;
    await ref
        .read(feedRepositoryProvider)
        .setUserTitle(feedId: feedId, userTitle: next);
  }

  Future<void> _importOpml(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    const group = XTypeGroup(
      label: 'OPML',
      extensions: ['opml', 'xml'],
      mimeTypes: ['text/xml', 'application/xml'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    final xml = await file.readAsString();
    List<OpmlEntry> entries;
    try {
      entries = ref.read(opmlServiceProvider).parseEntries(xml);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorMessage(l10n.opmlParseFailed))),
      );
      return;
    }
    if (entries.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noFeedsFoundInOpml)));
      return;
    }

    var added = 0;
    for (final e in entries) {
      final feedId = await ref.read(feedRepositoryProvider).upsertUrl(e.url);
      if (e.category != null && e.category!.trim().isNotEmpty) {
        final catId = await ref
            .read(categoryRepositoryProvider)
            .upsertByName(e.category!);
        await ref
            .read(feedRepositoryProvider)
            .setCategory(feedId: feedId, categoryId: catId);
      }
      added += 1;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.importedFeeds(added))));
  }

  Future<void> _exportOpml(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final loc = await getSaveLocation(suggestedName: 'subscriptions.opml');
    if (loc == null) return;
    final feeds = await ref.read(feedRepositoryProvider).getAll();
    final cats = await ref.read(categoryRepositoryProvider).getAll();
    final names = {for (final c in cats) c.id: c.name};
    final xml = ref
        .read(opmlServiceProvider)
        .buildOpml(feeds: feeds, categoryNames: names);
    final xfile = XFile.fromData(
      Uint8List.fromList(utf8.encode(xml)),
      mimeType: 'text/xml',
      name: 'subscriptions.opml',
    );
    await xfile.saveTo(loc.path);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.exportedOpml)));
  }
}

class _ServicesTab extends ConsumerWidget {
  const _ServicesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final appSettings =
        ref.watch(appSettingsProvider).valueOrNull ?? const AppSettings();

    final interval = appSettings.autoRefreshMinutes;

    Future<void> refreshNow() async {
      final feeds = await ref.read(feedRepositoryProvider).getAll();
      if (feeds.isEmpty) return;

      final concurrency = appSettings.autoRefreshConcurrency;

      if (!context.mounted) return;

      // Show progress dialog
      final progressNotifier = ValueNotifier<String>('0/${feeds.length}');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 24),
                  ValueListenableBuilder<String>(
                    valueListenable: progressNotifier,
                    builder: (context, value, _) {
                      return Text(
                        l10n.refreshingProgress(
                          int.tryParse(value.split('/')[0]) ?? 0,
                          int.tryParse(value.split('/')[1]) ?? feeds.length,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );

      final batch = await ref
          .read(syncServiceProvider)
          .refreshFeedsSafe(
            feeds.map((f) => f.id),
            maxConcurrent: concurrency,
            onProgress: (current, total) {
              progressNotifier.value = '$current/$total';
            },
          );

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close progress dialog

      final err = batch.firstError?.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err == null ? l10n.refreshedAll : l10n.errorMessage(err.toString()),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(title: l10n.services),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.autoRefreshSubtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: interval,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text(l10n.off),
                            ),
                            for (final m in const [5, 15, 30, 60])
                              DropdownMenuItem<int?>(
                                value: m,
                                child: Text(l10n.everyMinutes(m)),
                              ),
                          ],
                          onChanged: (v) => ref
                              .read(appSettingsProvider.notifier)
                              .setAutoRefreshMinutes(v),
                        ),
                      ),
                      const Divider(height: 24),
                      Text(
                        l10n.refreshConcurrency,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: appSettings.autoRefreshConcurrency,
                          isExpanded: true,
                          items: [
                            for (final c in [1, 2, 4, 6])
                              DropdownMenuItem(
                                value: c,
                                child: Text(c.toString()),
                              ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              ref
                                  .read(appSettingsProvider.notifier)
                                  .setAutoRefreshConcurrency(v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: refreshNow,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.refreshAll),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutTab extends StatefulWidget {
  const _AboutTab();

  @override
  State<_AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<_AboutTab> {
  late final Future<Directory> _docDirFuture;

  @override
  void initState() {
    super.initState();
    _docDirFuture = getApplicationDocumentsDirectory();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(title: l10n.about),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.appTitle, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      FutureBuilder(
                        future: _docDirFuture,
                        builder: (context, snapshot) {
                          final path = snapshot.data?.path;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.dataDirectory,
                                style: theme.textTheme.labelLarge,
                              ),
                              const SizedBox(height: 4),
                              SelectableText(path ?? '...'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: path == null
                                        ? null
                                        : () async {
                                            await Clipboard.setData(
                                              ClipboardData(text: path),
                                            );
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(l10n.done),
                                              ),
                                            );
                                          },
                                    child: Text(l10n.copyPath),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton(
                                    onPressed: path == null
                                        ? null
                                        : () {
                                            launchUrl(
                                              Uri.file(path),
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                          },
                                    child: Text(l10n.openFolder),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _SectionHeader(title: l10n.keyboardShortcuts),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DefaultTextStyle(
                    style: theme.textTheme.bodyMedium!,
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('J / K: Next / previous article'),
                        Text('R: Refresh (current selection)'),
                        Text('U: Toggle unread-only'),
                        Text('M: Toggle read/unread for selected article'),
                        Text('S: Toggle star for selected article'),
                        Text('Ctrl+F: Search articles'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({
    required this.title,
    required this.url,
    required this.lastCheckedAt,
    required this.lastSyncedAt,
    required this.lastStatusCode,
    required this.lastError,
    required this.onEdit,
    required this.onRefresh,
    required this.onMove,
    required this.onDelete,
  });

  final String title;
  final String url;
  final DateTime? lastCheckedAt;
  final DateTime? lastSyncedAt;
  final int? lastStatusCode;
  final String? lastError;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final checkedStr = lastCheckedAt == null
        ? l10n.never
        : DateFormat('yyyy/MM/dd HH:mm').format(lastCheckedAt!.toLocal());
    final syncedStr = lastSyncedAt == null
        ? l10n.never
        : DateFormat('yyyy/MM/dd HH:mm').format(lastSyncedAt!.toLocal());

    final lines = <String>[
      url,
      '${l10n.lastChecked}: $checkedStr'
          '${lastStatusCode == null ? '' : ' (${lastStatusCode!})'}',
      '${l10n.lastSynced}: $syncedStr',
      if (lastError != null && lastError!.trim().isNotEmpty)
        l10n.errorMessage(lastError!.trim()),
    ];

    // Keep the tile compact, but show enough status to debug sync issues.
    final maxLines = lines.length.clamp(2, 4);
    return ListTile(
      leading: const Icon(Icons.rss_feed),
      title: Text(title),
      subtitle: Text(
        lines.join('\n'),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<_FeedMenuAction>(
        onSelected: (v) {
          switch (v) {
            case _FeedMenuAction.edit:
              onEdit();
              return;
            case _FeedMenuAction.refresh:
              onRefresh();
              return;
            case _FeedMenuAction.move:
              onMove();
              return;
            case _FeedMenuAction.delete:
              onDelete();
              return;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: _FeedMenuAction.edit, child: Text(l10n.edit)),
          PopupMenuItem(
            value: _FeedMenuAction.refresh,
            child: Text(l10n.refresh),
          ),
          PopupMenuItem(
            value: _FeedMenuAction.move,
            child: Text(l10n.moveToCategory),
          ),
          PopupMenuItem(
            value: _FeedMenuAction.delete,
            child: Text(l10n.deleteSubscription),
          ),
        ],
      ),
    );
  }
}

enum _FeedMenuAction { edit, refresh, move, delete }

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ThemeRadioItem extends StatelessWidget {
  const _ThemeRadioItem({required this.label, required this.value});

  final String label;
  final ThemeMode value;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ThemeMode>(
      title: Text(label),
      value: value,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.format,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String Function(double v) format;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(title), Text(format(value))],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

sealed class _SubscriptionItem {}

class _HeaderItem extends _SubscriptionItem {
  final Category? category;
  final String name;
  _HeaderItem(this.category, this.name);
}

class _FeedItem extends _SubscriptionItem {
  final Feed feed;
  _FeedItem(this.feed);
}

class _CategoryHeaderWidget extends StatelessWidget {
  const _CategoryHeaderWidget({
    required this.name,
    this.onRename,
    this.onDelete,
  });

  final String name;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (onRename != null)
            IconButton(
              tooltip: AppLocalizations.of(context)!.rename,
              onPressed: onRename,
              icon: const Icon(Icons.edit_outlined),
              iconSize: 20,
              splashRadius: 20,
            ),
          if (onDelete != null)
            IconButton(
              tooltip: AppLocalizations.of(context)!.deleteCategory,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              iconSize: 20,
              splashRadius: 20,
            ),
        ],
      ),
    );
  }
}
