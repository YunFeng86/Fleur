import 'reader_code_models.dart';

final class ScriptCodeLexer {
  const ScriptCodeLexer({required this.jsx});

  final bool jsx;

  List<ReaderCodeToken> tokenize(String code) {
    return _tokenizeRange(code, 0, code.length, jsx: jsx);
  }

  List<ReaderCodeToken> _tokenizeRange(
    String code,
    int start,
    int end, {
    required bool jsx,
  }) {
    final tokens = <ReaderCodeToken>[];
    var cursor = start;
    while (cursor < end) {
      final char = code[cursor];
      if (char == '/' && cursor + 1 < end && code[cursor + 1] == '/') {
        final tokenEnd = _readLineComment(code, cursor, end);
        _addToken(tokens, code, cursor, tokenEnd, ReaderCodeTokenRole.comment);
        cursor = tokenEnd;
        continue;
      }
      if (char == '/' && cursor + 1 < end && code[cursor + 1] == '*') {
        final tokenEnd = _readBlockComment(code, cursor, end);
        _addToken(tokens, code, cursor, tokenEnd, ReaderCodeTokenRole.comment);
        cursor = tokenEnd;
        continue;
      }
      if (char == '"' || char == "'" || char == '`') {
        final tokenEnd = _readString(code, cursor, end, char);
        _addToken(
          tokens,
          code,
          cursor,
          tokenEnd,
          _isLikelyStringObjectKey(code, cursor, tokenEnd)
              ? ReaderCodeTokenRole.property
              : ReaderCodeTokenRole.string,
        );
        cursor = tokenEnd;
        continue;
      }
      if (jsx && char == '<' && _looksLikeJsxTag(code, cursor, end)) {
        cursor = _scanJsxTag(code, cursor, end, tokens);
        continue;
      }
      if (_isDigit(code.codeUnitAt(cursor))) {
        final tokenEnd = _readNumber(code, cursor, end);
        _addToken(tokens, code, cursor, tokenEnd, ReaderCodeTokenRole.number);
        cursor = tokenEnd;
        continue;
      }
      if (_isIdentifierStart(code.codeUnitAt(cursor))) {
        final tokenEnd = _readIdentifier(code, cursor, end);
        final value = code.substring(cursor, tokenEnd);
        _addToken(
          tokens,
          code,
          cursor,
          tokenEnd,
          _scriptIdentifierRole(code, cursor, tokenEnd, value),
        );
        cursor = tokenEnd;
        continue;
      }
      if (_isOperatorStart(char)) {
        final tokenEnd = _readOperator(code, cursor, end);
        _addToken(
          tokens,
          code,
          cursor,
          tokenEnd,
          _operatorRole(code.substring(cursor, tokenEnd)),
        );
        cursor = tokenEnd;
        continue;
      }
      final tokenEnd = _readPlain(code, cursor, end, jsx: jsx);
      _addToken(tokens, code, cursor, tokenEnd, ReaderCodeTokenRole.plain);
      cursor = tokenEnd;
    }
    return tokens;
  }

  ReaderCodeTokenRole _scriptIdentifierRole(
    String code,
    int start,
    int end,
    String value,
  ) {
    if (_scriptKeywords.contains(value)) return ReaderCodeTokenRole.keyword;
    if (_scriptConstants.contains(value)) return ReaderCodeTokenRole.constant;
    if (_scriptBuiltins.contains(value)) return ReaderCodeTokenRole.builtin;
    if (_isLikelyObjectKey(code, start, end)) {
      return ReaderCodeTokenRole.property;
    }
    if (_isLikelyPropertyAccess(code, start)) {
      return _isLikelyFunction(code, end)
          ? ReaderCodeTokenRole.function
          : ReaderCodeTokenRole.property;
    }
    if (_reactFunctions.contains(value) || _isLikelyFunction(code, end)) {
      return ReaderCodeTokenRole.function;
    }
    if (_startsUppercase(value)) return ReaderCodeTokenRole.type;
    return ReaderCodeTokenRole.plain;
  }

  int _scanJsxTag(
    String code,
    int start,
    int end,
    List<ReaderCodeToken> tokens,
  ) {
    var cursor = start;
    if (cursor + 1 < end && code[cursor + 1] == '/') {
      _addToken(
        tokens,
        code,
        cursor,
        cursor + 2,
        ReaderCodeTokenRole.punctuation,
      );
      cursor += 2;
    } else {
      _addToken(
        tokens,
        code,
        cursor,
        cursor + 1,
        ReaderCodeTokenRole.punctuation,
      );
      cursor++;
    }

    if (cursor < end && code[cursor] == '>') {
      _addToken(
        tokens,
        code,
        cursor,
        cursor + 1,
        ReaderCodeTokenRole.punctuation,
      );
      return cursor + 1;
    }

    if (cursor < end && _isIdentifierStart(code.codeUnitAt(cursor))) {
      final nameEnd = _readMarkupName(code, cursor, end);
      final name = code.substring(cursor, nameEnd);
      _addToken(tokens, code, cursor, nameEnd, _jsxTagRole(name));
      cursor = nameEnd;
    }

    while (cursor < end) {
      final char = code[cursor];
      if (char == '>') {
        _addToken(
          tokens,
          code,
          cursor,
          cursor + 1,
          ReaderCodeTokenRole.punctuation,
        );
        return cursor + 1;
      }
      if (char == '/' && cursor + 1 < end && code[cursor + 1] == '>') {
        _addToken(
          tokens,
          code,
          cursor,
          cursor + 2,
          ReaderCodeTokenRole.punctuation,
        );
        return cursor + 2;
      }
      if (char == '"' || char == "'") {
        final tokenEnd = _readString(code, cursor, end, char);
        _addToken(tokens, code, cursor, tokenEnd, ReaderCodeTokenRole.string);
        cursor = tokenEnd;
        continue;
      }
      if (char == '{') {
        cursor = _scanJsxExpression(code, cursor, end, tokens);
        continue;
      }
      if (_isIdentifierStart(code.codeUnitAt(cursor))) {
        final tokenEnd = _readMarkupName(code, cursor, end);
        _addToken(
          tokens,
          code,
          cursor,
          tokenEnd,
          ReaderCodeTokenRole.attribute,
        );
        cursor = tokenEnd;
        continue;
      }
      if (_isOperatorStart(char)) {
        final tokenEnd = _readOperator(code, cursor, end);
        _addToken(
          tokens,
          code,
          cursor,
          tokenEnd,
          _operatorRole(code.substring(cursor, tokenEnd)),
        );
        cursor = tokenEnd;
        continue;
      }
      final tokenEnd = _readPlain(code, cursor, end, jsx: true);
      _addToken(tokens, code, cursor, tokenEnd, ReaderCodeTokenRole.plain);
      cursor = tokenEnd;
    }
    return cursor;
  }

