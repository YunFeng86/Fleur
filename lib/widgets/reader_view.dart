import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:html/dom.dart' as dom;

import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:fleur/l10n/app_localizations.dart';

import 'reader_bottom_bar.dart';
import 'reader_search_bar.dart';
import 'app_scrollbar.dart';
import 'fleur_empty_state.dart';
import '../models/article.dart';
import '../providers/app_settings_providers.dart';
import '../providers/article_ai_providers.dart';
import '../providers/reader_search_providers.dart';
import '../providers/reader_providers.dart';
import '../providers/query_providers.dart';
import '../providers/service_providers.dart';
import '../providers/settings_providers.dart';
import '../services/cache/image_meta_store.dart';
import '../services/html_sanitizer.dart';
import '../services/reader_search_service.dart';
import '../services/settings/app_settings.dart';
import '../services/settings/reader_settings.dart';
import '../services/settings/reader_progress_store.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../utils/platform.dart';
import '../utils/content_hash.dart';
import '../utils/language_utils.dart';
import '../ui/layout.dart';
import '../ui/workspace_layers.dart';
import '../ui/reader/reader_selectable_rich_text.dart';

part '../ui/reader/reader_session_coordinator.dart';
part '../ui/reader/reader_progress_coordinator.dart';
part '../ui/reader/reader_chunk_coordinator.dart';
part '../ui/reader/reader_interaction_controller.dart';
part '../ui/reader/reader_scene_scaffold.dart';

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

class _ToggleReaderSearchIntent extends Intent {
  const _ToggleReaderSearchIntent();
}

class _CloseReaderSearchIntent extends Intent {
  const _CloseReaderSearchIntent();
}

class _ReaderViewState extends ConsumerState<ReaderView> {
  ProviderSubscription<AsyncValue<void>>? _fullTextSub;
  late final _ReaderInteractionController _interactionController;
  late final _ReaderViewportCoordinator _viewportCoordinator;
  late final _ReaderSessionCoordinator _sessionCoordinator;
  String? _lastScheduledSearchHtml;
  bool _searchHtmlSyncScheduled = false;
  static const double _autoScrollDeadZone = 6;
  static const double _autoScrollSpeedFactor = 0.12;
  static const int _chunkThreshold = 50000;

