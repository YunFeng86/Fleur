part of '../reader_view.dart';

enum _ReaderSettingsLineHeightPreset { compact, standard, relaxed }

final class _ReaderInteractionController {
  _ReaderInteractionController({
    required _ReaderViewState owner,
    required ImageMetaStore imageMetaStore,
  }) : _owner = owner,
       _imageMetaStore = imageMetaStore;

  final _ReaderViewState _owner;
  final ImageMetaStore _imageMetaStore;

  final GlobalKey<SelectionAreaState> selectionAreaKey =
      GlobalKey<SelectionAreaState>();
  final ContextMenuController _contextMenuController = ContextMenuController();
  final ContextMenuController _quickMenuController = ContextMenuController();

  /// Currently hovered link URL (null when not hovering a link).
  final ValueNotifier<String?> hoveredUrl = ValueNotifier<String?>(null);

  /// Map from recognizer identity to href, populated by the WidgetFactory.
  final Map<int, String> recognizerUrlMap = {};

  _ReaderViewportCoordinator? _viewport;
  Timer? _quickMenuTimer;
  String _pendingQuickMenuText = '';
  OverlayEntry? _autoScrollOverlay;
  Timer? _autoScrollTimer;
  Timer? _hoverResumeTimer;
  Offset? _autoScrollAnchor;
  Offset? _autoScrollPointer;
  bool _suppressNextContextMenu = false;
  bool _hoverSuspendedForScroll = false;

  BuildContext get context => _owner.context;
  WidgetRef get ref => _owner.ref;
  ReaderView get widget => _owner.widget;
  bool get mounted => _owner.mounted;
  ScrollController get _scrollController => _viewport!.scrollController;
  GlobalKey<SelectionAreaState> get _selectionAreaKey => selectionAreaKey;

  void attachViewport(_ReaderViewportCoordinator viewport) {
    _viewport = viewport;
  }

  void prime() {
    unawaited(_imageMetaStore.getMany(const []));
  }

  void dispose() {
    _quickMenuTimer?.cancel();
    _hoverResumeTimer?.cancel();
    ContextMenuController.removeAny();
    _autoScrollTimer?.cancel();
    _autoScrollOverlay?.remove();
    _autoScrollOverlay = null;
    hoveredUrl.dispose();
  }

  void suspendHoverForScroll() {
    if (!isDesktop) return;
    if (!_hoverSuspendedForScroll) {
      _hoverSuspendedForScroll = true;
      hoveredUrl.value = null;
    }
    _hoverResumeTimer?.cancel();
    _hoverResumeTimer = Timer(const Duration(milliseconds: 180), () {
      _hoverSuspendedForScroll = false;
    });
  }

