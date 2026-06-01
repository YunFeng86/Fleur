import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;

import '../../../services/reader_search_service.dart';
import 'reader_code_models.dart';

final class ReaderCodeHtmlRenderer {
  const ReaderCodeHtmlRenderer();

  ReaderCodeExtraction extract(dom.Element source) {
    final buffer = StringBuffer();
    final ranges = <ReaderCodeSearchRange>[];
    final segments = <ReaderCodeSpanSegment>[];
    var lastIsNewline = false;
    var hasTokenStyles = false;

    void writeText(String text, TextStyle? style) {
      final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      if (normalized.isEmpty) return;
      buffer.write(normalized);
      segments.add(ReaderCodeSpanSegment(text: normalized, style: style));
      if (style?.color != null) hasTokenStyles = true;
      lastIsNewline = normalized.endsWith('\n');
    }

    void writeNewline() {
      buffer.write('\n');
      segments.add(const ReaderCodeSpanSegment(text: '\n', style: null));
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

    void visit(dom.Node node, TextStyle? inheritedStyle) {
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
      if (style?.color != null && style != inheritedStyle) {
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
    var normalizedSegments = segments;
    if (text.endsWith('\n')) {
      text = text.substring(0, text.length - 1);
      normalizedSegments = _trimTrailingNewline(normalizedSegments);
    }
    return ReaderCodeExtraction(
      text: text,
      searchRanges: ranges,
      spans: normalizedSegments,
      hasTokenStyles: hasTokenStyles,
    );
  }

  TextSpan spanFromExtraction(
    ReaderCodeExtraction extraction,
    TextStyle baseStyle,
  ) {
    return TextSpan(
      style: baseStyle,
      children: [
        for (final segment in extraction.spans)
          TextSpan(text: segment.text, style: segment.style),
      ],
    );
  }

  static List<ReaderCodeSpanSegment> _trimTrailingNewline(
    List<ReaderCodeSpanSegment> segments,
  ) {
    if (segments.isEmpty) return segments;
    final last = segments.last;
    if (!last.text.endsWith('\n')) return segments;
    final next = [...segments]..removeLast();
    final text = last.text.substring(0, last.text.length - 1);
    if (text.isNotEmpty) {
      next.add(ReaderCodeSpanSegment(text: text, style: last.style));
    }
    return next;
  }

  static TextStyle? _styleForElement(
    dom.Element element,
    TextStyle? inheritedStyle,
  ) {
    final inlineColor = _inlineColor(element.attributes['style']);
    final tokenStyle = _tokenStyle(element.classes);
    final style = _mergeStyles(inheritedStyle, tokenStyle);
    if (inlineColor == null) return style;
    return (style ?? const TextStyle()).copyWith(color: inlineColor);
  }

  static TextStyle? _mergeStyles(TextStyle? base, TextStyle? overlay) {
    if (base == null) return overlay;
    if (overlay == null) return base;
    return base.merge(overlay);
  }

  static TextStyle? _tokenStyle(Set<String> classes) {
    final color = _tokenColor(classes);
    return color == null ? null : TextStyle(color: color);
  }

  static Color? _tokenColor(Set<String> classes) {
    if (classes.contains('token')) {
      if (classes.contains('comment') || classes.contains('prolog')) {
        return const Color(0xFF6A737D);
      }
      if (classes.contains('keyword') || classes.contains('selector')) {
        return const Color(0xFF00009F);
      }
      if (classes.contains('string') || classes.contains('attr-value')) {
        return const Color(0xFFE3116C);
      }
      if (classes.contains('number') ||
          classes.contains('boolean') ||
          classes.contains('constant') ||
          classes.contains('property') ||
          classes.contains('attr-name')) {
        return const Color(0xFF36ACAA);
      }
      if (classes.contains('function') || classes.contains('class-name')) {
        return const Color(0xFFD73A49);
      }
      if (classes.contains('tag')) return const Color(0xFF00009F);
      if (classes.contains('operator') || classes.contains('punctuation')) {
        return const Color(0xFF393A34);
      }
    }

    if (classes.contains('hljs-comment') || classes.contains('hljs-quote')) {
      return const Color(0xFF6A737D);
    }
    if (classes.contains('hljs-keyword') ||
        classes.contains('hljs-selector-tag')) {
      return const Color(0xFF00009F);
    }
    if (classes.contains('hljs-string') ||
        classes.contains('hljs-template-variable')) {
      return const Color(0xFFE3116C);
    }
    if (classes.contains('hljs-number') ||
        classes.contains('hljs-literal') ||
        classes.contains('hljs-attr') ||
        classes.contains('hljs-attribute')) {
      return const Color(0xFF36ACAA);
    }
    if (classes.contains('hljs-title') ||
        classes.contains('hljs-name') ||
        classes.contains('hljs-section')) {
      return const Color(0xFFD73A49);
    }
    if (classes.contains('hljs-tag')) return const Color(0xFF00009F);
    return null;
  }

  static Color? _inlineColor(String? style) {
    if (style == null || style.isEmpty) return null;
    final match = RegExp(
      r'(?:^|;)\s*color\s*:\s*([^;]+)',
      caseSensitive: false,
    ).firstMatch(style);
    final raw = match?.group(1)?.trim();
    if (raw == null || raw.isEmpty) return null;
    return _parseCssColor(raw);
  }

  static Color? _parseCssColor(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.startsWith('#')) return _parseHexColor(value);
    if (value.startsWith('rgb(') || value.startsWith('rgba(')) {
      return _parseRgbColor(value);
    }
    return null;
  }

  static Color? _parseHexColor(String value) {
    final hex = value.substring(1);
    if (hex.length == 3) {
      final expanded = hex.split('').map((c) => '$c$c').join();
      return _parseHexColor('#$expanded');
    }
    if (hex.length != 6) return null;
    final rgb = int.tryParse(hex, radix: 16);
    return rgb == null ? null : Color(0xFF000000 | rgb);
  }

  static Color? _parseRgbColor(String value) {
    final start = value.indexOf('(');
    final end = value.lastIndexOf(')');
    if (start < 0 || end <= start) return null;
    final parts = value
        .substring(start + 1, end)
        .split(',')
        .map((part) => part.trim())
        .toList(growable: false);
    if (parts.length < 3) return null;
    final r = _parseRgbComponent(parts[0]);
    final g = _parseRgbComponent(parts[1]);
    final b = _parseRgbComponent(parts[2]);
    if (r == null || g == null || b == null) return null;
    final alpha = parts.length >= 4 ? _parseAlpha(parts[3]) : 255;
    if (alpha == null) return null;
    return Color.fromARGB(alpha, r, g, b);
  }

  static int? _parseRgbComponent(String value) {
    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) return null;
      return (percent.clamp(0, 100) * 2.55).round();
    }
    final parsed = int.tryParse(value);
    return parsed == null ? null : math.max(0, math.min(255, parsed));
  }

  static int? _parseAlpha(String value) {
    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) return null;
      return (percent.clamp(0, 100) * 2.55).round();
    }
    final parsed = double.tryParse(value);
    if (parsed == null) return null;
    return (parsed.clamp(0, 1) * 255).round();
  }
}