  int _scanJsxExpression(
    String code,
    int start,
    int end,
    List<ReaderCodeToken> tokens,
  ) {
    final close = _findMatchingBrace(code, start, end);
    if (close == null) {
      _addToken(
        tokens,
        code,
        start,
        start + 1,
        ReaderCodeTokenRole.punctuation,
      );
      return start + 1;
    }
    _addToken(tokens, code, start, start + 1, ReaderCodeTokenRole.punctuation);
    tokens.addAll(_tokenizeRange(code, start + 1, close, jsx: false));
    _addToken(tokens, code, close, close + 1, ReaderCodeTokenRole.punctuation);
    return close + 1;
  }

  bool _looksLikeJsxTag(String code, int start, int end) {
    if (start + 1 >= end) return false;
    final next = code[start + 1];
    if (next == '>') return true;
    if (next == '/') {
      return start + 2 < end &&
          (code[start + 2] == '>' ||
              _isIdentifierStart(code.codeUnitAt(start + 2)));
    }
    return _isIdentifierStart(code.codeUnitAt(start + 1));
  }

  ReaderCodeTokenRole _jsxTagRole(String name) {
    return _startsUppercase(name)
        ? ReaderCodeTokenRole.type
        : ReaderCodeTokenRole.tag;
  }

  int? _findMatchingBrace(String code, int start, int end) {
    var depth = 0;
    var cursor = start;
    while (cursor < end) {
      final char = code[cursor];
      if (char == '"' || char == "'" || char == '`') {
        cursor = _readString(code, cursor, end, char);
        continue;
      }
      if (char == '/' && cursor + 1 < end && code[cursor + 1] == '/') {
        cursor = _readLineComment(code, cursor, end);
        continue;
      }
      if (char == '/' && cursor + 1 < end && code[cursor + 1] == '*') {
        cursor = _readBlockComment(code, cursor, end);
        continue;
      }
      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) return cursor;
      }
      cursor++;
    }
    return null;
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
    'FinalizationRegistry',
    'Map',
    'Math',
    'Number',
    'Object',
    'Promise',
    'React',
    'Set',
    'String',
    'WeakMap',
    'WeakRef',
    'WeakSet',
    'console',
    'document',
    'window',
  };

  static const Set<String> _reactFunctions = {
    'createContext',
    'forwardRef',
    'memo',
    'useCallback',
    'useContext',
    'useEffect',
    'useId',
    'useLayoutEffect',
    'useMemo',
    'useReducer',
    'useRef',
    'useState',
  };
}

final class ShellCodeLexer {
  const ShellCodeLexer();

  List<ReaderCodeToken> tokenize(String code) {
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
      return _token(code, match.start, match.end, role);
    });
    return tokens;
  }
}

final class MarkdownCodeLexer {
  const MarkdownCodeLexer();

  List<ReaderCodeToken> tokenize(String code) {
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
      return _token(code, match.start, match.end, role);
    });
    return tokens;
  }
}

final class ConfigCodeLexer {
  const ConfigCodeLexer({required this.language});

  final String language;

  List<ReaderCodeToken> tokenize(String code) {
    return switch (language) {
      'json' => _tokenizeJson(code),
      'yaml' => _tokenizeYaml(code),
      'toml' => _tokenizeToml(code),
      'ini' || 'properties' => _tokenizeIni(code),
      _ => const [],
    };
  }

  List<ReaderCodeToken> _tokenizeJson(String code) {
    final tokens = <ReaderCodeToken>[];
    final pattern = RegExp(
      r'''"(?:\\.|[^"\\])*"\s*(?=:)|"(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|\b(?:true|false|null)\b|[{}[\]:,]''',
    );
    _scanMatches(code, pattern, tokens, (match) {
      final value = match.group(0)!;
      final trimmed = value.trimRight();
      final next = _nextNonSpace(code, match.end);
      final role = switch (trimmed) {
        final v when v.startsWith('"') && next != null && code[next] == ':' =>
          ReaderCodeTokenRole.property,
        final v when v.startsWith('"') => ReaderCodeTokenRole.string,
        final v when RegExp(r'^-?\d').hasMatch(v) => ReaderCodeTokenRole.number,
        'true' || 'false' || 'null' => ReaderCodeTokenRole.constant,
        _ => ReaderCodeTokenRole.punctuation,
      };
      return _token(code, match.start, match.end, role);
    });
    return tokens;
  }

