import 'reader_code_models.dart';

final class ReaderCodeLanguageGuesser {
  const ReaderCodeLanguageGuesser();

  ReaderCodeLanguage? guess(String code) {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;

    final lower = trimmed.toLowerCase();
    if (trimmed.startsWith('#!')) return _guessFromShebang(trimmed);
    if (_looksLikeHtml(trimmed)) return const ReaderCodeLanguage(id: 'html');
    if (_looksLikeCss(trimmed, lower)) {
      return const ReaderCodeLanguage(id: 'css');
    }
    if (_looksLikeJson(trimmed)) return const ReaderCodeLanguage(id: 'json');
    if (_looksLikePython(trimmed)) {
      return const ReaderCodeLanguage(id: 'python');
    }
    if (_looksLikeShell(trimmed)) return const ReaderCodeLanguage(id: 'shell');
    if (_looksLikeJavaScript(trimmed)) {
      return const ReaderCodeLanguage(id: 'javascript');
    }
    return null;
  }

  static ReaderCodeLanguage? _guessFromShebang(String code) {
    final firstLine = code.split('\n').first.toLowerCase();
    if (firstLine.contains('python')) {
      return const ReaderCodeLanguage(id: 'python');
    }
    if (firstLine.contains('node')) {
      return const ReaderCodeLanguage(id: 'javascript');
    }
    if (firstLine.contains('bash') ||
        firstLine.contains('zsh') ||
        firstLine.contains('sh')) {
      return const ReaderCodeLanguage(id: 'shell');
    }
    return null;
  }

  static bool _looksLikeHtml(String code) {
    return RegExp(
      r'</?[a-z][a-z0-9-]*(\s+[^>]*)?>',
      caseSensitive: false,
    ).hasMatch(code);
  }

  static bool _looksLikeCss(String code, String lower) {
    if (lower.contains('@container') ||
        lower.contains('@media') ||
        lower.contains('@supports') ||
        lower.contains('contrast-color(')) {
      return true;
    }
    return RegExp(
          r'(^|[;{\s])--[a-z0-9_-]+\s*:',
          caseSensitive: false,
        ).hasMatch(code) ||
        RegExp(
          r'[.#]?[a-z][a-z0-9_-]*\s*\{[^}]*[a-z-]+\s*:',
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

  static bool _looksLikePython(String code) {
    return RegExp(
          r'(^|\n)\s*(def|class)\s+\w+',
          multiLine: true,
        ).hasMatch(code) ||
        RegExp(r'(^|\n)\s*(from\s+\w+\s+import|import\s+\w+)').hasMatch(code) ||
        RegExp(r'(^|\n)\s*if\s+__name__\s*==').hasMatch(code);
  }

  static bool _looksLikeShell(String code) {
    return RegExp(
          r'(^|\n)\s*(echo|cd|mkdir|rm|cp|mv|grep|curl|wget|npm|pnpm|yarn|flutter|dart)\b',
        ).hasMatch(code) ||
        RegExp(r'(^|\n)\s*[A-Z_][A-Z0-9_]*=.*').hasMatch(code);
  }

  static bool _looksLikeJavaScript(String code) {
    var score = 0;
    final checks = [
      RegExp(
        r'\b(const|let|var|function|class|import|export|return|await|async|new)\b',
      ),
      RegExp(
        r'\b(console|WeakRef|WeakSet|WeakMap|Promise|Map|Set|Array|Object)\b',
      ),
      RegExp(r'=>'),
      RegExp(r'\?\.\w+'),
      RegExp(r'\.\w+\s*\('),
      RegExp(r'//|/\*'),
      RegExp(r';\s*(\n|$)'),
    ];
    for (final check in checks) {
      if (check.hasMatch(code)) score++;
    }
    return score >= 2;
  }
}
