part of '../../widgets/reader_view.dart';

extension _ReaderViewportChunkCoordinator on _ReaderViewportCoordinator {
  void _setChunkedLayout(bool isChunked) {
    if (_usingChunkedLayout == isChunked) return;
    _usingChunkedLayout = isChunked;
    _chunkKeys.clear();
    _chunkHtmlKeys.clear();
    _pendingAnchor = null;
    _resizeRestoreAttempts = 0;
    _resizeTimer?.cancel();
    _resizeTimer = null;
    _lastViewportSize = null;
    _lastViewportSettings = null;
    _isResizing = false;
    _prefetchedChunks.clear();
    _prefetchTimer?.cancel();
    _prefetchTimer = null;
    _currentChunks = null;
    _lastAnchor = null;
  }

  void _handleViewportSizeChange(
    Size size, {
    required bool isChunked,
    required ReaderSettings settings,
  }) {
    if (!isChunked) {
      _setChunkedLayout(false);
      _lastViewportSize = size;
      _lastViewportSettings = settings;
      return;
    }

    _setChunkedLayout(true);
    final last = _lastViewportSize;
    final lastSettings = _lastViewportSettings;
    _lastViewportSize = size;
    _lastViewportSettings = settings;
    if (last == null || lastSettings == null) return;
    final settingsChanged =
        (settings.fontSize - lastSettings.fontSize).abs() >= 0.01 ||
        (settings.lineHeight - lastSettings.lineHeight).abs() >= 0.01 ||
        (settings.horizontalPadding - lastSettings.horizontalPadding).abs() >=
            0.01;
    if ((size.width - last.width).abs() < 1 &&
        (size.height - last.height).abs() < 1 &&
        !settingsChanged) {
      return;
    }
    _startResizeSession();
  }

  void _startResizeSession() {
    if (!_isResizing) {
      _isResizing = true;
      _captureChunkAnchor();
    }
    _resizeTimer?.cancel();
    _resizeTimer = Timer(const Duration(milliseconds: 240), () {
      _isResizing = false;
      _restoreChunkAnchor();
    });
  }

  void _captureChunkAnchor() {
    final anchor = _findChunkAnchor();
    if (anchor == null) return;
    _pendingAnchor = anchor;
    _lastAnchor = anchor;
  }

  _ChunkAnchor? _findChunkAnchor() {
    if (!_scrollController.hasClients) return null;
    final listBox =
        _listViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (listBox == null || !listBox.hasSize) return null;
    final viewportCenterY =
        listBox.localToGlobal(Offset.zero).dy + listBox.size.height / 2;

    double bestDistance = double.infinity;
    int? bestIndex;
    double bestTop = 0;
    double bestHeight = 0;

    for (final entry in _chunkKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      final center = top + box.size.height / 2;
      final distance = (center - viewportCenterY).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = entry.key;
        bestTop = top;
        bestHeight = box.size.height;
      }
    }