  List<ReaderCodeToken> _tokenizeYaml(String code) {
    final tokens = <ReaderCodeToken>[];
    final pattern = RegExp(
      r'''#[^\n]*|^(\s*[-?]?\s*)([A-Za-z0-9_.-]+)(\s*:)|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\b(?:true|false|null|yes|no|on|off)\b|-?\d+(?:\.\d+)?|[&*][A-Za-z0-9_-]+|^---|^\.\.\.''',
      multiLine: true,
    );
    _scanMatches(code, pattern, tokens, (match) {
      final key = match.group(2);
      if (key != null) {
        return _token(
          code,
          match.start,
          match.end,
          ReaderCodeTokenRole.property,
        );
      }
      final value = match.group(0)!;
      final role = switch (value.trim()) {
        final v when v.startsWith('#') => ReaderCodeTokenRole.comment,
        final v when v.startsWith('"') || v.startsWith("'") =>
          ReaderCodeTokenRole.string,
        final v when v.startsWith('&') || v.startsWith('*') =>
          ReaderCodeTokenRole.variable,
        final v
            when RegExp(
              r'^(true|false|null|yes|no|on|off)$',
              caseSensitive: false,
            ).hasMatch(v) =>
          ReaderCodeTokenRole.constant,
        final v when RegExp(r'^-?\d').hasMatch(v) => ReaderCodeTokenRole.number,
        _ => ReaderCodeTokenRole.punctuation,
      };
      return _token(code, match.start, match.end, role);
    });
    return tokens;
  }

  List<ReaderCodeToken> _tokenizeToml(String code) {
    final tokens = <ReaderCodeToken>[];
    final pattern = RegExp(
      r'''#[^\n]*|^\s*\[[^\]\n]+\]|^[ \t]*[A-Za-z0-9_.-]+(?=\s*=)|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\b(?:true|false)\b|-?\d+(?:\.\d+)?|[=,\[\]{}]''',
      multiLine: true,
    );
    _scanMatches(code, pattern, tokens, (match) {
      final value = match.group(0)!;
      final role = switch (value.trim()) {
        final v when v.startsWith('#') => ReaderCodeTokenRole.comment,
        final v when v.startsWith('[') => ReaderCodeTokenRole.tag,
        final v when v.startsWith('"') || v.startsWith("'") =>
          ReaderCodeTokenRole.string,
        'true' || 'false' => ReaderCodeTokenRole.constant,
        final v when RegExp(r'^-?\d').hasMatch(v) => ReaderCodeTokenRole.number,
        final v when RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(v) =>
          ReaderCodeTokenRole.property,
        _ => ReaderCodeTokenRole.punctuation,
      };
      return _token(code, match.start, match.end, role);
    });
    return tokens;
  }

  List<ReaderCodeToken> _tokenizeIni(String code) {
    final tokens = <ReaderCodeToken>[];
    final pattern = RegExp(
      r'''^[ \t]*[;#][^\n]*|^\s*\[[^\]\n]+\]|^[ \t]*[A-Za-z0-9_.-]+(?=\s*[=:])|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\b(?:true|false|yes|no|on|off)\b|-?\d+(?:\.\d+)?|[=:]''',
      multiLine: true,
    );
    _scanMatches(code, pattern, tokens, (match) {
      final value = match.group(0)!;
      final role = switch (value.trim()) {
        final v when v.startsWith('#') || v.startsWith(';') =>
          ReaderCodeTokenRole.comment,
        final v when v.startsWith('[') => ReaderCodeTokenRole.tag,
        final v when v.startsWith('"') || v.startsWith("'") =>
          ReaderCodeTokenRole.string,
        final v
            when RegExp(
              r'^(true|false|yes|no|on|off)$',
              caseSensitive: false,
            ).hasMatch(v) =>
          ReaderCodeTokenRole.constant,
        final v when RegExp(r'^-?\d').hasMatch(v) => ReaderCodeTokenRole.number,
        final v when RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(v) =>
          ReaderCodeTokenRole.property,
        _ => ReaderCodeTokenRole.operator,
      };
      return _token(code, match.start, match.end, role);
    });
    return tokens;
  }
}

final class CssCodeLexer {
  const CssCodeLexer();

  List<ReaderCodeToken> tokenize(String code) {
    final tokens = <ReaderCodeToken>[];
    final pattern = RegExp(
      r'''/\*[\s\S]*?\*/|#[0-9A-Fa-f]{3,8}\b|--[A-Za-z0-9_-]+|[A-Za-z-]+(?=\s*:)|\.[A-Za-z0-9_-]+|#[A-Za-z0-9_-]+|:[A-Za-z-]+|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|-?\d+(?:\.\d+)?(?:px|rem|em|%|vh|vw|s|ms)?|\b(?:rgb|rgba|hsl|hsla|var|calc|url)\b|[{}():;,>]''',
    );
    _scanMatches(code, pattern, tokens, (match) {
      final value = match.group(0)!;
      final role = switch (value) {
        final v when v.startsWith('/*') => ReaderCodeTokenRole.comment,
        final v when v.startsWith('"') || v.startsWith("'") =>
          ReaderCodeTokenRole.string,
        final v
            when v.startsWith('#') && RegExp(r'^#[0-9A-Fa-f]').hasMatch(v) =>
          ReaderCodeTokenRole.number,
        final v when v.startsWith('--') => ReaderCodeTokenRole.variable,
        final v
            when v.startsWith('.') || v.startsWith('#') || v.startsWith(':') =>
          ReaderCodeTokenRole.tag,
        final v when RegExp(r'^-?\d').hasMatch(v) => ReaderCodeTokenRole.number,
        final v when _cssFunctions.contains(v) => ReaderCodeTokenRole.function,
        final v when RegExp(r'^[A-Za-z-]+$').hasMatch(v) =>
          ReaderCodeTokenRole.property,
        _ => ReaderCodeTokenRole.punctuation,
      };
      return _token(code, match.start, match.end, role);
    });
    return tokens;
  }

