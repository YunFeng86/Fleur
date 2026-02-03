import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../providers/query_providers.dart';
import '../providers/unread_providers.dart';
import '../ui/global_nav.dart';
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

  String _labelWithCount(String label, int? count) {
    if (count == null) return label;
    return '$label ($count)';
  }

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
    final starredCount = ref.watch(starredCountProvider).valueOrNull;
    final readLaterCount = ref.watch(readLaterCountProvider).valueOrNull;
    final totalWidth = MediaQuery.sizeOf(context).width;
    final useCompactTopBar =
        !isDesktop || globalNavModeForWidth(totalWidth) == GlobalNavMode.bottom;

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

        final header = Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              SegmentedButton<_SavedMode>(
                segments: [
                  ButtonSegment(
                    value: _SavedMode.starred,
                    label: Text(_labelWithCount(l10n.starred, starredCount)),
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
}
