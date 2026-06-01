import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;

enum ReaderCodeSourceKind { htmlTokens, syntaxHighlight, plainText }

final class ReaderCodeRenderInput {
  const ReaderCodeRenderInput({
    required this.source,
    required this.pre,
    required this.baseStyle,
    required this.activeSearchBackground,
    required this.searchBackground,
    required this.errorColor,
    required this.brightness,
    required this.currentAnchorId,
    this.maxHighlightedCodeLength = 20000,
  });

  final dom.Element source;
  final dom.Element pre;
  final TextStyle baseStyle;
  final Color activeSearchBackground;
  final Color searchBackground;
  final Color errorColor;
  final Brightness brightness;
  final String? currentAnchorId;
  final int maxHighlightedCodeLength;
}

final class ReaderCodeRenderResult {
  const ReaderCodeRenderResult({
    required this.text,
    required this.language,
    required this.sourceKind,
    required this.searchRanges,
    required this.span,
  });

  final String text;
  final String? language;
  final ReaderCodeSourceKind sourceKind;
  final List<ReaderCodeSearchRange> searchRanges;
  final TextSpan span;
}

final class ReaderCodeExtraction {
  const ReaderCodeExtraction({
    required this.text,
    required this.searchRanges,
    required this.spans,
    required this.hasTokenStyles,
  });

  final String text;
  final List<ReaderCodeSearchRange> searchRanges;
  final List<ReaderCodeSpanSegment> spans;
  final bool hasTokenStyles;
}

final class ReaderCodeSearchRange {
  const ReaderCodeSearchRange({
    required this.anchorId,
    required this.start,
    required this.end,
  });

  final String anchorId;
  final int start;
  final int end;
}

final class ReaderCodeSpanSegment {
  const ReaderCodeSpanSegment({required this.text, required this.style});

  final String text;
  final TextStyle? style;
}

final class ReaderCodeLanguage {
  const ReaderCodeLanguage({
    required this.id,
    this.innerLanguage,
    this.isPlainText = false,
  });

  final String id;
  final String? innerLanguage;
  final bool isPlainText;
}
