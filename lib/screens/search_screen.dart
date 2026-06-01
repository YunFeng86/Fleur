import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../app/search_routes.dart';
import '../models/article_scope.dart';
import '../models/category.dart';
import '../models/feed.dart';
import '../providers/core_providers.dart';
import '../providers/query_providers.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../ui/layout.dart';
import '../ui/layout_spec.dart';
import '../ui/sidebar_layout.dart';
import '../ui/workspace_layers.dart';
import '../utils/platform.dart';
import '../widgets/article_list.dart';
import '../widgets/fleur_empty_state.dart';
import '../widgets/reader_view.dart';
import '../widgets/staggered_reveal.dart';
import '../widgets/sync_status_capsule.dart';
import '../ui/app_drawer_scope.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    required this.selectedArticleId,
    this.routeState = const SearchRouteState(),
  });

  final int? selectedArticleId;
  final SearchRouteState routeState;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _routeDebounceDuration = Duration(milliseconds: 250);
  static const _emptySearchMaxWidth = 720.0;
  static const _topSearchMaxWidth = 640.0;

  bool _initialized = false;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _suppressControllerListener = false;
  Timer? _routeDebounce;

  ArticleListFilter _filterForRoute(SearchRouteState state) {
    if (!state.hasQuery) {
      return const ArticleListFilter(searchInContentOverride: true);
    }
    return ArticleListFilter(
      scope: state.scope,
      unreadOnly: state.unreadOnly,
      searchQuery: state.query.trim(),
      searchInContentOverride: state.searchInContent,
    );
  }

  bool _sameFilter(ArticleListFilter a, ArticleListFilter b) {
    return a.scope == b.scope &&
        a.unreadOnly == b.unreadOnly &&
        a.searchQuery == b.searchQuery &&
        a.searchInContentOverride == b.searchInContentOverride;
  }

  void _setControllerText(String text) {
    if (_controller.text == text) return;
    _suppressControllerListener = true;
    _controller.value = _controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
    _suppressControllerListener = false;
  }

  void _applyRouteState(SearchRouteState state) {
    final next = _filterForRoute(state);
    final current = ref.read(articleListFilterProvider);
    if (!_sameFilter(current, next)) {
      ref.read(articleListFilterProvider.notifier).state = next;
    }
    _setControllerText(next.searchQuery);
  }

  void _scheduleApplyRouteState(SearchRouteState state) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyRouteState(state);
      if (!_initialized) setState(() => _initialized = true);
    });
  }

  SearchRouteState _stateFromFilter(ArticleListFilter filter) {
    final query = filter.searchQuery.trim();
    if (query.isEmpty) return const SearchRouteState();
    return SearchRouteState(
      query: query,
      scope: filter.scope,
      unreadOnly: filter.unreadOnly,
      searchInContent: filter.searchInContentOverride ?? true,
    );
  }

  void _goToSearchState(SearchRouteState state) {
    final location = searchLocation(state);
    final router = GoRouter.maybeOf(context);
    final current = router?.routerDelegate.currentConfiguration.uri.toString();
    if (current == location) return;
    if (router != null) {
      router.go(location);
      return;
    }
    context.go(location);
  }

  void _scheduleRouteUpdate(SearchRouteState state, {bool immediate = false}) {
    _routeDebounce?.cancel();
    if (immediate) {
      _goToSearchState(state);
      return;
    }
    _routeDebounce = Timer(_routeDebounceDuration, () {
      if (!mounted) return;
      _goToSearchState(state);
    });
  }

  bool _isSearchArticleRoute() {
    final uri = GoRouter.maybeOf(
      context,
    )?.routerDelegate.currentConfiguration.uri;
    final segments = uri?.pathSegments;
    return segments != null &&
        segments.length >= 3 &&
        segments[0] == 'search' &&
        segments[1] == 'article';
  }

  void _updateSearchState({
    String? query,
    ArticleScope? scope,
    bool? unreadOnly,
    bool? searchInContent,
    bool immediate = false,
  }) {
    final current = ref.read(articleListFilterProvider);
    final nextQuery = query ?? current.searchQuery;
    final trimmed = nextQuery.trim();
    final nextFilter = trimmed.isEmpty
        ? const ArticleListFilter(searchInContentOverride: true)
        : current.copyWith(
            scope: scope ?? current.scope,
            unreadOnly: unreadOnly ?? current.unreadOnly,
            searchQuery: nextQuery,
            searchInContentOverride:
                searchInContent ?? current.searchInContentOverride ?? true,
          );

    ref.read(articleListFilterProvider.notifier).state = nextFilter;
    _setControllerText(nextFilter.searchQuery);
    _scheduleRouteUpdate(
      _stateFromFilter(nextFilter),
      immediate: immediate || _isSearchArticleRoute(),
    );
  }

  void _clearQuery() {
    _updateSearchState(query: '', immediate: true);
  }

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode();
    _controller = TextEditingController(text: widget.routeState.query);
    _controller.addListener(() {
      if (_suppressControllerListener) return;
      _updateSearchState(query: _controller.text);
    });
    _scheduleApplyRouteState(widget.routeState);
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeState != widget.routeState) {
      _routeDebounce?.cancel();
      _scheduleApplyRouteState(widget.routeState);
    }
  }

  @override
  void dispose() {
    _routeDebounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final surfaces = Theme.of(context).fleurSurface;
    final useCompactTopBar = !isDesktop;

    if (!_initialized) {
      final loading = Container(
        color: surfaces.list,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
      if (!useCompactTopBar) return loading;
      return Scaffold(
        appBar: AppBar(
          leading: AppDrawerScope.drawerLeading(context),
          title: Text(l10n.search),
        ),
        body: loading,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final showSyncCapsule = LayoutSpec.fromContext(
          context,
        ).showsListSyncStatusCapsule;
        final width = constraints.maxWidth;
        final listWidth = clampWorkspaceListWidth(
          ref.watch(workspaceListWidthProvider),
          width,
        );
        final spec = LayoutSpec.fromContentSize(
          contentWidth: width,
          contentHeight: MediaQuery.sizeOf(context).height,
          listWidth: listWidth,
        );
        final isEmbedded = shouldEmbedReaderForLayout(
          spec,
          listWidth: kDesktopListWidth,
        );

        final query = ref.watch(articleSearchQueryProvider);
        final filter = ref.watch(articleListFilterProvider);
        final routeState = _stateFromFilter(filter);
        final trimmed = query.trim();
        final showResults = trimmed.isNotEmpty;
        final feeds = ref.watch(feedsProvider).valueOrNull ?? const <Feed>[];
        final categories =
            ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];

        final searchField = _SearchTaskField(
          controller: _controller,
          focusNode: _focusNode,
          large: !showResults,
          autofocus: widget.selectedArticleId == null,
          onSubmitted: (value) =>
              _updateSearchState(query: value, immediate: true),
          onClear: _clearQuery,
        );

        final filters = _SearchFilterBar(
          visible: showResults,
          state: routeState,
          feeds: feeds,
          categories: categories,
          onScopeChanged: (scope) => _updateSearchState(scope: scope),
          onUnreadChanged: (value) => _updateSearchState(unreadOnly: value),
          onSearchInContentChanged: (value) =>
              _updateSearchState(searchInContent: value),
        );

        Widget listPane() {
          if (!showResults) {
            return SizedBox.expand(
              key: const Key('search_task_empty_stage'),
              child: LayoutBuilder(
                builder: (context, stageConstraints) {
                  final horizontalInset = stageConstraints.maxWidth >= 640
                      ? 32.0
                      : 16.0;
                  final fieldWidth =
                      (stageConstraints.maxWidth - horizontalInset * 2)
                          .clamp(0.0, _emptySearchMaxWidth)
                          .toDouble();
                  return Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: fieldWidth,
                      child: StaggeredReveal(
                        enabled: isDesktop,
                        child: searchField,
                      ),
                    ),
                  );
                },
              ),
            );
          }

          return Column(
            children: [
              StaggeredReveal(
                enabled: isDesktop,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _topSearchMaxWidth,
                      ),
                      child: searchField,
                    ),
                  ),
                ),
              ),
              filters,
              Expanded(
                child: SyncStatusCapsuleHost(
                  enabled: showSyncCapsule,
                  child: ArticleList(
                    selectedArticleId: widget.selectedArticleId,
                    baseLocation: searchLocation(routeState),
                    readerListWidth: kDesktopListWidth,
                    articleLocationBuilder: (article) =>
                        searchArticleLocation(routeState, article.id),
                    emptyBuilder: (context, state) => FleurEmptyState(
                      variant: FleurEmptyStateVariant.list,
                      icon: FleurIcons.search,
                      title: l10n.notFound,
                      subtitle: l10n.searchNoResultsSubtitle(trimmed),
                      actions: [
                        OutlinedButton.icon(
                          onPressed: _clearQuery,
                          icon: const Icon(FleurIcons.clear),
                          label: Text(l10n.clearSearch),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        Widget readerPane({required bool embedded}) {
          final id = widget.selectedArticleId;
          if (id == null) {
            return FleurEmptyState(
              variant: FleurEmptyStateVariant.reader,
              icon: FleurIcons.search,
              title: l10n.searchReaderEmptyTitle,
              subtitle: l10n.searchReaderEmptySubtitle,
            );
          }
          return Container(
            color: surfaces.reader,
            child: ReaderView(
              key: ValueKey('search-reader-$id'),
              articleId: id,
              embedded: embedded,
              showBack: !embedded,
              fallbackBackLocation: searchLocation(routeState),
            ),
          );
        }

        Widget content;
        if (!isEmbedded || widget.selectedArticleId == null) {
          content = listPane();
        } else {
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RepaintBoundary(
                child: SizedBox(width: listWidth, child: listPane()),
              ),
              WorkspaceSplitHandle(
                key: const Key('workspace_list_split_handle'),
                onDragDelta: (delta) {
                  final notifier = ref.read(
                    workspaceListWidthProvider.notifier,
                  );
                  notifier.state = clampWorkspaceListWidth(
                    notifier.state + delta,
                    spec.contentWidth,
                  );
                },
              ),
              Expanded(child: readerPane(embedded: true)),
            ],
          );
        }

        if (!useCompactTopBar) {
          return Material(color: surfaces.list, child: content);
        }

        return Scaffold(
          appBar: AppBar(
            leading: AppDrawerScope.drawerLeading(context),
            title: Text(l10n.search),
          ),
          body: content,
        );
      },
    );
  }
}

