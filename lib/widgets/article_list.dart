import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fleur/l10n/app_localizations.dart';

import '../providers/backend_capabilities_provider.dart';
import '../providers/article_list_controller.dart';
import '../providers/app_settings_providers.dart';
import '../providers/query_providers.dart';
import '../providers/service_providers.dart';
import '../providers/unread_providers.dart';
import '../services/sync/backend_capabilities.dart';
import '../services/settings/app_settings.dart';
import '../theme/fleur_icons.dart';
import '../app/article_scope_routes.dart';
import '../models/article_scope.dart';
import '../ui/app_menu.dart';
import '../ui/actions/subscription_actions.dart';
import '../theme/fleur_theme_extensions.dart';
import '../ui/layout.dart';
import '../ui/layout_spec.dart';
import '../ui/motion.dart';
import '../ui/sidebar_layout.dart';
import '../ui/workspace_layers.dart';
import '../utils/platform.dart';
import '../models/article.dart';
import 'app_scrollbar.dart';
import 'appear.dart';
import 'article_list_item.dart';
import 'fleur_empty_state.dart';

class ArticleList extends ConsumerStatefulWidget {
  const ArticleList({
    super.key,
    required this.selectedArticleId,
    this.baseLocation,
    this.articleRoutePrefix,
    this.articleLocationBuilder,
    this.readerListWidth,
    this.topBar,
    this.emptyBuilder,
  });

  final int? selectedArticleId;
  final String? baseLocation;
  final String? articleRoutePrefix;
  final String Function(Article article)? articleLocationBuilder;
  final double? readerListWidth;
  final Widget? topBar;
  final Widget Function(BuildContext context, ArticleListEmptyState state)?
  emptyBuilder;

  @override
  ConsumerState<ArticleList> createState() => _ArticleListState();
}

