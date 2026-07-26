part of '../reader_view.dart';

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
