part of '../reader_view.dart';

extension _ReaderViewportChunkCoordinator on _ReaderViewportCoordinator {
  static void registerCodeSearchAnchors(
    BuildContext context,
    List<ReaderCodeSearchRange> ranges,
  ) {
    final coordinator = context
        .findAncestorStateOfType<_ReaderViewState>()
        ?._viewportCoordinator;
    final key =
        context.widget.key ??
        context.findAncestorWidgetOfExactType<_ReaderCodeBlock>()?.key;
    if (coordinator == null || key is! GlobalKey) return;
    for (final range in ranges) {
      coordinator._codeSearchAnchorKeys[range.anchorId] = key;
    }
  }

  static void revealCodeSearchContext(BuildContext context) {
    final coordinator = context
        .findAncestorStateOfType<_ReaderViewState>()
        ?._viewportCoordinator;
    coordinator?._revealContextInReaderScroll(context, alignment: 0.1);
  }

  void _setChunkedLayout(bool isChunked) {
    if (_usingChunkedLayout == isChunked) return;
    _usingChunkedLayout = isChunked;
    _chunkKeys.clear();
    _chunkHtmlKeys.clear();
    _chunkHtmlSources.clear();
    _codeSearchAnchorKeys.clear();
    _fullHtmlSource = null;
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
    final chunks = _currentDocumentSnapshot?.chunks;
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
    final snapshot = _currentDocumentSnapshot;
    final handle = _currentDocumentHandle;
    final baseUrl = _currentImageBaseUrl;
    if (snapshot == null || handle == null || baseUrl == null) return;
    final chunks = snapshot.chunks;
    if (chunks.isEmpty) return;
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
        final html = handle.materializeRange(chunks[idx - 1]);
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
                final handle = _currentDocumentHandle;
                if (handle != null) {
                  controller.setDocumentHandle(handle);
                }
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
      if (await _scrollToCodeSearchAnchor(
        match.anchorId,
        requestId: requestId,
      )) {
        return;
      }
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

    if (await _scrollToCodeSearchAnchor(match.anchorId, requestId: requestId)) {
      return;
    }

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
      duration: AppMotion.effectiveDuration(
        context,
        AppMotion.navigationTransitionDuration,
      ),
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

  Future<bool> _scrollToCodeSearchAnchor(
    String anchorId, {
    required int requestId,
  }) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      if (!mounted) return false;
      if (requestId != _searchScrollRequestId) return false;
      final codeKey = _codeSearchAnchorKeys[anchorId];
      final codeContext = codeKey?.currentContext;
      if (codeContext != null && codeContext.mounted) {
        return _revealContextInReaderScroll(codeContext, alignment: 0.1);
      }
      await WidgetsBinding.instance.endOfFrame;
    }
    return false;
  }

  bool _revealContextInReaderScroll(
    BuildContext targetContext, {
    required double alignment,
  }) {
    if (!_scrollController.hasClients) return false;
    final targetBox = targetContext.findRenderObject() as RenderBox?;
    final scrollContext =
        _scrollController.position.context.notificationContext;
    final scrollBox = scrollContext?.findRenderObject() as RenderBox?;
    if (targetBox == null ||
        scrollBox == null ||
        !targetBox.hasSize ||
        !scrollBox.hasSize) {
      return false;
    }
    final targetTop = targetBox.localToGlobal(Offset.zero).dy;
    final viewportTop = scrollBox.localToGlobal(Offset.zero).dy;
    final viewportOffset = scrollBox.size.height * alignment;
    final delta = targetTop - viewportTop - viewportOffset;
    final position = _scrollController.position;
    final next = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((next - position.pixels).abs() < 0.5) return true;
    if (AppMotion.reduceMotion(context)) {
      _scrollController.jumpTo(next);
      return true;
    }
    unawaited(
      _scrollController.animateTo(
        next,
        duration: AppMotion.navigationTransitionDuration,
        curve: Curves.easeOut,
      ),
    );
    return true;
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

    final chunks = _currentDocumentSnapshot?.chunks;
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
          duration: AppMotion.effectiveDuration(
            context,
            const Duration(milliseconds: 200),
          ),
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
    ReaderDocumentHandle documentHandle,
    ReaderDocumentSnapshot snapshot,
    List<String>? highlightedChunks,
    Article article,
    ReaderSettings settings,
    ThemeData sceneTheme,
    Widget inlineHeader,
    String? currentAnchorId,
  ) {
    final cacheManager = ref.read(cacheManagerProvider);
    _currentDocumentHandle = documentHandle;
    _currentDocumentSnapshot = snapshot;
    _currentImageBaseUrl = Uri.tryParse(article.link);
    final theme = sceneTheme;
    final states = theme.fleurState;
    final reader = theme.fleurReader;
    final contentHorizontalPadding = math.max(
      settings.horizontalPadding,
      reader.contentPaddingHorizontal,
    );
    _codeSearchAnchorKeys.clear();

    String rgba(Color color, {double alpha = 1}) {
      final a = (color.a * alpha).clamp(0.0, 1.0);
      final r = (color.r * 255.0).round().clamp(0, 255);
      final g = (color.g * 255.0).round().clamp(0, 255);
      final b = (color.b * 255.0).round().clamp(0, 255);
      return 'rgba($r,$g,$b,${a.toStringAsFixed(3)})';
    }

    String cssColor(Color color) => rgba(color);
    String cssFontFamily(TextStyle style) {
      final fonts = <String>[?style.fontFamily, ...?style.fontFamilyFallback];
      if (fonts.isEmpty) return 'monospace';
      return fonts
          .map((font) => font.contains(' ') ? '"$font"' : font)
          .join(', ');
    }

    final codeStyle = reader.codeStyle;
    final codeCssFontFamily = cssFontFamily(codeStyle);
    final codeCssFontSize = codeStyle.fontSize ?? settings.fontSize - 1;
    final codeCssLineHeight =
        codeStyle.height ?? ReaderSettings.defaultCodeLineHeight;

    bool isInsideTableCell(dom.Element element) {
      dom.Element? current = element.parent;
      while (current != null) {
        final localName = current.localName;
        if (localName == 'td' || localName == 'th') return true;
        current = current.parent;
      }
      return false;
    }

    Map<String, String>? customStyles(dom.Element element) {
      final localName = element.localName;
      // Search highlight styles
      if (localName == 'mark') {
        if (element.attributes[ReaderSearchService.markerAttribute] ==
            ReaderSearchService.markerAttributeValue) {
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
      }

      // Link underline: dashed so adjacent links are visually distinct
      if (localName == 'a') {
        return const <String, String>{'text-decoration-style': 'dashed'};
      }

      if (localName == 'blockquote') {
        return <String, String>{
          'background-color': rgba(reader.bannerSurface, alpha: 0.64),
          'border-left': '4px solid ${cssColor(reader.blockquoteAccent)}',
          'border-radius': '6px',
          'color': cssColor(theme.colorScheme.onSurfaceVariant),
          'font-style': 'italic',
          'margin': '18px 0',
          'padding': '12px 16px',
        };
      }

      if (localName == 'pre') {
        final insideTableCell = isInsideTableCell(element);
        return <String, String>{
          'background-color': cssColor(reader.codeBlockSurface),
          if (!insideTableCell)
            'border': '1px solid ${rgba(theme.fleurSurface.subtleDivider)}',
          'border-radius': '6px',
          'font-family': codeCssFontFamily,
          'font-size': '${codeCssFontSize.toStringAsFixed(0)}px',
          'font-style': 'normal',
          'font-weight': '400',
          'line-height': codeCssLineHeight.toStringAsFixed(2),
          'margin': insideTableCell ? '0' : '18px 0',
          'padding': insideTableCell ? '8px' : '14px 16px',
          'text-decoration': 'none',
          'white-space': reader.codeSoftWrap ? 'pre-wrap' : 'pre',
        };
      }

      if (localName == 'code') {
        return <String, String>{
          'background-color': cssColor(reader.codeBlockSurface),
          'border-radius': '4px',
          'font-family': codeCssFontFamily,
          'font-size': '${codeCssFontSize.toStringAsFixed(0)}px',
          'font-style': 'normal',
          'font-weight': '400',
          'line-height': codeCssLineHeight.toStringAsFixed(2),
          'padding': '1px 4px',
          'text-decoration': 'none',
        };
      }

      if (localName == 'table') {
        return <String, String>{
          'border': '1px solid ${rgba(theme.fleurSurface.subtleDivider)}',
          'border-collapse': 'collapse',
          'margin': '18px 0',
        };
      }

      if (localName == 'th') {
        return <String, String>{
          'background-color': rgba(reader.bannerSurface, alpha: 0.72),
          'border': '1px solid ${rgba(theme.fleurSurface.subtleDivider)}',
          'padding': '8px 10px',
          'text-align': 'left',
        };
      }

      if (localName == 'td') {
        return <String, String>{
          'border': '1px solid ${rgba(theme.fleurSurface.subtleDivider)}',
          'padding': '8px 10px',
        };
      }

      if (localName == 'caption') {
        return <String, String>{
          'caption-side': 'top',
          'color': cssColor(theme.colorScheme.onSurfaceVariant),
          'font-style': 'italic',
          'padding': '8px 10px',
          'text-align': 'left',
        };
      }

      if (localName == 'tfoot') {
        return <String, String>{
          'background-color': rgba(reader.bannerSurface, alpha: 0.44),
        };
      }

      if (localName == 'ul' || localName == 'ol') {
        return const <String, String>{
          'margin': '10px 0 14px 0',
          'padding-left': '24px',
        };
      }

      if (localName == 'li') {
        return const <String, String>{'margin': '4px 0'};
      }

      return null;
    }

    Widget? customWidgets(dom.Element element) {
      final localName = element.localName;
      if (localName == 'fleur-math') {
        final expression = element.attributes['data-fleur-math']?.trim();
        if (expression == null || expression.isEmpty) return null;
        final display =
            element.attributes['data-fleur-math-display'] == 'block';
        final math = _ReaderMathNode(expression: expression, display: display);
        return display ? math : InlineCustomWidget(child: math);
      }

      if (localName == 'pre') {
        // HTML tables measure cell children with an unbounded width. Keep
        // table-contained code in the native renderer so it can participate
        // in intrinsic sizing instead of mounting the full-width code chrome.
        if (isInsideTableCell(element)) return null;

        final codeElement = element.querySelector('code');
        final source = codeElement ?? element;
        final extraction = const ReaderCodeHtmlRenderer().extract(source);
        if (extraction.text.trim().isEmpty) return null;
        final key = GlobalKey();
        return _ReaderCodeBlock(
          key: key,
          source: source,
          pre: element,
          fontSize: settings.fontSize,
          currentAnchorId: currentAnchorId,
        );
      }

      if (localName == 'button') {
        return InlineCustomWidget(child: _ReaderInertButton(element: element));
      }

      if (localName == 'input') {
        return InlineCustomWidget(child: _ReaderInertInput(element: element));
      }

      if (localName == 'iframe' ||
          localName == 'video' ||
          localName == 'audio') {
        final src = _mediaSourceForElement(element);
        final resolved = src == null
            ? ''
            : Uri.tryParse(article.link)?.resolve(src).toString() ?? src;
        return _MediaEmbedCard(
          kind: switch (localName) {
            'iframe' => 'Embedded',
            'video' => 'Video',
            'audio' => 'Audio',
            _ => 'Embedded',
          },
          url: resolved,
          onOpen: () {
            if (resolved.isNotEmpty) {
              unawaited(_onTapUrl(resolved));
            }
          },
        );
      }

      return null;
    }

    if (!snapshot.isChunked) {
      final highlightedHtml = highlightedChunks;
      final html = highlightedHtml == null || highlightedHtml.isEmpty
          ? snapshot.displayHtml
          : highlightedHtml.first;
      if (_fullHtmlSource != html) {
        _fullHtmlSource = html;
        _fullHtmlKey = GlobalKey<HtmlWidgetState>();
      }
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
                            factoryBuilder: () => ReaderWidgetFactory(
                              cacheManager,
                              settings: settings,
                              hoveredUrl: _interactionController.hoveredUrl,
                              recognizerUrlMap:
                                  _interactionController.recognizerUrlMap,
                            ),
                            renderMode: RenderMode.column,
                            buildAsync: true,
                            onLoadingBuilder: _buildImageLoadingPlaceholder,
                            onErrorBuilder: _buildImageErrorPlaceholder,
                            customStylesBuilder: customStyles,
                            customWidgetBuilder: customWidgets,
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

    final highlightedHtml = highlightedChunks;
    final chunkCount = highlightedHtml?.length ?? snapshot.chunks.length;
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
                  itemCount: chunkCount + 1,
                  itemBuilder: (context, index) {
                    final key = _chunkKeys.putIfAbsent(
                      index,
                      () => GlobalKey(),
                    );
                    if (index == 0) {
                      return KeyedSubtree(key: key, child: inlineHeader);
                    }
                    final chunkHtml = highlightedHtml == null
                        ? documentHandle.materializeRange(
                            snapshot.chunks[index - 1],
                          )
                        : highlightedHtml[index - 1];
                    if (_chunkHtmlSources[index] != chunkHtml) {
                      _chunkHtmlSources[index] = chunkHtml;
                      _chunkHtmlKeys[index] = GlobalKey<HtmlWidgetState>();
                    }
                    final htmlKey = _chunkHtmlKeys[index]!;
                    return KeyedSubtree(
                      key: key,
                      child: HtmlWidget(
                        chunkHtml,
                        key: htmlKey,
                        baseUrl: Uri.tryParse(article.link),
                        factoryBuilder: () => ReaderWidgetFactory(
                          cacheManager,
                          settings: settings,
                          hoveredUrl: _interactionController.hoveredUrl,
                          recognizerUrlMap:
                              _interactionController.recognizerUrlMap,
                        ),
                        renderMode: RenderMode.column,
                        buildAsync: true,
                        onLoadingBuilder: _buildImageLoadingPlaceholder,
                        onErrorBuilder: _buildImageErrorPlaceholder,
                        customStylesBuilder: customStyles,
                        customWidgetBuilder: customWidgets,
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