  static const Set<String> _cssFunctions = {
    'calc',
    'hsl',
    'hsla',
    'rgb',
    'rgba',
    'url',
    'var',
  };
}

final class MarkupCodeLexer {
  const MarkupCodeLexer();

  List<ReaderCodeToken> tokenize(String code) {
    final tokens = <ReaderCodeToken>[];
    final pattern = RegExp(
      r'''<!--[\s\S]*?-->|<!DOCTYPE[^>]*>|<\?xml[^>]*\?>|</?[A-Za-z_][\w:.-]*|[A-Za-z_:][\w:.-]*(?=\s*=)|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|/?>''',
      caseSensitive: false,
    );
    _scanMatches(code, pattern, tokens, (match) {
      final value = match.group(0)!;
      final role = switch (value) {
        final v when v.startsWith('<!--') || v.startsWith('<!') =>
          ReaderCodeTokenRole.comment,
        final v when v.startsWith('<?') => ReaderCodeTokenRole.keyword,
        final v when v.startsWith('<') => ReaderCodeTokenRole.tag,
        final v when v.startsWith('"') || v.startsWith("'") =>
          ReaderCodeTokenRole.string,
        final v when v == '>' || v == '/>' => ReaderCodeTokenRole.punctuation,
        _ => ReaderCodeTokenRole.attribute,
      };
      return _token(code, match.start, match.end, role);
    });
    return tokens;
  }
}

final class PythonLikeCodeLexer {
  const PythonLikeCodeLexer();

  List<ReaderCodeToken> tokenize(String code) {
    return CStyleCodeLexer(
      lineComment: '#',
      blockComment: false,
      decoratorPrefix: '@',
      keywords: _pythonKeywords,
      constants: _pythonConstants,
      builtins: _pythonBuiltins,
    ).tokenize(code);
  }

  static const Set<String> _pythonKeywords = {
    'and',
    'as',
    'assert',
    'async',
    'await',
    'break',
    'class',
    'continue',
    'def',
    'del',
    'elif',
    'else',
    'except',
    'finally',
    'for',
    'from',
    'global',
    'if',
    'import',
    'in',
    'is',
    'lambda',
    'nonlocal',
    'not',
    'or',
    'pass',
    'raise',
    'return',
    'try',
    'while',
    'with',
    'yield',
  };

  static const Set<String> _pythonConstants = {'False', 'None', 'True'};

  static const Set<String> _pythonBuiltins = {
    'bool',
    'dict',
    'enumerate',
    'float',
    'int',
    'len',
    'list',
    'map',
    'print',
    'range',
    'set',
    'str',
    'tuple',
    'zip',
  };
}

final class CStyleCodeLexer {
  const CStyleCodeLexer({
    required this.lineComment,
    required this.keywords,
    required this.constants,
    required this.builtins,
    this.blockComment = true,
    this.decoratorPrefix,
  });

  factory CStyleCodeLexer.forLanguage(String language) {
    final spec = _cStyleSpecs[language];
    if (spec == null) return const CStyleCodeLexer.empty();
    return CStyleCodeLexer(
      lineComment: '//',
      keywords: spec.keywords,
      constants: spec.constants,
      builtins: spec.builtins,
      blockComment: true,
      decoratorPrefix: spec.decoratorPrefix,
    );
  }

  const CStyleCodeLexer.empty()
    : lineComment = '//',
      keywords = const {},
      constants = const {},
      builtins = const {},
      blockComment = true,
      decoratorPrefix = null;

  final String lineComment;
  final Set<String> keywords;
  final Set<String> constants;
  final Set<String> builtins;
  final bool blockComment;
  final String? decoratorPrefix;

  List<ReaderCodeToken> tokenize(String code) {
    final tokens = <ReaderCodeToken>[];
    var cursor = 0;
    while (cursor < code.length) {
      final char = code[cursor];
      if (_startsWithAt(code, lineComment, cursor)) {
        final tokenEnd = _readLineComment(code, cursor, code.length);
        _addToken(tokens, code, cursor, tokenEnd, ReaderCodeTokenRole.comment);
        cursor = tokenEnd;
        continue;
      }
      if (blockComment &&
          char == '/' &&
          cursor + 1 < code.length &&
          code[cursor + 1] == '*') {
        final tokenEnd = _readBlockComment(code, cursor, code.length);
        _addToken(tokens, code, cursor, tokenEnd, ReaderCodeTokenRole.comment);
        cursor = tokenEnd;
        continue;
      }
      if (decoratorPrefix != null && char == decoratorPrefix) {
        final tokenEnd = _readDecorator(code, cursor, code.length);
        _addToken(
          tokens,
          code,
          cursor,
          tokenEnd,
          ReaderCodeTokenRole.attribute,
        );
        cursor = tokenEnd;
        continue;
      }
      if (char == '"' || char == "'" || char == '`') {
        final tokenEnd = _readString(code, cursor, code.length, char);
        _addToken(tokens, code, cursor, tokenEnd, ReaderCodeTokenRole.string);
        cursor = tokenEnd;
        continue;
      }
      if (_isDigit(code.codeUnitAt(cursor))) {
        final tokenEnd = _readNumber(code, cursor, code.length);
        _addToken(tokens, code, cursor, tokenEnd, ReaderCodeTokenRole.number);
        cursor = tokenEnd;
        continue;
      }
      if (_isIdentifierStart(code.codeUnitAt(cursor))) {
        final tokenEnd = _readIdentifier(code, cursor, code.length);
        final value = code.substring(cursor, tokenEnd);
        _addToken(
          tokens,
          code,
          cursor,
          tokenEnd,
          _identifierRole(code, cursor, tokenEnd, value),
        );
        cursor = tokenEnd;
        continue;
      }
      if (_isOperatorStart(char)) {
        final tokenEnd = _readOperator(code, cursor, code.length);
        _addToken(
          tokens,
          code,
          cursor,
          tokenEnd,
          _operatorRole(code.substring(cursor, tokenEnd)),
        );
        cursor = tokenEnd;
        continue;
      }
      final tokenEnd = _readPlain(code, cursor, code.length, jsx: false);
      _addToken(tokens, code, cursor, tokenEnd, ReaderCodeTokenRole.plain);
      cursor = tokenEnd;
    }
    return tokens;
  }

