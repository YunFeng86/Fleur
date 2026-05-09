import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fleur/l10n/app_localizations.dart';

import '../providers/article_list_controller.dart';
import '../providers/app_settings_providers.dart';
import '../providers/query_providers.dart';
import '../providers/service_providers.dart';
import '../providers/unread_providers.dart';
import '../services/settings/app_settings.dart';
import '../theme/fleur_theme_extensions.dart';
import '../ui/layout.dart';
import '../ui/layout_spec.dart';
import '../ui/motion.dart';
import '../utils/platform.dart';
import '../models/article.dart';
import 'app_scrollbar.dart';
import 'appear.dart';
import 'article_list_item.dart';

class ArticleList extends ConsumerStatefulWidget {
  const ArticleList({
    super.key,
    required this.selectedArticleId,
    this.baseLocation = '/',
    this.articleRoutePrefix = '',
    this.emptyBuilder,
  });

  final int? selectedArticleId;
  final String baseLocation;
  final String articleRoutePrefix;
  final Widget Function(BuildContext context, ArticleListEmptyState state)?
  emptyBuilder;

  @override
  ConsumerState<ArticleList> createState() => _ArticleListState();
}

class _ArticleListState extends ConsumerState<ArticleList> {
  late final ScrollController _controller;
  bool _loadMoreScheduled = false;

  int? _lastContextKey;
  Set<int> _seenArticleIds = <int>{};
  Set<String> _seenHeaderTitles = <String>{};

