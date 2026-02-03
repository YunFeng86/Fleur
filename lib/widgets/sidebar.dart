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
import '../utils/platform.dart';
import '../utils/tag_colors.dart';
import '../services/opml/opml_service.dart';

class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({super.key, required this.onSelectFeed, this.router});

  final void Function(int? feedId) onSelectFeed;
  final GoRouter? router;

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  int? _expandedCategoryId;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchText = '';

  void _closeDrawerIfDesktopDrawer() {
    if (!isDesktop || widget.router == null) return;
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null) {
      scaffold.closeDrawer();
      return;
    }
    final router = widget.router;
    if (router != null && router.canPop()) router.pop();
  }

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
    _scrollController.dispose();
    super.dispose();
  }

  NavigatorState get _navigator {
    if (widget.router != null) {
      final key = widget.router!.routerDelegate.navigatorKey;
      if (key.currentState != null) {
        return key.currentState!;
      }
    }
    return Navigator.of(context);
  }

  Future<T?> _showDialog<T>({required WidgetBuilder builder}) {
    // Manually push a DialogRoute on the correct navigator.
    // We pass `context` (Sidebar's context) to DialogRoute so it inherits correct
    // Theme and Localizations, but we push it to `_navigator` (which might be
    // the root navigator from GoRouter) to ensure it has an Overlay.
    return _navigator.push<T>(
      DialogRoute<T>(
        context: context,
        builder: builder,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        useSafeArea: true,
      ),
    );
  }

  Future<T?> _showModalBottomSheet<T>({required WidgetBuilder builder}) {
    return _navigator.push<T>(
      ModalBottomSheetRoute<T>(
        builder: builder,
        isScrollControlled: false,
        useSafeArea: true,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // On desktop we sometimes show the sidebar inside a Scaffold drawer that is
    // *outside* the app's Navigator (see `App` overlay). In that case, using
    // `Navigator.of(context)` will throw. We only show a close button when the
    // caller provided a router to pop with.
    final showDrawerClose = isDesktop && widget.router != null;
    final feeds = ref.watch(feedsProvider);
    final categories = ref.watch(categoriesProvider);
    final selectedFeedId = ref.watch(selectedFeedIdProvider);
    final selectedCategoryId = ref.watch(selectedCategoryIdProvider);
    final selectedTagId = ref.watch(selectedTagIdProvider);
    final tags = ref.watch(tagsProvider);

    final starredOnly = ref.watch(starredOnlyProvider);
    final readLaterOnly = ref.watch(readLaterOnlyProvider);
    final allUnreadCounts = ref.watch(allUnreadCountsProvider);

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (showDrawerClose) ...[
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: () {
                      _closeDrawerIfDesktopDrawer();
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
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
              ],
            ),
          ),
          Expanded(
            child: feeds.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text(l10n.errorMessage(e.toString()))),
              data: (feedItems) {
                // Filter feeds by search text
                final filteredFeeds = _searchText.isEmpty
                    ? feedItems
                    : feedItems.where((f) {
                        final title = (f.userTitle ?? f.title ?? '')
                            .toLowerCase();
                        final url = f.url.toLowerCase();
                        return title.contains(_searchText) ||
                            url.contains(_searchText);
                      }).toList();

                return categories.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text(l10n.errorMessage(e.toString()))),
                  data: (cats) {
                    final byCat = <int?, List<Feed>>{};
                    for (final f in filteredFeeds) {
                      byCat.putIfAbsent(f.categoryId, () => []).add(f);
                    }

                    final children = <Widget>[];

                    // All Articles Tile
                    Widget allTile = allUnreadCounts.when(
                      loading: () => _SidebarItem(
                        selected:
                            !starredOnly &&
                            !readLaterOnly &&
                            selectedFeedId == null &&
                            selectedCategoryId == null &&
                            selectedTagId == null,
                        icon: Icons.all_inbox,
                        title: l10n.all,
                        onTap: () => _selectAll(ref),
                      ),
                      error: (e, _) => _SidebarItem(
                        key: const ValueKey('all_inbox'),
                        selected:
                            !starredOnly &&
                            !readLaterOnly &&
                            selectedFeedId == null &&
                            selectedCategoryId == null &&
                            selectedTagId == null,
                        icon: Icons.all_inbox,
                        title: l10n.all,
                        onTap: () => _selectAll(ref),
                      ),
                      data: (counts) => _SidebarItem(
                        selected:
                            !starredOnly &&
                            !readLaterOnly &&
                            selectedFeedId == null &&
                            selectedCategoryId == null &&
                            selectedTagId == null,
                        icon: Icons.all_inbox,
                        title: l10n.all,
                        count: counts[null] ?? 0,
                        onTap: () => _selectAll(ref),
                      ),
                    );
                    children.add(allTile);
                    // Tags
                    children.add(
                      tags.when(
                        data: (tagList) {
                          if (tagList.isEmpty) return const SizedBox.shrink();
                          return ExpansionTile(
                            leading: const Icon(Icons.label_outline),
                            title: Text(l10n.tags),
                            initiallyExpanded: selectedTagId != null,
                            children: tagList.map((tag) {
                              return _SidebarItem(
                                selected: selectedTagId == tag.id,
                                icon: Icons.label,
                                title: tag.name,
                                iconColor: resolveTagColor(tag.name, tag.color),
                                onTap: () => _selectTag(ref, tag.id),
                                indent: 16,
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    );

                    // Subscriptions Header with Actions
                    children.add(
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.subscriptions,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
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
                              onPressed: () =>
                                  _showAddCategoryDialog(context, ref),
                              icon: const Icon(
                                Icons.create_new_folder_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    for (final c in cats) {
                      // Only show category if it has feeds matching search (or if no search)
                      final catFeeds = byCat[c.id] ?? const <Feed>[];
                      if (_searchText.isNotEmpty && catFeeds.isEmpty) continue;

                      children.add(
                        _categoryTile(
                          context: context,
                          ref: ref,
                          category: c,
                          feeds: catFeeds,
                          selectedFeedId: selectedFeedId,
                          selectedCategoryId: selectedCategoryId,
                          unreadCounts: allUnreadCounts.value,
                        ),
                      );
                    }

                    // Uncategorized group.
                    final uncategorizedFeeds = byCat[null] ?? const <Feed>[];
                    if (_searchText.isEmpty || uncategorizedFeeds.isNotEmpty) {
                      final counts = allUnreadCounts.value;
                      for (final f in uncategorizedFeeds) {
                        children.add(
                          _feedTile(
                            context,
                            ref,
                            f,
                            selectedFeedId,
                            counts?[f.id],
                          ),
                        );
                      }
                    }

                    return Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: isDesktop,
                      interactive: true,
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: children,
                      ),
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
    Map<int?, int>? unreadCounts,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final unread = ref.watch(unreadCountByCategoryProvider(category.id));
    final starredOnly = ref.watch(starredOnlyProvider);
    final selected =
        !starredOnly &&
        selectedFeedId == null &&
        selectedCategoryId == category.id;
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
            return _feedTile(
              context,
              ref,
              f,
              selectedFeedId,
              unreadCounts?[f.id],
              indent: 16,
              key: ValueKey('feed_${f.id}'),
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
    int? unreadCount, {
    double indent = 0,
    Key? key,
  }) {
    final displayTitle = f.userTitle?.trim().isNotEmpty == true
        ? f.userTitle!
        : (f.title?.trim().isNotEmpty == true ? f.title! : f.url);
    return ListTile(
      key: key,
      selected: selectedFeedId == f.id,
      contentPadding: EdgeInsets.only(left: 16 + indent, right: 8),
      leading: const Icon(Icons.rss_feed),
      title: Text(displayTitle),
      subtitle:
          (f.userTitle?.trim().isNotEmpty == true ||
              f.title?.trim().isNotEmpty == true)
          ? Text(f.url, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: unreadCount == null ? null : _UnreadBadge(unreadCount),
      onTap: () => _select(ref, f.id),
      onLongPress: () => _showFeedMenu(context, ref, f),
    );
  }

  void _select(WidgetRef ref, int? id) {
    if (ref.read(selectedFeedIdProvider) == id) {
      _selectAll(ref);
      return;
    }
    ref.read(starredOnlyProvider.notifier).state = false;
    ref.read(readLaterOnlyProvider.notifier).state = false;
    ref.read(selectedFeedIdProvider.notifier).state = id;
    ref.read(selectedCategoryIdProvider.notifier).state = null;
    ref.read(selectedTagIdProvider.notifier).state = null;
    ref.read(articleSearchQueryProvider.notifier).state = '';
    widget.onSelectFeed(id);
    _closeDrawerIfDesktopDrawer();
  }

  void _selectAll(WidgetRef ref) {
    ref.read(starredOnlyProvider.notifier).state = false;
    ref.read(readLaterOnlyProvider.notifier).state = false;
    ref.read(selectedFeedIdProvider.notifier).state = null;
    ref.read(selectedCategoryIdProvider.notifier).state = null;
    ref.read(selectedTagIdProvider.notifier).state = null;
    ref.read(articleSearchQueryProvider.notifier).state = '';
    widget.onSelectFeed(null);
    _closeDrawerIfDesktopDrawer();
  }

  void _selectCategory(WidgetRef ref, int categoryId) {
    if (ref.read(selectedCategoryIdProvider) == categoryId) {
      _selectAll(ref);
      return;
    }
    ref.read(starredOnlyProvider.notifier).state = false;
    ref.read(readLaterOnlyProvider.notifier).state = false;
    ref.read(selectedFeedIdProvider.notifier).state = null;
    ref.read(selectedCategoryIdProvider.notifier).state = categoryId;
    ref.read(selectedTagIdProvider.notifier).state = null;
    ref.read(articleSearchQueryProvider.notifier).state = '';
    widget.onSelectFeed(null);
    _closeDrawerIfDesktopDrawer();
  }

  void _selectTag(WidgetRef ref, int tagId) {
    if (ref.read(selectedTagIdProvider) == tagId) {
      _selectAll(ref);
      return;
    }
    ref.read(starredOnlyProvider.notifier).state = false;
    ref.read(readLaterOnlyProvider.notifier).state = false;
    ref.read(selectedFeedIdProvider.notifier).state = null;
    ref.read(selectedCategoryIdProvider.notifier).state = null;
    ref.read(selectedTagIdProvider.notifier).state = tagId;
    ref.read(articleSearchQueryProvider.notifier).state = '';
    widget.onSelectFeed(null);
    _closeDrawerIfDesktopDrawer();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int feedId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _showDialog<bool>(
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
    if (ref.read(selectedFeedIdProvider) == feedId) {
      _selectAll(ref);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.deleted)));
  }

  Future<void> _confirmDeleteCategory(
    BuildContext context,
    WidgetRef ref,
    int categoryId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _showDialog<bool>(
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteCategoryConfirmTitle),
          content: Text(l10n.deleteCategoryConfirmContent),
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
    await ref.read(categoryRepositoryProvider).delete(categoryId);
    if (!context.mounted) return;
    if (ref.read(selectedCategoryIdProvider) == categoryId) {
      _selectAll(ref);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.categoryDeleted)));
  }

  Future<void> _showAddFeedDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final url = await _showDialog<String>(
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
    ref.read(selectedFeedIdProvider.notifier).state = id;
    ref.read(selectedCategoryIdProvider.notifier).state = null;
    ref.read(selectedTagIdProvider.notifier).state = null;
    widget.onSelectFeed(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.ok ? l10n.addedAndSynced : l10n.errorMessage(r.error.toString()),
        ),
      ),
    );
  }

  Future<void> _showAddCategoryDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await _showDialog<String>(
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

  Future<void> _showCategoryMenu(
    BuildContext context,
    WidgetRef ref,
    Category c,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final v = await _showModalBottomSheet<_CategoryAction>(
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.rename),
                onTap: () => Navigator.of(context).pop(_CategoryAction.rename),
              ),
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
    if (!context.mounted) return;
    switch (v) {
      case _CategoryAction.rename:
        await _renameCategory(context, ref, c);
        return;
      case _CategoryAction.delete:
        await _confirmDeleteCategory(context, ref, c.id);
        return;
      case null:
        return;
    }
  }

  Future<void> _showFeedMenu(
    BuildContext context,
    WidgetRef ref,
    Feed f,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await _showModalBottomSheet<_FeedAction>(
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.edit),
                onTap: () => Navigator.of(context).pop(_FeedAction.edit),
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(l10n.refresh),
                onTap: () => Navigator.of(context).pop(_FeedAction.refresh),
              ),
              ListTile(
                leading: const Icon(Icons.download_for_offline_outlined),
                title: Text(l10n.makeAvailableOffline),
                onTap: () =>
                    Navigator.of(context).pop(_FeedAction.offlineCache),
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
      case _FeedAction.edit:
        await _editFeedTitle(context, ref, f);
        return;
      case _FeedAction.refresh:
        final r = await ref.read(syncServiceProvider).refreshFeedSafe(f.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              r.ok ? l10n.refreshed : l10n.errorMessage(r.error.toString()),
            ),
          ),
        );
        return;
      case _FeedAction.offlineCache:
        final count = await ref
            .read(syncServiceProvider)
            .offlineCacheFeed(f.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.cachingArticles(count))));
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

  Future<void> _renameCategory(
    BuildContext context,
    WidgetRef ref,
    Category c,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: c.name);
    final next = await _showDialog<String?>(
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
      await ref.read(categoryRepositoryProvider).rename(c.id, next);
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
    BuildContext context,
    WidgetRef ref,
    Feed f,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: f.userTitle ?? '');
    final next = await _showDialog<String?>(
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
        .setUserTitle(feedId: f.id, userTitle: next);
  }

  Future<void> _moveFeedToCategory(
    BuildContext context,
    WidgetRef ref,
    Feed f,
  ) async {
    final cats = await ref.read(categoryRepositoryProvider).getAll();
    if (!context.mounted) return;
    final selected = await _showDialog<int?>(
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
    await ref
        .read(feedRepositoryProvider)
        .setCategory(feedId: f.id, categoryId: selected);
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    _SidebarMenu v,
  ) async {
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
        final batch = await ref
            .read(syncServiceProvider)
            .refreshFeedsSafe(feeds.map((f) => f.id));
        if (!context.mounted) return;
        final err = batch.firstError?.error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              err == null
                  ? l10n.refreshedAll
                  : l10n.errorMessage(err.toString()),
            ),
          ),
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
    List<OpmlEntry> entries;
    try {
      entries = ref.read(opmlServiceProvider).parseEntries(xml);
    } catch (_) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorMessage(l10n.opmlParseFailed))),
      );
      return;
    }
    if (entries.isEmpty) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
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
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.importedFeeds(added))));
  }

  Future<void> _exportOpml(BuildContext context, WidgetRef ref) async {
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
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.exportedOpml)));
  }
}

enum _SidebarMenu { settings, refreshAll, importOpml, exportOpml }

enum _FeedAction { edit, refresh, offlineCache, move, delete }

enum _CategoryAction { rename, delete }

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
    super.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
    this.count,
    this.iconColor,
    this.indent = 0,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int? count;
  final Color? iconColor;
  final double indent;

  @override
  Widget build(BuildContext context) {
    // Mimic the dense, rounded style from the reference
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        selected: selected,
        leading: Icon(icon, size: 20, color: iconColor),
        title: Text(title),
        trailing: count != null && count! > 0 ? _UnreadBadge(count!) : null,
        onTap: onTap,
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        // Visual adjustments to match "denser" look
        visualDensity: VisualDensity.compact,
        contentPadding: EdgeInsets.only(left: 12 + indent, right: 12),
      ),
    );
  }
}
