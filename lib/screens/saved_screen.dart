import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../providers/query_providers.dart';
import '../providers/unread_providers.dart';
import '../ui/layout.dart';
import '../utils/platform.dart';
import '../widgets/article_list.dart';
import '../widgets/reader_view.dart';

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
    ref.read(unreadOnlyProvider.notifier).state = false;
    ref.read(selectedFeedIdProvider.notifier).state = null;
    ref.read(selectedCategoryIdProvider.notifier).state = null;
    ref.read(selectedTagIdProvider.notifier).state = null;

    ref.read(starredOnlyProvider.notifier).state = mode == _SavedMode.starred;
    ref.read(readLaterOnlyProvider.notifier).state =
        mode == _SavedMode.readLater;
    _searchController.text = '';
    ref.read(articleSearchQueryProvider.notifier).state = '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final starredCount = ref.watch(starredCountProvider).valueOrNull;
    final readLaterCount = ref.watch(readLaterCountProvider).valueOrNull;
    final searchQuery = ref.watch(articleSearchQueryProvider);
    // Desktop has a top title bar provided by App chrome; avoid in-page AppBar.
    final useCompactTopBar = !isDesktop;

    if (!_initialized) {
      final loading = Container(
        color: Theme.of(context).colorScheme.surface,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
      if (!useCompactTopBar) return loading;
      return Scaffold(
        appBar: AppBar(title: Text(l10n.saved)),
        body: loading,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isEmbedded = isDesktop
            ? desktopReaderEmbedded(desktopModeForWidth(width))
            : width >= 600;

        final searchField = TextField(
          controller: _searchController,
          onChanged: (value) {
            ref.read(articleSearchQueryProvider.notifier).state = value;
          },
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchInContent,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchQuery.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.delete,
                    onPressed: () {
                      _searchController.clear();
                      ref.read(articleSearchQueryProvider.notifier).state = '';
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
        );

        final header = Padding(
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
                        icon: const Icon(Icons.star),
                      ),
                      ButtonSegment(
                        value: _SavedMode.readLater,
                        label: Text(
                          _labelWithCount(l10n.readLater, readLaterCount),
                        ),
                        icon: const Icon(Icons.bookmark),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) {
                      final next = s.first;
                      setState(() => _mode = next);
                      _applyMode(next);
                      // Deselect the current article when switching mode.
                      if (context.mounted) context.go('/saved');
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
        );

        Widget listPane() {
          return Column(
            children: [
              header,
              const Divider(height: 1),
              Expanded(
                child: ArticleList(
                  selectedArticleId: widget.selectedArticleId,
                  baseLocation: '/saved',
                  articleRoutePrefix: '/saved',
                  emptyBuilder: (context, state) =>
                      _buildEmptyState(context, l10n, state),
                ),
              ),
            ],
          );
        }

        Widget readerPane({required bool embedded}) {
          final id = widget.selectedArticleId;
          if (id == null) {
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              alignment: Alignment.center,
              child: Text(l10n.selectAnArticle),
            );
          }
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: ReaderView(
              key: ValueKey('saved-reader-$id'),
              articleId: id,
              embedded: embedded,
              showBack: !embedded,
              fallbackBackLocation: '/saved',
            ),
          );
        }

        Widget content;
        if (!isEmbedded) {
          // List-only; reader is a secondary route (or shown full page if deep-linked).
          content = listPane();
        } else {
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: kDesktopListWidth, child: listPane()),
              const VerticalDivider(width: 1),
              Expanded(child: readerPane(embedded: true)),
            ],
          );
        }

        if (!useCompactTopBar) return content;

        return Scaffold(
          appBar: AppBar(title: Text(l10n.saved)),
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
    final theme = Theme.of(context);
    final isStarred = state.starredOnly && !state.readLaterOnly;
    final title = isStarred
        ? l10n.starred
        : (state.readLaterOnly ? l10n.readLater : l10n.saved);
    final subtitle = state.hasSearch ? l10n.notFound : l10n.noArticles;
    final icon = isStarred ? Icons.star_border : Icons.bookmark_border;

    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 54, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.rss_feed),
                  label: Text(l10n.feeds),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/search'),
                  icon: const Icon(Icons.search),
                  label: Text(l10n.search),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