  ReaderCodeTokenRole _identifierRole(
    String code,
    int start,
    int end,
    String value,
  ) {
    if (keywords.contains(value)) return ReaderCodeTokenRole.keyword;
    if (constants.contains(value)) return ReaderCodeTokenRole.constant;
    if (builtins.contains(value)) return ReaderCodeTokenRole.builtin;
    if (_isLikelyPropertyAccess(code, start)) {
      return _isLikelyFunction(code, end)
          ? ReaderCodeTokenRole.function
          : ReaderCodeTokenRole.property;
    }
    if (_isLikelyFunction(code, end)) return ReaderCodeTokenRole.function;
    if (_startsUppercase(value)) return ReaderCodeTokenRole.type;
    return ReaderCodeTokenRole.plain;
  }
}

final class SqlCodeLexer {
  const SqlCodeLexer();

  List<ReaderCodeToken> tokenize(String code) {
    final tokens = <ReaderCodeToken>[];
    final pattern = RegExp(
      r'''--[^\n]*|/\*[\s\S]*?\*/|'(?:''|[^'])*'|"(?:\\"|[^"])*"|\b[A-Za-z_][\w$]*\b|-?\d+(?:\.\d+)?|[(),.;*=<>+-]''',
      caseSensitive: false,
    );
    _scanMatches(code, pattern, tokens, (match) {
      final value = match.group(0)!;
      final lower = value.toLowerCase();
      final role = switch (value) {
        final v when v.startsWith('--') || v.startsWith('/*') =>
          ReaderCodeTokenRole.comment,
        final v when v.startsWith("'") || v.startsWith('"') =>
          ReaderCodeTokenRole.string,
        final v when RegExp(r'^-?\d').hasMatch(v) => ReaderCodeTokenRole.number,
        _ when _sqlKeywords.contains(lower) => ReaderCodeTokenRole.keyword,
        _ when _sqlFunctions.contains(lower) => ReaderCodeTokenRole.function,
        _ when _sqlTypes.contains(lower) => ReaderCodeTokenRole.type,
        _ =>
          RegExp(r'^[(),.;*=<>+-]$').hasMatch(value)
              ? ReaderCodeTokenRole.operator
              : ReaderCodeTokenRole.plain,
      };
      return _token(code, match.start, match.end, role);
    });
    return tokens;
  }

  static const Set<String> _sqlKeywords = {
    'and',
    'as',
    'by',
    'case',
    'create',
    'delete',
    'desc',
    'distinct',
    'else',
    'end',
    'from',
    'group',
    'having',
    'in',
    'insert',
    'into',
    'is',
    'join',
    'left',
    'limit',
    'not',
    'null',
    'on',
    'or',
    'order',
    'outer',
    'right',
    'select',
    'set',
    'then',
    'update',
    'values',
    'when',
    'where',
  };

  static const Set<String> _sqlFunctions = {
    'avg',
    'coalesce',
    'count',
    'date',
    'lower',
    'max',
    'min',
    'sum',
    'upper',
  };

  static const Set<String> _sqlTypes = {
    'bigint',
    'boolean',
    'date',
    'decimal',
    'float',
    'int',
    'integer',
    'json',
    'numeric',
    'text',
    'timestamp',
    'varchar',
  };
}

final class DockerfileCodeLexer {
  const DockerfileCodeLexer();

  List<ReaderCodeToken> tokenize(String code) {
    final tokens = <ReaderCodeToken>[];
    final pattern = RegExp(
      r'''#[^\n]*|^\s*(FROM|RUN|CMD|LABEL|MAINTAINER|EXPOSE|ENV|ADD|COPY|ENTRYPOINT|VOLUME|USER|WORKDIR|ARG|ONBUILD|STOPSIGNAL|HEALTHCHECK|SHELL)\b|--[A-Za-z0-9_-]+|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\$[A-Za-z_][\w]*|\b[A-Za-z_./:-][\w./:-]*\b''',
      caseSensitive: false,
      multiLine: true,
    );
    _scanMatches(code, pattern, tokens, (match) {
      final value = match.group(0)!;
      final trimmed = value.trimLeft();
      final role = switch (trimmed) {
        final v when v.startsWith('#') => ReaderCodeTokenRole.comment,
        final v when _dockerInstructions.contains(v.toUpperCase()) =>
          ReaderCodeTokenRole.keyword,
        final v when v.startsWith('"') || v.startsWith("'") =>
          ReaderCodeTokenRole.string,
        final v when v.startsWith(r'$') => ReaderCodeTokenRole.variable,
        final v when v.startsWith('-') => ReaderCodeTokenRole.attribute,
        _ => ReaderCodeTokenRole.plain,
      };
      return _token(code, match.start, match.end, role);
    });
    return tokens;
  }