class _SearchTaskField extends StatelessWidget {
  const _SearchTaskField({
    required this.controller,
    required this.focusNode,
    required this.large,
    required this.autofocus,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool large;
  final bool autofocus;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  static const _largeHeight = 46.0;
  static const _topHeight = 42.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final surfaces = theme.fleurSurface;
    final states = theme.fleurState;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().isNotEmpty;
        final height = large ? _largeHeight : _topHeight;
        final textStyle =
            (large ? theme.textTheme.bodyLarge : theme.textTheme.bodyMedium)
                ?.copyWith(
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                  height: 1.15,
                );
        return SizedBox(
          key: Key(large ? 'search_task_field_large' : 'search_task_field_top'),
          width: double.infinity,
          height: height,
          child: SearchBar(
            key: const Key('search_task_field'),
            controller: controller,
            focusNode: focusNode,
            autoFocus: autofocus,
            hintText: l10n.search,
            leading: Icon(
              FleurIcons.search,
              size: large ? 18 : 16,
              color: colorScheme.onSurfaceVariant,
            ),
            trailing: hasText
                ? [
                    IconButton(
                      tooltip: l10n.delete,
                      onPressed: onClear,
                      icon: const Icon(FleurIcons.clear, size: 16),
                    ),
                  ]
                : null,
            constraints: BoxConstraints(
              minHeight: height,
              maxHeight: height,
              minWidth: 0,
            ),
            elevation: const WidgetStatePropertyAll(0),
            backgroundColor: WidgetStatePropertyAll(surfaces.floating),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            shadowColor: const WidgetStatePropertyAll(Colors.transparent),
            overlayColor: WidgetStateProperty.resolveWith((widgetStates) {
              if (widgetStates.contains(WidgetState.pressed)) {
                return states.pressedTint;
              }
              if (widgetStates.contains(WidgetState.hovered) ||
                  widgetStates.contains(WidgetState.focused)) {
                return states.hoverTint;
              }
              return null;
            }),
            side: WidgetStateProperty.resolveWith((widgetStates) {
              final color = widgetStates.contains(WidgetState.focused)
                  ? states.focusRing
                  : surfaces.subtleDivider;
              return BorderSide(color: color, width: 1);
            }),
            shape: const WidgetStatePropertyAll(StadiumBorder()),
            padding: WidgetStatePropertyAll(
              EdgeInsetsDirectional.only(
                start: large ? 16 : 14,
                end: hasText ? 2 : (large ? 16 : 14),
              ),
            ),
            textStyle: WidgetStatePropertyAll(textStyle),
            hintStyle: WidgetStatePropertyAll(
              textStyle?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmitted,
          ),
        );
      },
    );
  }
}

