import 'package:html/dom.dart' as dom;

import 'reader_code_language_guesser.dart';
import 'reader_code_models.dart';

final class ReaderCodeLanguageResolver {
  const ReaderCodeLanguageResolver({
    ReaderCodeLanguageCatalog catalog = const ReaderCodeLanguageCatalog(),
    ReaderCodeLanguageGuesser languageGuesser =
        const ReaderCodeLanguageGuesser(),
  }) : _catalog = catalog,
       _languageGuesser = languageGuesser;

  final ReaderCodeLanguageCatalog _catalog;
  final ReaderCodeLanguageGuesser _languageGuesser;

  ReaderCodeLanguage? resolveForElements(dom.Element source, dom.Element pre) {
    return resolveForCodeBlock(
      source: source,
      pre: pre,
      text: source.text,
      hasUpstreamTokenStyles: true,
    ).language;
  }

  ReaderCodeLanguageDecision resolveForCodeBlock({
    required dom.Element source,
    required dom.Element pre,
    required String text,
    required bool hasUpstreamTokenStyles,
  }) {
    final candidates = <ReaderCodeLanguageCandidate>[
      ..._dataLanguageCandidates(
        source,
        source: ReaderCodeLanguageDecisionSource.codeDataLanguage,
        confidence: 1,
        reasonPrefix: 'code:data-language',
      ),
      ..._classCandidates(
        source,
        source: ReaderCodeLanguageDecisionSource.codeClass,
        confidence: 0.98,
        reasonPrefix: 'code:class',
      ),
      if (!identical(source, pre))
        ..._dataLanguageCandidates(
          pre,
          source: ReaderCodeLanguageDecisionSource.preDataLanguage,
          confidence: 0.94,
          reasonPrefix: 'pre:data-language',
        ),
      if (!identical(source, pre))
        ..._classCandidates(
          pre,
          source: ReaderCodeLanguageDecisionSource.preClass,
          confidence: 0.92,
          reasonPrefix: 'pre:class',
        ),
      ..._metaCandidates(source),
      if (!identical(source, pre)) ..._metaCandidates(pre),
      ..._shebangCandidates(text),
    ];

    final explicitDecision = _decisionFromCandidates(candidates);
    if (explicitDecision.language != null &&
        !explicitDecision.language!.isPlainText) {
      return explicitDecision;
    }

    if (!hasUpstreamTokenStyles) {
      candidates.addAll(_languageGuesser.guessCandidates(text));
      final decision = _decisionFromCandidates(candidates);
      if (decision.language != null) return decision;
    }

    return explicitDecision.language == null
        ? _decisionFromCandidates(candidates)
        : explicitDecision;
  }

  ReaderCodeLanguage? resolveCandidates(Iterable<String> rawCandidates) {
    final candidates = rawCandidates.expand(
      (raw) => _resolvedCandidates(
        raw,
        source: ReaderCodeLanguageDecisionSource.codeClass,
        confidence: 0.98,
        reason: 'candidate:$raw',
      ),
    );
    return _decisionFromCandidates(candidates).language;
  }

  Iterable<ReaderCodeLanguageCandidate> _dataLanguageCandidates(
    dom.Element element, {
    required ReaderCodeLanguageDecisionSource source,
    required double confidence,
    required String reasonPrefix,
  }) sync* {
    final dataLanguage = element.attributes['data-language']?.trim();
    if (dataLanguage != null && dataLanguage.isNotEmpty) {
      yield* _resolvedCandidates(
        dataLanguage,
        source: source,
        confidence: confidence,
        reason: '$reasonPrefix:$dataLanguage',
      );
    }
    final lang = element.attributes['lang']?.trim();
    if (lang != null && lang.isNotEmpty) {
      yield* _resolvedCandidates(
        lang,
        source: source,
        confidence: confidence,
        reason: 'lang:$lang',
      );
    }
  }

  Iterable<ReaderCodeLanguageCandidate> _classCandidates(
    dom.Element element, {
    required ReaderCodeLanguageDecisionSource source,
    required double confidence,
    required String reasonPrefix,
  }) sync* {
    final rawClass = element.attributes['class'] ?? '';
    for (final part in rawClass.split(RegExp(r'\s+'))) {
      if (part.isEmpty) continue;
      if (part.startsWith('language-')) {
        yield* _resolvedCandidates(
          part.substring('language-'.length),
          source: source,
          confidence: confidence,
          reason: '$reasonPrefix:$part',
        );
      } else if (part.startsWith('lang-')) {
        yield* _resolvedCandidates(
          part.substring('lang-'.length),
          source: source,
          confidence: confidence,
          reason: '$reasonPrefix:$part',
        );
      } else if (part.startsWith('source-')) {
        yield* _resolvedCandidates(
          part.substring('source-'.length),
          source: source,
          confidence: confidence,
          reason: '$reasonPrefix:$part',
        );
      }
    }
  }

