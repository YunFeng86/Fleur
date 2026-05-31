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
import 'package:flutter_math_fork/flutter_math.dart' as flutter_math;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:syntax_highlight/syntax_highlight.dart';

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

  static const List<String> _highlightLanguages = [
    'css',
    'dart',
    'go',
    'html',
    'java',
    'javascript',
    'json',
    'kotlin',
    'python',
    'rust',
    'sql',
    'swift',
    'typescript',
    'yaml',
  ];

  static Future<void>? _syntaxHighlightInit;

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

class _MediaEmbedCard extends StatelessWidget {
  const _MediaEmbedCard({
    required this.kind,
    required this.url,
    required this.onOpen,
  });

  final String kind;
  final String url;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = Uri.tryParse(url)?.host;
    final label = _mediaLabel(url, host);
    final canOpen = url.trim().isNotEmpty;
    return Container(
      key: const Key('reader_media_embed_card'),
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
          onTap: canOpen ? onOpen : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  canOpen ? FleurIcons.openExternal : FleurIcons.brokenImage,
                  size: 22,
                  color: canOpen
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$kind media',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: AppTypography.platformWeight(
                            FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        canOpen ? label : 'Media source unavailable',
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
                  color: canOpen
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurfaceVariant.withAlpha(120),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _mediaLabel(String url, String? host) {
    if (host != null && host.isNotEmpty) return host;
    final path = Uri.tryParse(url)?.pathSegments.lastOrNull;
    if (path != null && path.trim().isNotEmpty) return path;
    return url;
  }
}

class _ReaderCodeBlock extends StatefulWidget {
  const _ReaderCodeBlock({
    required this.code,
    required this.language,
    required this.fontSize,
  });

  final String code;
  final String? language;
  final double fontSize;

  @override
  State<_ReaderCodeBlock> createState() => _ReaderCodeBlockState();
}

class _ReaderCodeBlockState extends State<_ReaderCodeBlock> {
  Future<TextSpan>? _highlightFuture;
  Brightness? _highlightBrightness;
  String? _highlightLanguage;
  String? _highlightCodeText;
  double? _highlightFontSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshHighlightFuture();
  }

  @override
  void didUpdateWidget(covariant _ReaderCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code ||
        oldWidget.language != widget.language ||
        oldWidget.fontSize != widget.fontSize) {
      _refreshHighlightFuture();
    }
  }

  void _refreshHighlightFuture() {
    final brightness = Theme.of(context).brightness;
    if (_highlightFuture != null &&
        _highlightBrightness == brightness &&
        _highlightLanguage == widget.language &&
        _highlightCodeText == widget.code &&
        _highlightFontSize == widget.fontSize) {
      return;
    }
    _highlightBrightness = brightness;
    _highlightLanguage = widget.language;
    _highlightCodeText = widget.code;
    _highlightFontSize = widget.fontSize;
    _highlightFuture = _highlightCode(
      context,
      widget.code,
      widget.language,
      _codeStyle(context),
    );
  }

  TextStyle _codeStyle(BuildContext context) {
    final theme = Theme.of(context);
    return TextStyle(
      color: theme.colorScheme.onSurface,
      decoration: TextDecoration.none,
      fontFamily: 'monospace',
      fontSize: math.max(12, widget.fontSize - 1),
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w400,
      height: 1.45,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = theme.fleurReader;
    final codeStyle = _codeStyle(context);

    return Container(
      key: const Key('reader_code_block'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: reader.codeBlockSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.fleurSurface.subtleDivider),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: FutureBuilder<TextSpan>(
            future: _highlightFuture,
            builder: (context, snapshot) {
              final span =
                  snapshot.data ??
                  TextSpan(text: widget.code, style: codeStyle);
              return SelectableText.rich(span);
            },
          ),
        ),
      ),
    );
  }

  static Future<TextSpan> _highlightCode(
    BuildContext context,
    String code,
    String? language,
    TextStyle fallbackStyle,
  ) async {
    final normalized = _normalizeCodeLanguage(language);
    if (normalized == null) return TextSpan(text: code, style: fallbackStyle);
    if (normalized == 'diff') {
      return _highlightDiffCode(context, code, fallbackStyle);
    }
    final brightness = Theme.of(context).brightness;
    try {
      _ReaderViewState._syntaxHighlightInit ??= Highlighter.initialize(
        _ReaderViewState._highlightLanguages,
      );
      await _ReaderViewState._syntaxHighlightInit;
      final highlighter = Highlighter(
        language: normalized,
        theme: await HighlighterTheme.loadForBrightness(brightness),
      );
      return _readerCodeHighlightSpan(
        highlighter.highlight(code),
        fallbackStyle,
      );
    } catch (_) {
      return TextSpan(text: code, style: fallbackStyle);
    }
  }
}

