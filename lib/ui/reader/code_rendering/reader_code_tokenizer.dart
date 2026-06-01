import 'reader_code_models.dart';

final class ReaderCodeTokenizer {
  const ReaderCodeTokenizer();

  List<ReaderCodeToken>? tokenize(String code, String? language) {
    return switch (language) {
      'javascript' || 'typescript' || 'jsx' || 'tsx' => _tokenizeScript(code),
      'shell' => _tokenizeShell(code),
      'markdown' => _tokenizeMarkdown(code),
      _ => null,
    };
  }

  List<ReaderCodeToken> _tokenizeScript(String code) {
    final tokens = <ReaderCodeToken>[];
    final pattern = RegExp(
      r'''//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`|</?[A-Za-z][\w.:-]*|[A-Za-z_$][\w$]*|\d+(?:\.\d+)?|[{}()[\].,;:+\-*/%!=<>?&|]+''',
    );
    _scanMatches(code, pattern, tokens, (match) {
      final value = match.group(0)!;
      final start = match.start;
      final role = _scriptRole(value, code, start);
      return ReaderCodeToken(
        text: value,
        role: role,
        start: start,
        end: match.end,
      );
    });
    return tokens;
  }

  ReaderCodeTokenRole _scriptRole(String value, String code, int start) {
    if (value.startsWith('//') || value.startsWith('/*')) {
      return ReaderCodeTokenRole.comment;
    }
    if (value.startsWith('"') ||
        value.startsWith("'") ||
        value.startsWith('`')) {
      return ReaderCodeTokenRole.string;
    }
    if (RegExp(r'^\d').hasMatch(value)) return ReaderCodeTokenRole.number;
    if (value.startsWith('<')) return ReaderCodeTokenRole.tag;
    if (_scriptKeywords.contains(value)) return ReaderCodeTokenRole.keyword;
    if (_scriptConstants.contains(value)) return ReaderCodeTokenRole.constant;
    if (_scriptBuiltins.contains(value)) return ReaderCodeTokenRole.builtin;
    if (_isLikelyAttribute(code, start)) return ReaderCodeTokenRole.attribute;
    if (_isLikelyFunction(code, start + value.length)) {
      return ReaderCodeTokenRole.function;
    }
    if (value.isNotEmpty &&
        value.codeUnitAt(0) >= 65 &&
        value.codeUnitAt(0) <= 90) {
      return ReaderCodeTokenRole.type;
    }
    if (RegExp(r'^[{}()[\].,;:+\-*/%!=<>?&|]+$').hasMatch(value)) {
      return ReaderCodeTokenRole.punctuation;
    }
    return ReaderCodeTokenRole.plain;
  }

  bool _isLikelyAttribute(String code, int start) {
    var i = start - 1;
    while (i >= 0 && code.codeUnitAt(i) != 10) {
      final char = code[i];
      if (char == '<') return true;
      if (char == '>') return false;
      i--;
    }
    return false;
  }

  bool _isLikelyFunction(String code, int end) {
    var i = end;
    while (i < code.length && code.codeUnitAt(i) == 32) {
      i++;
    }
    return i < code.length && code[i] == '(';
  }

  List<ReaderCodeToken> _tokenizeShell(String code) {
    final tokens = <ReaderCodeToken>[];
    final pattern = RegExp(
      r'''#[^\n]*|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\$[A-Za-z_][\w]*|--?[\w-]+|[A-Za-z_./-][\w./-]*''',
    );
    _scanMatches(code, pattern, tokens, (match) {
      final value = match.group(0)!;
      final role = switch (value) {
        final v when v.startsWith('#') => ReaderCodeTokenRole.comment,
        final v when v.startsWith('"') || v.startsWith("'") =>
          ReaderCodeTokenRole.string,
        final v when v.startsWith(r'$') => ReaderCodeTokenRole.variable,
        final v when v.startsWith('-') => ReaderCodeTokenRole.attribute,
        _ => ReaderCodeTokenRole.function,
      };
      return ReaderCodeToken(
        text: value,
        role: role,
        start: match.start,
        end: match.end,
      );
    });
    return tokens;
  }

  List<ReaderCodeToken> _tokenizeMarkdown(String code) {
    final tokens = <ReaderCodeToken>[];
    final pattern = RegExp(
      r'^#{1,6}\s.*$|`[^`\n]+`|\[[^\]]+\]\([^)]+\)|^\s*[-*+]\s+',
      multiLine: true,
    );
    _scanMatches(code, pattern, tokens, (match) {
      final value = match.group(0)!;
      final role = value.startsWith('`')
          ? ReaderCodeTokenRole.string
          : value.startsWith('[')
          ? ReaderCodeTokenRole.tag
          : ReaderCodeTokenRole.keyword;
      return ReaderCodeToken(
        text: value,
        role: role,
        start: match.start,
        end: match.end,
      );
    });
    return tokens;
  }

  void _scanMatches(
    String code,
    RegExp pattern,
    List<ReaderCodeToken> tokens,
    ReaderCodeToken Function(RegExpMatch match) map,
  ) {
    var cursor = 0;
    for (final match in pattern.allMatches(code)) {
      if (match.start > cursor) {
        tokens.add(
          ReaderCodeToken(
            text: code.substring(cursor, match.start),
            role: ReaderCodeTokenRole.plain,
            start: cursor,
            end: match.start,
          ),
        );
      }
      tokens.add(map(match));
      cursor = match.end;
    }
    if (cursor < code.length) {
      tokens.add(
        ReaderCodeToken(
          text: code.substring(cursor),
          role: ReaderCodeTokenRole.plain,
          start: cursor,
          end: code.length,
        ),
      );
    }
  }

  static const Set<String> _scriptKeywords = {
    'as',
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'do',
    'else',
    'export',
    'extends',
    'finally',
    'for',
    'from',
    'function',
    'if',
    'import',
    'in',
    'interface',
    'let',
    'new',
    'of',
    'return',
    'switch',
    'throw',
    'try',
    'type',
    'var',
    'while',
    'yield',
  };

  static const Set<String> _scriptConstants = {
    'false',
    'null',
    'true',
    'undefined',
  };

  static const Set<String> _scriptBuiltins = {
    'Array',
    'Boolean',
    'Date',
    'Error',
    'Map',
    'Math',
    'Number',
    'Object',
    'Promise',
    'React',
    'Set',
    'String',
    'console',
    'document',
    'window',
  };
}