  Iterable<ReaderCodeLanguageCandidate> _metaCandidates(
    dom.Element element,
  ) sync* {
    for (final name in const ['data-meta', 'metastring', 'data-filename']) {
      final value = element.attributes[name]?.trim();
      if (value == null || value.isEmpty) continue;
      yield* _filenameCandidates(value, attributeName: name);
      final parts = value.split(RegExp(r'\s+'));
      final first = parts.isEmpty ? '' : parts.first;
      if (first.isNotEmpty && !first.contains('=')) {
        yield* _resolvedCandidates(
          first,
          source: ReaderCodeLanguageDecisionSource.metadata,
          confidence: 0.86,
          reason: 'metadata:$name:$first',
        );
      }
    }
  }

  Iterable<ReaderCodeLanguageCandidate> _filenameCandidates(
    String value, {
    required String attributeName,
  }) sync* {
    final filenameMatch = RegExp(
      r'(^|[/\\])([A-Za-z0-9_.+-]+)$',
    ).firstMatch(value);
    final filename = filenameMatch?.group(2);
    if (filename != null && filename.isNotEmpty) {
      yield* _resolvedCandidates(
        filename,
        source: ReaderCodeLanguageDecisionSource.metadata,
        confidence: 0.86,
        reason: 'metadata:$attributeName:filename:$filename',
      );
    }
    final match = RegExp(r'[\w./-]+\.([A-Za-z0-9_+-]+)').firstMatch(value);
    final extension = match?.group(1);
    if (extension != null && extension.isNotEmpty) {
      yield* _resolvedCandidates(
        extension,
        source: ReaderCodeLanguageDecisionSource.metadata,
        confidence: 0.86,
        reason: 'metadata:$attributeName:extension:$extension',
      );
    }
  }

  Iterable<ReaderCodeLanguageCandidate> _shebangCandidates(String text) sync* {
    final trimmed = text.trimLeft();
    if (!trimmed.startsWith('#!')) return;
    final firstLineEnd = trimmed.indexOf('\n');
    final firstLine = firstLineEnd < 0
        ? trimmed
        : trimmed.substring(0, firstLineEnd);
    final executable = firstLine.split(RegExp(r'\s+')).last;
    final slash = executable.lastIndexOf('/');
    final raw = slash < 0 ? executable : executable.substring(slash + 1);
    yield* _resolvedCandidates(
      raw,
      source: ReaderCodeLanguageDecisionSource.shebang,
      confidence: 0.9,
      reason: 'shebang:$raw',
    );
  }

  Iterable<ReaderCodeLanguageCandidate> _resolvedCandidates(
    String raw, {
    required ReaderCodeLanguageDecisionSource source,
    required double confidence,
    required String reason,
  }) sync* {
    for (final token in _splitCandidate(raw)) {
      final resolved = _catalog.resolve(token);
      if (resolved == null) continue;
      final isLowValue = resolved.isPlainText;
      yield ReaderCodeLanguageCandidate(
        raw: token,
        language: resolved,
        confidence: isLowValue ? 0.1 : confidence,
        source: isLowValue
            ? ReaderCodeLanguageDecisionSource.plainFallback
            : source,
        reasons: [reason],
        isLowValue: isLowValue,
      );
    }
  }

  static ReaderCodeLanguageDecision _decisionFromCandidates(
    Iterable<ReaderCodeLanguageCandidate> candidates,
  ) {
    final all = candidates.toList(growable: false);
    for (final candidate in all) {
      if (candidate.language != null && !candidate.isLowValue) {
        return _decisionFromCandidate(candidate, all);
      }
    }
    for (final candidate in all) {
      if (candidate.language != null && candidate.isLowValue) {
        return _decisionFromCandidate(candidate, all);
      }
    }
    return ReaderCodeLanguageDecision(
      language: null,
      confidence: 0,
      source: ReaderCodeLanguageDecisionSource.none,
      reasons: const [],
      candidates: all,
    );
  }

