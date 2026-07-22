import 'package:html/dom.dart' as dom;

import '../../../services/reader_search_service.dart';
import 'reader_code_models.dart';
import 'reader_code_scope_mapper.dart';

final class ReaderCodeHtmlRenderer {
  const ReaderCodeHtmlRenderer({
    ReaderCodeScopeMapper scopeMapper = const ReaderCodeScopeMapper(),
  }) : _scopeMapper = scopeMapper;

  final ReaderCodeScopeMapper _scopeMapper;

  ReaderCodeExtraction extract(dom.Element source) {
    final buffer = StringBuffer();
    final ranges = <ReaderCodeSearchRange>[];
    final tokens = <ReaderCodeToken>[];
    var lastIsNewline = false;
    var hasTokenStyles = false;

    void writeText(String text, ReaderCodeScopeStyle? style) {
      final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      if (normalized.isEmpty) return;
      final start = buffer.length;
      buffer.write(normalized);
      tokens.add(
        ReaderCodeToken(
          text: normalized,
          role: style?.role ?? ReaderCodeTokenRole.plain,
          start: start,
          end: start + normalized.length,
          colorOverride: style?.colorOverride,
        ),
      );
      if (style != null &&
          (style.role != ReaderCodeTokenRole.plain ||
              style.colorOverride != null)) {
        hasTokenStyles = true;
      }
      lastIsNewline = normalized.endsWith('\n');
    }

    void writeNewline() {
      buffer.write('\n');
      lastIsNewline = true;
    }

    void writeLineBoundary(int startLength) {
      if (buffer.length == startLength || !lastIsNewline) {
        writeNewline();
      }
    }

    bool isSearchMark(dom.Element element) {
      return element.localName == 'mark' &&
          element.attributes[ReaderSearchService.markerAttribute] ==
              ReaderSearchService.markerAttributeValue;
    }

    bool isLineElement(dom.Element element) {
      final tag = element.localName;
      return element.classes.contains('token-line') ||
          element.classes.contains('line') ||
          element.attributes.containsKey('data-line') ||
          tag == 'div' ||
          tag == 'p' ||
          tag == 'li';
    }

    void visit(dom.Node node, ReaderCodeScopeStyle? inheritedStyle) {
      if (node is dom.Text) {
        writeText(node.text, inheritedStyle);
        return;
      }
      if (node is! dom.Element) return;

      if (node.localName == 'br') {
        writeNewline();
        return;
      }

      final style = _styleForElement(node, inheritedStyle);
      if (style != null &&
          style != inheritedStyle &&
          (style.role != ReaderCodeTokenRole.plain ||
              style.colorOverride != null)) {
        hasTokenStyles = true;
      }

      final startLength = buffer.length;
      if (isSearchMark(node)) {
        for (final child in node.nodes) {
          visit(child, style);
        }
        final id =
            (node.attributes[ReaderSearchService.markerAnchorAttribute] ??
                    node.id)
                .trim();
        if (id.isNotEmpty && buffer.length > startLength) {
          ranges.add(
            ReaderCodeSearchRange(
              anchorId: id,
              start: startLength,
              end: buffer.length,
            ),
          );
        }
        return;
      }

      for (final child in node.nodes) {
        visit(child, style);
      }
      if (isLineElement(node)) {
        writeLineBoundary(startLength);
      }
    }

    for (final child in source.nodes) {
      visit(child, null);
    }

    var text = buffer.toString();
    var normalizedTokens = tokens;
    if (text.endsWith('\n')) {
      text = text.substring(0, text.length - 1);
      normalizedTokens = _trimTrailingNewline(normalizedTokens);
    }
    return ReaderCodeExtraction(
      text: text,
      searchRanges: ranges,
      tokens: normalizedTokens,
      hasTokenStyles: hasTokenStyles,
    );
  }

  static List<ReaderCodeToken> _trimTrailingNewline(
    List<ReaderCodeToken> tokens,
  ) {
    if (tokens.isEmpty) return tokens;
    final last = tokens.last;
    if (!last.text.endsWith('\n')) return tokens;
    final next = [...tokens]..removeLast();
    final text = last.text.substring(0, last.text.length - 1);
    if (text.isNotEmpty) {
      next.add(last.copyWith(text: text, end: last.end - 1));
    }
    return next;
  }

  ReaderCodeScopeStyle? _styleForElement(
    dom.Element element,
    ReaderCodeScopeStyle? inheritedStyle,
  ) {
    final tokenStyle = _scopeMapper.styleFor(
      classes: element.classes,
      inlineStyle: element.attributes['style'],
    );
    final style = _mergeStyles(inheritedStyle, tokenStyle);
    return style;
  }

  static ReaderCodeScopeStyle? _mergeStyles(
    ReaderCodeScopeStyle? base,
    ReaderCodeScopeStyle? overlay,
  ) {
    if (base == null) return overlay;
    if (overlay == null) return base;
    return base.copyWith(
      role: overlay.role,
      colorOverride: overlay.colorOverride,
    );
  }
}
