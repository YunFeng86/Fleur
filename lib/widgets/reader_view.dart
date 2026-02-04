import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:go_router/go_router.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';

import 'reader_bottom_bar.dart';
import '../models/article.dart';
import '../providers/app_settings_providers.dart';
import '../providers/reader_providers.dart';
import '../providers/query_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/service_providers.dart';
import '../providers/settings_providers.dart';
import '../services/settings/app_settings.dart';
import '../services/settings/reader_settings.dart';
import '../utils/platform.dart';
import '../ui/layout.dart';

class ReaderView extends ConsumerStatefulWidget {
  const ReaderView({
    super.key,
    required this.articleId,
    this.embedded = false,
    this.showBack = false,
    this.fallbackBackLocation = '/',
  });

  final int articleId;
  final bool embedded;
  final bool showBack;
  final String fallbackBackLocation;

  static const double maxReadingWidth = kMaxReadingWidth;

  @override
  ConsumerState<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends ConsumerState<ReaderView> {
  ProviderSubscription<AsyncValue<Article?>>? _articleSub;
  ProviderSubscription<AsyncValue<void>>? _fullTextSub;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<SelectionAreaState> _selectionAreaKey =
      GlobalKey<SelectionAreaState>();
  final ContextMenuController _contextMenuController = ContextMenuController();
  final ContextMenuController _quickMenuController = ContextMenuController();
  Timer? _quickMenuTimer;
  String _pendingQuickMenuText = '';
  OverlayEntry? _autoScrollOverlay;
  Timer? _autoScrollTimer;
  Offset? _autoScrollAnchor;
  Offset? _autoScrollPointer;
  bool _suppressNextContextMenu = false;
  static const double _autoScrollDeadZone = 6;
  static const double _autoScrollSpeedFactor = 0.12;

  @override
  void initState() {
    super.initState();

    // Show extraction errors from the one-shot full text fetch.
    _fullTextSub = ref.listenManual<AsyncValue<void>>(
      fullTextControllerProvider,
      (prev, next) {
        if (!mounted) return;
        if (next.hasError) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.fullTextFailed(next.error.toString()))),
          );
        }
      },
      fireImmediately: false,
    );

    _listenArticle(widget.articleId);
  }

  @override
  void didUpdateWidget(covariant ReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.articleId != widget.articleId) {
      _listenArticle(widget.articleId);
    }
  }

  void _listenArticle(int articleId) {
    final sub = _articleSub;
    if (sub != null) {
      sub.close();
    }
    var hasMarkedRead = false; // 追踪是否已标记
    _articleSub = ref.listenManual<AsyncValue<Article?>>(
      articleProvider(articleId),
      (prev, next) {
        final a = next.valueOrNull;

        // Auto-mark as read when entering/opening the reader for this article.
        // If the user explicitly toggles the article back to unread while
        // staying on this reader view, we do not immediately flip it back.
        if (!hasMarkedRead && a != null && !a.isRead) {
          final appSettings =
              ref.read(appSettingsProvider).valueOrNull ?? const AppSettings();
          if (appSettings.autoMarkRead) {
            unawaited(
              ref.read(articleRepositoryProvider).markRead(articleId, true),
            );
            hasMarkedRead = true;
          }
        }

        // Prefetch images when content changes.
        final prevA = prev?.valueOrNull;
        final prevHtml =
            (prevA?.extractedContentHtml ?? prevA?.contentHtml ?? '').trim();
        final html = (a?.extractedContentHtml ?? a?.contentHtml ?? '').trim();
        if (a == null || html.isEmpty) return;
        if (prevA != null && prevA.id == a.id && prevHtml == html) return;
        unawaited(
          ref
              .read(articleCacheServiceProvider)
              .prefetchImagesFromHtml(html, baseUrl: Uri.tryParse(a.link)),
        );
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _articleSub?.close();
    _fullTextSub?.close();
    _scrollController.dispose();
    _quickMenuTimer?.cancel();
    ContextMenuController.removeAny();
    _autoScrollTimer?.cancel();
    _autoScrollOverlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(articleProvider(widget.articleId));
    // final fullTextRequest = ref.watch(fullTextControllerProvider); // Unused
    final useFullText = ref.watch(
      fullTextViewEnabledProvider(widget.articleId),
    );
    final settingsAsync = ref.watch(readerSettingsProvider);
    return a.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(AppLocalizations.of(context)!.errorMessage(e.toString())),
      ),
      data: (article) {
        final l10n = AppLocalizations.of(context)!;
        if (article == null) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            alignment: Alignment.center,
            child: Text(l10n.notFound),
          );
        }

        final settings = settingsAsync.valueOrNull ?? const ReaderSettings();
        final hasExtracted = (article.extractedContentHtml ?? '')
            .trim()
            .isNotEmpty;
        final showExtracted = hasExtracted && useFullText;
        final html =
            ((showExtracted ? article.extractedContentHtml : null) ??
                    article.contentHtml ??
                    '')
                .trim();
        final title = article.title?.trim().isNotEmpty == true
            ? article.title!
            : l10n.reader;

        // Format date: e.g. "2026/1/14 08:00:00"
        final dateStr = DateFormat(
          'yyyy/MM/dd HH:mm:ss',
        ).format(article.publishedAt.toLocal());

        // New Inline Header
        final inlineHeader = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dateStr,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 24),
          ],
        );

        final contentWidget = html.isEmpty
            ? Center(child: Text(article.link))
            : _buildContentWidget(
                context,
                html,
                article,
                settings,
                inlineHeader,
              );

        final bottomBar = Positioned(
          left: 0,
          right: 0, // Stretch full width
          bottom: 0,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ReaderView.maxReadingWidth,
              ),
              child: ReaderBottomBar(
                article: article,
                onShowSettings: () =>
                    _showReaderSettings(context, ref, settings),
              ),
            ),
          ),
        );

        // Show AppBar if we are not embedded (i.e. strictly full screen) OR if
        // we explicitly want a back button (e.g. secondary page on desktop).
        // On mobile (!isDesktop), we almost always want the scaffold if not embedded.
        final showAppBar = (!isDesktop && !widget.embedded) || widget.showBack;

        if (showAppBar) {
          return Scaffold(
            appBar: AppBar(
              title: null, // Title is inline
              automaticallyImplyLeading: true,
              leading: widget.showBack
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(widget.fallbackBackLocation);
                        }
                      },
                    )
                  : null,
              actions: const [], // Actions moved to bottom bar
            ),
            body: Stack(
              fit: StackFit.expand,
              children: [contentWidget, bottomBar],
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [contentWidget, bottomBar],
        );
      },
    );
  }

  Widget _buildContentWidget(
    BuildContext context,
    String html,
    Article article,
    ReaderSettings settings,
    Widget inlineHeader,
  ) {
    const chunkThreshold = 50000;
    if (html.length < chunkThreshold) {
      return SelectionArea(
        key: _selectionAreaKey,
        onSelectionChanged: _handleSelectionChanged,
        contextMenuBuilder: _buildContextMenu,
        child: _wrapScrollable(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: ReaderView.maxReadingWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    settings.horizontalPadding,
                    24, // Top padding
                    settings.horizontalPadding,
                    100, // Bottom padding for floating bar
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      inlineHeader,
                      HtmlWidget(
                        html,
                        baseUrl: Uri.tryParse(article.link),
                        renderMode: RenderMode.column,
                        buildAsync: true,
                        onLoadingBuilder: (context, element, loadingProgress) =>
                            const SizedBox.shrink(),
                        textStyle: TextStyle(
                          fontSize: settings.fontSize,
                          height: settings.lineHeight,
                          color: Theme.of(context).colorScheme.onSurface,
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
        ),
      );
    }

    // Lazy load long articles
    final chunks = _splitHtmlIntoChunks(html);
    return SelectionArea(
      key: _selectionAreaKey,
      onSelectionChanged: _handleSelectionChanged,
      contextMenuBuilder: _buildContextMenu,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ReaderView.maxReadingWidth,
          ),
          child: _wrapScrollable(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                settings.horizontalPadding,
                24,
                settings.horizontalPadding,
                100,
              ),
              itemCount: chunks.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return inlineHeader;
                return HtmlWidget(
                  chunks[index - 1],
                  baseUrl: Uri.tryParse(article.link),
                  renderMode: RenderMode.column,
                  buildAsync: true,
                  onLoadingBuilder: (context, element, loadingProgress) =>
                      const SizedBox.shrink(),
                  textStyle: TextStyle(
                    fontSize: settings.fontSize,
                    height: settings.lineHeight,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onTapUrl: _onTapUrl,
                  onTapImage: _onTapImage,
                );
              },
            ),
          ),
        ),
      ),
    );
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
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: isDesktop,
          interactive: true,
          child: child,
        ),
      ),
    );
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
    if (_autoScrollTimer == null) return;
    if (event.kind != PointerDeviceKind.mouse) return;
    _autoScrollPointer = event.position;
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
    if (delta.abs() < _autoScrollDeadZone) return;
    final position = _scrollController.position;
    final next = (position.pixels + delta * _autoScrollSpeedFactor).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
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
    final theme = Theme.of(context);
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
                  color: theme.colorScheme.surfaceContainerHighest,
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                    width: 1,
                  ),
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
                    Icons.unfold_more,
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
    // 注意：textEditingValue 已弃用，但目前没有更好的替代 API
    // 未来应该使用 contextMenuBuilder 相关的新 API
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

  void _searchSelectedText(String text) {
    final query = Uri.encodeQueryComponent(text);
    final uri = Uri.parse('https://duckduckgo.com/?q=$query');
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
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
            _searchSelectedText(selectedText);
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
          icon: Icons.content_copy,
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
        icon: Icons.search,
        label: l10n.search,
        onPressed: () {
          _searchSelectedText(text);
          ContextMenuController.removeAny();
        },
      ),
    );
    actions.add(
      _QuickAction(
        icon: Icons.keyboard_arrow_up,
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

  /// 构建自定义上下文菜单，使用 Material Design 风格
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
    final theme = Theme.of(context);
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
          return Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(999),
            color: theme.colorScheme.surfaceContainerHigh,
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

  List<String> _splitHtmlIntoChunks(String html, {int chunkSize = 20000}) {
    final chunks = <String>[];
    int start = 0;
    // Regex to find closing block tags (case insensitive)
    final blockTagRe = RegExp(
      r'</(p|div|section|article|h[1-6]|ul|ol|table|blockquote)>',
      caseSensitive: false,
    );

    while (start < html.length) {
      if (start + chunkSize >= html.length) {
        chunks.add(html.substring(start));
        break;
      }

      int end = start + chunkSize;
      // Look for the next closing tag after the rough chunk boundary
      final match = blockTagRe.firstMatch(html.substring(end));
      if (match != null) {
        // Split after the closing tag
        end += match.end;
      } else {
        // Fallback: look for generic closing tag
        final closeIdx = html.indexOf('>', end);
        if (closeIdx != -1) {
          end = closeIdx + 1;
        }
        // If really no tags, use hard cut (unlikely for HTML)
      }

      chunks.add(html.substring(start, end));
      start = end;
    }
    return chunks;
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
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          );
        },
      ).then((_) {}),
    );
  }

  Future<void> _showReaderSettings(
    BuildContext context,
    WidgetRef ref,
    ReaderSettings settings,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final isNarrow = MediaQuery.sizeOf(context).width < 600;

    Future<void> saveAndPop(ReaderSettings cur) async {
      await ref.read(readerSettingsProvider.notifier).save(cur);
      if (!context.mounted) return;
      Navigator.of(context).pop();
    }

    Widget buildContent(
      BuildContext context,
      ReaderSettings initial,
      EdgeInsets padding,
    ) {
      var cur = initial;
      return StatefulBuilder(
        builder: (context, setState) {
          return SafeArea(
            child: Padding(
              padding: padding,
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
                        onPressed: () => saveAndPop(cur),
                        child: Text(l10n.done),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _slider(
                    label: l10n.fontSize,
                    value: cur.fontSize,
                    min: 12,
                    max: 28,
                    onChanged: (v) =>
                        setState(() => cur = cur.copyWith(fontSize: v)),
                  ),
                  _slider(
                    label: l10n.lineHeight,
                    value: cur.lineHeight,
                    min: 1.1,
                    max: 2.2,
                    onChanged: (v) =>
                        setState(() => cur = cur.copyWith(lineHeight: v)),
                  ),
                  _slider(
                    label: l10n.horizontalPadding,
                    value: cur.horizontalPadding,
                    min: 8,
                    max: 32,
                    onChanged: (v) => setState(
                      () => cur = cur.copyWith(horizontalPadding: v),
                    ),
                  ),
                ],
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

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(value.toStringAsFixed(1)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}