  @override
  void initState() {
    super.initState();
    _interactionController = _ReaderInteractionController(
      owner: this,
      imageMetaStore: ref.read(imageMetaStoreProvider),
    );
    _viewportCoordinator = _ReaderViewportCoordinator(
      owner: this,
      progressStore: ref.read(readerProgressStoreProvider),
      interactionController: _interactionController,
    );
    _interactionController.attachViewport(_viewportCoordinator);
    _sessionCoordinator = _ReaderSessionCoordinator(
      owner: this,
      viewportCoordinator: _viewportCoordinator,
    );
    _interactionController.prime();
    _viewportCoordinator.init();

    // Show extraction errors from the one-shot full text fetch.
    _fullTextSub = ref.listenManual<AsyncValue<void>>(
      fullTextControllerProvider,
      (prev, next) {
        if (!mounted) return;
        if (next.hasError) {
          final l10n = AppLocalizations.of(context)!;
          final error = next.error;
          if (error == null) return;

          String message;
          if (error is ArticleExtractionException) {
            switch (error.type) {
              case ArticleExtractionErrorType.emptyContent:
                message = l10n.fullTextRetry;
            }
          } else {
            message = l10n.fullTextFailed(error.toString());
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      fireImmediately: false,
    );

    _sessionCoordinator.listenArticle(widget.articleId);
    _sessionCoordinator.listenTranslationHtml(widget.articleId);
  }

  @override
  void didUpdateWidget(covariant ReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.articleId != widget.articleId) {
      _viewportCoordinator.flushPendingProgressSave();
      _viewportCoordinator.resetState();
      if (_viewportCoordinator.scrollController.hasClients) {
        _viewportCoordinator.scrollController.jumpTo(
          _viewportCoordinator.scrollController.position.minScrollExtent,
        );
      }
      _sessionCoordinator.listenArticle(widget.articleId);
      _sessionCoordinator.listenTranslationHtml(widget.articleId);
    }
  }

  @override
  void dispose() {
    _viewportCoordinator.dispose();
    _sessionCoordinator.dispose();
    _interactionController.dispose();
    _fullTextSub?.close();
    super.dispose();
  }

  void _scheduleSearchDocumentHtmlSync(String html) {
    if (_lastScheduledSearchHtml == html) return;
    _lastScheduledSearchHtml = html;
    if (_searchHtmlSyncScheduled) return;
    _searchHtmlSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchHtmlSyncScheduled = false;
      if (!mounted) return;
      final nextHtml = _lastScheduledSearchHtml;
      if (nextHtml == null) return;
      ref
          .read(readerSearchControllerProvider(widget.articleId).notifier)
          .setDocumentHtml(nextHtml);
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(articleProvider(widget.articleId));
    // final fullTextRequest = ref.watch(fullTextControllerProvider); // Unused
    final settingsAsync = ref.watch(readerSettingsProvider);
    return a.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(AppLocalizations.of(context)!.errorMessage(e.toString())),
      ),
      data: (article) {
        final l10n = AppLocalizations.of(context)!;
        final baseTheme = Theme.of(context);
        final sceneTheme = AppTheme.readerScene(baseTheme);
        final readerTokens = sceneTheme.fleurReader;
        if (article == null) {
          return FleurEmptyState(
            variant: FleurEmptyStateVariant.reader,
            icon: FleurIcons.article,
            title: l10n.notFound,
            subtitle: l10n.articleNotFoundSubtitle,
          );
        }

        final settings = settingsAsync.valueOrNull ?? const ReaderSettings();
        final aiState = ref.watch(
          articleAiControllerProvider(widget.articleId),
        );
        return _buildReaderSceneBody(
          context: context,
          l10n: l10n,
          article: article,
          settings: settings,
          aiState: aiState,
          sceneTheme: sceneTheme,
          readerTokens: readerTokens,
        );
      },
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

class _ReaderWidgetFactory extends WidgetFactory {
  _ReaderWidgetFactory(
    this._cacheManager, {
    required ReaderSettings settings,
    ValueNotifier<String?>? hoveredUrl,
    Map<int, String>? recognizerUrlMap,
  }) : _settings = settings,
       _hoveredUrl = hoveredUrl,
       _recognizerUrlMap = recognizerUrlMap;

  final BaseCacheManager _cacheManager;
  final ReaderSettings _settings;
  final ValueNotifier<String?>? _hoveredUrl;
  final Map<int, String>? _recognizerUrlMap;

  @override
  BaseCacheManager? get cacheManager => _cacheManager;

  @override
  GestureRecognizer? buildGestureRecognizer(
    BuildTree tree, {
    GestureTapCallback? onTap,
  }) {
    final recognizer = super.buildGestureRecognizer(tree, onTap: onTap);
    final href = tree.element.attributes['href'];
    if (href != null && href.isNotEmpty && recognizer != null) {
      _recognizerUrlMap?[identityHashCode(recognizer)] = href;
    }
    return recognizer;
  }

  @override
  Widget? buildGestureDetector(
    BuildTree tree,
    Widget child,
    GestureRecognizer recognizer,
  ) {
    final built = super.buildGestureDetector(tree, child, recognizer);
    if (built == null || _hoveredUrl == null) return built;
    final url = tree.element.attributes['href'];
    if (url == null || url.isEmpty) return built;
    final notifier = _hoveredUrl;
    return MouseRegion(
      onEnter: (_) => notifier.value = url,
      onExit: (_) {
        if (notifier.value == url) notifier.value = null;
      },
      child: built,
    );
  }

  @override
  Widget? buildText(
    BuildTree tree,
    InheritedProperties resolved,
    InlineSpan text,
  ) {
    final softWrap = resolved.get<CssWhitespace>() != CssWhitespace.nowrap;
    final textAlign = resolved.get<TextAlign>() ?? TextAlign.start;
    final textDirection = resolved.get<ui.TextDirection>();
    final textStyle = resolved.prepareTextStyle();
    final strutStyle = StrutStyle.fromTextStyle(
      textStyle,
      fontSize: textStyle.fontSize ?? _settings.fontSize,
      height: textStyle.height ?? _settings.lineHeight,
      forceStrutHeight: false,
    );

    return Builder(
      builder: (context) {
        final selectionRegistrar = SelectionContainer.maybeOf(context);
        final selectionColor = selectionRegistrar != null
            ? DefaultSelectionStyle.of(context).selectionColor ??
                  DefaultSelectionStyle.defaultColor
            : null;

        Widget built = ReaderSelectableRichText(
          overflow: TextOverflow.clip,
          selectionColor: selectionColor,
          selectionRegistrar: selectionRegistrar,
          softWrap: softWrap,
          strutStyle: strutStyle,
          text: text,
          textAlign: textAlign,
          textDirection: textDirection,
        );

        if (selectionRegistrar != null) {
          built = MouseRegion(cursor: SystemMouseCursors.text, child: built);
        }

        return built;
      },
    );
  }
}

class _ChunkAnchor {
  const _ChunkAnchor({required this.index, required this.fraction});

  final int index;
  final double fraction;
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({
    required this.widthPx,
    required this.heightPx,
    required this.widthPercent,
    required this.heightPercent,
    required this.loadingProgress,
    required this.aspectRatio,
  });

  factory _ImagePlaceholder.fromElement({
    required dom.Element element,
    required double? loadingProgress,
    required double? aspectRatio,
  }) {
    final spec = _parseImageSizeSpec(element);
    return _ImagePlaceholder(
      widthPx: spec.widthPx,
      heightPx: spec.heightPx,
      widthPercent: spec.widthPercent,
      heightPercent: spec.heightPercent,
      loadingProgress: loadingProgress,
      aspectRatio: aspectRatio,
    );
  }

  static const double _fallbackAspectRatio = 4 / 3;

  final double? widthPx;
  final double? heightPx;
  final double? widthPercent;
  final double? heightPercent;
  final double? loadingProgress;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = theme.fleurReader;
    final base = DecoratedBox(
      decoration: BoxDecoration(
        color: reader.codeBlockSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: loadingProgress == null
          ? null
          : Align(
              alignment: Alignment.bottomCenter,
              child: LinearProgressIndicator(
                value: loadingProgress,
                minHeight: 3,
                backgroundColor: theme.fleurSurface.card,
                color: theme.colorScheme.primary,
              ),
            ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth = _resolveLength(
          widthPx,
          widthPercent,
          constraints.maxWidth,
        );
        final resolvedHeight = _resolveLength(
          heightPx,
          heightPercent,
          constraints.maxHeight,
        );

        if (resolvedWidth != null && resolvedHeight != null) {
          return SizedBox(
            width: resolvedWidth,
            height: resolvedHeight,
            child: base,
          );
        }

        if (resolvedWidth != null) {
          return SizedBox(
            width: resolvedWidth,
            height: resolvedWidth / (aspectRatio ?? _fallbackAspectRatio),
            child: base,
          );
        }

        if (resolvedHeight != null) {
          return SizedBox(height: resolvedHeight, child: base);
        }

        if (constraints.hasBoundedWidth && constraints.maxWidth.isFinite) {
          return SizedBox(
            width: constraints.maxWidth,
            height:
                constraints.maxWidth / (aspectRatio ?? _fallbackAspectRatio),
            child: base,
          );
        }

        return SizedBox(height: 180, child: base);
      },
    );
  }

  static double? _resolveLength(double? px, double? percent, double max) {
    if (px != null && px > 0) return px;
    if (percent != null && percent > 0 && max.isFinite && max > 0) {
      return max * percent / 100;
    }
    return null;
  }
}

class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder({
    required this.widthPx,
    required this.heightPx,
    required this.widthPercent,
    required this.heightPercent,
    required this.label,
  });

  factory _ImageErrorPlaceholder.fromElement({required dom.Element element}) {
    final spec = _parseImageSizeSpec(element);
    final label =
        (element.attributes['alt'] ?? element.attributes['title'] ?? '').trim();
    return _ImageErrorPlaceholder(
      widthPx: spec.widthPx,
      heightPx: spec.heightPx,
      widthPercent: spec.widthPercent,
      heightPercent: spec.heightPercent,
      label: label.isEmpty ? 'Image failed to load' : label,
    );
  }

  final double? widthPx;
  final double? heightPx;
  final double? widthPercent;
  final double? heightPercent;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = theme.fleurReader;
    final content = DecoratedBox(
      key: const Key('reader_image_error_placeholder'),
      decoration: BoxDecoration(
        color: reader.codeBlockSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.fleurSurface.subtleDivider),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FleurIcons.brokenImage,
                size: 22,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth = _ImagePlaceholder._resolveLength(
          widthPx,
          widthPercent,
          constraints.maxWidth,
        );
        final resolvedHeight = _ImagePlaceholder._resolveLength(
          heightPx,
          heightPercent,
          constraints.maxHeight,
        );

        if (resolvedWidth != null && resolvedHeight != null) {
          return SizedBox(
            width: resolvedWidth,
            height: resolvedHeight,
            child: content,
          );
        }

        if (resolvedWidth != null) {
          return SizedBox(
            width: resolvedWidth,
            height: math.min(180, math.max(96, resolvedWidth * 0.36)),
            child: content,
          );
        }

        if (resolvedHeight != null) {
          return SizedBox(height: resolvedHeight, child: content);
        }

        if (constraints.hasBoundedWidth && constraints.maxWidth.isFinite) {
          return SizedBox(
            width: constraints.maxWidth,
            height: 140,
            child: content,
          );
        }

        return SizedBox(height: 140, child: content);
      },
    );
  }
}

