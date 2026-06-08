import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../motion.dart';
import '../sidebar_layout.dart';
import '../workspace_layers.dart';

class ArticleReaderWorkspaceLayout extends StatefulWidget {
  const ArticleReaderWorkspaceLayout({
    super.key,
    required this.selectedArticleId,
    required this.contentWidth,
    required this.listWidth,
    required this.listPane,
    required this.readerPane,
    required this.onResizeList,
    required this.showSplitHandle,
  });

  final int? selectedArticleId;
  final double contentWidth;
  final double listWidth;
  final Widget listPane;
  final Widget? readerPane;
  final ValueChanged<double>? onResizeList;
  final bool showSplitHandle;

  @override
  State<ArticleReaderWorkspaceLayout> createState() =>
      _ArticleReaderWorkspaceLayoutState();
}

class _ArticleReaderWorkspaceLayoutState
    extends State<ArticleReaderWorkspaceLayout> {
  Timer? _clearReaderTimer;
  Widget? _retainedReaderPane;

  bool get _isOpen =>
      widget.selectedArticleId != null && widget.readerPane != null;

  @override
  void initState() {
    super.initState();
    if (_isOpen) _retainedReaderPane = widget.readerPane;
  }

  @override
  void didUpdateWidget(covariant ArticleReaderWorkspaceLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRetainedReaderPane();
  }

  @override
  void dispose() {
    _clearReaderTimer?.cancel();
    super.dispose();
  }

  void _syncRetainedReaderPane() {
    _clearReaderTimer?.cancel();

    if (_isOpen) {
      _retainedReaderPane = widget.readerPane;
      return;
    }

    final reduceMotion = AppMotion.reduceMotion(context);
    if (reduceMotion || _retainedReaderPane == null) {
      _retainedReaderPane = null;
      return;
    }

    _clearReaderTimer = Timer(AppMotion.medium, () {
      if (!mounted || _isOpen) return;
      setState(() => _retainedReaderPane = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final contentWidth = math.max(0.0, widget.contentWidth);
    final openListWidth = math.min(
      math.max(0.0, widget.listWidth),
      contentWidth,
    );
    final showHandle =
        widget.showSplitHandle &&
        widget.onResizeList != null &&
        openListWidth > 0;
    final handleWidth = showHandle ? kWorkspaceSplitHandleHitWidth : 0.0;
    final readerOpenLeft = openListWidth;
    final closedListWidth = contentWidth;
    final duration = AppMotion.reduceMotion(context)
        ? Duration.zero
        : AppMotion.medium;
    final target = _isOpen ? 1.0 : 0.0;
    final readerPane = _retainedReaderPane ?? const SizedBox.shrink();

    return ClipRect(
      child: TweenAnimationBuilder<double>(
        key: const Key('article_reader_workspace_layout'),
        tween: Tween<double>(end: target),
        duration: duration,
        curve: _isOpen
            ? AppMotion.emphasizedDecelerate
            : AppMotion.emphasizedAccelerate,
        builder: (context, progress, _) {
          final listWidth = ui.lerpDouble(
            closedListWidth,
            openListWidth,
            progress,
          )!;
          final boundaryLeft = ui.lerpDouble(
            closedListWidth,
            openListWidth,
            progress,
          )!;
          final handleLeft = boundaryLeft - handleWidth / 2;
          final readerLeft = ui.lerpDouble(
            contentWidth,
            readerOpenLeft,
            progress,
          )!;
          final finalReaderWidth = math.max(0.0, contentWidth - readerOpenLeft);
          final revealWidth = math.max(0.0, contentWidth - readerLeft);
          const readerOpacity = 1.0;
          final readerInteractive = progress > 0.99 && _isOpen;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                key: const Key('article_reader_workspace_list_layer'),
                left: 0,
                top: 0,
                bottom: 0,
                width: listWidth,
                child: RepaintBoundary(child: widget.listPane),
              ),
              Positioned(
                key: const Key('article_reader_workspace_reader_layer'),
                left: readerLeft,
                top: 0,
                bottom: 0,
                width: revealWidth,
                child: IgnorePointer(
                  ignoring: !readerInteractive,
                  child: Opacity(
                    opacity: readerOpacity,
                    child: finalReaderWidth <= 0
                        ? const SizedBox.shrink()
                        : ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.centerRight,
                              minWidth: finalReaderWidth,
                              maxWidth: finalReaderWidth,
                              child: SizedBox(
                                width: finalReaderWidth,
                                child: readerPane,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              if (showHandle)
                Positioned(
                  key: const Key('article_reader_workspace_split_layer'),
                  left: handleLeft,
                  top: kWorkspaceHeaderHeight,
                  bottom: 0,
                  width: handleWidth,
                  child: IgnorePointer(
                    ignoring: !readerInteractive,
                    child: Opacity(
                      opacity: readerOpacity,
                      child: WorkspaceSplitHandle(
                        key: const Key('workspace_list_split_handle'),
                        onDragDelta: widget.onResizeList!,
                        showDivider: false,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
