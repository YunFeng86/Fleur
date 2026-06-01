import 'reader_code_models.dart';

final class ReaderCodeTokenizer {
  const ReaderCodeTokenizer();

  List<ReaderCodeToken>? tokenize(String code, String? language) {
    return switch (language) {
      'javascript' || 'typescript' => _tokenizeScript(code, jsx: false),
      'jsx' || 'tsx' => _tokenizeScript(code, jsx: true),
      'json' => _tokenizeJson(code),
      'yaml' => _tokenizeYaml(code),
      'css' => _tokenizeCss(code),
      'html' => _tokenizeHtml(code),
      'python' => _tokenizePython(code),
      'dart' => _tokenizeDart(code),
      'sql' => _tokenizeSql(code),
      'shell' => _tokenizeShell(code),
      'markdown' => _tokenizeMarkdown(code),
      _ => null,
    };
  }

  List<ReaderCodeToken> _tokenizeScript(String code, {required bool jsx}) {
    return _tokenizeScriptRange(code, 0, code.length, jsx: jsx);
  }

  List<ReaderCodeToken> _tokenizeScriptRange(
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
    if (_isReactFunctionName(value) || _isLikelyFunction(code, end)) {
      return ReaderCodeTokenRole.function;
    }
    if (value.isNotEmpty &&
        value.codeUnitAt(0) >= 65 &&
        value.codeUnitAt(0) <= 90) {
      return ReaderCodeTokenRole.type;
    }
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
      final nameEnd = _readJsxName(code, cursor, end);
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
        final tokenEnd = _readJsxName(code, cursor, end);
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
    tokens.addAll(_tokenizeScriptRange(code, start + 1, close, jsx: false));
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
    final first = name.isEmpty ? 0 : name.codeUnitAt(0);
    return first >= 65 && first <= 90
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
      if (char == '\\') {
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
      final unit = code.codeUnitAt(cursor);
      if (!_isDigit(unit) && code[cursor] != '.') break;
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

  int _readJsxName(String code, int start, int end) {
    var cursor = start + 1;
    while (cursor < end) {
      final unit = code.codeUnitAt(cursor);
      final char = code[cursor];
      if (!_isIdentifierPart(unit) &&
          char != '-' &&
          char != ':' &&
          char != '.') {
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
          (jsx && char == '<' && _looksLikeJsxTag(code, cursor, end)) ||
          _isDigit(unit) ||
          _isIdentifierStart(unit) ||
          _isOperatorStart(char)) {
        break;
      }
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

  ReaderCodeTokenRole _cStyleIdentifierRole(
    String code,
    int start,
    int end,
    String value, {
    required Set<String> keywords,
    required Set<String> constants,
    required Set<String> builtins,
  }) {
    if (keywords.contains(value)) return ReaderCodeTokenRole.keyword;
    if (constants.contains(value)) return ReaderCodeTokenRole.constant;
    if (builtins.contains(value)) return ReaderCodeTokenRole.builtin;
    if (_isLikelyPropertyAccess(code, start)) {
      return _isLikelyFunction(code, end)
          ? ReaderCodeTokenRole.function
          : ReaderCodeTokenRole.property;
    }
    if (_isLikelyFunction(code, end)) return ReaderCodeTokenRole.function;
    if (value.isNotEmpty &&
        value.codeUnitAt(0) >= 65 &&
        value.codeUnitAt(0) <= 90) {
      return ReaderCodeTokenRole.type;
    }
    return ReaderCodeTokenRole.plain;
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

  bool _isReactFunctionName(String value) {
    return _reactFunctions.contains(value);
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

  void _addToken(
    List<ReaderCodeToken> tokens,
    String code,
    int start,
    int end,
    ReaderCodeTokenRole role,
  ) {
    if (start >= end) return;
    tokens.add(
      ReaderCodeToken(
        text: code.substring(start, end),
        role: role,
        start: start,
        end: end,
      ),
    );
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
      return ReaderCodeToken(
        text: value,
        role: role,
        start: match.start,
        end: match.end,
      );
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
        return ReaderCodeToken(
          text: match.group(0)!,
          role: ReaderCodeTokenRole.property,
          start: match.start,
          end: match.end,
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
      return ReaderCodeToken(
        text: value,
        role: role,
        start: match.start,
        end: match.end,
      );
    });
    return tokens;
  }

  List<ReaderCodeToken> _tokenizeCss(String code) {
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
      return ReaderCodeToken(
        text: value,
        role: role,
        start: match.start,
        end: match.end,
      );
    });
    return tokens;
  }

  List<ReaderCodeToken> _tokenizeHtml(String code) {
    final tokens = <ReaderCodeToken>[];
    final pattern = RegExp(
      r'''<!--[\s\S]*?-->|<!DOCTYPE[^>]*>|</?[A-Za-z][\w:-]*|[A-Za-z_:][\w:.-]*(?=\s*=)|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|/?>''',
      caseSensitive: false,
    );
    _scanMatches(code, pattern, tokens, (match) {
      final value = match.group(0)!;
      final role = switch (value) {
        final v when v.startsWith('<!--') || v.startsWith('<!') =>
          ReaderCodeTokenRole.comment,
        final v when v.startsWith('<') => ReaderCodeTokenRole.tag,
        final v when v.startsWith('"') || v.startsWith("'") =>
          ReaderCodeTokenRole.string,
        final v when v == '>' || v == '/>' => ReaderCodeTokenRole.punctuation,
        _ => ReaderCodeTokenRole.attribute,
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

  List<ReaderCodeToken> _tokenizePython(String code) {
    return _tokenizeCStyleLike(
      code,
      lineComment: '#',
      keywords: _pythonKeywords,
      constants: _pythonConstants,
      builtins: _pythonBuiltins,
      decoratorPrefix: '@',
    );
  }

  List<ReaderCodeToken> _tokenizeDart(String code) {
    return _tokenizeCStyleLike(
      code,
      lineComment: '//',
      blockComment: true,
      keywords: _dartKeywords,
      constants: _dartConstants,
      builtins: _dartBuiltins,
      decoratorPrefix: '@',
    );
  }

  List<ReaderCodeToken> _tokenizeSql(String code) {
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
      return ReaderCodeToken(
        text: value,
        role: role,
        start: match.start,
        end: match.end,
      );
    });
    return tokens;
  }

  List<ReaderCodeToken> _tokenizeCStyleLike(
    String code, {
    required String lineComment,
    required Set<String> keywords,
    required Set<String> constants,
    required Set<String> builtins,
    bool blockComment = false,
    String? decoratorPrefix,
  }) {
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
      if (char == '"' || char == "'") {
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
          _cStyleIdentifierRole(
            code,
            cursor,
            tokenEnd,
            value,
            keywords: keywords,
            constants: constants,
            builtins: builtins,
          ),
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

  static const Set<String> _cssFunctions = {
    'calc',
    'hsl',
    'hsla',
    'rgb',
    'rgba',
    'url',
    'var',
  };

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

  static const Set<String> _dartKeywords = {
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

  static const Set<String> _dartConstants = {'false', 'null', 'true'};

  static const Set<String> _dartBuiltins = {
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
