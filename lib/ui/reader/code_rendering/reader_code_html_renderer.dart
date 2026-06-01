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
    final tokens = <ReaderCodeToken>[];
    var lastIsNewline = false;
    var hasTokenStyles = false;

    void writeText(String text, _ReaderCodeImportedStyle? style) {
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

    void visit(dom.Node node, _ReaderCodeImportedStyle? inheritedStyle) {
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

  TextSpan spanFromExtraction(
    ReaderCodeExtraction extraction,
    TextStyle baseStyle,
  ) {
    return TextSpan(
      style: baseStyle,
      children: [
        for (final token in extraction.tokens)
          TextSpan(text: token.text, style: _styleForToken(token, baseStyle)),
      ],
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

  static _ReaderCodeImportedStyle? _styleForElement(
    dom.Element element,
    _ReaderCodeImportedStyle? inheritedStyle,
  ) {
    final inlineColor = _inlineColor(element.attributes['style']);
    final tokenStyle = _tokenRole(element.classes);
    final style = _mergeStyles(inheritedStyle, tokenStyle);
    if (inlineColor == null) return style;
    return (style ?? const _ReaderCodeImportedStyle()).copyWith(
      colorOverride: inlineColor,
    );
  }

  static _ReaderCodeImportedStyle? _mergeStyles(
    _ReaderCodeImportedStyle? base,
    _ReaderCodeImportedStyle? overlay,
  ) {
    if (base == null) return overlay;
    if (overlay == null) return base;
    return base.copyWith(
      role: overlay.role,
      colorOverride: overlay.colorOverride,
    );
  }

  static _ReaderCodeImportedStyle? _tokenRole(Set<String> classes) {
    if (classes.contains('token')) {
      if (classes.contains('comment') || classes.contains('prolog')) {
        return const _ReaderCodeImportedStyle(
          role: ReaderCodeTokenRole.comment,
        );
      }
      if (classes.contains('cdata') || classes.contains('doctype')) {
        return const _ReaderCodeImportedStyle(
          role: ReaderCodeTokenRole.comment,
        );
      }
      if (classes.contains('plain') || classes.contains('plain-text')) {
        return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.plain);
      }
      if (classes.contains('keyword') ||
          classes.contains('module') ||
          classes.contains('selector') ||
          classes.contains('important')) {
        return const _ReaderCodeImportedStyle(
          role: ReaderCodeTokenRole.keyword,
        );
      }
      if (classes.contains('string') ||
          classes.contains('char') ||
          classes.contains('string-property') ||
          classes.contains('attr-value')) {
        return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.string);
      }
      if (classes.contains('number') || classes.contains('boolean')) {
        return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.number);
      }
      if (classes.contains('constant')) {
        return const _ReaderCodeImportedStyle(
          role: ReaderCodeTokenRole.constant,
        );
      }
      if (classes.contains('symbol')) {
        return const _ReaderCodeImportedStyle(
          role: ReaderCodeTokenRole.constant,
        );
      }
      if (classes.contains('attr-name')) {
        return const _ReaderCodeImportedStyle(
          role: ReaderCodeTokenRole.attribute,
        );
      }
      if (classes.contains('property') ||
          classes.contains('key') ||
          classes.contains('literal-property')) {
        return const _ReaderCodeImportedStyle(
          role: ReaderCodeTokenRole.property,
        );
      }
      if (classes.contains('function')) {
        return const _ReaderCodeImportedStyle(
          role: ReaderCodeTokenRole.function,
        );
      }
      if (classes.contains('class-name') ||
          classes.contains('maybe-class-name')) {
        return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.type);
      }
      if (classes.contains('tag')) {
        return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.tag);
      }
      if (classes.contains('builtin') || classes.contains('known-class-name')) {
        return const _ReaderCodeImportedStyle(
          role: ReaderCodeTokenRole.builtin,
        );
      }
      if (classes.contains('variable') ||
          classes.contains('parameter') ||
          classes.contains('imports')) {
        return const _ReaderCodeImportedStyle(
          role: ReaderCodeTokenRole.variable,
        );
      }
      if (classes.contains('regex')) {
        return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.regex);
      }
      if (classes.contains('namespace')) {
        return const _ReaderCodeImportedStyle(
          role: ReaderCodeTokenRole.namespace,
        );
      }
      if (classes.contains('url')) {
        return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.string);
      }
      if (classes.contains('inserted')) {
        return const _ReaderCodeImportedStyle(
          role: ReaderCodeTokenRole.diffInserted,
        );
      }
      if (classes.contains('deleted')) {
        return const _ReaderCodeImportedStyle(
          role: ReaderCodeTokenRole.diffDeleted,
        );
      }
      if (classes.contains('operator')) {
        return const _ReaderCodeImportedStyle(
          role: ReaderCodeTokenRole.operator,
        );
      }
      if (classes.contains('punctuation')) {
        return const _ReaderCodeImportedStyle(
          role: ReaderCodeTokenRole.punctuation,
        );
      }
      if (classes.contains('entity')) {
        return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.tag);
      }
    }

    if (classes.contains('hljs-comment') || classes.contains('hljs-quote')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.comment);
    }
    if (classes.contains('hljs-keyword') ||
        classes.contains('hljs-meta') ||
        classes.contains('hljs-doctag') ||
        classes.contains('hljs-selector-tag')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.keyword);
    }
    if (classes.contains('hljs-string') ||
        classes.contains('hljs-code') ||
        classes.contains('hljs-template-variable')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.string);
    }
    if (classes.contains('hljs-number') || classes.contains('hljs-literal')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.number);
    }
    if (classes.contains('hljs-attr') || classes.contains('hljs-attribute')) {
      return const _ReaderCodeImportedStyle(
        role: ReaderCodeTokenRole.attribute,
      );
    }
    if (classes.contains('hljs-title') ||
        classes.contains('hljs-title.function') ||
        classes.contains('hljs-section')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.function);
    }
    if (classes.contains('hljs-name') ||
        classes.contains('hljs-type') ||
        classes.contains('hljs-built_in')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.type);
    }
    if (classes.contains('hljs-tag')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.tag);
    }
    if (classes.contains('hljs-variable') ||
        classes.contains('hljs-params') ||
        classes.contains('hljs-symbol') ||
        classes.contains('hljs-bullet')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.variable);
    }
    if (classes.contains('hljs-regexp')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.regex);
    }
    if (classes.contains('hljs-addition')) {
      return const _ReaderCodeImportedStyle(
        role: ReaderCodeTokenRole.diffInserted,
      );
    }
    if (classes.contains('hljs-deletion')) {
      return const _ReaderCodeImportedStyle(
        role: ReaderCodeTokenRole.diffDeleted,
      );
    }
    if (classes.contains('hljs-operator')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.operator);
    }
    if (classes.contains('hljs-punctuation')) {
      return const _ReaderCodeImportedStyle(
        role: ReaderCodeTokenRole.punctuation,
      );
    }
    final githubRole = _githubTokenRole(classes);
    if (githubRole != null) return githubRole;
    return null;
  }

  static _ReaderCodeImportedStyle? _githubTokenRole(Set<String> classes) {
    if (classes.contains('pl-c') || classes.contains('pl-c1-comment')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.comment);
    }
    if (classes.contains('pl-k')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.keyword);
    }
    if (classes.contains('pl-s') ||
        classes.contains('pl-pds') ||
        classes.contains('pl-s1')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.string);
    }
    if (classes.contains('pl-c1') || classes.contains('pl-kos')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.constant);
    }
    if (classes.contains('pl-en')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.function);
    }
    if (classes.contains('pl-ent')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.tag);
    }
    if (classes.contains('pl-e') || classes.contains('pl-v')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.variable);
    }
    if (classes.contains('pl-smi')) {
      return const _ReaderCodeImportedStyle(role: ReaderCodeTokenRole.type);
    }
    return null;
  }

  static TextStyle? _styleForToken(ReaderCodeToken token, TextStyle baseStyle) {
    final color = token.colorOverride ?? _colorForRole(token.role);
    if (color == null) return null;
    return TextStyle(color: color);
  }

  static Color? _colorForRole(ReaderCodeTokenRole role) {
    return switch (role) {
      ReaderCodeTokenRole.keyword => const Color(0xFF00009F),
      ReaderCodeTokenRole.string ||
      ReaderCodeTokenRole.regex => const Color(0xFFE3116C),
      ReaderCodeTokenRole.number ||
      ReaderCodeTokenRole.constant ||
      ReaderCodeTokenRole.property ||
      ReaderCodeTokenRole.attribute => const Color(0xFF36ACAA),
      ReaderCodeTokenRole.comment => const Color(0xFF6A737D),
      ReaderCodeTokenRole.function ||
      ReaderCodeTokenRole.type ||
      ReaderCodeTokenRole.builtin => const Color(0xFFD73A49),
      ReaderCodeTokenRole.tag ||
      ReaderCodeTokenRole.namespace => const Color(0xFF00009F),
      ReaderCodeTokenRole.operator ||
      ReaderCodeTokenRole.punctuation => const Color(0xFF393A34),
      ReaderCodeTokenRole.diffInserted => const Color(0xFF116329),
      ReaderCodeTokenRole.diffDeleted => const Color(0xFFD1242F),
      _ => null,
    };
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

final class _ReaderCodeImportedStyle {
  const _ReaderCodeImportedStyle({
    this.role = ReaderCodeTokenRole.plain,
    this.colorOverride,
  });

  final ReaderCodeTokenRole role;
  final Color? colorOverride;

  _ReaderCodeImportedStyle copyWith({
    ReaderCodeTokenRole? role,
    Color? colorOverride,
  }) {
    return _ReaderCodeImportedStyle(
      role: role ?? this.role,
      colorOverride: colorOverride ?? this.colorOverride,
    );
  }
}