class _SearchFilterBar extends StatelessWidget {
  const _SearchFilterBar({
    required this.visible,
    required this.state,
    required this.feeds,
    required this.categories,
    required this.onScopeChanged,
    required this.onUnreadChanged,
    required this.onSearchInContentChanged,
  });

  final bool visible;
  final SearchRouteState state;
  final List<Feed> feeds;
  final List<Category> categories;
  final ValueChanged<ArticleScope> onScopeChanged;
  final ValueChanged<bool> onUnreadChanged;
  final ValueChanged<bool> onSearchInContentChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: visible
          ? Padding(
              key: const Key('search_advanced_filters'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _SearchScopeDropdown(
                        state: state,
                        feeds: feeds,
                        categories: categories,
                        onChanged: onScopeChanged,
                      ),
                      FilterChip(
                        key: const Key('search_filter_unread'),
                        label: Text(AppLocalizations.of(context)!.unreadOnly),
                        selected: state.unreadOnly,
                        onSelected: onUnreadChanged,
                      ),
                      FilterChip(
                        key: const Key('search_filter_content'),
                        label: Text(
                          AppLocalizations.of(context)!.searchInContent,
                        ),
                        selected: state.searchInContent,
                        onSelected: onSearchInContentChanged,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(key: Key('search_advanced_filters_hidden')),
    );
  }
}

class _SearchScopeDropdown extends StatelessWidget {
  const _SearchScopeDropdown({
    required this.state,
    required this.feeds,
    required this.categories,
    required this.onChanged,
  });

