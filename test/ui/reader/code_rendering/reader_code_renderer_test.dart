import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:fleur/services/reader_search_service.dart';
import 'package:fleur/ui/reader/code_rendering/reader_code_rendering.dart';

void main() {
  const renderer = ReaderCodeRenderer();

  test('uses internal tokenizer before syntax highlight fallback', () async {
    final fragment = html_parser.parseFragment(
      '<pre><code class="language-jsx">export default function App() { return &lt;Box count={1} /&gt; }</code></pre>',
    );
    final pre = fragment.querySelector('pre')!;
    final code = fragment.querySelector('code')!;

    final result = await renderer.render(
      ReaderCodeRenderInput(
        source: code,
        pre: pre,
        baseStyle: const TextStyle(fontFamily: 'monospace'),
        activeSearchBackground: const Color(0xFFFFFF00),
        searchBackground: const Color(0xFFEEEE00),
        errorColor: const Color(0xFFD1242F),
        brightness: Brightness.light,
        currentAnchorId: null,
      ),
    );

    expect(result.sourceKind, ReaderCodeSourceKind.internalTokenizer);
    expect(result.document.language?.id, 'jsx');
    expect(
      result.document.lines.single.tokens.any(
        (token) =>
            token.text == 'export' && token.role == ReaderCodeTokenRole.keyword,
      ),
      isTrue,
    );
    expect(
      result.document.lines.single.tokens.any(
        (token) =>
            token.text == '<Box' && token.role == ReaderCodeTokenRole.tag,
      ),
      isTrue,
    );
  });

  test('applies search background without replacing token role', () async {
    final fragment = html_parser.parseFragment(
      '<pre><code class="language-jsx"><mark '
      '${ReaderSearchService.markerAttribute}="${ReaderSearchService.markerAttributeValue}" '
      '${ReaderSearchService.markerAnchorAttribute}="a1">export</mark> default App</code></pre>',
    );
    final pre = fragment.querySelector('pre')!;
    final code = fragment.querySelector('code')!;

    final result = await renderer.render(
      ReaderCodeRenderInput(
        source: code,
        pre: pre,
        baseStyle: const TextStyle(fontFamily: 'monospace'),
        activeSearchBackground: const Color(0xFFFFFF00),
        searchBackground: const Color(0xFFEEEE00),
        errorColor: const Color(0xFFD1242F),
        brightness: Brightness.light,
        currentAnchorId: 'a1',
      ),
    );

    final exportToken = result.document.lines.single.tokens.firstWhere(
      (token) => token.text == 'export',
    );
    expect(exportToken.role, ReaderCodeTokenRole.keyword);
    expect(exportToken.backgroundRole, ReaderCodeTokenRole.searchCurrent);
  });
}