TextSpan _readerCodeHighlightSpan(TextSpan span, TextStyle baseStyle) {
  return TextSpan(
    text: span.text,
    style: baseStyle,
    children: _readerCodeHighlightChildren(span.children),
  );
}

List<InlineSpan>? _readerCodeHighlightChildren(List<InlineSpan>? children) {
  if (children == null) return null;
  return [
    for (final child in children)
      if (child is TextSpan)
        TextSpan(
          text: child.text,
          style: _highlightColorOnly(child.style),
          children: _readerCodeHighlightChildren(child.children),
        )
      else
        child,
  ];
}

TextStyle? _highlightColorOnly(TextStyle? style) {
  final color = style?.color;
  return color == null ? null : TextStyle(color: color);
}

TextSpan _highlightDiffCode(
  BuildContext context,
  String code,
  TextStyle fallbackStyle,
) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  final addedColor = dark ? const Color(0xFF7EE787) : const Color(0xFF116329);
  final removedColor = dark ? const Color(0xFFFF7B72) : theme.colorScheme.error;
  final addedBackground = addedColor.withAlpha(dark ? 44 : 30);
  final removedBackground = removedColor.withAlpha(dark ? 42 : 28);
  final spans = <TextSpan>[];

  var start = 0;
  while (start < code.length) {
    final newline = code.indexOf('\n', start);
    final end = newline < 0 ? code.length : newline + 1;
    final line = code.substring(start, end);
    final marker = line.codeUnitAt(0);
    final style = switch (marker) {
      43 => TextStyle(color: addedColor, backgroundColor: addedBackground),
      45 => TextStyle(color: removedColor, backgroundColor: removedBackground),
      _ => null,
    };
    spans.add(TextSpan(text: line, style: style));
    start = end;
  }

  return TextSpan(style: fallbackStyle, children: spans);
}

String? _normalizeCodeLanguage(String? raw) {
  final tokens = (raw ?? '').trim().toLowerCase().split(RegExp(r'\s+'));
  for (var lang in tokens) {
    if (lang.isEmpty) continue;
    if (lang.startsWith('language-')) {
      lang = lang.substring('language-'.length);
    }
    if (lang == 'diff' || lang.startsWith('diff-')) return 'diff';
    final normalized = switch (lang) {
      'js' || 'jsx' => 'javascript',
      'ts' || 'tsx' => 'typescript',
      'py' => 'python',
      'kt' => 'kotlin',
      'rs' => 'rust',
      'yml' => 'yaml',
      _ => lang,
    };
    if (_ReaderViewState._highlightLanguages.contains(normalized)) {
      return normalized;
    }
  }
  return null;
}

class _ReaderMathNode extends StatelessWidget {
  const _ReaderMathNode({required this.expression, required this.display});

  final String expression;
  final bool display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.fleurReader.bodyStyle.copyWith(
      color: theme.colorScheme.onSurface,
    );
    final math = flutter_math.Math.tex(
      expression,
      key: const Key('reader_math_node'),
      mathStyle: display
          ? flutter_math.MathStyle.display
          : flutter_math.MathStyle.text,
      textStyle: textStyle,
      onErrorFallback: (_) => Text(
        expression,
        key: const Key('reader_math_fallback'),
        style: textStyle.copyWith(fontFamily: 'monospace'),
      ),
    );

    if (!display) {
      return math;
    }

