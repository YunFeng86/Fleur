import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/feed.dart';
import '../providers/app_settings_providers.dart';
import '../providers/opml_providers.dart';
import '../providers/query_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/service_providers.dart';
import '../providers/settings_providers.dart';
import '../services/settings/app_settings.dart';
import '../services/settings/reader_settings.dart';

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
        content: _PlaceholderTab(l10n.groupingAndSorting),
      ),
      _SettingsPageItem(
        icon: Icons.filter_alt_outlined,
        selectedIcon: Icons.filter_alt,
        label: l10n.rules,
        content: _PlaceholderTab(l10n.rules),
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
                      Container(
                        width: 260,
                        color: theme.colorScheme.surfaceContainerLow,
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
                      // Divider
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
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

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
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

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(24),
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
                  onChanged: (v) =>
                      ref.read(appSettingsProvider.notifier).setLocaleTag(v),
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
                  _ThemeRadioItem(label: l10n.system, value: ThemeMode.system),
                  _ThemeRadioItem(label: l10n.light, value: ThemeMode.light),
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
          ],
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

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(24),
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
            feedsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(l10n.errorMessage(e.toString())),
              data: (feeds) {
                final filteredFeeds = _searchText.isEmpty
                    ? feeds
                    : feeds.where((f) {
                        final t = f.title?.toLowerCase() ?? '';
                        return t.contains(_searchText) ||
                            f.url.toLowerCase().contains(_searchText);
                      }).toList();

                return categoriesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(l10n.errorMessage(e.toString())),
                  data: (cats) {
                    final byCat = <int?, List<Feed>>{};
                    for (final f in filteredFeeds) {
                      byCat.putIfAbsent(f.categoryId, () => <Feed>[]).add(f);
                    }

                    final tiles = <Widget>[];
                    for (final c in cats) {
                      final catFeeds = byCat[c.id] ?? const <Feed>[];
                      if (_searchText.isNotEmpty && catFeeds.isEmpty) continue;
                      tiles.add(
                        _CategorySection(
                          categoryName: c.name,
                          onDelete: () => _deleteCategory(context, c.id),
                          children: (catFeeds)
                              .map((f) {
                                return _FeedTile(
                                  title: (f.title?.trim().isNotEmpty == true)
                                      ? f.title!
                                      : f.url,
                                  url: f.url,
                                  lastSyncedAt: f.lastSyncedAt,
                                  onRefresh: () => _refreshFeed(context, f.id),
                                  onMove: () =>
                                      _moveFeedToCategory(context, f.id),
                                  onDelete: () => _deleteFeed(context, f.id),
                                );
                              })
                              .toList(growable: false),
                        ),
                      );
                    }

                    final uncategorized = byCat[null] ?? const <Feed>[];
                    if (_searchText.isEmpty || uncategorized.isNotEmpty) {
                      tiles.add(
                        _CategorySection(
                          categoryName: l10n.uncategorized,
                          onDelete: null,
                          children: uncategorized
                              .map((f) {
                                return _FeedTile(
                                  title: (f.title?.trim().isNotEmpty == true)
                                      ? f.title!
                                      : f.url,
                                  url: f.url,
                                  lastSyncedAt: f.lastSyncedAt,
                                  onRefresh: () => _refreshFeed(context, f.id),
                                  onMove: () =>
                                      _moveFeedToCategory(context, f.id),
                                  onDelete: () => _deleteFeed(context, f.id),
                                );
                              })
                              .toList(growable: false),
                        ),
                      );
                    }

                    if (tiles.isEmpty) {
                      return Text(l10n.notFound);
                    }

                    return Column(children: tiles);
                  },
                );
              },
            ),
          ],
        ),
      ),
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
    final batch = await ref
        .read(syncServiceProvider)
        .refreshFeedsSafe(feeds.map((f) => f.id));
    if (!context.mounted) return;
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
    final entries = ref.read(opmlServiceProvider).parseEntries(xml);
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
      final batch = await ref
          .read(syncServiceProvider)
          .refreshFeedsSafe(feeds.map((f) => f.id));
      if (!context.mounted) return;
      final err = batch.firstError?.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err == null ? l10n.refreshedAll : l10n.errorMessage(err.toString()),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(24),
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
                  Text(l10n.autoRefresh),
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
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(24),
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
                    future: getApplicationDocumentsDirectory(),
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
                                          SnackBar(content: Text(l10n.done)),
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
                                          mode: LaunchMode.externalApplication,
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
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.categoryName,
    required this.children,
    required this.onDelete,
  });

  final String categoryName;
  final List<Widget> children;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    categoryName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: AppLocalizations.of(context)!.deleteCategory,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                AppLocalizations.of(context)!.notFound,
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({
    required this.title,
    required this.url,
    required this.lastSyncedAt,
    required this.onRefresh,
    required this.onMove,
    required this.onDelete,
  });

  final String title;
  final String url;
  final DateTime? lastSyncedAt;
  final VoidCallback onRefresh;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final synced = lastSyncedAt == null
        ? null
        : DateFormat('yyyy/MM/dd HH:mm').format(lastSyncedAt!.toLocal());
    return ListTile(
      leading: const Icon(Icons.rss_feed),
      title: Text(title),
      subtitle: Text(
        synced == null ? url : '$url\n$synced',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: synced != null,
      trailing: PopupMenuButton<_FeedMenuAction>(
        onSelected: (v) {
          switch (v) {
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

enum _FeedMenuAction { refresh, move, delete }

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
