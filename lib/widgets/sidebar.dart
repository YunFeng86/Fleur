import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';

import '../models/category.dart';
import '../models/feed.dart';
import '../providers/query_providers.dart';
import '../providers/opml_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/service_providers.dart';
import '../providers/unread_providers.dart';

class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({
    super.key,
    required this.onSelectFeed,
    this.router,
  });

  final void Function(int? feedId) onSelectFeed;
  final GoRouter? router;

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  int? _expandedCategoryId;
  bool _expandedUncategorized = false;
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
    final feeds = ref.watch(feedsProvider);
    final categories = ref.watch(categoriesProvider);
    final selectedFeedId = ref.watch(selectedFeedIdProvider);
    final selectedCategoryId = ref.watch(selectedCategoryIdProvider);
    final allUnread = ref.watch(unreadCountProvider(null));

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                isDense: true,
                border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: feeds.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(l10n.errorMessage(e.toString()))),
              data: (feedItems) {
                // Filter feeds by search text
                final filteredFeeds = _searchText.isEmpty
                    ? feedItems
                    : feedItems.where((f) {
                        final title = f.title?.toLowerCase() ?? '';
                        final url = f.url.toLowerCase();
                        return title.contains(_searchText) || url.contains(_searchText);
                      }).toList();

                return categories.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text(l10n.errorMessage(e.toString()))),
                  data: (cats) {
                    final byCat = <int?, List<Feed>>{};
                    for (final f in filteredFeeds) {
                      byCat.putIfAbsent(f.categoryId, () => []).add(f);
                    }

                    final children = <Widget>[];

                    // All Articles Tile
                    Widget allTile = allUnread.when(
                      loading: () => _SidebarItem(
                        selected: selectedFeedId == null && selectedCategoryId == null,
                        icon: Icons.all_inbox,
                        title: l10n.all,
                        onTap: () => _selectAll(ref),
                      ),
                      error: (e, _) => _SidebarItem(
                        selected: selectedFeedId == null && selectedCategoryId == null,
                        icon: Icons.all_inbox,
                        title: l10n.all,
                        onTap: () => _selectAll(ref),
                      ),
                      data: (count) => _SidebarItem(
                        selected: selectedFeedId == null && selectedCategoryId == null,
                        icon: Icons.all_inbox,
                        title: l10n.all,
                        count: count,
                        onTap: () => _selectAll(ref),
                      ),
                    );
                    children.add(allTile);

                    // Subscriptions Header with Actions
                    children.add(
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.subscriptions,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                             PopupMenuButton<_SidebarMenu>(
                              icon: const Icon(Icons.more_horiz, size: 20),
                              tooltip: l10n.more,
                              padding: EdgeInsets.zero,
                              onSelected: (v) => _onMenu(context, ref, v),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: _SidebarMenu.settings,
                                  child: Text(l10n.settings),
                                ),
                                const PopupMenuDivider(),
                                PopupMenuItem(
                                  value: _SidebarMenu.refreshAll,
                                  child: Text(l10n.refreshAll),
                                ),
                                const PopupMenuDivider(),
                                PopupMenuItem(
                                  value: _SidebarMenu.importOpml,
                                  child: Text(l10n.importOpml),
                                ),
                                PopupMenuItem(
                                  value: _SidebarMenu.exportOpml,
                                  child: Text(l10n.exportOpml),
                                ),
                              ],
                            ),
                            IconButton(
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: l10n.addSubscription,
                              onPressed: () => _showAddFeedDialog(context, ref),
                              icon: const Icon(Icons.add),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: l10n.newCategory,
                              onPressed: () => _showAddCategoryDialog(context, ref),
                              icon: const Icon(Icons.create_new_folder_outlined),
                            ),
                          ],
                        ),
                      ),
                    );

                    for (final c in cats) {
                      // Only show category if it has feeds matching search (or if no search)
                      final catFeeds = byCat[c.id] ?? const <Feed>[];
                      if (_searchText.isNotEmpty && catFeeds.isEmpty) continue;

                      children.add(_categoryTile(
                        context: context,
                        ref: ref,
                        category: c,
                        feeds: catFeeds,
                        selectedFeedId: selectedFeedId,
                        selectedCategoryId: selectedCategoryId,
                      ));
                    }

                    // Uncategorized group.
                    final uncategorizedFeeds = byCat[null] ?? const <Feed>[];
                    if (_searchText.isEmpty || uncategorizedFeeds.isNotEmpty) {
                       children.add(_uncategorizedTile(
                        context: context,
                        ref: ref,
                        feeds: uncategorizedFeeds,
                        selectedFeedId: selectedFeedId,
                        selectedCategoryId: selectedCategoryId,
                      ));
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: children
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryTile({
    required BuildContext context,
    required WidgetRef ref,
    required Category category,
    required List<Feed> feeds,
    required int? selectedFeedId,
    required int? selectedCategoryId,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final unread = ref.watch(unreadCountByCategoryProvider(category.id));
    final selected = selectedFeedId == null && selectedCategoryId == category.id;
    final expanded = _expandedCategoryId == category.id;

    return Column(
      children: [
        ListTile(
          selected: selected,
          leading: const Icon(Icons.folder_outlined),
          title: Text(category.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              unread.when(
                data: (c) => _UnreadBadge(c),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              IconButton(
                tooltip: expanded ? l10n.collapse : l10n.expand,
                onPressed: () {
                  setState(() {
                    _expandedCategoryId = expanded ? null : category.id;
                  });
                },
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ),
            ],
          ),
          onTap: () => _selectCategory(ref, category.id),
          onLongPress: () => _showCategoryMenu(context, ref, category),
        ),
        if (expanded)
          ...feeds.map((f) {
            final unread = ref.watch(unreadCountProvider(f.id));
            return unread.when(
              data: (count) => _feedTile(
                context,
                ref,
                f,
                selectedFeedId,
                count,
                indent: 16,
              ),
              loading: () => _feedTile(
                context,
                ref,
                f,
                selectedFeedId,
                null,
                indent: 16,
              ),
              error: (_, _) => _feedTile(
                context,
                ref,
                f,
                selectedFeedId,
                null,
                indent: 16,
              ),
            );
          }),
      ],
    );
  }

  Widget _uncategorizedTile({
    required BuildContext context,
    required WidgetRef ref,
    required List<Feed> feeds,
    required int? selectedFeedId,
    required int? selectedCategoryId,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final expanded = _expandedUncategorized;
    final selected = selectedFeedId == null && selectedCategoryId == -1;
    final unread = ref.watch(unreadCountUncategorizedProvider);
    return Column(
      children: [
        ListTile(
          selected: selected,
          leading: const Icon(Icons.folder_open_outlined),
          title: Text(l10n.uncategorized),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              unread.when(
                data: (c) => _UnreadBadge(c),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              IconButton(
                tooltip: expanded ? l10n.collapse : l10n.expand,
                onPressed: () => setState(() => _expandedUncategorized = !expanded),
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ),
            ],
          ),
          onTap: () => _selectUncategorized(ref),
        ),
        if (expanded)
          ...feeds.map((f) {
            final unread = ref.watch(unreadCountProvider(f.id));
            return unread.when(
              data: (count) => _feedTile(
                context,
                ref,
                f,
                selectedFeedId,
                count,
                indent: 16,
              ),
              loading: () => _feedTile(
                context,
                ref,
                f,
                selectedFeedId,
                null,
                indent: 16,
              ),
              error: (_, _) => _feedTile(
                context,
                ref,
                f,
                selectedFeedId,
                null,
                indent: 16,
              ),
            );
          }),
      ],
    );
  }

  Widget _feedTile(
    BuildContext context,
    WidgetRef ref,
    Feed f,
    int? selectedFeedId,
    int? unreadCount,
    {double indent = 0}
  ) {
    final title = f.title?.trim().isNotEmpty == true ? f.title! : f.url;
    return ListTile(
      selected: selectedFeedId == f.id,
      contentPadding: EdgeInsets.only(left: 16 + indent, right: 8),
      leading: const Icon(Icons.rss_feed),
      title: Text(title),
      subtitle: f.title?.trim().isNotEmpty == true
          ? Text(f.url, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: unreadCount == null ? null : _UnreadBadge(unreadCount),
      onTap: () => _select(ref, f.id),
      onLongPress: () => _showFeedMenu(context, ref, f),
    );
  }

  void _select(WidgetRef ref, int? id) {
    ref.read(selectedFeedIdProvider.notifier).state = id;
    ref.read(selectedCategoryIdProvider.notifier).state = null;
    widget.onSelectFeed(id);
  }

  void _selectAll(WidgetRef ref) {
    ref.read(selectedFeedIdProvider.notifier).state = null;
    ref.read(selectedCategoryIdProvider.notifier).state = null;
    widget.onSelectFeed(null);
  }

  void _selectCategory(WidgetRef ref, int categoryId) {
    ref.read(selectedFeedIdProvider.notifier).state = null;
    ref.read(selectedCategoryIdProvider.notifier).state = categoryId;
    widget.onSelectFeed(null);
  }

  void _selectUncategorized(WidgetRef ref) {
    // We use -1 sentinel in UI; the Article list filters by `categoryId == null`
    // by selecting no category and no feed. This keeps MVP simple.
    ref.read(selectedFeedIdProvider.notifier).state = null;
    ref.read(selectedCategoryIdProvider.notifier).state = -1;
    widget.onSelectFeed(null);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, int feedId) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
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
    if (ok != true) return;
    await ref.read(feedRepositoryProvider).delete(feedId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.deleted)),
    );
  }

  Future<void> _showAddFeedDialog(BuildContext context, WidgetRef ref) async {
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
    await ref.read(syncServiceProvider).refreshFeed(id);
    ref.read(selectedFeedIdProvider.notifier).state = id;
    ref.read(selectedCategoryIdProvider.notifier).state = null;
    widget.onSelectFeed(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.addedAndSynced)),
    );
  }

  Future<void> _showAddCategoryDialog(BuildContext context, WidgetRef ref) async {
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
    final id = await ref.read(categoryRepositoryProvider).upsertByName(name);
    setState(() => _expandedCategoryId = id);
  }

  Future<void> _showCategoryMenu(BuildContext context, WidgetRef ref, Category c) async {
    final l10n = AppLocalizations.of(context)!;
    final v = await showModalBottomSheet<_CategoryAction>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.deleteCategory),
                onTap: () => Navigator.of(context).pop(_CategoryAction.delete),
              ),
            ],
          ),
        );
      },
    );
    if (v != _CategoryAction.delete) return;
    await ref.read(categoryRepositoryProvider).delete(c.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.categoryDeleted)),
    );
  }

  Future<void> _showFeedMenu(BuildContext context, WidgetRef ref, Feed f) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showModalBottomSheet<_FeedAction>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(l10n.refresh),
                onTap: () => Navigator.of(context).pop(_FeedAction.refresh),
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: Text(l10n.moveToCategory),
                onTap: () => Navigator.of(context).pop(_FeedAction.move),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.deleteSubscription),
                onTap: () => Navigator.of(context).pop(_FeedAction.delete),
              ),
            ],
          ),
        );
      },
    );
    if (!context.mounted) return;

    switch (action) {
      case _FeedAction.refresh:
        await ref.read(syncServiceProvider).refreshFeed(f.id);
        return;
      case _FeedAction.move:
        await _moveFeedToCategory(context, ref, f);
        return;
      case _FeedAction.delete:
        await _confirmDelete(context, ref, f.id);
        return;
      case null:
        return;
    }
  }

  Future<void> _moveFeedToCategory(BuildContext context, WidgetRef ref, Feed f) async {
    final cats = await ref.read(categoryRepositoryProvider).getAll();
    if (!context.mounted) return;
    final selected = await showDialog<int?>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final picked = f.categoryId;
        return SimpleDialog(
          title: Text(l10n.moveToCategory),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(null),
              child: Row(
                children: [
                  Icon(picked == null ? Icons.check : Icons.clear),
                  const SizedBox(width: 8),
                  Text(l10n.uncategorized),
                ],
              ),
            ),
            for (final c in cats)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(c.id),
                child: Row(
                  children: [
                    Icon(picked == c.id ? Icons.check : Icons.clear),
                    const SizedBox(width: 8),
                    Text(c.name),
                  ],
                ),
              ),
          ],
        );
      },
    );
    if (selected == f.categoryId) return;
    await ref.read(feedRepositoryProvider).setCategory(feedId: f.id, categoryId: selected);
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, _SidebarMenu v) async {
    switch (v) {
      case _SidebarMenu.settings:
        final router = widget.router ?? GoRouter.maybeOf(context);
        if (router != null) {
          await router.push('/settings');
        }
        return;
      case _SidebarMenu.refreshAll:
        final l10n = AppLocalizations.of(context)!;
        final feeds = await ref.read(feedRepositoryProvider).getAll();
        for (final f in feeds) {
          await ref.read(syncServiceProvider).refreshFeed(f.id);
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.refreshedAll)),
        );
        return;
      case _SidebarMenu.importOpml:
        await _importOpml(context, ref);
        return;
      case _SidebarMenu.exportOpml:
        await _exportOpml(context, ref);
        return;
    }
  }

  Future<void> _importOpml(BuildContext context, WidgetRef ref) async {
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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noFeedsFoundInOpml)),
      );
      return;
    }

    var added = 0;
    for (final e in entries) {
      final feedId = await ref.read(feedRepositoryProvider).upsertUrl(e.url);
      if (e.category != null && e.category!.trim().isNotEmpty) {
        final catId = await ref.read(categoryRepositoryProvider).upsertByName(e.category!);
        await ref.read(feedRepositoryProvider).setCategory(feedId: feedId, categoryId: catId);
      }
      added += 1;
    }
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.importedFeeds(added))),
    );
  }

  Future<void> _exportOpml(BuildContext context, WidgetRef ref) async {
    final loc = await getSaveLocation(suggestedName: 'subscriptions.opml');
    if (loc == null) return;
    final feeds = await ref.read(feedRepositoryProvider).getAll();
    final cats = await ref.read(categoryRepositoryProvider).getAll();
    final names = {for (final c in cats) c.id: c.name};
    final xml = ref.read(opmlServiceProvider).buildOpml(feeds: feeds, categoryNames: names);
    final xfile = XFile.fromData(
      Uint8List.fromList(utf8.encode(xml)),
      mimeType: 'text/xml',
      name: 'subscriptions.opml',
    );
    await xfile.saveTo(loc.path);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.exportedOpml)),
    );
  }
}

enum _SidebarMenu { settings, refreshAll, importOpml, exportOpml }
enum _FeedAction { refresh, move, delete }
enum _CategoryAction { delete }

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Badge(
      label: Text('$count'),
      backgroundColor: Theme.of(context).colorScheme.primary,
      textColor: Theme.of(context).colorScheme.onPrimary,
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
    this.count,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    // Mimic the dense, rounded style from the reference
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        selected: selected,
        leading: Icon(icon, size: 20),
        title: Text(title),
        trailing: count != null && count! > 0
            ? _UnreadBadge(count!)
            : null,
        onTap: onTap,
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        // Visual adjustments to match "denser" look
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}