    return Container(
      key: const Key('reader_math_block'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.fleurReader.codeBlockSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.fleurSurface.subtleDivider),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: math,
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

@visibleForTesting
String normalizeReaderHtmlForDisplay(String html) {
  if (html.trim().isEmpty) return '';
  final fragment = html_parser.parseFragment(html);

  void visit(dom.Node node) {
    if (node is dom.Element && _skipMathNormalizationInside(node)) {
      return;
    }

    final children = List<dom.Node>.from(node.nodes);
    for (final child in children) {
      if (child is dom.Text) {
        _replaceMathTextNode(child);
      } else {
        visit(child);
      }
    }
  }

  visit(fragment);
  return fragment.outerHtml;
}

bool _skipMathNormalizationInside(dom.Element element) {
  final tag = element.localName?.toLowerCase();
  return tag == 'pre' || tag == 'code' || tag == 'a' || tag == 'fleur-math';
}

void _replaceMathTextNode(dom.Text node) {
  final text = node.text;
  if (!_mayContainMathDelimiter(text)) return;
  final parent = node.parent;
  if (parent == null) return;
  final index = parent.nodes.indexOf(node);
  if (index < 0) return;

  final replacements = _parseMathText(text);
  if (replacements == null) return;
  parent.nodes.removeAt(index);
  parent.nodes.insertAll(index, replacements);
}

bool _mayContainMathDelimiter(String text) {
  return text.contains(r'$') || text.contains(r'\(') || text.contains(r'\[');
}

List<dom.Node>? _parseMathText(String text) {
  final nodes = <dom.Node>[];
  var cursor = 0;
  var found = false;

  while (cursor < text.length) {
    final match = _findNextMath(text, cursor);
    if (match == null) break;
    if (match.start > cursor) {
      nodes.add(dom.Text(text.substring(cursor, match.start)));
    }
    nodes.add(_buildMathElement(match.expression, display: match.display));
    found = true;
    cursor = match.end;
  }

  if (!found) return null;
  if (cursor < text.length) {
    nodes.add(dom.Text(text.substring(cursor)));
  }
  return nodes;
}

_MathMatch? _findNextMath(String text, int start) {
  _MathMatch? best;
  for (final opener in const [r'$$', r'\[', r'\(', r'$']) {
    final candidate = _findMathWithOpener(text, start, opener);
    if (candidate == null) continue;
    if (best == null || candidate.start < best.start) {
      best = candidate;
    }
  }
  return best;
}

_MathMatch? _findMathWithOpener(String text, int start, String opener) {
  final openIndex = _indexOfUnescaped(text, opener, start);
  if (openIndex < 0) return null;
  if (opener == r'$' && _isDoubleDollarAt(text, openIndex)) {
    return null;
  }

  final closer = switch (opener) {
    r'$$' => r'$$',
    r'\[' => r'\]',
    r'\(' => r'\)',
    _ => r'$',
  };
  final closeStart = openIndex + opener.length;
  final closeIndex = _indexOfUnescaped(text, closer, closeStart);
  if (closeIndex < 0) return null;
  if (closer == r'$' && _isDoubleDollarAt(text, closeIndex)) {
    return null;
  }

  final expression = text.substring(closeStart, closeIndex).trim();
  if (expression.isEmpty) return null;
  return _MathMatch(
    start: openIndex,
    end: closeIndex + closer.length,
    expression: expression,
    display: opener == r'$$' || opener == r'\[',
  );
}

int _indexOfUnescaped(String text, String pattern, int start) {
  var index = text.indexOf(pattern, start);
  while (index >= 0) {
    if (!_isEscaped(text, index)) return index;
    index = text.indexOf(pattern, index + pattern.length);
  }
  return -1;
}

bool _isEscaped(String text, int index) {
  var count = 0;
  for (var i = index - 1; i >= 0 && text.codeUnitAt(i) == 92; i--) {
    count++;
  }
  return count.isOdd;
}

bool _isDoubleDollarAt(String text, int index) {
  return index + 1 < text.length &&
      text.codeUnitAt(index) == 36 &&
      text.codeUnitAt(index + 1) == 36;
}

dom.Element _buildMathElement(String expression, {required bool display}) {
  return dom.Element.tag('fleur-math')
    ..attributes['data-fleur-math'] = expression
    ..attributes['data-fleur-math-display'] = display ? 'block' : 'inline'
    ..text = expression;
}

class _MathMatch {
  const _MathMatch({
    required this.start,
    required this.end,
    required this.expression,
    required this.display,
  });

  final int start;
  final int end;
  final String expression;
  final bool display;
}

String? _codeLanguage(dom.Element element) {
  final dataLanguage = element.attributes['data-language']?.trim();
  if (dataLanguage != null && dataLanguage.isNotEmpty) return dataLanguage;
  final rawClass = element.attributes['class'] ?? '';
  for (final part in rawClass.split(RegExp(r'\s+'))) {
    if (part.startsWith('language-')) {
      return part.substring('language-'.length);
    }
  }
  return null;
}

String? _mediaSourceForElement(dom.Element element) {
  final direct = element.attributes['src']?.trim();
  if (direct != null && direct.isNotEmpty) return direct;
  final source = element.querySelector('source[src]');
  final nested = source?.attributes['src']?.trim();
  return nested == null || nested.isEmpty ? null : nested;
}