  // Cache to avoid recalculating entries on every build
  List<Article> _cachedItems = [];
  ArticleGroupMode _cachedGroupMode = ArticleGroupMode.none;
  List<_ArticleListEntry> _cachedEntries = [];

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()
      ..addListener(() {
        final pos = _controller.position;
        if (pos.maxScrollExtent <= 0) return;
        if (pos.pixels >= pos.maxScrollExtent - 600) {
          _scheduleLoadMore();
        }
      });
  }

  void _scheduleLoadMore() {
    if (_loadMoreScheduled) return;
    _loadMoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreScheduled = false;
      if (!mounted) return;
      unawaited(ref.read(articleListControllerProvider.notifier).loadMore());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_ArticleListEntry> _getEntries(
    List<Article> items,
    ArticleGroupMode groupMode,
  ) {
    // Only recalculate if items or groupMode changed
    if (items != _cachedItems || groupMode != _cachedGroupMode) {
      _cachedItems = items;
      _cachedGroupMode = groupMode;
      _cachedEntries = groupMode == ArticleGroupMode.day
          ? _buildDayGroupedEntries(items)
          : items.map<_ArticleListEntry>((a) => _ArticleEntry(a)).toList();
    }
    return _cachedEntries;
  }

  Future<void> _openArticle(
    BuildContext context,
    Article article,
    LayoutSpec spec, {
    required bool closeIfSelected,
  }) async {
    if (article.id == widget.selectedArticleId) {
      if (closeIfSelected) context.go(widget.baseLocation);
      return;
    }

    final openAsSecondaryPage = isDesktop
        ? !spec.desktopEmbedsReader
        : !spec.canEmbedReader(
            listWidth: widget.baseLocation == '/'
                ? kHomeListWidth
                : kDesktopListWidth,
          );

    final loc = widget.articleRoutePrefix.isEmpty
        ? '/article/${article.id}'
        : '${widget.articleRoutePrefix}/article/${article.id}';

    if (openAsSecondaryPage) {
      await context.push(loc);
    } else {
      context.go(loc);
    }
  }

  Future<void> _showArticleContextMenu(
    BuildContext context,
    WidgetRef ref,
    Article article,
    Offset position,
    LayoutSpec spec,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showMenu<_ArticleContextAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: _ArticleContextAction.open,
          child: ListTile(
            leading: const Icon(Icons.article_outlined),
            title: Text(l10n.openArticle),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _ArticleContextAction.markRead,
          child: ListTile(
            leading: Icon(
              article.isRead ? Icons.mark_email_unread : Icons.mark_email_read,
            ),
            title: Text(article.isRead ? l10n.markUnread : l10n.markRead),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _ArticleContextAction.toggleStar,
          child: ListTile(
            leading: Icon(article.isStarred ? Icons.star : Icons.star_border),
            title: Text(article.isStarred ? l10n.unstar : l10n.star),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _ArticleContextAction.toggleReadLater,
          child: ListTile(
            leading: Icon(
              article.isReadLater
                  ? Icons.watch_later
                  : Icons.watch_later_outlined,
            ),
            title: Text(
              article.isReadLater ? l10n.removeReadLater : l10n.readLater,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _ArticleContextAction.copyLink,
          child: ListTile(
            leading: const Icon(Icons.content_copy),
            title: Text(l10n.copyLink),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _ArticleContextAction.openInBrowser,
          child: ListTile(
            leading: const Icon(Icons.open_in_browser),
            title: Text(l10n.openInBrowser),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
    if (!context.mounted || action == null) return;

    final actions = ref.read(articleActionServiceProvider);
    switch (action) {
      case _ArticleContextAction.open:
        await _openArticle(context, article, spec, closeIfSelected: false);
        return;
      case _ArticleContextAction.markRead:
        await actions.markRead(article.id, !article.isRead);
        return;
      case _ArticleContextAction.toggleStar:
        await actions.toggleStar(article.id);
        return;
      case _ArticleContextAction.toggleReadLater:
        await actions.toggleReadLater(article.id);
        return;
      case _ArticleContextAction.copyLink:
        await Clipboard.setData(ClipboardData(text: article.link));
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
        return;
      case _ArticleContextAction.openInBrowser:
        final uri = Uri.tryParse(article.link);
        if (uri == null) return;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final feedId = ref.watch(selectedFeedIdProvider);
    final categoryId = ref.watch(selectedCategoryIdProvider);
    final tagId = ref.watch(selectedTagIdProvider);
    final unreadOnly = ref.watch(unreadOnlyProvider);
    final starredOnly = ref.watch(starredOnlyProvider);
    final readLaterOnly = ref.watch(readLaterOnlyProvider);
    final searchQuery = ref.watch(articleSearchQueryProvider).trim();
    final state = ref.watch(articleListControllerProvider);
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final groupMode = settings?.articleGroupMode ?? ArticleGroupMode.none;
    final sortAscending =
        (settings?.articleSortOrder ?? ArticleSortOrder.newestFirst) ==
        ArticleSortOrder.oldestFirst;
    final searchInContent = settings?.searchInContent ?? true;

    final contextKey = Object.hash(
      widget.baseLocation,
      widget.articleRoutePrefix,
      feedId,
      categoryId,
      tagId,
      unreadOnly,
      starredOnly,
      readLaterOnly,
      searchQuery,
      sortAscending,
      searchInContent,
      groupMode,
    );

    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorMessage(e.toString()))),
      data: (data) {
        final items = data.items;
        final surfaces = Theme.of(context).fleurSurface;
        if (items.isEmpty) {
          final emptyState = ArticleListEmptyState(
            searchQuery: searchQuery,
            unreadOnly: unreadOnly,
            starredOnly: starredOnly,
            readLaterOnly: readLaterOnly,
          );
          if (widget.emptyBuilder != null) {
            return widget.emptyBuilder!(context, emptyState);
          }
          Widget child;
          if (searchQuery.isNotEmpty || starredOnly) {
            child = Text(l10n.notFound);
          } else {
            child = Text(unreadOnly ? l10n.noUnreadArticles : l10n.noArticles);
          }
          return Container(
            color: surfaces.list,
            alignment: Alignment.center,
            child: child,
          );
        }

        final spec = LayoutSpec.fromContext(context);
        final isCompact = spec.isCompact;

        final entries = _getEntries(items, groupMode);

        final contextChanged = _lastContextKey != contextKey;
        final atTop = !_controller.hasClients || _controller.offset < 24;

        // When the "context" changes (feed/category/tag/unread/search...), treat
        // this as a new list rather than an incremental update. We'll still do a
        // subtle list fade-in (keyed by [contextKey]), but avoid per-item
        // insertion animations that would otherwise fire for the whole list.
        final newArticleIds = <int>{};
        final newHeaderTitles = <String>{};
        if (contextChanged) {
          _lastContextKey = contextKey;
          _seenArticleIds = items.map((a) => a.id).toSet();
          _seenHeaderTitles = entries
              .whereType<_HeaderEntry>()
              .map((e) => e.title)
              .toSet();
        } else {
          for (final a in items) {
            if (_seenArticleIds.add(a.id)) {
              newArticleIds.add(a.id);
            }
          }
          for (final e in entries) {
            if (e is _HeaderEntry && _seenHeaderTitles.add(e.title)) {
              newHeaderTitles.add(e.title);
            }
          }
        }

        Widget list = Container(
          color: surfaces.list,
          child: AppScrollbar(
            controller: _controller,
            thumbVisibility: isDesktop,
            interactive: true,
            child: ListView.builder(
              controller: _controller,
              itemCount: entries.length + (data.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= entries.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: data.isLoadingMore
                          ? const CircularProgressIndicator()
                          : Text(l10n.scrollToLoadMore),
                    ),
                  );
                }

                final entry = entries[index];
                if (entry is _HeaderEntry) {
                  final animate =
                      !contextChanged &&
                      atTop &&
                      index < 12 &&
                      newHeaderTitles.contains(entry.title);
                  return KeyedSubtree(
                    key: ValueKey('h-${entry.title}'),
                    child: Appear(
                      enabled: animate,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                        child: Text(
                          entry.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ),
                  );
                }

                final seed = (entry as _ArticleEntry).article;
                return Consumer(
                  builder: (context, ref, _) {
                    final live =
                        ref.watch(articleProvider(seed.id)).valueOrNull ?? seed;
                    Widget child = ArticleListItem(
                      article: live,
                      selected: live.id == widget.selectedArticleId,
                      onTap: () => _openArticle(
                        context,
                        live,
                        spec,
                        closeIfSelected: true,
                      ),
                      onSecondaryTapDown: (details) => unawaited(
                        _showArticleContextMenu(
                          context,
                          ref,
                          live,
                          details.globalPosition,
                          spec,
                        ),
                      ),
                    );

                    if (spec.canSwipeToDelete && isCompact) {
                      child = Dismissible(
                        key: ValueKey(live.id),
                        background: Container(
                          color: Colors.green.shade700,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(
                            live.isRead
                                ? Icons.mark_email_unread
                                : Icons.mark_email_read,
                            color: Colors.white,
                          ),
                        ),
                        secondaryBackground: Container(
                          color: Colors.amber.shade800,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(
                            live.isStarred ? Icons.star_border : Icons.star,
                            color: Colors.white,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          final actions = ref.read(
                            articleActionServiceProvider,
                          );
                          if (direction == DismissDirection.startToEnd) {
                            await actions.markRead(live.id, !live.isRead);
                          } else {
                            await actions.toggleStar(live.id);
                          }
                          return false; // keep item in list
                        },
                        child: child,
                      );
                    }

                    final animate =
                        !contextChanged &&
                        atTop &&
                        index < 16 &&
                        newArticleIds.contains(seed.id);
                    return KeyedSubtree(
                      key: ValueKey('a-${seed.id}'),
                      child: Appear(enabled: animate, child: child),
                    );
                  },
                );
              },
            ),
          ),
        );

        if (AppMotion.reduceMotion(context)) return list;

        // Keyed "content switch": on context changes, fade/slide in the new list.
        // This keeps a single ScrollController attached (no AnimatedSwitcher).
        return TweenAnimationBuilder<double>(
          key: ValueKey(contextKey),
          tween: Tween<double>(begin: 0, end: 1),
          duration: AppMotion.short,
          curve: AppMotion.standardCurve,
          builder: (context, t, child) {
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 8),
                child: child,
              ),
            );
          },
          child: list,
        );
      },
    );
  }
}

sealed class _ArticleListEntry {}

enum _ArticleContextAction {
  open,
  markRead,
  toggleStar,
  toggleReadLater,
  copyLink,
  openInBrowser,
}

class _HeaderEntry extends _ArticleListEntry {
  _HeaderEntry(this.title);
  final String title;
}

class _ArticleEntry extends _ArticleListEntry {
  _ArticleEntry(this.article);
  final Article article;
}

class ArticleListEmptyState {
  const ArticleListEmptyState({
    required this.searchQuery,
    required this.unreadOnly,
    required this.starredOnly,
    required this.readLaterOnly,
  });

  final String searchQuery;
  final bool unreadOnly;
  final bool starredOnly;
  final bool readLaterOnly;

  bool get hasSearch => searchQuery.isNotEmpty;
}

List<_ArticleListEntry> _buildDayGroupedEntries(List<Article> items) {
  final out = <_ArticleListEntry>[];
  DateTime? currentDay;
  for (final a in items) {
    final t = a.publishedAt.toLocal();
    final day = DateTime(t.year, t.month, t.day);
    if (currentDay == null || day != currentDay) {
      currentDay = day;
      out.add(_HeaderEntry(DateFormat('yyyy/MM/dd').format(day)));
    }
    out.add(_ArticleEntry(a));
  }
  return out;
}
