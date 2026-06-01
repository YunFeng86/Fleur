import 'reader_code_lexers.dart';
import 'reader_code_models.dart';

final class ReaderCodeTokenizer {
  const ReaderCodeTokenizer();

  List<ReaderCodeToken>? tokenize(String code, String? language) {
    return switch (language) {
      'javascript' ||
      'typescript' => const ScriptCodeLexer(jsx: false).tokenize(code),
      'jsx' || 'tsx' => const ScriptCodeLexer(jsx: true).tokenize(code),
      'json' ||
      'yaml' ||
      'toml' ||
      'ini' ||
      'properties' => ConfigCodeLexer(language: language!).tokenize(code),
      'css' => const CssCodeLexer().tokenize(code),
      'html' || 'xml' => const MarkupCodeLexer().tokenize(code),
      'python' => const PythonLikeCodeLexer().tokenize(code),
      'dart' ||
      'go' ||
      'rust' ||
      'java' ||
      'kotlin' ||
      'swift' ||
      'c' ||
      'cpp' ||
      'csharp' => CStyleCodeLexer.forLanguage(language!).tokenize(code),
      'sql' => const SqlCodeLexer().tokenize(code),
      'shell' => const ShellCodeLexer().tokenize(code),
      'markdown' => const MarkdownCodeLexer().tokenize(code),
      'dockerfile' => const DockerfileCodeLexer().tokenize(code),
      'makefile' => const MakefileCodeLexer().tokenize(code),
      _ => null,
    };
  }
}
