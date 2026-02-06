import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_settings_providers.dart';
import '../providers/query_providers.dart';
import '../providers/unread_providers.dart';
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
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _suppressControllerListener = false;

  void _applyQuery(String q) {
    // Typing/searching should reset any embedded selection.
    if (widget.selectedArticleId != null) context.go('/search');
    ref.read(articleSearchQueryProvider.notifier).state = q;
  }

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode();
    _controller = TextEditingController(
      text: ref.read(articleSearchQueryProvider),
    );
    _controller.addListener(() {
      if (_suppressControllerListener) return;
      _applyQuery(_controller.text);
    });

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
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
        appBar: AppBar(title: Text(l10n.search)),
        body: loading,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isEmbedded = isDesktop
            ? desktopReaderEmbedded(desktopModeForWidth(width))
            : width >= 600;

        final query = ref.watch(articleSearchQueryProvider);
        final appSettings = ref.watch(appSettingsProvider).valueOrNull;
        final searchInContent = appSettings?.searchInContent ?? true;

        // Keep the TextField controller in sync with external updates (e.g.
        // navigating back to Search with an existing query).
        if (_controller.text != query) {
          _suppressControllerListener = true;
          _controller.value = _controller.value.copyWith(
            text: query,
            selection: TextSelection.collapsed(offset: query.length),
            composing: TextRange.empty,
          );
          _suppressControllerListener = false;
        }

        final header = Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (width >= 600)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: widget.selectedArticleId == null,
                        decoration: InputDecoration(
                          hintText: l10n.search,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (query.trim().isNotEmpty)
                                IconButton(
                                  tooltip: l10n.delete,
                                  onPressed: () => _applyQuery(''),
                                  icon: const Icon(Icons.clear),
                                ),
                            ],
                          ),
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: _applyQuery,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: Text(l10n.searchInContent),
                      selected: searchInContent,
                      onSelected: (v) async {
                        await ref
                            .read(appSettingsProvider.notifier)
                            .setSearchInContent(v);
                      },
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: widget.selectedArticleId == null,
                      decoration: InputDecoration(
                        hintText: l10n.search,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (query.trim().isNotEmpty)
                              IconButton(
                                tooltip: l10n.delete,
                                onPressed: () => _applyQuery(''),
                                icon: const Icon(Icons.clear),
                              ),
                          ],
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: _applyQuery,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilterChip(
                        label: Text(l10n.searchInContent),
                        selected: searchInContent,
                        onSelected: (v) async {
                          await ref
                              .read(appSettingsProvider.notifier)
                              .setSearchInContent(v);
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );

        Widget listPane() {
          final trimmed = query.trim();
          final showResults = trimmed.isNotEmpty;
          return Column(
            children: [
              header,
              const Divider(height: 1),
              Expanded(
                child: showResults
                    ? ArticleList(
                        selectedArticleId: widget.selectedArticleId,
                        baseLocation: '/search',
                        articleRoutePrefix: '/search',
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.surface,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(24),
                        child: Text(l10n.search),
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
              key: ValueKey('search-reader-$id'),
              articleId: id,
              embedded: embedded,
              showBack: !embedded,
              fallbackBackLocation: '/search',
            ),
          );
        }

        Widget content;
        if (!isEmbedded) {
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
          appBar: AppBar(title: Text(l10n.search)),
          body: content,
        );
      },
    );
  }
}
