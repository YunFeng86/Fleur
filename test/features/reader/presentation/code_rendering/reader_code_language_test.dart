import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:fleur/features/reader/presentation/code_rendering/reader_code_rendering.dart';

void main() {
  const resolver = ReaderCodeLanguageResolver();

  test('keeps jsx and tsx canonical ids while resolving aliases', () {
    expect(resolver.resolveCandidates(['jsx'])?.id, 'jsx');
    expect(resolver.resolveCandidates(['tsx'])?.id, 'tsx');
    expect(resolver.resolveCandidates(['js'])?.id, 'javascript');
    expect(resolver.resolveCandidates(['ts'])?.id, 'typescript');
    expect(resolver.resolveCandidates(['bash'])?.id, 'shell');
    expect(resolver.resolveCandidates(['md'])?.id, 'markdown');
    expect(resolver.resolveCandidates(['mdx'])?.id, 'markdown');
    expect(resolver.resolveCandidates(['jsonc'])?.id, 'json');
    expect(resolver.resolveCandidates(['scss'])?.id, 'css');
    expect(resolver.resolveCandidates(['svg'])?.id, 'xml');
    expect(resolver.resolveCandidates(['python3'])?.id, 'python');
    expect(resolver.resolveCandidates(['postgres'])?.id, 'sql');
    expect(resolver.resolveCandidates(['atom'])?.id, 'xml');
    expect(resolver.resolveCandidates(['toml'])?.id, 'toml');
    expect(resolver.resolveCandidates(['cfg'])?.id, 'ini');
    expect(resolver.resolveCandidates(['props'])?.id, 'properties');
    expect(resolver.resolveCandidates(['Containerfile'])?.id, 'dockerfile');
    expect(resolver.resolveCandidates(['Makefile'])?.id, 'makefile');
    expect(resolver.resolveCandidates(['cc'])?.id, 'cpp');
    expect(resolver.resolveCandidates(['cs'])?.id, 'csharp');
    expect(resolver.resolveCandidates(['plain'])?.id, 'plain');
  });

  test('skips plain text candidates when a stronger language follows', () {
    final language = resolver.resolveCandidates(['text', 'language-jsx']);

    expect(language?.id, 'jsx');
    expect(language?.isPlainText, isFalse);
  });

  test('resolves diff composite languages and inner hints', () {
    final language = resolver.resolveCandidates(['language-diff-js']);

    expect(language?.id, 'diff');
    expect(language?.innerLanguage, 'javascript');
    expect(
      resolver.resolveCandidates(['patch-ts'])?.innerLanguage,
      'typescript',
    );
    expect(resolver.resolveCandidates(['shell-session'])?.id, 'shell');
  });

  test('uses element candidate order from code before pre', () {
    final fragment = html_parser.parseFragment(
      '<pre class="language-python">'
      '<code class="language-text language-tsx">const value = 1;</code>'
      '</pre>',
    );
    final pre = fragment.querySelector('pre')!;
    final code = fragment.querySelector('code')!;

    expect(resolver.resolveForElements(code, pre)?.id, 'tsx');
  });

  test('returns decision metadata for explicit candidates', () {
    final fragment = html_parser.parseFragment(
      '<pre class="language-python">'
      '<code data-language="jsx">const value = 1;</code>'
      '</pre>',
    );
    final pre = fragment.querySelector('pre')!;
    final code = fragment.querySelector('code')!;

    final decision = resolver.resolveForCodeBlock(
      source: code,
      pre: pre,
      text: code.text,
      hasUpstreamTokenStyles: false,
    );

    expect(decision.language?.id, 'jsx');
    expect(decision.confidence, 1);
    expect(decision.source, ReaderCodeLanguageDecisionSource.codeDataLanguage);
    expect(decision.reasons, contains('code:data-language:jsx'));
  });

  test('resolves language from filename metadata and shebang', () {
    final filenameFragment = html_parser.parseFragment(
      '<pre data-filename="Containerfile"><code>FROM dart:stable</code></pre>',
    );
    final filenamePre = filenameFragment.querySelector('pre')!;
    final filenameCode = filenameFragment.querySelector('code')!;
    expect(
      resolver.resolveForElements(filenameCode, filenamePre)?.id,
      'dockerfile',
    );

    final makefileFragment = html_parser.parseFragment(
      '<pre data-meta="GNUmakefile"><code>build:\n\tflutter test</code></pre>',
    );
    final makefilePre = makefileFragment.querySelector('pre')!;
    final makefileCode = makefileFragment.querySelector('code')!;
    expect(
      resolver.resolveForElements(makefileCode, makefilePre)?.id,
      'makefile',
    );

    final shebangFragment = html_parser.parseFragment(
      '<pre><code>#!/usr/bin/env zsh\necho hi</code></pre>',
    );
    final shebangPre = shebangFragment.querySelector('pre')!;
    final shebangCode = shebangFragment.querySelector('code')!;
    expect(resolver.resolveForElements(shebangCode, shebangPre)?.id, 'shell');
  });

  test('decision records metadata and shebang sources', () {
    final filenameFragment = html_parser.parseFragment(
      '<pre data-filename="Containerfile"><code>FROM dart:stable</code></pre>',
    );
    final filenamePre = filenameFragment.querySelector('pre')!;
    final filenameCode = filenameFragment.querySelector('code')!;
    final filenameDecision = resolver.resolveForCodeBlock(
      source: filenameCode,
      pre: filenamePre,
      text: filenameCode.text,
      hasUpstreamTokenStyles: false,
    );

    expect(filenameDecision.language?.id, 'dockerfile');
    expect(filenameDecision.source, ReaderCodeLanguageDecisionSource.metadata);
    expect(filenameDecision.reasons.single, contains('Containerfile'));

    final shebangFragment = html_parser.parseFragment(
      '<pre><code>#!/usr/bin/env zsh\necho hi</code></pre>',
    );
    final shebangPre = shebangFragment.querySelector('pre')!;
    final shebangCode = shebangFragment.querySelector('code')!;
    final shebangDecision = resolver.resolveForCodeBlock(
      source: shebangCode,
      pre: shebangPre,
      text: shebangCode.text,
      hasUpstreamTokenStyles: false,
    );

    expect(shebangDecision.language?.id, 'shell');
    expect(shebangDecision.source, ReaderCodeLanguageDecisionSource.shebang);
    expect(shebangDecision.confidence, 0.9);
  });

  test('content heuristic reports confidence and reasons', () {
    final fragment = html_parser.parseFragment(
      '<pre>'
      "const ref = new WeakRef({ data: 'heavy resource' });\n"
      'console.log(ref.deref()?.data);'
      '</pre>',
    );
    final pre = fragment.querySelector('pre')!;

    final decision = resolver.resolveForCodeBlock(
      source: pre,
      pre: pre,
      text: pre.text,
      hasUpstreamTokenStyles: false,
    );

    expect(decision.language?.id, 'javascript');
    expect(decision.source, ReaderCodeLanguageDecisionSource.contentHeuristic);
    expect(decision.confidence, greaterThanOrEqualTo(0.72));
    expect(decision.reasons, contains('keyword:const'));
    expect(decision.reasons, contains('builtin:WeakRef'));
  });

  test('skips content heuristic when upstream token styles exist', () {
    final fragment = html_parser.parseFragment(
      '<pre><code>'
      '<span class="token keyword">const</span> ref = new WeakRef(obj);'
      '</code></pre>',
    );
    final pre = fragment.querySelector('pre')!;
    final code = fragment.querySelector('code')!;

    final decision = resolver.resolveForCodeBlock(
      source: code,
      pre: pre,
      text: code.text,
      hasUpstreamTokenStyles: true,
    );

    expect(decision.language, isNull);
    expect(decision.source, ReaderCodeLanguageDecisionSource.none);
  });

  test('short plain text is not guessed', () {
    final fragment = html_parser.parseFragment('<pre>Hello world</pre>');
    final pre = fragment.querySelector('pre')!;

    final decision = resolver.resolveForCodeBlock(
      source: pre,
      pre: pre,
      text: pre.text,
      hasUpstreamTokenStyles: false,
    );

    expect(decision.language, isNull);
    expect(decision.candidates, isEmpty);
  });
}