  String? _resolveImageUrl(String? raw) {
    return _viewport?._resolveImageUrl(raw);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!isDesktop || event.kind != PointerDeviceKind.mouse) return;
    if ((event.buttons & kSecondaryMouseButton) != 0) {
      _suppressContextMenuOnce();
      _showFullContextMenu(event.position);
      return;
    }
    if ((event.buttons & kMiddleMouseButton) != 0) {
      if (_autoScrollTimer == null) {
        _startAutoScroll(event.position);
      } else {
        _stopAutoScroll();
      }
      return;
    }
    if (_autoScrollTimer != null) {
      _stopAutoScroll();
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_autoScrollTimer == null) return;
    if (event.kind != PointerDeviceKind.mouse) return;
    _autoScrollPointer = event.position;
  }

  void _handlePointerHover(PointerHoverEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    _autoScrollPointer = event.position;
    if (_hoverSuspendedForScroll) return;
    _detectInlineLinkHover(event.position);
  }

  void _detectInlineLinkHover(Offset globalPosition) {
    if (!isDesktop) return;
    final selectionAreaKey = _selectionAreaKey;
    final selectionAreaContext = selectionAreaKey.currentContext;
    if (selectionAreaContext == null) {
      hoveredUrl.value = null;
      return;
    }
    final selectionArea = selectionAreaContext.findRenderObject();
    if (selectionArea is! RenderBox || !selectionArea.hasSize) {
      hoveredUrl.value = null;
      return;
    }
    final local = selectionArea.globalToLocal(globalPosition);
    if (!selectionArea.size.contains(local)) {
      hoveredUrl.value = null;
      return;
    }
    final hitResult = BoxHitTestResult();
    if (!selectionArea.hitTest(hitResult, position: local)) {
      hoveredUrl.value = null;
      return;
    }
    // Walk hit test results to find a RenderParagraph under the cursor.
    for (final entry in hitResult.path) {
      final target = entry.target;
      if (target is RenderParagraph) {
        final paragraphLocal = target.globalToLocal(globalPosition);
        if (!target.size.contains(paragraphLocal)) continue;
        final textPosition = target.getPositionForOffset(paragraphLocal);
        final url = _findLinkUrlInSpan(target.text, textPosition);
        if (url != null) {
          hoveredUrl.value = url;
          return;
        }
      }
    }
    // No link found under cursor — only clear if the current value wasn't set
    // by buildGestureDetector (block-level links manage their own state).
    hoveredUrl.value = null;
  }

  /// Walk the [InlineSpan] tree to find a link recognizer at [position].
  String? _findLinkUrlInSpan(InlineSpan span, TextPosition position) {
    final hitSpan = span.getSpanForPosition(position);
    if (hitSpan is! TextSpan) return null;

    final recognizer = hitSpan.recognizer;
    if (recognizer == null) return null;
    return recognizerUrlMap[identityHashCode(recognizer)];
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_autoScrollTimer == null) return;
    _stopAutoScroll();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (_autoScrollTimer == null) return;
    if (event is PointerScrollEvent) {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll(Offset position) {
    if (!_scrollController.hasClients) return;
    _autoScrollAnchor = position;
    _autoScrollPointer = position;
    _autoScrollTimer?.cancel();
    _showAutoScrollIndicator(position);
    _autoScrollTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _autoScrollTick(),
    );
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollAnchor = null;
    _autoScrollPointer = null;
    _autoScrollOverlay?.remove();
    _autoScrollOverlay = null;
  }

  void _autoScrollTick() {
    if (!_scrollController.hasClients) return;
    final anchor = _autoScrollAnchor;
    final pointer = _autoScrollPointer;
    if (anchor == null || pointer == null) return;
    final delta = pointer.dy - anchor.dy;
    if (delta.abs() < _ReaderViewState._autoScrollDeadZone) return;
    final position = _scrollController.position;
    final next =
        (position.pixels + delta * _ReaderViewState._autoScrollSpeedFactor)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (next != position.pixels) {
      _scrollController.jumpTo(next);
    }
  }

  void _showAutoScrollIndicator(Offset position) {
    _autoScrollOverlay?.remove();
    _autoScrollOverlay = null;
    if (!mounted) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject();
    if (overlayBox is! RenderBox) return;
    final local = overlayBox.globalToLocal(position);
    final theme = AppTheme.readerScene(Theme.of(context));
    final surfaces = theme.fleurSurface;
    _autoScrollOverlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: local.dx - 14,
          top: local.dy - 14,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: surfaces.floating,
                  border: Border.all(color: surfaces.subtleDivider, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    FleurIcons.autoScroll,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_autoScrollOverlay!);
  }

  // ignore: deprecated_member_use
  String? _getSelectedText(SelectableRegionState selectableRegionState) {
    // ignore: deprecated_member_use
    final value = selectableRegionState.textEditingValue;
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) return null;
    if (selection.start < 0 || selection.end < 0) return null;
    if (selection.start >= selection.end) return null;
    if (selection.end > value.text.length) return null;
    final selected = value.text
        .substring(selection.start, selection.end)
        .trim();
    return selected.isEmpty ? null : selected;
  }

  Future<void> _searchSelectedText(String text) async {
    final query = Uri.encodeQueryComponent(text);
    final uri = Uri.parse('https://duckduckgo.com/?q=$query');
    // Capture the message and owner before awaiting: the quick menu closes
    // right after this call and the reader state may be disposed.
    final owner = _owner;
    final message = AppLocalizations.of(owner.context)!.openFailedGeneral;
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, s) {
      AppLogger.w(
        'Search selected text failed',
        tag: 'reader',
        error: e,
        stackTrace: s,
      );
    }
    if (!opened && owner.mounted) {
      owner.context.showErrorMessage(message);
    }
  }

  void _handleSelectionChanged(SelectedContent? selection) {
    if (!isDesktop) return;
    _quickMenuTimer?.cancel();
    final text = selection?.plainText.trim() ?? '';
    _pendingQuickMenuText = text;
    if (text.isEmpty) {
      ContextMenuController.removeAny();
      return;
    }
    _quickMenuTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      if (_pendingQuickMenuText != text) return;
      _showQuickMenu(text);
    });
  }

  void _suppressContextMenuOnce() {
    _suppressNextContextMenu = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _suppressNextContextMenu = false;
    });
  }

  List<ContextMenuButtonItem> _buildContextMenuItems(
    SelectableRegionState selectableRegionState,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final buttonItems = List<ContextMenuButtonItem>.of(
      selectableRegionState.contextMenuButtonItems,
    );
    final selectedText = _getSelectedText(selectableRegionState);
    if (selectedText != null) {
      buttonItems.insert(
        0,
        ContextMenuButtonItem(
          label: l10n.search,
          onPressed: () {
            selectableRegionState.hideToolbar();
            unawaited(_searchSelectedText(selectedText));
          },
          type: ContextMenuButtonType.custom,
        ),
      );
    }
    final hasSelectAll = buttonItems.any(
      (item) => item.type == ContextMenuButtonType.selectAll,
    );
    if (!hasSelectAll) {
      buttonItems.add(
        ContextMenuButtonItem(
          onPressed: () =>
              selectableRegionState.selectAll(SelectionChangedCause.toolbar),
          type: ContextMenuButtonType.selectAll,
        ),
      );
    }
    return buttonItems;
  }

  void _showFullContextMenu(Offset globalPosition) {
    final selectionArea = _selectionAreaKey.currentState;
    final selectableRegion = selectionArea?.selectableRegion;
    if (selectableRegion == null) return;
    _showFullContextMenuWithAnchors(
      selectableRegion,
      TextSelectionToolbarAnchors(primaryAnchor: globalPosition),
    );
  }

  void _showFullContextMenuWithAnchors(
    SelectableRegionState selectableRegionState,
    TextSelectionToolbarAnchors anchors,
  ) {
    final items = _buildContextMenuItems(selectableRegionState);
    if (items.isEmpty) return;
    _quickMenuController.remove();
    _contextMenuController.remove();
    _contextMenuController.show(
      context: context,
      contextMenuBuilder: (overlayContext) {
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: anchors,
          buttonItems: items,
        );
      },
      debugRequiredFor: widget,
    );
  }

  void _showQuickMenu(String text) {
    final selectionArea = _selectionAreaKey.currentState;
    final selectableRegion = selectionArea?.selectableRegion;
    if (selectableRegion == null) return;
    final anchors = selectableRegion.contextMenuAnchors;
    final items = selectableRegion.contextMenuButtonItems;
    final l10n = AppLocalizations.of(context)!;
    final copyItem = items.cast<ContextMenuButtonItem?>().firstWhere(
      (item) => item?.type == ContextMenuButtonType.copy,
      orElse: () => null,
    );
    final actions = <_QuickAction>[];
    if (copyItem != null) {
      actions.add(
        _QuickAction(
          icon: FleurIcons.copy,
          label: AdaptiveTextSelectionToolbar.getButtonLabel(context, copyItem),
          onPressed: () {
            copyItem.onPressed?.call();
            ContextMenuController.removeAny();
          },
        ),
      );
    }
    actions.add(
      _QuickAction(
        icon: FleurIcons.search,
        label: l10n.search,
        onPressed: () {
          unawaited(_searchSelectedText(text));
          ContextMenuController.removeAny();
        },
      ),
    );
    actions.add(
      _QuickAction(
        icon: FleurIcons.previousMatch,
        label: l10n.more,
        onPressed: () {
          _suppressContextMenuOnce();
          _showFullContextMenuWithAnchors(selectableRegion, anchors);
        },
      ),
    );
    if (actions.isEmpty) return;
    _quickMenuController.show(
      context: context,
      contextMenuBuilder: (overlayContext) {
        return _buildQuickActionMenu(overlayContext, anchors, actions);
      },
      debugRequiredFor: widget,
    );
  }

  Widget _buildContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    if (isDesktop && _suppressNextContextMenu) {
      return const SizedBox.shrink();
    }
    _quickMenuController.remove();
    _contextMenuController.remove();
    final buttonItems = _buildContextMenuItems(selectableRegionState);
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  Widget _buildQuickActionMenu(
    BuildContext context,
    TextSelectionToolbarAnchors anchors,
    List<_QuickAction> actions,
  ) {
    final children = actions
        .map(
          (action) => IconButton(
            onPressed: action.onPressed,
            icon: Icon(action.icon, size: 18),
            tooltip: action.label,
          ),
        )
        .toList();
    return Listener(
      onPointerDown: (event) {
        if (!isDesktop || event.kind != PointerDeviceKind.mouse) return;
        if ((event.buttons & kSecondaryMouseButton) == 0) return;
        _suppressContextMenuOnce();
        _showFullContextMenu(event.position);
      },
      child: TextSelectionToolbar(
        anchorAbove: anchors.primaryAnchor,
        anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
        toolbarBuilder: (context, child) {
          final theme = Theme.of(context);
          final surfaces = theme.fleurSurface;
          return Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(999),
            color: surfaces.floating,
            shadowColor: theme.shadowColor.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: child,
            ),
          );
        },
        children: children,
      ),
    );
  }

  Widget? _buildImageLoadingPlaceholder(
    BuildContext context,
    dom.Element element,
    double? loadingProgress,
  ) {
    if (element.localName != 'img') {
      return null;
    }
    final resolvedUrl = _resolveImageUrl(element.attributes['src']);
    final meta = resolvedUrl == null ? null : _imageMetaStore.peek(resolvedUrl);
    final aspectRatio = meta == null ? null : meta.width / meta.height;
    return _ImagePlaceholder.fromElement(
      element: element,
      loadingProgress: loadingProgress,
      aspectRatio: aspectRatio,
    );
  }

  Widget? _buildImageErrorPlaceholder(
    BuildContext context,
    dom.Element element,
    dynamic error,
  ) {
    if (element.localName != 'img') {
      return null;
    }
    return _ImageErrorPlaceholder.fromElement(element: element);
  }

  Future<bool> _onTapUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _onTapImage(ImageMetadata meta) {
    final src = meta.sources.isNotEmpty ? meta.sources.first.url : null;
    if (src == null || src.trim().isEmpty) return;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) {
          return Dialog(
            insetPadding: EdgeInsets.zero,
            child: Stack(
              children: [
                InteractiveViewer(
                  child: Image.network(src, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(FleurIcons.close),
                  ),
                ),
              ],
            ),
          );
        },
      ).then((_) {}),
    );
  }

  Future<void> showReaderSettings(ReaderSettings settings) async {
    final l10n = AppLocalizations.of(context)!;
    final isNarrow = MediaQuery.sizeOf(context).width < kCompactWidth;

    String readerFontLabel(ReaderFontFamily family) => switch (family) {
      ReaderFontFamily.system => l10n.readerFontSystem,
      ReaderFontFamily.serif => l10n.readerFontSerif,
      ReaderFontFamily.sans => l10n.readerFontSans,
      ReaderFontFamily.mono => l10n.readerFontMono,
      ReaderFontFamily.custom => l10n.custom,
    };
    String readerThemeLabel(ReaderThemePreset preset) => switch (preset) {
      ReaderThemePreset.defaultLightAware => l10n.readerThemeDefault,
      ReaderThemePreset.paper => l10n.readerThemePaper,
      ReaderThemePreset.sepia => l10n.readerThemeSepia,
      ReaderThemePreset.dim => l10n.readerThemeDim,
    };
    String readingWidthLabel(ReaderContentWidthPreset preset) =>
        switch (preset) {
          ReaderContentWidthPreset.narrow => l10n.readingWidthNarrow,
          ReaderContentWidthPreset.standard => l10n.readingWidthStandard,
          ReaderContentWidthPreset.wide => l10n.readingWidthWide,
        };
    String fontSizePresetLabel(ReaderFontSizePreset preset) => switch (preset) {
      ReaderFontSizePreset.extraSmall => l10n.fontSizeExtraSmall,
      ReaderFontSizePreset.small => l10n.fontSizeSmall,
      ReaderFontSizePreset.medium => l10n.fontSizeMediumRecommended,
      ReaderFontSizePreset.large => l10n.fontSizeLarge,
      ReaderFontSizePreset.extraLarge => l10n.fontSizeExtraLarge,
    };
    String lineHeightPresetLabel(_ReaderSettingsLineHeightPreset preset) =>
        switch (preset) {
          _ReaderSettingsLineHeightPreset.compact => l10n.lineHeightCompact,
          _ReaderSettingsLineHeightPreset.standard => l10n.lineHeightStandard,
          _ReaderSettingsLineHeightPreset.relaxed => l10n.lineHeightRelaxed,
        };

    Future<void> save(ReaderSettings next) {
      return ref.read(readerSettingsProvider.notifier).save(next);
    }

    Widget buildContent(
      BuildContext context,
      ReaderSettings initial,
      EdgeInsets padding,
    ) {
      var current = initial.fontFamily == ReaderFontFamily.custom
          ? initial.copyWith(fontFamily: ReaderFontFamily.system)
          : initial;
      return StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            child: Padding(
              padding: padding,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.readerSettings,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l10n.done),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SettingsControlRow(
                      padding: EdgeInsets.zero,
                      title: Text(l10n.readerFontFamily),
                      control: SettingsSelectField<ReaderFontFamily>(
                        value: current.fontFamily,
                        options: [
                          for (final family in ReaderFontFamily.values)
                            if (family != ReaderFontFamily.custom)
                              SettingsSelectOption(
                                value: family,
                                label: Text(readerFontLabel(family)),
                              ),
                        ],
                        onChanged: (value) {
                          final next = current.copyWith(fontFamily: value);
                          setState(() => current = next);
                          unawaited(save(next));
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SettingsControlRow(
                      padding: EdgeInsets.zero,
                      title: Text(l10n.fontSize),
                      controlWidth: 260,
                      control: SettingsSelectField<ReaderFontSizePreset>(
                        value: ReaderFontSizePreset.fromFontSize(
                          current.fontSize,
                        ),
                        options: [
                          for (final preset in ReaderFontSizePreset.values)
                            SettingsSelectOption(
                              value: preset,
                              label: Text(fontSizePresetLabel(preset)),
                            ),
                        ],
                        onChanged: (preset) {
                          final next = current.copyWith(
                            fontSize: preset.fontSize,
                          );
                          setState(() => current = next);
                          unawaited(save(next));
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SettingsControlRow(
                      padding: EdgeInsets.zero,
                      title: Text(l10n.lineHeight),
                      controlWidth: 260,
                      control:
                          SettingsSelectField<_ReaderSettingsLineHeightPreset>(
                            value: _readerSettingsLineHeightPresetFor(
                              current.lineHeight,
                            ),
                            options: [
                              for (final preset
                                  in _ReaderSettingsLineHeightPreset.values)
                                SettingsSelectOption(
                                  value: preset,
                                  label: Text(lineHeightPresetLabel(preset)),
                                ),
                            ],
                            onChanged: (preset) {
                              final next = current.copyWith(
                                lineHeight:
                                    _readerSettingsLineHeightPresetValue(
                                      preset,
                                    ),
                              );
                              setState(() => current = next);
                              unawaited(save(next));
                            },
                          ),
                    ),
                    const SizedBox(height: 10),
                    SettingsControlRow(
                      padding: EdgeInsets.zero,
                      title: Text(l10n.readingWidth),
                      controlWidth: 300,
                      control: SegmentedButton<ReaderContentWidthPreset>(
                        segments: [
                          for (final preset in ReaderContentWidthPreset.values)
                            ButtonSegment(
                              value: preset,
                              label: Text(readingWidthLabel(preset)),
                            ),
                        ],
                        selected: {current.contentWidthPreset},
                        onSelectionChanged: (selected) {
                          if (selected.isEmpty) return;
                          final next = current.copyWith(
                            contentWidthPreset: selected.first,
                          );
                          setState(() => current = next);
                          unawaited(save(next));
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    SettingsControlRow(
                      padding: EdgeInsets.zero,
                      title: Text(l10n.readerTheme),
                      control: SettingsSelectField<ReaderThemePreset>(
                        value: current.readerTheme,
                        options: [
                          for (final preset in ReaderThemePreset.values)
                            SettingsSelectOption(
                              value: preset,
                              label: Text(readerThemeLabel(preset)),
                            ),
                        ],
                        onChanged: (value) {
                          final next = current.copyWith(readerTheme: value);
                          setState(() => current = next);
                          unawaited(save(next));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    if (isNarrow) {
      await showModalBottomSheet<void>(
        context: context,
        builder: (context) {
          return buildContent(context, settings, const EdgeInsets.all(16));
        },
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return Dialog(
            child: buildContent(context, settings, const EdgeInsets.all(16)),
          );
        },
      );
    }
  }
}

_ReaderSettingsLineHeightPreset _readerSettingsLineHeightPresetFor(
  double value,
) {
  if (value <= 1.475) return _ReaderSettingsLineHeightPreset.compact;
  if (value <= 1.725) return _ReaderSettingsLineHeightPreset.standard;
  return _ReaderSettingsLineHeightPreset.relaxed;
}

double _readerSettingsLineHeightPresetValue(
  _ReaderSettingsLineHeightPreset preset,
) {
  return switch (preset) {
    _ReaderSettingsLineHeightPreset.compact => 1.35,
    _ReaderSettingsLineHeightPreset.standard =>
      ReaderSettings.defaultLineHeight,
    _ReaderSettingsLineHeightPreset.relaxed => 1.85,
  };
}
