import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../providers/query_providers.dart';
import '../providers/unread_providers.dart';
import '../ui/dialogs/article_search_dialog.dart';
import '../ui/layout.dart';
import '../utils/platform.dart';
import '../widgets/article_list.dart';
import '../widgets/reader_view.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, required this.selectedArticleId});

  final int? selectedArticleId;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Riverpod: avoid modifying providers during initState/build.
      // Apply section state after the first frame.
      ref.read(unreadOnlyProvider.notifier).state = false;
      ref.read(starredOnlyProvider.notifier).state = false;
      ref.read(readLaterOnlyProvider.notifier).state = false;
      ref.read(selectedFeedIdProvider.notifier).state = null;
      ref.read(selectedCategoryIdProvider.notifier).state = null;
      ref.read(selectedTagIdProvider.notifier).state = null;

      if (!mounted) return;
      setState(() => _initialized = true);

      // Only auto-prompt for a query when we're on the list root.
      if (widget.selectedArticleId != null) return;
      if (ref.read(articleSearchQueryProvider).trim().isNotEmpty) return;

      await showArticleSearchDialog(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!_initialized) {
      return Container(
        color: Theme.of(context).colorScheme.surface,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isEmbedded = isDesktop
            ? desktopReaderEmbedded(desktopModeForWidth(width))
            : width >= 600;

        final query = ref.watch(articleSearchQueryProvider).trim();

        final header = Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  query.isEmpty ? l10n.search : query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: l10n.search,
                onPressed: () async {
                  await showArticleSearchDialog(context, ref);
                  // If we're showing an embedded article, return to list root
                  // after changing the query.
                  if (!context.mounted) return;
                  if (widget.selectedArticleId != null) context.go('/search');
                },
                icon: const Icon(Icons.search),
              ),
              if (query.isNotEmpty)
                IconButton(
                  tooltip: l10n.delete,
                  onPressed: () {
                    ref.read(articleSearchQueryProvider.notifier).state = '';
                    if (context.mounted) context.go('/search');
                  },
                  icon: const Icon(Icons.clear),
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
                  baseLocation: '/search',
                  articleRoutePrefix: '/search',
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
              articleId: id,
              embedded: embedded,
              showBack: !embedded,
              fallbackBackLocation: '/search',
            ),
          );
        }

        if (!isEmbedded) return listPane();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: kDesktopListWidth, child: listPane()),
            const VerticalDivider(width: 1),
            Expanded(child: readerPane(embedded: true)),
          ],
        );
      },
    );
  }
}