  static const Set<String> _dockerInstructions = {
    'FROM',
    'RUN',
    'CMD',
    'LABEL',
    'MAINTAINER',
    'EXPOSE',
    'ENV',
    'ADD',
    'COPY',
    'ENTRYPOINT',
    'VOLUME',
    'USER',
    'WORKDIR',
    'ARG',
    'ONBUILD',
    'STOPSIGNAL',
    'HEALTHCHECK',
    'SHELL',
  };
}

final class MakefileCodeLexer {
  const MakefileCodeLexer();

  List<ReaderCodeToken> tokenize(String code) {
    final tokens = <ReaderCodeToken>[];
    final pattern = RegExp(
      r'''#[^\n]*|^[A-Za-z0-9_.-]+(?=\s*:)|^\s*(include|export|override|define|endef|ifeq|ifneq|ifdef|ifndef|else|endif)\b|\$\([A-Za-z0-9_.-]+\)|[A-Za-z0-9_.-]+(?=\s*=)|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|[:=]''',
      multiLine: true,
    );
    _scanMatches(code, pattern, tokens, (match) {
      final value = match.group(0)!;
      final trimmed = value.trimLeft();
      final role = switch (trimmed) {
        final v when v.startsWith('#') => ReaderCodeTokenRole.comment,
        final v when _makeKeywords.contains(v) => ReaderCodeTokenRole.keyword,
        final v when v.startsWith(r'$(') => ReaderCodeTokenRole.variable,
        final v when v.startsWith('"') || v.startsWith("'") =>
          ReaderCodeTokenRole.string,
        final v when v == ':' || v == '=' => ReaderCodeTokenRole.operator,
        final v
            when RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(v) &&
                _nextNonSpace(code, match.end) != null &&
                code[_nextNonSpace(code, match.end)!] == ':' =>
          ReaderCodeTokenRole.function,
        _ => ReaderCodeTokenRole.property,
      };
      return _token(code, match.start, match.end, role);
    });
    return tokens;
  }

