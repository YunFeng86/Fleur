import 'reader_code_models.dart';

final class ReaderCodeLanguageGuesser {
  const ReaderCodeLanguageGuesser();

  ReaderCodeLanguage? guess(String code) {
    final candidates = guessCandidates(code);
    return candidates.isEmpty ? null : candidates.first.language;
  }

  List<ReaderCodeLanguageCandidate> guessCandidates(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return const [];

    final lower = trimmed.toLowerCase();
    final candidates = <ReaderCodeLanguageCandidate>[
      if (_looksLikeHtml(trimmed)) _candidate('html', 0.78, ['html:tag']),
      ..._cssCandidates(trimmed, lower),
      if (_looksLikeJson(trimmed)) _candidate('json', 0.78, ['json:key']),
      ..._pythonCandidates(trimmed),
      ..._shellCandidates(trimmed),
      ..._javaScriptCandidates(trimmed),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates;
  }

  static ReaderCodeLanguageCandidate _candidate(
    String id,
    double confidence,
    List<String> reasons,
  ) {
    return ReaderCodeLanguageCandidate(
      raw: id,
      language: ReaderCodeLanguage(id: id),
      confidence: confidence.clamp(0, 0.82).toDouble(),
      source: ReaderCodeLanguageDecisionSource.contentHeuristic,
      reasons: reasons,
    );
  }

  static List<ReaderCodeLanguageCandidate> _cssCandidates(
    String code,
    String lower,
  ) {
    final reasons = <String>[];
    if (lower.contains('contrast-color(')) {
      reasons.add('css:function:contrast-color');
    }
    for (final directive in const ['@container', '@media', '@supports']) {
      if (lower.contains(directive)) reasons.add('css:at-rule:$directive');
    }
    if (RegExp(
      r'(^|[;{\s])--[a-z0-9_-]+\s*:',
      caseSensitive: false,
    ).hasMatch(code)) {
      reasons.add('css:custom-property');
    }
    if (RegExp(
      r'[.#]?[a-z][a-z0-9_-]*\s*\{[^}]*[a-z-]+\s*:',
      caseSensitive: false,
    ).hasMatch(code)) {
      reasons.add('css:rule-with-property');
    }
    if (reasons.isEmpty) return const [];
    final confidence = reasons.contains('css:function:contrast-color')
        ? 0.76
        : 0.5 + reasons.length * 0.12;
    return [_candidate('css', confidence, reasons)];
  }

  static List<ReaderCodeLanguageCandidate> _pythonCandidates(String code) {
    final reasons = <String>[];
    if (RegExp(r'(^|\n)\s*(def|class)\s+\w+', multiLine: true).hasMatch(code)) {
      reasons.add('python:def-or-class');
    }
    if (RegExp(r'(^|\n)\s*(from\s+\w+\s+import|import\s+\w+)').hasMatch(code)) {
      reasons.add('python:import');
    }
    if (RegExp(r'(^|\n)\s*if\s+__name__\s*==').hasMatch(code)) {
      reasons.add('python:main-guard');
    }
    if (reasons.isEmpty) return const [];
    return [_candidate('python', 0.46 + reasons.length * 0.12, reasons)];
  }

  static List<ReaderCodeLanguageCandidate> _shellCandidates(String code) {
    final reasons = <String>[];
    if (RegExp(
      r'(^|\n)\s*(echo|cd|mkdir|rm|cp|mv|grep|curl|wget|npm|pnpm|yarn|flutter|dart)\b',
    ).hasMatch(code)) {
      reasons.add('shell:command');
    }
    if (RegExp(r'(^|\n)\s*[A-Z_][A-Z0-9_]*=.*').hasMatch(code)) {
      reasons.add('shell:environment-assignment');
    }
    if (reasons.isEmpty) return const [];
    return [_candidate('shell', 0.46 + reasons.length * 0.12, reasons)];
  }

  static List<ReaderCodeLanguageCandidate> _javaScriptCandidates(String code) {
    final reasons = <String>[];
    final keywordMatch = RegExp(
      r'\b(const|let|var|function|class|import|export|return|await|async|new)\b',
    ).firstMatch(code);
    if (keywordMatch != null) reasons.add('keyword:${keywordMatch.group(1)}');

    final builtinMatch = RegExp(
      r'\b(console|FinalizationRegistry|WeakRef|WeakSet|WeakMap|Promise|Map|Set|Array|Object)\b',
    ).firstMatch(code);
    if (builtinMatch != null) reasons.add('builtin:${builtinMatch.group(1)}');

    if (RegExp(r'=>').hasMatch(code)) reasons.add('operator:arrow');
    if (RegExp(r'\?\.\w+').hasMatch(code)) {
      reasons.add('operator:optional-chaining');
    }
    if (RegExp(r'\.\w+\s*\(').hasMatch(code)) {
      reasons.add('js:property-call');
    }
    if (RegExp(r'//|/\*').hasMatch(code)) reasons.add('js:comment');
    if (RegExp(r';\s*(\n|$)').hasMatch(code)) reasons.add('js:semicolon');

    if (reasons.length < 2) return const [];
    return [_candidate('javascript', 0.46 + reasons.length * 0.08, reasons)];
  }

  static bool _looksLikeHtml(String code) {
    return RegExp(
      r'</?[a-z][a-z0-9-]*(\s+[^>]*)?>',
      caseSensitive: false,
    ).hasMatch(code);
  }

  static bool _looksLikeJson(String code) {
    if (!((code.startsWith('{') && code.endsWith('}')) ||
        (code.startsWith('[') && code.endsWith(']')))) {
      return false;
    }
    return RegExp(r'"[^"]+"\s*:').hasMatch(code);
  }
}
