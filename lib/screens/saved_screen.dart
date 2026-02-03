import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';
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

  @override
  void initState() {
    super.initState();
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
    ref.read(articleSearchQueryProvider.notifier).state = '';

    ref.read(starredOnlyProvider.notifier).state = mode == _SavedMode.starred;
    ref.read(readLaterOnlyProvider.notifier).state =
        mode == _SavedMode.readLater;
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

        final header = Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.saved,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              SegmentedButton<_SavedMode>(
                segments: [
                  ButtonSegment(
                    value: _SavedMode.starred,
                    label: Text(l10n.starred),
                    icon: const Icon(Icons.star),
                  ),
                  ButtonSegment(
                    value: _SavedMode.readLater,
                    label: Text(l10n.readLater),
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
              fallbackBackLocation: '/saved',
            ),
          );
        }

        if (!isEmbedded) {
          // List-only; reader is a secondary route (or shown full page if deep-linked).
          return listPane();
        }

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
