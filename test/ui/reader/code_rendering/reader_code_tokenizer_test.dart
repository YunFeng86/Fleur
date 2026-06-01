import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/ui/reader/code_rendering/reader_code_rendering.dart';

void main() {
  const tokenizer = ReaderCodeTokenizer();

  test('tokenizes jsx and tsx high value roles', () {
    final tokens = tokenizer.tokenize(
      "export default function App() {\n"
          "  return <Box sx={{ color: 'red' }} count={1} />\n"
          "}",
      'jsx',
    )!;

    expect(
      tokens.any(
        (token) =>
            token.text == 'export' && token.role == ReaderCodeTokenRole.keyword,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == '<Box' && token.role == ReaderCodeTokenRole.tag,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == 'count' &&
            token.role == ReaderCodeTokenRole.attribute,
      ),
      isTrue,
    );
  });

  test('tokenizes shell command flags strings variables and comments', () {
    final tokens = tokenizer.tokenize(
      'npm run build -- --watch "\$TARGET" # keep running',
      'shell',
    )!;

    expect(
      tokens.any(
        (token) =>
            token.text == 'npm' && token.role == ReaderCodeTokenRole.function,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == '--watch' &&
            token.role == ReaderCodeTokenRole.attribute,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == '# keep running' &&
            token.role == ReaderCodeTokenRole.comment,
      ),
      isTrue,
    );
  });

  test('tokenizes markdown heading link inline code and list markers', () {
    final tokens = tokenizer.tokenize(
      '# Title\n- [Docs](https://example.com) `code`',
      'markdown',
    )!;

    expect(tokens.any((token) => token.text == '# Title'), isTrue);
    expect(tokens.any((token) => token.text.startsWith('[Docs]')), isTrue);
    expect(tokens.any((token) => token.text == '`code`'), isTrue);
  });
}