  static ReaderCodeLanguageDecision _decisionFromCandidate(
    ReaderCodeLanguageCandidate candidate,
    List<ReaderCodeLanguageCandidate> candidates,
  ) {
    return ReaderCodeLanguageDecision(
      language: candidate.language,
      confidence: candidate.confidence,
      source: candidate.source,
      reasons: candidate.reasons,
      candidates: candidates,
    );
  }

  static Iterable<String> _splitCandidate(String raw) sync* {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return;
    for (var token in normalized.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      if (token.startsWith('language-')) {
        token = token.substring('language-'.length);
      } else if (token.startsWith('lang-')) {
        token = token.substring('lang-'.length);
      } else if (token.startsWith('source-')) {
        token = token.substring('source-'.length);
      }
      if (token.isNotEmpty) yield token;
    }
  }
}

final class ReaderCodeLanguageCatalog {
  const ReaderCodeLanguageCatalog();

  ReaderCodeLanguage? resolve(String token) {
    final clean = token.trim().toLowerCase();
    if (clean.isEmpty) return null;
    final diffInner = _diffInnerLanguage(clean);
    if (clean == 'diff' || diffInner != null) {
      return ReaderCodeLanguage(
        id: 'diff',
        innerLanguage: diffInner == null ? null : canonicalId(diffInner),
      );
    }
    if (clean == 'shell-session' || clean == 'console') {
      return const ReaderCodeLanguage(id: 'shell');
    }
    final canonical = canonicalId(clean);
    if (canonical == null) return null;
    return ReaderCodeLanguage(
      id: canonical,
      isPlainText: _plainTextIds.contains(canonical),
    );
  }

  String? canonicalId(String token) {
    return _aliases[token] ?? (_supportedIds.contains(token) ? token : null);
  }

  static String? _diffInnerLanguage(String token) {
    if (token.startsWith('diff-') && token.length > 'diff-'.length) {
      return token.substring('diff-'.length);
    }
    if (token.startsWith('patch-') && token.length > 'patch-'.length) {
      return token.substring('patch-'.length);
    }
    return null;
  }

  static const Set<String> _plainTextIds = {
    'plain',
    'plain-text',
    'text',
    'plaintext',
    'txt',
    'none',
  };

  static const Set<String> _supportedIds = {
    'c',
    'cpp',
    'css',
    'csharp',
    'dart',
    'diff',
    'dockerfile',
    'go',
    'html',
    'ini',
    'java',
    'javascript',
    'json',
    'jsx',
    'kotlin',
    'makefile',
    'markdown',
    'mdx',
    'plain',
    'plaintext',
    'properties',
    'python',
    'rust',
    'shell',
    'sql',
    'swift',
    'text',
    'toml',
    'tsx',
    'typescript',
    'xml',
    'yaml',
  };

  static const Map<String, String> _aliases = {
    'atom': 'xml',
    'bash': 'shell',
    'c': 'c',
    'cc': 'cpp',
    'cjs': 'javascript',
    'conf': 'ini',
    'containerfile': 'dockerfile',
    'cpp': 'cpp',
    'cs': 'csharp',
    'csharp': 'csharp',
    'cts': 'typescript',
    'cxx': 'cpp',
    'cfg': 'ini',
    'dockerfile': 'dockerfile',
    'envrc': 'shell',
    'gnumakefile': 'makefile',
    'h': 'c',
    'hh': 'cpp',
    'hpp': 'cpp',
    'htm': 'html',
    'ini': 'ini',
    'json5': 'json',
    'jsonc': 'json',
    'js': 'javascript',
    'kt': 'kotlin',
    'less': 'css',
    'makefile': 'makefile',
    'mjs': 'javascript',
    'md': 'markdown',
    'mdx': 'markdown',
    'mysql': 'sql',
    'mts': 'typescript',
    'node': 'javascript',
    'none': 'plain',
    'pgsql': 'sql',
    'plain': 'plain',
    'plain-text': 'plain',
    'plaintext': 'plain',
    'postgres': 'sql',
    'postgresql': 'sql',
    'properties': 'properties',
    'props': 'properties',
    'py': 'python',
    'py3': 'python',
    'python3': 'python',
    'rss': 'xml',
    'rs': 'rust',
    'sass': 'css',
    'scss': 'css',
    'sh': 'shell',
    'shell-script': 'shell',
    'sqlite': 'sql',
    'svg': 'xml',
    'textile': 'plain',
    'text': 'plain',
    'toml': 'toml',
    'ts': 'typescript',
    'txt': 'plain',
    'xhtml': 'xml',
    'xml': 'xml',
    'yml': 'yaml',
    'zsh': 'shell',
  };
}
