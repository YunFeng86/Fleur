import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;

enum ReaderCodeSourceKind {
  htmlTokens,
  internalTokenizer,
  syntaxHighlightFallback,
  plainText,
}

enum ReaderCodeTokenRole {
  plain,
  keyword,
  string,
  number,
  comment,
  function,
  type,
  property,
  variable,
  constant,
  tag,
  attribute,
  operator,
  punctuation,
  builtin,
  regex,
  namespace,
  diffInserted,
  diffDeleted,
  searchMatch,
  searchCurrent,
}

enum ReaderCodeLanguageDecisionSource {
  codeDataLanguage,
  codeClass,
  preDataLanguage,
  preClass,
  metadata,
  shebang,
  contentHeuristic,
  plainFallback,
  none,
}

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
  const ReaderCodeRenderResult({required this.document});

  final ReaderCodeDocument document;

  String get text => document.text;
  String? get language => document.language?.id;
  ReaderCodeSourceKind get sourceKind => document.sourceKind;
  List<ReaderCodeSearchRange> get searchRanges => document.searchRanges;
}

final class ReaderCodeExtraction {
  const ReaderCodeExtraction({
    required this.text,
    required this.searchRanges,
    required this.tokens,
    required this.hasTokenStyles,
  });

  final String text;
  final List<ReaderCodeSearchRange> searchRanges;
  final List<ReaderCodeToken> tokens;
  final bool hasTokenStyles;
}

final class ReaderCodeDocument {
  const ReaderCodeDocument({
    required this.text,
    required this.language,
    required this.languageDecision,
    required this.sourceKind,
    required this.lines,
    required this.searchRanges,
  });

  factory ReaderCodeDocument.fromTokens({
    required String text,
    required ReaderCodeLanguage? language,
    ReaderCodeLanguageDecision? languageDecision,
    required ReaderCodeSourceKind sourceKind,
    required List<ReaderCodeToken> tokens,
    required List<ReaderCodeSearchRange> searchRanges,
  }) {
    final decision =
        languageDecision ?? ReaderCodeLanguageDecision.fromLanguage(language);
    return ReaderCodeDocument(
      text: text,
      language: decision.language,
      languageDecision: decision,
      sourceKind: sourceKind,
      lines: ReaderCodeLine.split(text: text, tokens: tokens),
      searchRanges: searchRanges,
    );
  }

  final String text;
  final ReaderCodeLanguage? language;
  final ReaderCodeLanguageDecision languageDecision;
  final ReaderCodeSourceKind sourceKind;
  final List<ReaderCodeLine> lines;
  final List<ReaderCodeSearchRange> searchRanges;
}

final class ReaderCodeLine {
  const ReaderCodeLine({
    required this.number,
    required this.start,
    required this.end,
    required this.tokens,
  });

  static List<ReaderCodeLine> split({
    required String text,
    required List<ReaderCodeToken> tokens,
  }) {
    final lines = <ReaderCodeLine>[];
    var start = 0;
    var number = 1;
    while (true) {
      final newline = text.indexOf('\n', start);
      final end = newline < 0 ? text.length : newline;
      lines.add(
        ReaderCodeLine(
          number: number,
          start: start,
          end: end,
          tokens: _tokensForLine(tokens, start, end),
        ),
      );
      if (newline < 0) break;
      start = newline + 1;
      number++;
    }
    return lines.isEmpty
        ? const [ReaderCodeLine(number: 1, start: 0, end: 0, tokens: [])]
        : lines;
  }

  static List<ReaderCodeToken> _tokensForLine(
    List<ReaderCodeToken> tokens,
    int lineStart,
    int lineEnd,
  ) {
    final lineTokens = <ReaderCodeToken>[];
    for (final token in tokens) {
      if (token.end <= lineStart) continue;
      if (token.start >= lineEnd) break;
      final start = token.start.clamp(lineStart, lineEnd);
      final end = token.end.clamp(lineStart, lineEnd);
      if (start == end) continue;
      lineTokens.add(
        token.copyWith(
          text: token.text.substring(start - token.start, end - token.start),
          start: start,
          end: end,
        ),
      );
    }
    return lineTokens;
  }

  final int number;
  final int start;
  final int end;
  final List<ReaderCodeToken> tokens;
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

final class ReaderCodeToken {
  const ReaderCodeToken({
    required this.text,
    required this.role,
    required this.start,
    required this.end,
    this.colorOverride,
    this.backgroundRole,
  });

  final String text;
  final ReaderCodeTokenRole role;
  final int start;
  final int end;
  final Color? colorOverride;
  final ReaderCodeTokenRole? backgroundRole;

  ReaderCodeToken copyWith({
    String? text,
    ReaderCodeTokenRole? role,
    int? start,
    int? end,
    Color? colorOverride,
    ReaderCodeTokenRole? backgroundRole,
  }) {
    return ReaderCodeToken(
      text: text ?? this.text,
      role: role ?? this.role,
      start: start ?? this.start,
      end: end ?? this.end,
      colorOverride: colorOverride ?? this.colorOverride,
      backgroundRole: backgroundRole ?? this.backgroundRole,
    );
  }
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

final class ReaderCodeLanguageCandidate {
  const ReaderCodeLanguageCandidate({
    required this.raw,
    required this.language,
    required this.confidence,
    required this.source,
    required this.reasons,
    this.isLowValue = false,
  });

  final String raw;
  final ReaderCodeLanguage? language;
  final double confidence;
  final ReaderCodeLanguageDecisionSource source;
  final List<String> reasons;
  final bool isLowValue;
}

final class ReaderCodeLanguageDecision {
  const ReaderCodeLanguageDecision({
    required this.language,
    required this.confidence,
    required this.source,
    required this.reasons,
    required this.candidates,
  });

  factory ReaderCodeLanguageDecision.fromLanguage(
    ReaderCodeLanguage? language,
  ) {
    if (language == null) return none;
    return ReaderCodeLanguageDecision(
      language: language,
      confidence: language.isPlainText ? 0.1 : 1,
      source: language.isPlainText
          ? ReaderCodeLanguageDecisionSource.plainFallback
          : ReaderCodeLanguageDecisionSource.none,
      reasons: const [],
      candidates: const [],
    );
  }

  static const contentHighlightConfidenceThreshold = 0.62;
  static const contentLabelConfidenceThreshold = 0.72;

  static const none = ReaderCodeLanguageDecision(
    language: null,
    confidence: 0,
    source: ReaderCodeLanguageDecisionSource.none,
    reasons: [],
    candidates: [],
  );

  final ReaderCodeLanguage? language;
  final double confidence;
  final ReaderCodeLanguageDecisionSource source;
  final List<String> reasons;
  final List<ReaderCodeLanguageCandidate> candidates;

  bool get isContentHeuristic =>
      source == ReaderCodeLanguageDecisionSource.contentHeuristic;

  bool get shouldHighlight {
    final resolved = language;
    if (resolved == null || resolved.isPlainText) return false;
    return !isContentHeuristic ||
        confidence >= contentHighlightConfidenceThreshold;
  }

  bool get shouldDisplayLabel {
    final resolved = language;
    if (resolved == null || resolved.isPlainText) return false;
    return !isContentHeuristic || confidence >= contentLabelConfidenceThreshold;
  }
}
