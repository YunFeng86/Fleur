import 'package:html/dom.dart' as dom;

import 'reader_code_models.dart';

final class ReaderCodeLanguageResolver {
  const ReaderCodeLanguageResolver({
    ReaderCodeLanguageCatalog catalog = const ReaderCodeLanguageCatalog(),
  }) : _catalog = catalog;

  final ReaderCodeLanguageCatalog _catalog;

  ReaderCodeLanguage? resolveForElements(dom.Element source, dom.Element pre) {
    final candidates = <_LanguageCandidate>[
      ..._dataLanguageCandidates(source, priority: 0),
      ..._classCandidates(source, priority: 1),
      if (!identical(source, pre)) ..._dataLanguageCandidates(pre, priority: 2),
      if (!identical(source, pre)) ..._classCandidates(pre, priority: 3),
      ..._metaCandidates(source, priority: 4),
      if (!identical(source, pre)) ..._metaCandidates(pre, priority: 4),
      ..._shebangCandidates(source, priority: 5),
    ];
    return resolveCandidates(candidates.map((candidate) => candidate.value));
  }

  ReaderCodeLanguage? resolveCandidates(Iterable<String> rawCandidates) {
    ReaderCodeLanguage? plainText;
    for (final raw in rawCandidates) {
      for (final token in _splitCandidate(raw)) {
        final resolved = _catalog.resolve(token);
        if (resolved == null) continue;
        if (resolved.isPlainText) {
          plainText ??= resolved;
          continue;
        }
        return resolved;
      }
    }
    return plainText;
  }

  static Iterable<_LanguageCandidate> _dataLanguageCandidates(
    dom.Element element, {
    required int priority,
  }) sync* {
    final dataLanguage = element.attributes['data-language']?.trim();
    if (dataLanguage != null && dataLanguage.isNotEmpty) {
      yield _LanguageCandidate(dataLanguage, priority);
    }
    final lang = element.attributes['lang']?.trim();
    if (lang != null && lang.isNotEmpty) {
      yield _LanguageCandidate(lang, priority);
    }
  }

  static Iterable<_LanguageCandidate> _classCandidates(
    dom.Element element, {
    required int priority,
  }) sync* {
    final rawClass = element.attributes['class'] ?? '';
    for (final part in rawClass.split(RegExp(r'\s+'))) {
      if (part.isEmpty) continue;
      if (part.startsWith('language-')) {
        yield _LanguageCandidate(part.substring('language-'.length), priority);
      } else if (part.startsWith('lang-')) {
        yield _LanguageCandidate(part.substring('lang-'.length), priority);
      } else if (part.startsWith('source-')) {
        yield _LanguageCandidate(part.substring('source-'.length), priority);
      }
    }
  }

  static Iterable<_LanguageCandidate> _metaCandidates(
    dom.Element element, {
    required int priority,
  }) sync* {
    for (final name in const ['data-meta', 'metastring', 'data-filename']) {
      final value = element.attributes[name]?.trim();
      if (value == null || value.isEmpty) continue;
      yield* _filenameCandidates(value, priority: priority);
      final parts = value.split(RegExp(r'\s+'));
      final first = parts.isEmpty ? '' : parts.first;
      if (first.isNotEmpty && !first.contains('=')) {
        yield _LanguageCandidate(first, priority);
      }
    }
  }

  static Iterable<_LanguageCandidate> _filenameCandidates(
    String value, {
    required int priority,
  }) sync* {
    final match = RegExp(r'[\w./-]+\.([A-Za-z0-9_+-]+)').firstMatch(value);
    final extension = match?.group(1);
    if (extension != null && extension.isNotEmpty) {
      yield _LanguageCandidate(extension, priority);
    }
  }

  static Iterable<_LanguageCandidate> _shebangCandidates(
    dom.Element source, {
    required int priority,
  }) sync* {
    final text = source.text.trimLeft();
    if (!text.startsWith('#!')) return;
    final firstLineEnd = text.indexOf('\n');
    final firstLine = firstLineEnd < 0 ? text : text.substring(0, firstLineEnd);
    final executable = firstLine.split(RegExp(r'\s+')).last;
    final slash = executable.lastIndexOf('/');
    yield _LanguageCandidate(
      slash < 0 ? executable : executable.substring(slash + 1),
      priority,
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
    'css',
    'dart',
    'diff',
    'go',
    'html',
    'java',
    'javascript',
    'json',
    'jsx',
    'kotlin',
    'markdown',
    'mdx',
    'plain',
    'plaintext',
    'python',
    'rust',
    'shell',
    'sql',
    'swift',
    'text',
    'tsx',
    'typescript',
    'yaml',
  };

  static const Map<String, String> _aliases = {
    'bash': 'shell',
    'cjs': 'javascript',
    'cts': 'typescript',
    'envrc': 'shell',
    'htm': 'html',
    'js': 'javascript',
    'kt': 'kotlin',
    'mjs': 'javascript',
    'md': 'markdown',
    'mdx': 'markdown',
    'mts': 'typescript',
    'node': 'javascript',
    'none': 'plain',
    'plain': 'plain',
    'plain-text': 'plain',
    'plaintext': 'plain',
    'py': 'python',
    'rs': 'rust',
    'sh': 'shell',
    'shell-script': 'shell',
    'textile': 'plain',
    'text': 'plain',
    'ts': 'typescript',
    'txt': 'plain',
    'xhtml': 'html',
    'yml': 'yaml',
    'zsh': 'shell',
  };
}

final class _LanguageCandidate {
  const _LanguageCandidate(this.value, this.priority);

  final String value;
  final int priority;
}