  final SearchRouteState state;
  final List<Feed> feeds;
  final List<Category> categories;
  final ValueChanged<ArticleScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = _scopeOptions(context, feeds, categories, state.scope);
    final value = options.any((option) => option.scope == state.scope)
        ? state.scope
        : ArticleScope.all;
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.fleurSurface.floating,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.fleurSurface.subtleDivider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<ArticleScope>(
            key: const Key('search_scope_filter'),
            value: value,
            borderRadius: BorderRadius.circular(12),
            icon: const Icon(FleurIcons.dropdown, size: 16),
            onChanged: (scope) {
              if (scope == null) return;
              onChanged(scope);
            },
            items: [
              for (final option in options)
                DropdownMenuItem<ArticleScope>(
                  value: option.scope,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchScopeOption {
  const _SearchScopeOption({required this.scope, required this.label});

  final ArticleScope scope;
  final String label;
}

List<_SearchScopeOption> _scopeOptions(
  BuildContext context,
  List<Feed> feeds,
  List<Category> categories,
  ArticleScope currentScope,
) {
  final l10n = AppLocalizations.of(context)!;
  final options = <_SearchScopeOption>[
    _SearchScopeOption(scope: ArticleScope.all, label: l10n.all),
    _SearchScopeOption(scope: ArticleScope.starred, label: l10n.starred),
    _SearchScopeOption(scope: ArticleScope.readLater, label: l10n.readLater),
    for (final category in categories)
      _SearchScopeOption(
        scope: ArticleScope.category(category.id),
        label: category.name,
      ),
    for (final feed in feeds)
      _SearchScopeOption(
        scope: ArticleScope.feed(feed.id),
        label: feed.userTitle?.trim().isNotEmpty == true
            ? feed.userTitle!.trim()
            : (feed.title?.trim().isNotEmpty == true
                  ? feed.title!.trim()
                  : feed.url),
      ),
  ];
  if (!options.any((option) => option.scope == currentScope)) {
    options.add(
      _SearchScopeOption(
        scope: currentScope,
        label: switch (currentScope.type) {
          ArticleScopeType.feed => 'Feed ${currentScope.id}',
          ArticleScopeType.category => 'Category ${currentScope.id}',
          _ => l10n.all,
        },
      ),
    );
  }
  return options;
}
