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

  test('tokenizes json keys strings numbers constants and punctuation', () {
    final tokens = tokenizer.tokenize(
      '{"name": "Fleur", "count": 2, "enabled": true}',
      'json',
    )!;

    expect(
      tokens.any(
        (token) =>
            token.text.trim() == '"name"' &&
            token.role == ReaderCodeTokenRole.property,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == '"Fleur"' && token.role == ReaderCodeTokenRole.string,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == '2' && token.role == ReaderCodeTokenRole.number,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == 'true' && token.role == ReaderCodeTokenRole.constant,
      ),
      isTrue,
    );
  });

  test('tokenizes yaml keys scalars anchors and comments', () {
    final tokens = tokenizer.tokenize(
      'name: Fleur\nenabled: true\nref: &base value\ncopy: *base # reuse',
      'yaml',
    )!;

    expect(
      tokens.any(
        (token) =>
            token.text.contains('name:') &&
            token.role == ReaderCodeTokenRole.property,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == 'true' && token.role == ReaderCodeTokenRole.constant,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == '&base' && token.role == ReaderCodeTokenRole.variable,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == '# reuse' &&
            token.role == ReaderCodeTokenRole.comment,
      ),
      isTrue,
    );
  });

  test('tokenizes css selectors properties values variables and comments', () {
    final tokens = tokenizer.tokenize(
      '.card { --gap: 8px; color: rgba(0,0,0,.8); /* note */ }',
      'css',
    )!;

    expect(
      tokens.any(
        (token) =>
            token.text == '.card' && token.role == ReaderCodeTokenRole.tag,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == '--gap' && token.role == ReaderCodeTokenRole.variable,
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
            token.text == 'rgba' && token.role == ReaderCodeTokenRole.function,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == '/* note */' &&
            token.role == ReaderCodeTokenRole.comment,
      ),
      isTrue,
    );
  });

  test('tokenizes html tags attributes strings and comments', () {
    final tokens = tokenizer.tokenize(
      '<!-- note --><section class="hero">Title</section>',
      'html',
    )!;

    expect(
      tokens.any(
        (token) =>
            token.text == '<!-- note -->' &&
            token.role == ReaderCodeTokenRole.comment,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == '<section' && token.role == ReaderCodeTokenRole.tag,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == 'class' &&
            token.role == ReaderCodeTokenRole.attribute,
      ),
      isTrue,
    );
    expect(
      tokens.any(
        (token) =>
            token.text == '"hero"' && token.role == ReaderCodeTokenRole.string,
      ),
      isTrue,
    );
  });

  test('tokenizes python dart and sql common roles', () {
    final python = tokenizer.tokenize(
      '@decorator\ndef greet(name):\n    print("hi", name) # note',
      'python',
    )!;
    final dart = tokenizer.tokenize(
      '@override\nFuture<String> load() async => "ok";',
      'dart',
    )!;
    final sql = tokenizer.tokenize(
      "SELECT count(*) FROM articles WHERE title = 'Fleur'",
      'sql',
    )!;

    expect(
      python.any(
        (token) =>
            token.text == '@decorator' &&
            token.role == ReaderCodeTokenRole.attribute,
      ),
      isTrue,
    );
    expect(
      python.any(
        (token) =>
            token.text == 'def' && token.role == ReaderCodeTokenRole.keyword,
      ),
      isTrue,
    );
    expect(
      python.any(
        (token) =>
            token.text == 'print' && token.role == ReaderCodeTokenRole.builtin,
      ),
      isTrue,
    );
    expect(
      dart.any(
        (token) =>
            token.text == 'Future' && token.role == ReaderCodeTokenRole.builtin,
      ),
      isTrue,
    );
    expect(
      dart.any(
        (token) =>
            token.text == 'load' && token.role == ReaderCodeTokenRole.function,
      ),
      isTrue,
    );
    expect(
      sql.any(
        (token) =>
            token.text.toLowerCase() == 'select' &&
            token.role == ReaderCodeTokenRole.keyword,
      ),
      isTrue,
    );
    expect(
      sql.any(
        (token) =>
            token.text.toLowerCase() == 'count' &&
            token.role == ReaderCodeTokenRole.function,
      ),
      isTrue,
    );
  });
}
