import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/features/reader/application/reader_search_providers.dart';
import 'package:fleur/theme/fleur_icons.dart';
import 'package:fleur/theme/fleur_theme_extensions.dart';
import 'package:fleur/ui/motion.dart';

class ReaderSearchBar extends ConsumerStatefulWidget {
  const ReaderSearchBar({super.key, required this.articleId});

  final int articleId;

  @override
  ConsumerState<ReaderSearchBar> createState() => ReaderSearchBarState();
}

class ReaderSearchBarState extends ConsumerState<ReaderSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _wasVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode(debugLabel: 'reader_search');
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReaderSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.articleId != widget.articleId) {
      _controller.clear();
      _focusNode.unfocus();
      _wasVisible = false;
    }
  }

  void _selectAll() {
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  void focusAndSelectAll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _selectAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final reader = theme.fleurReader;
    final statesTheme = theme.fleurState;
    final state = ref.watch(readerSearchControllerProvider(widget.articleId));
    final controller = ref.read(
      readerSearchControllerProvider(widget.articleId).notifier,
    );
    final reduceMotion = AppMotion.reduceMotion(context);
    final duration = reduceMotion ? Duration.zero : AppMotion.short;

    if (!state.visible) {
      if (_wasVisible) {
        if (state.query.isEmpty && _controller.text.isNotEmpty) {
          _controller.clear();
        }
        _focusNode.unfocus();
      }
      _wasVisible = false;
    }

    if (state.visible && !_wasVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNode.requestFocus();
        _selectAll();
      });
    }
    _wasVisible = state.visible;

    final counterText = '${state.currentMatchNumber}/${state.totalMatches}';

    return Positioned(
      top: 12,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: reader.maxWidth),
            child: IgnorePointer(
              ignoring: !state.visible,
              child: AnimatedSlide(
                offset: state.visible ? Offset.zero : const Offset(0, -0.08),
                duration: duration,
                curve: AppMotion.standardCurve,
                child: AnimatedOpacity(
                  opacity: state.visible ? 1 : 0,
                  duration: duration,
                  curve: AppMotion.standardCurve,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(12),
                    color: reader.searchBarSurface,
                    shadowColor: theme.shadowColor.withValues(alpha: 0.2),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 4),
                          Icon(
                            FleurIcons.search,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              onChanged: controller.setQuery,
                              onSubmitted: (_) => controller.nextMatch(),
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: l10n.findInPage,
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(counterText, style: reader.metaStyle),
                          const SizedBox(width: 4),
                          IconButton(
                            iconSize: 20,
                            tooltip: l10n.previousMatch,
                            onPressed: state.totalMatches > 0
                                ? controller.previousMatch
                                : null,
                            icon: const Icon(FleurIcons.previousMatch),
                          ),
                          IconButton(
                            iconSize: 20,
                            tooltip: l10n.nextMatch,
                            onPressed: state.totalMatches > 0
                                ? controller.nextMatch
                                : null,
                            icon: const Icon(FleurIcons.nextMatch),
                          ),
                          IconButton(
                            iconSize: 20,
                            tooltip: l10n.caseSensitive,
                            onPressed: controller.toggleCaseSensitive,
                            color: state.caseSensitive
                                ? statesTheme.syncAccent
                                : null,
                            icon: const Icon(FleurIcons.caseSensitive),
                          ),
                          if (state.isSearching) ...[
                            const SizedBox(width: 4),
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 4),
                          ],
                          IconButton(
                            iconSize: 20,
                            tooltip: l10n.close,
                            onPressed: () {
                              _controller.clear();
                              controller.close(clearQuery: true);
                            },
                            icon: const Icon(FleurIcons.close),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