    if (bestIndex == null || bestHeight <= 0) return null;
    final fraction = ((viewportCenterY - bestTop) / bestHeight)
        .clamp(0.0, 1.0)
        .toDouble();
    return _ChunkAnchor(index: bestIndex, fraction: fraction);
  }

  void _restoreChunkAnchor() {
    if (!_scrollController.hasClients) return;
    final anchor = _pendingAnchor;
    if (anchor == null) return;

    final listBox =
        _listViewKey.currentContext?.findRenderObject() as RenderBox?;
    final itemBox =
        _chunkKeys[anchor.index]?.currentContext?.findRenderObject()
            as RenderBox?;
    if (listBox == null ||
        itemBox == null ||
        !listBox.hasSize ||
        !itemBox.hasSize) {
      if (_resizeRestoreAttempts < 4) {
        _resizeRestoreAttempts++;
        _resizeTimer?.cancel();
        _resizeTimer = Timer(const Duration(milliseconds: 120), () {
          _restoreChunkAnchor();
        });
      }
      return;
    }

    final viewportCenterY =
        listBox.localToGlobal(Offset.zero).dy + listBox.size.height / 2;
    final itemTop = itemBox.localToGlobal(Offset.zero).dy;
    final itemHeight = itemBox.size.height;
    final targetY = itemTop + itemHeight * anchor.fraction;
    final delta = targetY - viewportCenterY;
    if (delta.abs() < 0.5) return;
    final position = _scrollController.position;
    final next = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((next - position.pixels).abs() < 0.5) return;
    _isRestoring = true;
    _scrollController.jumpTo(next);
    _isRestoring = false;
  }

  bool _canRestoreProgressAnchor(ReaderProgress progress) {
    return _usingChunkedLayout &&
        progress.anchorIndex != null &&
        progress.anchorFraction != null;
  }

  bool _restoreProgressAnchor(ReaderProgress progress) {
    final anchorIndex = progress.anchorIndex;
    final anchorFraction = progress.anchorFraction;
    if (anchorIndex == null || anchorFraction == null) return false;
    if (!_scrollController.hasClients) return false;

    final listBox =
        _listViewKey.currentContext?.findRenderObject() as RenderBox?;
    final itemBox =
        _chunkKeys[anchorIndex]?.currentContext?.findRenderObject()
            as RenderBox?;
    if (listBox == null ||
        itemBox == null ||
        !listBox.hasSize ||
        !itemBox.hasSize) {
      return false;
    }

    final viewportCenterY =
        listBox.localToGlobal(Offset.zero).dy + listBox.size.height / 2;
    final itemTop = itemBox.localToGlobal(Offset.zero).dy;
    final targetY = itemTop + itemBox.size.height * anchorFraction;
    final delta = targetY - viewportCenterY;
    final position = _scrollController.position;
    final next = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((next - position.pixels).abs() > 0.5) {
      _isRestoring = true;
      _scrollController.jumpTo(next);
      _isRestoring = false;
    }
    _lastAnchor = _ChunkAnchor(index: anchorIndex, fraction: anchorFraction);
    return true;
  }

  void _jumpNearProgressAnchor(ReaderProgress progress) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final chunks = _currentChunks;
    double target = progress.pixels;
    if (chunks != null && chunks.isNotEmpty && progress.anchorIndex != null) {
      final totalItems = chunks.length + 1;
      final denominator = totalItems <= 1 ? 1 : totalItems - 1;
      final fraction = (progress.anchorIndex! / denominator).clamp(0.0, 1.0);
      final estimated =
          position.minScrollExtent +
          (position.maxScrollExtent - position.minScrollExtent) * fraction;
      if (target < position.minScrollExtent ||
          target > position.maxScrollExtent) {
        target = estimated;
      }
    }
    final next = target
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((next - position.pixels).abs() <= 1) return;
    _isRestoring = true;
    _scrollController.jumpTo(next);
    _isRestoring = false;
  }

  void _maybePrefetchNextChunks() {
    if (!_usingChunkedLayout) return;
    final chunks = _currentChunks;
    final baseUrl = _currentImageBaseUrl;
    if (chunks == null || baseUrl == null) return;
    if (_prefetchTimer != null) return;
    _prefetchTimer = Timer(const Duration(milliseconds: 220), () async {
      _prefetchTimer = null;
      final anchor = _findChunkAnchor() ?? _lastAnchor;
      if (anchor == null) return;
      _lastAnchor = anchor;
      final targets = <int>[anchor.index + 1, anchor.index + 2];
      final toPrefetch = <int>[];
      for (final idx in targets) {
        if (idx <= 0 || idx >= chunks.length + 1) continue;
        if (_prefetchedChunks.contains(idx)) continue;
        toPrefetch.add(idx);
      }
      if (toPrefetch.isEmpty) return;
      final cache = ref.read(articleCacheServiceProvider);
      for (final idx in toPrefetch) {
        _prefetchedChunks.add(idx);
        final html = chunks[idx - 1];
        unawaited(
          cache.prefetchImagesFromHtml(
            html,
            baseUrl: baseUrl,
            maxImages: 8,
            maxConcurrent: 2,
          ),
        );
      }
    });
  }

  Widget _wrapSearchShortcuts({required Widget child}) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF):
            const _ToggleReaderSearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyF):
            const _ToggleReaderSearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape):
            const _CloseReaderSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ToggleReaderSearchIntent: CallbackAction<_ToggleReaderSearchIntent>(
            onInvoke: (_) {
              final controller = ref.read(
                readerSearchControllerProvider(widget.articleId).notifier,
              );
              final isVisible = ref
                  .read(readerSearchControllerProvider(widget.articleId))
                  .visible;
              if (!isVisible) {
                _syncSearchDocumentHtml(widget.articleId);
                controller.open();
                return null;
              }

              _searchBarKey.currentState?.focusAndSelectAll();
              return null;
            },
          ),
          _CloseReaderSearchIntent: CallbackAction<_CloseReaderSearchIntent>(
            onInvoke: (_) {
              ref
                  .read(
                    readerSearchControllerProvider(widget.articleId).notifier,
                  )
                  .close(clearQuery: true);
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }

  void _scheduleScrollToSearchMatch(ReaderSearchMatch match) {
    final requestId = ++_searchScrollRequestId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_scrollToSearchMatch(match, requestId: requestId));
    });
  }

  Future<void> _scrollToSearchMatch(
    ReaderSearchMatch match, {
    required int requestId,
  }) async {
    if (!mounted) return;
    if (requestId != _searchScrollRequestId) return;
    if (!_scrollController.hasClients) return;

    if (!_usingChunkedLayout) {
      final htmlState = _fullHtmlKey.currentState;
      if (htmlState != null) {
        unawaited(htmlState.scrollToAnchor(match.anchorId));
      }
      return;
    }

    final targetIndex = match.chunkIndex + 1;
    await _seekToChunkIndex(targetIndex, requestId: requestId);
    if (!mounted) return;
    if (requestId != _searchScrollRequestId) return;

    final state = _chunkHtmlKeys[targetIndex]?.currentState;
    if (state != null) {
      unawaited(state.scrollToAnchor(match.anchorId));
      return;
    }

    final ctx = _chunkKeys[targetIndex]?.currentContext;
    if (ctx == null) return;
    if (!ctx.mounted) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: 0.1,
    );
    if (!mounted) return;
    if (requestId != _searchScrollRequestId) return;
    await WidgetsBinding.instance.endOfFrame;
    final htmlState = _chunkHtmlKeys[targetIndex]?.currentState;
    if (htmlState != null) {
      unawaited(htmlState.scrollToAnchor(match.anchorId));
    }
  }

  double _estimateAverageChunkHeight() {
    double sum = 0;
    int count = 0;
    for (final entry in _chunkKeys.entries) {
      if (entry.key == 0) continue;
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      sum += box.size.height;
      count++;
    }
    if (count == 0) return 800;
    return sum / count;
  }

  Future<void> _seekToChunkIndex(
    int targetIndex, {
    required int requestId,
  }) async {
    if (!_scrollController.hasClients) return;
    if (requestId != _searchScrollRequestId) return;

    final chunks = _currentChunks;
    if (chunks == null || chunks.isEmpty) return;
    final totalItems = chunks.length + 1;
    if (targetIndex < 0 || targetIndex >= totalItems) return;

    for (int attempt = 0; attempt < 10; attempt++) {
      if (!mounted) return;
      if (requestId != _searchScrollRequestId) return;

      final ctx = _chunkKeys[targetIndex]?.currentContext;
      if (ctx != null) {
        if (!ctx.mounted) return;
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: 0.1,
        );
        return;
      }

      final position = _scrollController.position;
      final anchor = _findChunkAnchor();
      final diff = anchor == null ? null : (targetIndex - anchor.index);

      double nextOffset;
      if (diff == null) {
        final frac = (targetIndex / (totalItems - 1)).clamp(0.0, 1.0);
        nextOffset =
            position.minScrollExtent +
            (position.maxScrollExtent - position.minScrollExtent) * frac;
      } else {
        final avg = _estimateAverageChunkHeight();
        nextOffset = position.pixels + diff * avg;
      }

      nextOffset = nextOffset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((nextOffset - position.pixels).abs() < 1) {
        final direction = (diff ?? 0).sign;
        if (direction == 0) return;
        nextOffset = (position.pixels + direction * position.viewportDimension)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
      }

      _scrollController.jumpTo(nextOffset);
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Widget _buildContentWidget(
    BuildContext context,
    List<String> chunks,
    bool isChunked,
    Article article,
    ReaderSettings settings,
    Widget inlineHeader,
    String? currentAnchorId,
  ) {
    final cacheManager = ref.read(cacheManagerProvider);
    _currentImageBaseUrl = Uri.tryParse(article.link);
    final theme = Theme.of(context);
    final states = theme.fleurState;
    final reader = theme.fleurReader;
    final contentHorizontalPadding = math.max(
      settings.horizontalPadding,
      reader.contentPaddingHorizontal,
    );

    String rgba(Color color, {double alpha = 1}) {
      final a = (color.a * alpha).clamp(0.0, 1.0);
      final r = (color.r * 255.0).round().clamp(0, 255);
      final g = (color.g * 255.0).round().clamp(0, 255);
      final b = (color.b * 255.0).round().clamp(0, 255);
      return 'rgba($r,$g,$b,${a.toStringAsFixed(3)})';
    }

    Map<String, String>? searchStyles(dom.Element element) {
      if (element.localName != 'mark') return null;
      if (element.attributes[ReaderSearchService.markerAttribute] !=
          ReaderSearchService.markerAttributeValue) {
        return null;
      }

      final isCurrent =
          currentAnchorId != null && element.id == currentAnchorId;
      final bg = isCurrent
          ? rgba(states.selectionTint, alpha: 0.95)
          : rgba(reader.bannerSurface, alpha: 0.8);
      return <String, String>{
        'background-color': bg,
        'padding': '0 2px',
        'border-radius': '2px',
      };
    }

    if (!isChunked) {
      final html = chunks.isEmpty ? '' : chunks.first;
      _currentChunks = null;
      return SelectionArea(
        key: _selectionAreaKey,
        onSelectionChanged: _handleSelectionChanged,
        contextMenuBuilder: _buildContextMenu,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final readingWidth = _resolveReadingWidth(
              constraints,
              reader.maxWidth,
            );
            return _wrapScrollable(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: readingWidth,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        contentHorizontalPadding,
                        reader.contentPaddingTop,
                        contentHorizontalPadding,
                        reader.contentPaddingBottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          inlineHeader,
                          HtmlWidget(
                            html,
                            key: _fullHtmlKey,
                            baseUrl: Uri.tryParse(article.link),
                            factoryBuilder: () =>
                                _ReaderWidgetFactory(cacheManager),
                            renderMode: RenderMode.column,
                            buildAsync: true,
                            onLoadingBuilder: _buildImageLoadingPlaceholder,
                            customStylesBuilder: searchStyles,
                            textStyle: reader.bodyStyle.copyWith(
                              fontSize: settings.fontSize,
                              height: settings.lineHeight,
                            ),
                            onTapUrl: _onTapUrl,
                            onTapImage: _onTapImage,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    _currentChunks = chunks;
    return SelectionArea(
      key: _selectionAreaKey,
      onSelectionChanged: _handleSelectionChanged,
      contextMenuBuilder: _buildContextMenu,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final readingWidth = _resolveReadingWidth(
            constraints,
            reader.maxWidth,
          );
          return Center(
            child: SizedBox(
              width: readingWidth,
              child: _wrapScrollable(
                child: ListView.builder(
                  key: _listViewKey,
                  controller: _scrollController,
                  cacheExtent: 1200,
                  padding: EdgeInsets.fromLTRB(
                    contentHorizontalPadding,
                    reader.contentPaddingTop,
                    contentHorizontalPadding,
                    reader.contentPaddingBottom,
                  ),
                  itemCount: chunks.length + 1,
                  itemBuilder: (context, index) {
                    final key = _chunkKeys.putIfAbsent(
                      index,
                      () => GlobalKey(),
                    );
                    if (index == 0) {
                      return KeyedSubtree(key: key, child: inlineHeader);
                    }
                    final htmlKey = _chunkHtmlKeys.putIfAbsent(
                      index,
                      () => GlobalKey<HtmlWidgetState>(),
                    );
                    return KeyedSubtree(
                      key: key,
                      child: HtmlWidget(
                        chunks[index - 1],
                        key: htmlKey,
                        baseUrl: Uri.tryParse(article.link),
                        factoryBuilder: () =>
                            _ReaderWidgetFactory(cacheManager),
                        renderMode: RenderMode.column,
                        buildAsync: true,
                        onLoadingBuilder: _buildImageLoadingPlaceholder,
                        customStylesBuilder: searchStyles,
                        textStyle: reader.bodyStyle.copyWith(
                          fontSize: settings.fontSize,
                          height: settings.lineHeight,
                        ),
                        onTapUrl: _onTapUrl,
                        onTapImage: _onTapImage,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _resolveReadingWidth(BoxConstraints constraints, double maxWidth) {
    if (!constraints.hasBoundedWidth || !constraints.maxWidth.isFinite) {
      return maxWidth;
    }
    return math.min(constraints.maxWidth, maxWidth);
  }

  Widget _wrapScrollable({required Widget child}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) {
        if (!isDesktop) return;
        _suppressContextMenuOnce();
        _showFullContextMenu(details.globalPosition);
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerHover: _handlePointerHover,
        onPointerCancel: _handlePointerCancel,
        onPointerSignal: _handlePointerSignal,
        child: AppScrollbar(
          controller: _scrollController,
          thumbVisibility: isDesktop,
          interactive: true,
          child: child,
        ),
      ),
    );
  }
}