  static const Set<String> _makeKeywords = {
    'include',
    'export',
    'override',
    'define',
    'endef',
    'ifeq',
    'ifneq',
    'ifdef',
    'ifndef',
    'else',
    'endif',
  };
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

ReaderCodeToken _token(
  String code,
  int start,
  int end,
  ReaderCodeTokenRole role,
) {
  return ReaderCodeToken(
    text: code.substring(start, end),
    role: role,
    start: start,
    end: end,
  );
}

void _addToken(
  List<ReaderCodeToken> tokens,
  String code,
  int start,
  int end,
  ReaderCodeTokenRole role,
) {
  if (start >= end) return;
  tokens.add(_token(code, start, end, role));
}

int _readLineComment(String code, int start, int end) {
  final newline = code.indexOf('\n', start);
  return newline < 0 || newline > end ? end : newline;
}

int _readBlockComment(String code, int start, int end) {
  final close = code.indexOf('*/', start + 2);
  return close < 0 || close + 2 > end ? end : close + 2;
}

int _readString(String code, int start, int end, String quote) {
  var cursor = start + 1;
  while (cursor < end) {
    final char = code[cursor];
    if (char == r'\') {
      cursor += 2;
      continue;
    }
    cursor++;
    if (char == quote) return cursor;
  }
  return end;
}

int _readNumber(String code, int start, int end) {
  var cursor = start;
  while (cursor < end) {
    final char = code[cursor];
    final unit = code.codeUnitAt(cursor);
    if (!_isDigit(unit) &&
        char != '.' &&
        char != '_' &&
        char.toLowerCase() != 'x' &&
        char.toLowerCase() != 'b') {
      break;
    }
    cursor++;
  }
  return cursor;
}

int _readIdentifier(String code, int start, int end) {
  var cursor = start + 1;
  while (cursor < end && _isIdentifierPart(code.codeUnitAt(cursor))) {
    cursor++;
  }
  return cursor;
}

int _readMarkupName(String code, int start, int end) {
  var cursor = start + 1;
  while (cursor < end) {
    final unit = code.codeUnitAt(cursor);
    final char = code[cursor];
    if (!_isIdentifierPart(unit) && char != '-' && char != ':' && char != '.') {
      break;
    }
    cursor++;
  }
  return cursor;
}

int _readOperator(String code, int start, int end) {
  if (_isSinglePunctuation(code[start])) return start + 1;
  var cursor = start + 1;
  while (cursor < end && _isJoinableOperator(code[cursor])) {
    cursor++;
  }
  return cursor;
}

int _readPlain(String code, int start, int end, {required bool jsx}) {
  var cursor = start + 1;
  while (cursor < end) {
    final char = code[cursor];
    final unit = code.codeUnitAt(cursor);
    if (char == '"' ||
        char == "'" ||
        char == '`' ||
        (char == '/' && cursor + 1 < end && code[cursor + 1] == '/') ||
        (char == '/' && cursor + 1 < end && code[cursor + 1] == '*') ||
        (jsx && char == '<') ||
        _isDigit(unit) ||
        _isIdentifierStart(unit) ||
        _isOperatorStart(char)) {
      break;
    }
    cursor++;
  }
  return cursor;
}

int _readDecorator(String code, int start, int end) {
  var cursor = start + 1;
  while (cursor < end) {
    final unit = code.codeUnitAt(cursor);
    final char = code[cursor];
    if (!_isIdentifierPart(unit) && char != '.') break;
    cursor++;
  }
  return cursor;
}

bool _isLikelyObjectKey(String code, int start, int end) {
  final next = _nextNonSpace(code, end);
  if (next == null || code[next] != ':') return false;
  final previous = _previousNonSpace(code, start);
  if (previous == null) return true;
  return const {'{', ',', '('}.contains(code[previous]);
}

bool _isLikelyStringObjectKey(String code, int start, int end) {
  final next = _nextNonSpace(code, end);
  if (next == null || code[next] != ':') return false;
  final previous = _previousNonSpace(code, start);
  if (previous == null) return true;
  return const {'{', ','}.contains(code[previous]);
}

bool _isLikelyPropertyAccess(String code, int start) {
  final previous = _previousNonSpace(code, start);
  return previous != null && code[previous] == '.';
}

bool _isLikelyFunction(String code, int end) {
  final next = _nextNonSpace(code, end);
  return next != null && code[next] == '(';
}

int? _nextNonSpace(String code, int start) {
  var cursor = start;
  while (cursor < code.length && _isWhitespace(code.codeUnitAt(cursor))) {
    cursor++;
  }
  return cursor < code.length ? cursor : null;
}

int? _previousNonSpace(String code, int start) {
  var cursor = start - 1;
  while (cursor >= 0 && _isWhitespace(code.codeUnitAt(cursor))) {
    cursor--;
  }
  return cursor >= 0 ? cursor : null;
}

ReaderCodeTokenRole _operatorRole(String value) {
  return value.contains(RegExp(r'[=:+\-*/%!?&|<>]'))
      ? ReaderCodeTokenRole.operator
      : ReaderCodeTokenRole.punctuation;
}

bool _isOperatorStart(String char) {
  return '{}()[].,;:+-*/%!=<>?&|'.contains(char);
}

bool _isSinglePunctuation(String char) {
  return '{}()[].,;'.contains(char);
}

bool _isJoinableOperator(String char) {
  return ':+-*/%!=<>?&|'.contains(char);
}

bool _isIdentifierStart(int unit) {
  return (unit >= 65 && unit <= 90) ||
      (unit >= 97 && unit <= 122) ||
      unit == 95 ||
      unit == 36;
}

bool _isIdentifierPart(int unit) {
  return _isIdentifierStart(unit) || _isDigit(unit);
}

bool _isDigit(int unit) {
  return unit >= 48 && unit <= 57;
}

bool _isWhitespace(int unit) {
  return unit == 32 || unit == 9 || unit == 10 || unit == 13;
}

bool _startsWithAt(String code, String value, int start) {
  if (start + value.length > code.length) return false;
  return code.substring(start, start + value.length) == value;
}

bool _startsUppercase(String value) {
  if (value.isEmpty) return false;
  final first = value.codeUnitAt(0);
  return first >= 65 && first <= 90;
}

final class _CStyleSpec {
  const _CStyleSpec({
    required this.keywords,
    required this.constants,
    required this.builtins,
    this.decoratorPrefix,
  });

