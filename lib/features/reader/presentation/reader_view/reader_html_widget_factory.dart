part of '../reader_view.dart';

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
