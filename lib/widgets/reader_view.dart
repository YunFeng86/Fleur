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
import '../providers/reader_document_providers.dart';
import '../providers/reader_search_providers.dart';
import '../providers/reader_providers.dart';
import '../providers/query_providers.dart';
import '../providers/service_providers.dart';
import '../providers/settings_providers.dart';
import '../services/cache/image_meta_store.dart';
import '../services/reader_document/reader_document_handle.dart';
import '../services/reader_document/reader_document_models.dart';
import '../services/reader_html_normalizer.dart' as reader_html;
import '../services/reader_search_service.dart';
import '../services/settings/app_settings.dart';
import '../services/settings/reader_settings.dart';
import '../services/settings/reader_progress_store.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../utils/content_hash.dart';
import '../utils/platform.dart';
import '../utils/language_utils.dart';
import '../ui/layout.dart';
import '../ui/app_drawer_scope.dart';
import '../ui/workspace_layers.dart';
import '../ui/reader/code_rendering/reader_code_rendering.dart';
import '../ui/reader/reader_selectable_rich_text.dart';
import '../ui/settings/widgets/section_header.dart';

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
  ReaderDocumentHandle? _lastScheduledSearchDocumentHandle;
  ReaderDocumentKey? _lastScheduledSearchDocumentKey;
  bool _searchDocumentSyncScheduled = false;
  static const double _autoScrollDeadZone = 6;
  static const double _autoScrollSpeedFactor = 0.12;

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
    _sessionCoordinator = _ReaderSessionCoordinator(owner: this);
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

  void _scheduleSearchDocumentSync(ReaderDocumentHandle handle) {
    final key = handle.snapshot.documentKey;
    if (_lastScheduledSearchDocumentKey == key &&
        identical(_lastScheduledSearchDocumentHandle, handle)) {
      return;
    }
    _lastScheduledSearchDocumentKey = key;
    _lastScheduledSearchDocumentHandle = handle;
    if (_searchDocumentSyncScheduled) return;
    _searchDocumentSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchDocumentSyncScheduled = false;
      if (!mounted) return;
      final nextHandle = _lastScheduledSearchDocumentHandle;
      if (nextHandle == null) return;
      ref
          .read(readerSearchControllerProvider(widget.articleId).notifier)
          .setDocumentHandle(nextHandle);
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
        final settings = settingsAsync.valueOrNull ?? const ReaderSettings();
        final sceneTheme = AppTheme.readerScene(baseTheme, settings: settings);
        final readerTokens = sceneTheme.fleurReader;
        if (article == null) {
          return FleurEmptyState(
            variant: FleurEmptyStateVariant.reader,
            icon: FleurIcons.article,
            title: l10n.notFound,
            subtitle: l10n.articleNotFoundSubtitle,
          );
        }

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
  Future<bool> onTapUrl(String url) {
    if (url.startsWith('#') && url.length > 1) {
      return onTapAnchorWrapper(url.substring(1));
    }
    return super.onTapUrl(url);
  }

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
    final clampMinimumFontSize = !_isInsideCodeLikeElement(tree.element);
    final textStyle = clampMinimumFontSize
        ? _applyMinimumFontSize(resolved.prepareTextStyle())
        : resolved.prepareTextStyle();
    final effectiveText = clampMinimumFontSize
        ? _applyMinimumFontSizeToSpan(text)
        : text;
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
          text: effectiveText,
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

  TextStyle _applyMinimumFontSize(TextStyle style) {
    final minimum = _settings.minimumFontSize.clamp(10, 18).toDouble();
    final current = style.fontSize;
    if (current == null || current >= minimum) return style;
    return style.copyWith(fontSize: minimum);
  }

  InlineSpan _applyMinimumFontSizeToSpan(InlineSpan span) {
    if (span is! TextSpan) return span;
    return TextSpan(
      text: span.text,
      children: span.children
          ?.map(_applyMinimumFontSizeToSpan)
          .toList(growable: false),
      style: span.style == null ? null : _applyMinimumFontSize(span.style!),
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel,
      semanticsIdentifier: span.semanticsIdentifier,
      locale: span.locale,
      spellOut: span.spellOut,
    );
  }

  bool _isInsideCodeLikeElement(dom.Element element) {
    dom.Element? current = element;
    while (current != null) {
      final localName = current.localName;
      if (localName == 'pre' ||
          localName == 'code' ||
          localName == 'fleur-math') {
        return true;
      }
      current = current.parent;
    }
    return false;
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

class _ReaderInertButton extends StatelessWidget {
  const _ReaderInertButton({required this.element});

  final dom.Element element;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _controlLabel(element, fallback: 'Button');
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Container(
          key: const Key('reader_inert_button'),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.fleurReader.codeBlockSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.fleurSurface.subtleDivider),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: AppTypography.platformWeight(FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderInertInput extends StatelessWidget {
  const _ReaderInertInput({required this.element});

  final dom.Element element;

  @override
  Widget build(BuildContext context) {
    final type = (element.attributes['type'] ?? 'text').trim().toLowerCase();
    return type == 'color'
        ? _ReaderInertColorInput(element: element)
        : _ReaderInertTextInput(element: element, type: type);
  }
}

class _ReaderInertColorInput extends StatelessWidget {
  const _ReaderInertColorInput({required this.element});

  final dom.Element element;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = (element.attributes['value'] ?? '').trim();
    final color = _parseHexColor(value);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Container(
          key: const Key('reader_inert_color_input'),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: theme.fleurReader.codeBlockSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.fleurSurface.subtleDivider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: theme.fleurSurface.subtleDivider),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                value.isEmpty ? 'color' : value,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderInertTextInput extends StatelessWidget {
  const _ReaderInertTextInput({required this.element, required this.type});

  final dom.Element element;
  final String type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = (element.attributes['value'] ?? '').trim();
    final label = value.isEmpty
        ? _controlLabel(element, fallback: type.isEmpty ? 'input' : type)
        : value;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Container(
          key: const Key('reader_inert_input'),
          constraints: const BoxConstraints(maxWidth: 180),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: theme.fleurReader.codeBlockSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.fleurSurface.subtleDivider),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

String _controlLabel(dom.Element element, {required String fallback}) {
  for (final value in [
    element.text,
    element.attributes['aria-label'],
    element.attributes['title'],
    element.attributes['value'],
  ]) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return fallback;
}

Color? _parseHexColor(String value) {
  final normalized = value.trim().toLowerCase();
  final match = RegExp(r'^#([0-9a-f]{6})$').firstMatch(normalized);
  if (match == null) return null;
  return Color(int.parse('ff${match.group(1)}', radix: 16));
}

class _ReaderCodeBlock extends StatefulWidget {
  const _ReaderCodeBlock({
    super.key,
    required this.source,
    required this.pre,
    required this.fontSize,
    required this.currentAnchorId,
  });

  final dom.Element source;
  final dom.Element pre;
  final double fontSize;
  final String? currentAnchorId;

  @override
  State<_ReaderCodeBlock> createState() => _ReaderCodeBlockState();
}

class _ReaderCodeBlockState extends State<_ReaderCodeBlock> {
  Future<ReaderCodeRenderResult>? _renderFuture;
  final ReaderCodeRenderer _renderer = const ReaderCodeRenderer();
  Brightness? _highlightBrightness;
  dom.Element? _highlightSource;
  dom.Element? _highlightPre;
  double? _highlightFontSize;
  String? _highlightCurrentAnchorId;
  _ReaderCodeFallbackCacheKey? _fallbackCacheKey;
  ReaderCodeRenderResult? _fallbackCache;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshHighlightFuture();
  }

  @override
  void didUpdateWidget(covariant _ReaderCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.source, widget.source) ||
        !identical(oldWidget.pre, widget.pre) ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.currentAnchorId != widget.currentAnchorId) {
      _refreshHighlightFuture();
    }
  }

  void _refreshHighlightFuture() {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    if (_renderFuture != null &&
        _highlightBrightness == brightness &&
        identical(_highlightSource, widget.source) &&
        identical(_highlightPre, widget.pre) &&
        _highlightFontSize == widget.fontSize &&
        _highlightCurrentAnchorId == widget.currentAnchorId) {
      return;
    }
    _highlightBrightness = brightness;
    _highlightSource = widget.source;
    _highlightPre = widget.pre;
    _highlightFontSize = widget.fontSize;
    _highlightCurrentAnchorId = widget.currentAnchorId;
    _renderFuture = _renderer.render(
      ReaderCodeRenderInput(
        source: widget.source,
        pre: widget.pre,
        baseStyle: _codeStyle(context),
        activeSearchBackground: theme.fleurState.selectionTint.withValues(
          alpha: 0.95,
        ),
        searchBackground: theme.fleurReader.bannerSurface.withValues(
          alpha: 0.8,
        ),
        errorColor: theme.colorScheme.error,
        brightness: brightness,
        maxHighlightedCodeLength: _maxHighlightedCodeLength,
        currentAnchorId: widget.currentAnchorId,
      ),
    );
  }

  ReaderCodeRenderResult _fallbackResult() {
    final key = _ReaderCodeFallbackCacheKey(
      source: widget.source,
      pre: widget.pre,
      currentAnchorId: widget.currentAnchorId,
    );
    final cached = _fallbackCache;
    if (cached != null && _fallbackCacheKey == key) {
      return cached;
    }

    final extraction = const ReaderCodeHtmlRenderer().extract(widget.source);
    final languageDecision = const ReaderCodeLanguageResolver()
        .resolveForCodeBlock(
          source: widget.source,
          pre: widget.pre,
          text: extraction.text,
          hasUpstreamTokenStyles: extraction.hasTokenStyles,
        );
    final language = languageDecision.language;
    final tokens = applyReaderCodeSearchTokenOverlay(
      extraction.tokens,
      searchRanges: extraction.searchRanges,
      currentAnchorId: widget.currentAnchorId,
    );
    final result = ReaderCodeRenderResult(
      document: ReaderCodeDocument.fromTokens(
        text: extraction.text,
        language: language,
        languageDecision: languageDecision,
        sourceKind: extraction.hasTokenStyles
            ? ReaderCodeSourceKind.htmlTokens
            : ReaderCodeSourceKind.plainText,
        tokens: tokens,
        searchRanges: extraction.searchRanges,
      ),
    );
    _fallbackCacheKey = key;
    _fallbackCache = result;
    return result;
  }

  void _scheduleCodeSearchReveal(ReaderCodeRenderResult result) {
    final currentAnchorId = widget.currentAnchorId;
    if (currentAnchorId == null) return;
    if (!result.searchRanges.any(
      (range) => range.anchorId == currentAnchorId,
    )) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ReaderViewportChunkCoordinator.revealCodeSearchContext(context);
    });
  }

  void _registerCodeSearchAnchors(ReaderCodeRenderResult result) {
    _ReaderViewportChunkCoordinator.registerCodeSearchAnchors(
      context,
      result.searchRanges,
    );
  }

  TextStyle _codeStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.fleurReader.codeStyle.copyWith(
      color: theme.colorScheme.onSurface,
      decoration: TextDecoration.none,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _fallbackResult();
    return FutureBuilder<ReaderCodeRenderResult>(
      future: _renderFuture,
      initialData: fallback,
      builder: (context, snapshot) {
        final result = snapshot.connectionState == ConnectionState.done
            ? snapshot.data ?? fallback
            : fallback;
        _registerCodeSearchAnchors(result);
        _scheduleCodeSearchReveal(result);
        return ReaderCodeBlockChrome(
          document: result.document,
          codeStyle: _codeStyle(context),
          softWrap: Theme.of(context).fleurReader.codeSoftWrap,
        );
      },
    );
  }
}

@immutable
class _ReaderCodeFallbackCacheKey {
  const _ReaderCodeFallbackCacheKey({
    required this.source,
    required this.pre,
    required this.currentAnchorId,
  });

  final dom.Element source;
  final dom.Element pre;
  final String? currentAnchorId;

  @override
  bool operator ==(Object other) {
    return other is _ReaderCodeFallbackCacheKey &&
        identical(source, other.source) &&
        identical(pre, other.pre) &&
        currentAnchorId == other.currentAnchorId;
  }

  @override
  int get hashCode => Object.hash(
    identityHashCode(source),
    identityHashCode(pre),
    currentAnchorId,
  );
}

const int _maxHighlightedCodeLength = 20000;

class _ReaderMathNode extends StatelessWidget {
  const _ReaderMathNode({required this.expression, required this.display});

  final String expression;
  final bool display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.fleurReader.mathStyle.copyWith(
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
        style: theme.fleurReader.mathFallbackStyle.copyWith(
          color: theme.colorScheme.onSurface,
        ),
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
  return reader_html.normalizeReaderHtmlForDisplay(html);
}

String? _mediaSourceForElement(dom.Element element) {
  final direct = element.attributes['src']?.trim();
  if (direct != null && direct.isNotEmpty) return direct;
  final source = element.querySelector('source[src]');
  final nested = source?.attributes['src']?.trim();
  return nested == null || nested.isEmpty ? null : nested;
}
