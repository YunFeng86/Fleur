import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:fleur/services/reader_search_service.dart';
import 'package:fleur/ui/reader/code_rendering/reader_code_rendering.dart';

void main() {
  const renderer = ReaderCodeHtmlRenderer();

  test('preserves structured line breaks without double expansion', () {
    final fragment = html_parser.parseFragment(
      '<code>'
      '<span class="token-line"><span>import</span><span> React;</span><br></span>'
      '<span class="token-line"><span style="display: inline-block;"></span><br></span>'
      '<span class="token-line"><span>export default App;</span><br></span>'
      '</code>',
    );

    final extraction = renderer.extract(fragment.querySelector('code')!);

    expect(extraction.text, 'import React;\n\nexport default App;');
    expect(extraction.text, isNot(contains(';export')));
  });

  test('extracts search ranges from reader search marks', () {
    final fragment = html_parser.parseFragment(
      '<code>const '
      '<mark id="rs-0" '
      '${ReaderSearchService.markerAttribute}="${ReaderSearchService.markerAttributeValue}" '
      '${ReaderSearchService.markerAnchorAttribute}="rs-0">target</mark>'
      ' = 1;</code>',
    );

    final extraction = renderer.extract(fragment.querySelector('code')!);

    expect(extraction.text, 'const target = 1;');
    expect(extraction.searchRanges, hasLength(1));
    expect(extraction.searchRanges.single.anchorId, 'rs-0');
    expect(
      extraction.text.substring(
        extraction.searchRanges.single.start,
        extraction.searchRanges.single.end,
      ),
      'target',
    );
  });

  test('maps prism hljs and shiki token styles to text span colors', () {
    final fragment = html_parser.parseFragment(
      '<code>'
      '<span class="token keyword">import</span>'
      '<span class="hljs-string">"pkg"</span>'
      '<span style="color: rgb(255, 0, 0)">red</span>'
      '</code>',
    );
    final extraction = renderer.extract(fragment.querySelector('code')!);
    final span = renderer.spanFromExtraction(
      extraction,
      const TextStyle(fontFamily: 'monospace'),
    );
    final leafSpans = _flatten(span).where((span) => span.text != null);

    expect(extraction.hasTokenStyles, isTrue);
    expect(
      leafSpans.any(
        (span) => span.text == 'import' && span.style?.color != null,
      ),
      isTrue,
    );
    expect(
      leafSpans.any(
        (span) => span.text == '"pkg"' && span.style?.color != null,
      ),
      isTrue,
    );
    expect(
      leafSpans.any(
        (span) =>
            span.text == 'red' && span.style?.color == const Color(0xFFFF0000),
      ),
      isTrue,
    );
  });
}

List<TextSpan> _flatten(TextSpan span) {
  return [
    span,
    for (final child in span.children ?? const <InlineSpan>[])
      if (child is TextSpan) ..._flatten(child),
  ];
}
