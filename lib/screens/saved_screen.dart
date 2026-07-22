import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../providers/query_providers.dart';
import '../providers/unread_providers.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../ui/home/article_reader_workspace_layout.dart';
import '../ui/home/home_scene_panes.dart';
import '../ui/layout.dart';
import '../ui/layout_spec.dart';
import '../ui/shell_chrome_layout.dart';
import '../widgets/article_list.dart';
import '../widgets/fleur_empty_state.dart';
import '../features/reader/reader.dart';
import '../widgets/staggered_reveal.dart';
import '../widgets/sync_status_capsule.dart';
import '../ui/app_drawer_scope.dart';

enum _SavedMode { starred, readLater }

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key, required this.selectedArticleId});

  final int? selectedArticleId;

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  _SavedMode _mode = _SavedMode.starred;
  bool _initialized = false;
  late final TextEditingController _searchController;

  String _labelWithCount(String label, int? count) {
    if (count == null) return label;
    return '$label ($count)';
  }

  String _locationForMode(_SavedMode mode) {
    return switch (mode) {
      _SavedMode.starred => '/starred',
      _SavedMode.readLater => '/read-later',
    };
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(articleSearchQueryProvider),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyMode(_mode);
      if (!mounted) return;
      setState(() => _initialized = true);
    });
  }

  void _applyMode(_SavedMode mode) {
    // Ensure this top-level section is not affected by feed/category/tag/search.
    _searchController.text = '';
    ref
        .read(articleListFilterProvider.notifier)
        .update(
          (filter) => filter.savedOnly(starred: mode == _SavedMode.starred),
        );
  }

  void _clearSearch() {
    _searchController.clear();
    ref
        .read(articleListFilterProvider.notifier)
        .update((filter) => filter.copyWith(searchQuery: ''));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final surfaces = Theme.of(context).fleurSurface;
    final starredCount = ref.watch(starredCountProvider).valueOrNull;
    final readLaterCount = ref.watch(readLaterCountProvider).valueOrNull;
    final searchQuery = ref.watch(articleSearchQueryProvider);
    final layoutSpec = LayoutSpec.fromContext(context);
    final useCompactTopBar =
        layoutSpec.shellChromeLayout.profile == ShellChromeProfile.contentOnly;

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
          title: Text(l10n.saved),
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
        final spec = layoutSpec;
        final isEmbedded = shouldEmbedReaderForLayout(
          spec,
          listWidth: kDesktopListWidth,
        );

        final searchField = TextField(
          controller: _searchController,
          onChanged: (value) {
            ref
                .read(articleListFilterProvider.notifier)
                .update((filter) => filter.copyWith(searchQuery: value));
          },
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchInContent,
            prefixIcon: const Icon(FleurIcons.search),
            suffixIcon: searchQuery.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.delete,
                    onPressed: _clearSearch,
                    icon: const Icon(FleurIcons.clear),
                  ),
          ),
        );

        final header = StaggeredReveal(
          enabled: !spec.isCompact,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, headerConstraints) {
                    final narrow = headerConstraints.maxWidth < 760;
                    final segmented = SegmentedButton<_SavedMode>(
                      segments: [
                        ButtonSegment(
                          value: _SavedMode.starred,
                          label: Text(
                            _labelWithCount(l10n.starred, starredCount),
                          ),
                          icon: const Icon(FleurIcons.star),
                        ),
                        ButtonSegment(
                          value: _SavedMode.readLater,
                          label: Text(
                            _labelWithCount(l10n.readLater, readLaterCount),
                          ),
                          icon: const Icon(FleurIcons.readLater),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) {
                        final next = s.first;
                        setState(() => _mode = next);
                        _applyMode(next);
                        // Deselect the current article when switching mode.
                        if (context.mounted) context.go(_locationForMode(next));
                      },
                    );

                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          segmented,
                          const SizedBox(height: 8),
                          searchField,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        segmented,
                        const Spacer(),
                        SizedBox(width: 320, child: searchField),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );

        Widget listPane() {
          final modeLocation = _locationForMode(_mode);
          return Column(
            children: [
              header,
              const SizedBox(height: 8),
              Expanded(
                child: SyncStatusCapsuleHost(
                  enabled: showSyncCapsule,
                  child: ArticleList(
                    selectedArticleId: widget.selectedArticleId,
                    baseLocation: modeLocation,
                    articleRoutePrefix: modeLocation,
                    emptyBuilder: (context, state) =>
                        _buildEmptyState(context, l10n, state),
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
              icon: FleurIcons.saved,
              title: l10n.savedReaderEmptyTitle,
              subtitle: l10n.savedReaderEmptySubtitle,
            );
          }
          final reader = ReaderView(
            key: ValueKey('saved-reader-$id'),
            articleId: id,
            embedded: embedded,
            showBack: !embedded,
            fallbackBackLocation: _locationForMode(_mode),
          );
          if (!embedded) return reader;
          return ReadingPaneSurface(child: reader);
        }

        final id = widget.selectedArticleId;
        final content = id != null && !isEmbedded
            ? readerPane(embedded: false)
            : ArticleReaderWorkspaceLayout(
                selectedArticleId: id,
                contentWidth: width,
                listWidth: kDesktopListWidth,
                listPane: listPane(),
                readerPane: id == null ? null : readerPane(embedded: true),
                showSplitHandle: false,
                onResizeList: null,
              );

        if (!useCompactTopBar) {
          return Material(color: surfaces.list, child: content);
        }

        return Scaffold(
          appBar: AppBar(
            leading: AppDrawerScope.drawerLeading(context),
            title: Text(l10n.saved),
          ),
          body: content,
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations l10n,
    ArticleListEmptyState state,
  ) {
    final isStarred = state.starredOnly && !state.readLaterOnly;
    final isReadLater = state.readLaterOnly;
    final title = state.hasSearch
        ? l10n.notFound
        : (isStarred
              ? l10n.starred
              : (isReadLater ? l10n.readLater : l10n.saved));
    final subtitle = state.hasSearch
        ? l10n.savedSearchEmptySubtitle
        : (isStarred
              ? l10n.noStarredArticles
              : (isReadLater ? l10n.noReadLaterArticles : l10n.noArticles));
    final icon = state.hasSearch
        ? FleurIcons.search
        : (isStarred ? FleurIcons.star : FleurIcons.readLater);
    final actions = state.hasSearch
        ? <Widget>[
            OutlinedButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(FleurIcons.clear),
              label: Text(l10n.clearSearch),
            ),
          ]
        : <Widget>[
            FilledButton.tonalIcon(
              onPressed: () => context.go('/all'),
              icon: const Icon(FleurIcons.feed),
              label: Text(l10n.feeds),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/search'),
              icon: const Icon(FleurIcons.search),
              label: Text(l10n.search),
            ),
          ];

    return FleurEmptyState(
      variant: FleurEmptyStateVariant.list,
      icon: icon,
      title: title,
      subtitle: subtitle,
      actions: actions,
    );
  }
}