class _ArticleListState extends ConsumerState<ArticleList> {
  static const double _loadMoreThreshold = 600;

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
    _controller = ScrollController()..addListener(_handleScroll);
  }

  void _handleScroll() {
    final pos = _controller.position;
    final currentOffset = pos.pixels;

    if (pos.maxScrollExtent <= 0) {
      return;
    }

    if (currentOffset >= pos.maxScrollExtent - _loadMoreThreshold) {
      _scheduleLoadMore();
    }
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

  Widget _withTopBar(Widget child) {
    final topBar = widget.topBar;
    if (topBar == null) return child;

    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          height: kWorkspaceHeaderHeight,
          child: _ArticleListTopBar(child: topBar),
        ),
      ],
    );
  }

  Widget _withReadableListWidth(Widget child) {
    final leadingInset =
        ShellLayerScope.maybeOf(context)?.contentLeadingInset ?? 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;
        final readableWidth = math.min(kMaxReadingWidth, contentWidth);
        final centeredLeft = math.max(0.0, (contentWidth - readableWidth) / 2);
        final left = math.max(centeredLeft, leadingInset);
        final width = math.min(
          readableWidth,
          math.max(0.0, contentWidth - left),
        );

        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(left: left),
            child: SizedBox(width: width, child: child),
          ),
        );
      },
    );
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
    required ArticleScope scope,
  }) async {
    if (article.id == widget.selectedArticleId) {
      if (closeIfSelected) {
        context.go(widget.baseLocation ?? scopeLocation(scope));
      }
      return;
    }

    final listWidthForReader =
        widget.readerListWidth ??
        (widget.articleRoutePrefix == null
            ? kHomeListWidth
            : kDesktopListWidth);
    final openAsSecondaryPage = !shouldEmbedReaderForLayout(
      spec,
      listWidth: listWidthForReader,
    );

    final loc =
        widget.articleLocationBuilder?.call(article) ??
        (widget.articleRoutePrefix == null
            ? scopedArticleLocation(scope, article.id)
            : '${widget.articleRoutePrefix}/article/${article.id}');

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
    ArticleScope scope,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await AppMenuHost.showAt<_ArticleContextAction>(
      context,
      position: position,
      items: [
        AppMenuItem(
          value: _ArticleContextAction.open,
          icon: FleurIcons.article,
          label: l10n.openArticle,
        ),
        AppMenuItem(
          value: _ArticleContextAction.markRead,
          icon: article.isRead ? FleurIcons.markUnread : FleurIcons.markRead,
          label: article.isRead ? l10n.markUnread : l10n.markRead,
        ),
        AppMenuItem(
          value: _ArticleContextAction.toggleStar,
          icon: article.isStarred ? FleurIcons.starActive : FleurIcons.star,
          label: article.isStarred ? l10n.unstar : l10n.star,
        ),
        AppMenuItem(
          value: _ArticleContextAction.toggleReadLater,
          icon: article.isReadLater
              ? FleurIcons.readLaterActive
              : FleurIcons.readLater,
          label: article.isReadLater ? l10n.removeReadLater : l10n.readLater,
        ),
        AppMenuItem(
          value: _ArticleContextAction.copyLink,
          icon: FleurIcons.copy,
          label: l10n.copyLink,
        ),
        AppMenuItem(
          value: _ArticleContextAction.openInBrowser,
          icon: FleurIcons.openExternal,
          label: l10n.openInBrowser,
        ),
      ],
    );
    if (!context.mounted || action == null) return;

    final actions = ref.read(articleActionServiceProvider);
    switch (action) {
      case _ArticleContextAction.open:
        await _openArticle(
          context,
          article,
          spec,
          closeIfSelected: false,
          scope: scope,
        );
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
    final scope = ref.watch(currentArticleScopeProvider);
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
      widget.readerListWidth,
      scope,
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
      loading: () =>
          _withTopBar(const Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          _withTopBar(Center(child: Text(l10n.errorMessage(e.toString())))),
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
            return _withTopBar(widget.emptyBuilder!(context, emptyState));
          }
          return _withTopBar(
            _buildDefaultEmptyState(context, l10n, emptyState),
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
              padding: widget.topBar == null
                  ? null
                  : const EdgeInsets.only(top: kWorkspaceHeaderHeight),
              itemCount: entries.length + (data.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= entries.length) {
                  return _withReadableListWidth(
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: data.isLoadingMore
                            ? const CircularProgressIndicator()
                            : Text(l10n.scrollToLoadMore),
                      ),
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
                  return _withReadableListWidth(
                    KeyedSubtree(
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
                        scope: scope,
                      ),
                      onSecondaryTapDown: (details) => unawaited(
                        _showArticleContextMenu(
                          context,
                          ref,
                          live,
                          details.globalPosition,
                          spec,
                          scope,
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
                                ? FleurIcons.markUnread
                                : FleurIcons.markRead,
                            color: Colors.white,
                          ),
                        ),
                        secondaryBackground: Container(
                          color: Colors.amber.shade800,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(
                            live.isStarred
                                ? FleurIcons.star
                                : FleurIcons.starActive,
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
                    return _withReadableListWidth(
                      KeyedSubtree(
                        key: ValueKey('a-${seed.id}'),
                        child: Appear(enabled: animate, child: child),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );

        if (AppMotion.reduceMotion(context)) return _withTopBar(list);

        // Keyed "content switch": on context changes, fade/slide in the new list.
        // This keeps a single ScrollController attached (no AnimatedSwitcher).
        return _withTopBar(
          TweenAnimationBuilder<double>(
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
          ),
        );
      },
    );
  }

  Widget _buildDefaultEmptyState(
    BuildContext context,
    AppLocalizations l10n,
    ArticleListEmptyState state,
  ) {
    final capabilities = ref.watch(backendCapabilitiesProvider);
    final actions = <Widget>[];

    if (state.hasSearch) {
      actions.add(
        OutlinedButton.icon(
          onPressed: () {
            ref
                .read(articleListFilterProvider.notifier)
                .update((filter) => filter.copyWith(searchQuery: ''));
          },
          icon: const Icon(FleurIcons.clear),
          label: Text(l10n.clearSearch),
        ),
      );
    } else if (state.unreadOnly) {
      actions.add(
        OutlinedButton.icon(
          onPressed: () {
            ref
                .read(articleListFilterProvider.notifier)
                .update((filter) => filter.copyWith(unreadOnly: false));
          },
          icon: const Icon(FleurIcons.allArticles),
          label: Text(l10n.showAll),
        ),
      );
    } else if (!state.hasSearch && !state.starredOnly && !state.readLaterOnly) {
      if (capabilities.isVisible(BackendFeature.addSubscription)) {
        actions.add(
          FilledButton.tonalIcon(
            onPressed: () =>
                unawaited(SubscriptionActions.addFeed(context, ref)),
            icon: const Icon(FleurIcons.add),
            label: Text(l10n.addSubscription),
          ),
        );
      }
      if (capabilities.isVisible(BackendFeature.refreshAllSources)) {
        actions.add(
          OutlinedButton.icon(
            onPressed: () =>
                unawaited(SubscriptionActions.refreshAll(context, ref)),
            icon: const Icon(FleurIcons.refresh),
            label: Text(l10n.refreshAll),
          ),
        );
      }
    }

    final hasSearch = state.hasSearch;
    final isUnread = state.unreadOnly && !hasSearch;
    return FleurEmptyState(
      variant: FleurEmptyStateVariant.list,
      icon: hasSearch
          ? FleurIcons.search
          : (isUnread ? FleurIcons.markRead : FleurIcons.article),
      title: hasSearch
          ? l10n.notFound
          : (isUnread ? l10n.noUnreadArticles : l10n.noArticles),
      subtitle: hasSearch
          ? l10n.searchNoResultsSubtitle(state.searchQuery)
          : (isUnread
                ? l10n.unreadEmptySubtitle
                : l10n.articleListEmptySubtitle),
      actions: actions,
    );
  }
}

class _ArticleListTopBar extends StatelessWidget {
  const _ArticleListTopBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('article-list-top-bar'),
      child: child,
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