  final Set<String> keywords;
  final Set<String> constants;
  final Set<String> builtins;
  final String? decoratorPrefix;
}

const Map<String, _CStyleSpec> _cStyleSpecs = {
  'dart': _CStyleSpec(
    keywords: _dartKeywords,
    constants: _dartConstants,
    builtins: _dartBuiltins,
    decoratorPrefix: '@',
  ),
  'go': _CStyleSpec(
    keywords: _goKeywords,
    constants: _goConstants,
    builtins: _goBuiltins,
  ),
  'rust': _CStyleSpec(
    keywords: _rustKeywords,
    constants: _rustConstants,
    builtins: _rustBuiltins,
    decoratorPrefix: '#',
  ),
  'java': _CStyleSpec(
    keywords: _javaKeywords,
    constants: _javaConstants,
    builtins: _javaBuiltins,
    decoratorPrefix: '@',
  ),
  'kotlin': _CStyleSpec(
    keywords: _kotlinKeywords,
    constants: _kotlinConstants,
    builtins: _kotlinBuiltins,
    decoratorPrefix: '@',
  ),
  'swift': _CStyleSpec(
    keywords: _swiftKeywords,
    constants: _swiftConstants,
    builtins: _swiftBuiltins,
    decoratorPrefix: '@',
  ),
  'c': _CStyleSpec(
    keywords: _cKeywords,
    constants: _cConstants,
    builtins: _cBuiltins,
  ),
  'cpp': _CStyleSpec(
    keywords: _cppKeywords,
    constants: _cppConstants,
    builtins: _cppBuiltins,
  ),
  'csharp': _CStyleSpec(
    keywords: _csharpKeywords,
    constants: _csharpConstants,
    builtins: _csharpBuiltins,
    decoratorPrefix: '@',
  ),
};

const Set<String> _dartKeywords = {
  'abstract',
  'as',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'final',
  'finally',
  'for',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'of',
  'on',
  'operator',
  'part',
  'required',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'try',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

const Set<String> _dartConstants = {'false', 'null', 'true'};
const Set<String> _dartBuiltins = {
  'bool',
  'double',
  'Duration',
  'Future',
  'int',
  'Iterable',
  'List',
  'Map',
  'Object',
  'Set',
  'Stream',
  'String',
  'Widget',
};

const Set<String> _goKeywords = {
  'break',
  'case',
  'chan',
  'const',
  'continue',
  'defer',
  'else',
  'fallthrough',
  'for',
  'func',
  'go',
  'goto',
  'if',
  'import',
  'interface',
  'map',
  'package',
  'range',
  'return',
  'select',
  'struct',
  'switch',
  'type',
  'var',
};
const Set<String> _goConstants = {'false', 'iota', 'nil', 'true'};
const Set<String> _goBuiltins = {
  'bool',
  'byte',
  'error',
  'float64',
  'int',
  'int64',
  'make',
  'rune',
  'string',
  'uint',
};

const Set<String> _rustKeywords = {
  'as',
  'async',
  'await',
  'break',
  'const',
  'continue',
  'crate',
  'else',
  'enum',
  'extern',
  'fn',
  'for',
  'if',
  'impl',
  'in',
  'let',
  'loop',
  'match',
  'mod',
  'move',
  'mut',
  'pub',
  'ref',
  'return',
  'self',
  'static',
  'struct',
  'super',
  'trait',
  'type',
  'unsafe',
  'use',
  'where',
  'while',
};
const Set<String> _rustConstants = {'false', 'None', 'Some', 'true'};
const Set<String> _rustBuiltins = {
  'bool',
  'Box',
  'Result',
  'Option',
  'String',
  'Vec',
  'i32',
  'i64',
  'usize',
};

const Set<String> _javaKeywords = {
  'abstract',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'else',
  'enum',
  'extends',
  'final',
  'finally',
  'for',
  'if',
  'implements',
  'import',
  'instanceof',
  'interface',
  'new',
  'package',
  'private',
  'protected',
  'public',
  'return',
  'static',
  'super',
  'switch',
  'this',
  'throw',
  'throws',
  'try',
  'void',
  'while',
};
const Set<String> _javaConstants = {'false', 'null', 'true'};
const Set<String> _javaBuiltins = {
  'Boolean',
  'Double',
  'Integer',
  'List',
  'Map',
  'Object',
  'String',
  'System',
};

const Set<String> _kotlinKeywords = {
  'as',
  'break',
  'by',
  'catch',
  'class',
  'companion',
  'continue',
  'data',
  'do',
  'else',
  'enum',
  'false',
  'finally',
  'for',
  'fun',
  'if',
  'import',
  'in',
  'interface',
  'is',
  'object',
  'package',
  'return',
  'sealed',
  'super',
  'this',
  'throw',
  'true',
  'try',
  'typealias',
  'val',
  'var',
  'when',
  'while',
};
const Set<String> _kotlinConstants = {'false', 'null', 'true'};
const Set<String> _kotlinBuiltins = {
  'Any',
  'Boolean',
  'Double',
  'Int',
  'List',
  'Long',
  'Map',
  'String',
};

const Set<String> _swiftKeywords = {
  'as',
  'break',
  'case',
  'catch',
  'class',
  'continue',
  'defer',
  'do',
  'else',
  'enum',
  'extension',
  'false',
  'for',
  'func',
  'guard',
  'if',
  'import',
  'in',
  'init',
  'let',
  'nil',
  'protocol',
  'return',
  'self',
  'struct',
  'switch',
  'throw',
  'throws',
  'true',
  'try',
  'var',
  'while',
};
const Set<String> _swiftConstants = {'false', 'nil', 'true'};
const Set<String> _swiftBuiltins = {
  'Array',
  'Bool',
  'Dictionary',
  'Double',
  'Int',
  'Optional',
  'String',
};

const Set<String> _cKeywords = {
  'auto',
  'break',
  'case',
  'char',
  'const',
  'continue',
  'default',
  'do',
  'double',
  'else',
  'enum',
  'extern',
  'float',
  'for',
  'goto',
  'if',
  'inline',
  'int',
  'long',
  'register',
  'return',
  'short',
  'signed',
  'sizeof',
  'static',
  'struct',
  'switch',
  'typedef',
  'union',
  'unsigned',
  'void',
  'volatile',
  'while',
};
const Set<String> _cConstants = {'NULL', 'false', 'true'};
const Set<String> _cBuiltins = {'printf', 'size_t', 'uint32_t', 'uint64_t'};

const Set<String> _cppKeywords = {
  ..._cKeywords,
  'alignas',
  'class',
  'concept',
  'constexpr',
  'delete',
  'explicit',
  'friend',
  'namespace',
  'new',
  'noexcept',
  'operator',
  'private',
  'protected',
  'public',
  'template',
  'this',
  'typename',
  'using',
  'virtual',
};
const Set<String> _cppConstants = {'NULL', 'false', 'nullptr', 'true'};
const Set<String> _cppBuiltins = {
  'std',
  'string',
  'vector',
  'map',
  'unique_ptr',
  'shared_ptr',
};

const Set<String> _csharpKeywords = {
  'abstract',
  'as',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'delegate',
  'do',
  'else',
  'enum',
  'event',
  'finally',
  'for',
  'foreach',
  'if',
  'in',
  'interface',
  'internal',
  'is',
  'namespace',
  'new',
  'private',
  'protected',
  'public',
  'readonly',
  'return',
  'sealed',
  'static',
  'struct',
  'switch',
  'this',
  'throw',
  'try',
  'using',
  'var',
  'void',
  'while',
};
const Set<String> _csharpConstants = {'false', 'null', 'true'};
const Set<String> _csharpBuiltins = {
  'bool',
  'DateTime',
  'decimal',
  'double',
  'int',
  'List',
  'string',
  'Task',
};