class _IframeMediaCard extends StatelessWidget {
  const _IframeMediaCard({required this.url, required this.onOpen});

  final String url;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = Uri.tryParse(url)?.host;
    final label = (host == null || host.isEmpty) ? url : host;
    return Container(
      key: const Key('reader_iframe_media_card'),
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: theme.fleurReader.codeBlockSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.fleurSurface.subtleDivider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  FleurIcons.openExternal,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Embedded media',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: AppTypography.platformWeight(
                            FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  FleurIcons.chevronRight,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageSizeSpec {
  const _ImageSizeSpec({
    this.widthPx,
    this.heightPx,
    this.widthPercent,
    this.heightPercent,
  });

  final double? widthPx;
  final double? heightPx;
  final double? widthPercent;
  final double? heightPercent;
}

_ImageSizeSpec _parseImageSizeSpec(dom.Element element) {
  final attrs = element.attributes;
  final style = attrs['style'] ?? '';

  final styleWidth = _parseCssLength(_extractStyleValue(style, 'width'));
  final styleHeight = _parseCssLength(_extractStyleValue(style, 'height'));
  final attrWidth = _parseCssLength(attrs['width']);
  final attrHeight = _parseCssLength(attrs['height']);
  final dataWidth = _parseCssLength(attrs['data-width']);
  final dataHeight = _parseCssLength(attrs['data-height']);

  return _ImageSizeSpec(
    widthPx: styleWidth.px ?? attrWidth.px ?? dataWidth.px,
    heightPx: styleHeight.px ?? attrHeight.px ?? dataHeight.px,
    widthPercent: styleWidth.percent ?? attrWidth.percent ?? dataWidth.percent,
    heightPercent:
        styleHeight.percent ?? attrHeight.percent ?? dataHeight.percent,
  );
}

_CssLength _parseCssLength(String? raw) {
  if (raw == null) return const _CssLength();
  final value = raw.trim().toLowerCase();
  if (value.isEmpty) return const _CssLength();
  if (value.endsWith('%')) {
    final number = double.tryParse(value.replaceAll('%', '').trim());
    return _CssLength(percent: number);
  }
  final cleaned = value.replaceAll('px', '').trim();
  return _CssLength(px: double.tryParse(cleaned));
}

String? _extractStyleValue(String style, String key) {
  if (style.isEmpty) return null;
  final regex = RegExp('$key\\s*:\\s*([^;]+)', caseSensitive: false);
  final match = regex.firstMatch(style);
  return match?.group(1)?.trim();
}

class _CssLength {
  const _CssLength({this.px, this.percent});

  final double? px;
  final double? percent;
}
