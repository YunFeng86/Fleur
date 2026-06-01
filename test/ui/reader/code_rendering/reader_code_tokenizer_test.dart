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
            token.text == 'Box' && token.role == ReaderCodeTokenRole.type,
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
    expect(
      tokens.any(
        (token) =>
            token.text == 'color' && token.role == ReaderCodeTokenRole.property,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == "'red'" && token.role == ReaderCodeTokenRole.string,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == '1' && token.role == ReaderCodeTokenRole.number,
      ),
      isTrue,
    );
  });

  test('tokenizes jsx tags attributes expressions and react functions', () {
    final tokens = tokenizer.tokenize(
      "const [score, setScore] = useState(45)\n"
          "return <span>{score}</span>\n"
          "<Slider onChange={(e, val) => setScore(val)} />",
      'tsx',
    )!;

    expect(
      tokens.any(
        (token) =>
            token.text == 'useState' &&
            token.role == ReaderCodeTokenRole.function,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == 'span' && token.role == ReaderCodeTokenRole.tag,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == 'score' && token.role == ReaderCodeTokenRole.plain,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == 'Slider' && token.role == ReaderCodeTokenRole.type,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == 'onChange' &&
            token.role == ReaderCodeTokenRole.attribute,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == 'setScore' &&
            token.role == ReaderCodeTokenRole.function,
      ),
      isTrue,
    );
  });

  test('tokenizes jsx object and string property keys', () {
    final tokens = tokenizer.tokenize(
      "<Box sx={{ borderRadius: '5px', '& .MuiSlider-thumb': { width: 2 } }} />",
      'jsx',
    )!;

    expect(
      tokens.any(
        (token) =>
            token.text == 'borderRadius' &&
            token.role == ReaderCodeTokenRole.property,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == "'& .MuiSlider-thumb'" &&
            token.role == ReaderCodeTokenRole.property,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == 'width' && token.role == ReaderCodeTokenRole.property,
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
