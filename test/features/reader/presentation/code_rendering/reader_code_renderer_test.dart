import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:fleur/services/reader_search_service.dart';
import 'package:fleur/features/reader/presentation/code_rendering/reader_code_rendering.dart';

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
            token.text == 'Box' && token.role == ReaderCodeTokenRole.type,
      ),
      isTrue,
    );
  });

  test('guesses javascript for unlabeled rss code blocks', () async {
    final fragment = html_parser.parseFragment(
      '<pre>'
      "let obj = { data: 'heavy resource' };\n"
      'const ref = new WeakRef(obj);\n'
      '// 通过 .deref() 获取目标对象\n'
      'console.log(ref.deref()?.data);'
      '</pre>',
    );
    final pre = fragment.querySelector('pre')!;

    final result = await renderer.render(
      ReaderCodeRenderInput(
        source: pre,
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
    expect(result.document.language?.id, 'javascript');
    expect(
      result.document.languageDecision.source,
      ReaderCodeLanguageDecisionSource.contentHeuristic,
    );
    expect(
      result.document.languageDecision.reasons,
      contains('builtin:WeakRef'),
    );
    expect(
      result.document.lines
          .expand((line) => line.tokens)
          .any(
            (token) =>
                token.text == 'const' &&
                token.role == ReaderCodeTokenRole.keyword,
          ),
      isTrue,
    );
    expect(
      result.document.lines
          .expand((line) => line.tokens)
          .any(
            (token) =>
                token.text == 'WeakRef' &&
                token.role == ReaderCodeTokenRole.builtin,
          ),
      isTrue,
    );
  });

  test('guesses css for unlabeled style-like code blocks', () async {
    final fragment = html_parser.parseFragment(
      '<pre>button {\n'
      '  background-color: var(--button-color, black);\n'
      '  color: contrast-color(var(--button-color, black));\n'
      '}</pre>',
    );
    final pre = fragment.querySelector('pre')!;

    final result = await renderer.render(
      ReaderCodeRenderInput(
        source: pre,
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
    expect(result.document.language?.id, 'css');
    expect(
      result.document.languageDecision.source,
      ReaderCodeLanguageDecisionSource.contentHeuristic,
    );
    expect(
      result.document.languageDecision.reasons,
      contains('css:function:contrast-color'),
    );
    expect(
      result.document.lines
          .expand((line) => line.tokens)
          .any(
            (token) =>
                token.text == 'background-color' &&
                token.role == ReaderCodeTokenRole.property,
          ),
      isTrue,
    );
  });

  test('does not guess when explicit language exists', () async {
    final fragment = html_parser.parseFragment(
      '<pre><code class="language-python">const value = 1</code></pre>',
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

    expect(result.document.language?.id, 'python');
    expect(
      result.document.languageDecision.source,
      ReaderCodeLanguageDecisionSource.codeClass,
    );
  });

  test('keeps low-confidence content guesses as plain text', () async {
    final fragment = html_parser.parseFragment('<pre>echo hi</pre>');
    final pre = fragment.querySelector('pre')!;

    final result = await renderer.render(
      ReaderCodeRenderInput(
        source: pre,
        pre: pre,
        baseStyle: const TextStyle(fontFamily: 'monospace'),
        activeSearchBackground: const Color(0xFFFFFF00),
        searchBackground: const Color(0xFFEEEE00),
        errorColor: const Color(0xFFD1242F),
        brightness: Brightness.light,
        currentAnchorId: null,
      ),
    );

    expect(result.sourceKind, ReaderCodeSourceKind.plainText);
    expect(result.document.language?.id, 'shell');
    expect(
      result.document.languageDecision.source,
      ReaderCodeLanguageDecisionSource.contentHeuristic,
    );
    expect(result.document.languageDecision.confidence, lessThan(0.62));
    expect(
      result.document.lines.single.tokens.single.role,
      ReaderCodeTokenRole.plain,
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

  test(
    'diff tokenizer emits semantic roles without fixed color overrides',
    () async {
      final fragment = html_parser.parseFragment(
        '<pre><code class="language-diff">+added\n-removed</code></pre>',
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

      final added = result.document.lines.first.tokens.single;
      final removed = result.document.lines.last.tokens.single;
      expect(added.role, ReaderCodeTokenRole.diffInserted);
      expect(removed.role, ReaderCodeTokenRole.diffDeleted);
      expect(added.colorOverride, isNull);
      expect(removed.colorOverride, isNull);
    },
  );
}
