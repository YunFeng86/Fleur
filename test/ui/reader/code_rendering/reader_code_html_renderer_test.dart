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

    expect(extraction.hasTokenStyles, isTrue);
    expect(
      extraction.tokens.any(
        (token) =>
            token.text == 'import' && token.role == ReaderCodeTokenRole.keyword,
      ),
      isTrue,
    );
    expect(
      extraction.tokens.any(
        (token) =>
            token.text == '"pkg"' && token.role == ReaderCodeTokenRole.string,
      ),
      isTrue,
    );
    expect(
      extraction.tokens.any(
        (token) =>
            token.text == 'red' &&
            token.colorOverride == const Color(0xFFFF0000),
      ),
      isTrue,
    );
  });

  test('maps docusaurus prism token classes to richer roles', () {
    final fragment = html_parser.parseFragment(
      '<code>'
      '<span class="token keyword module">import</span>'
      '<span class="token imports maybe-class-name">Box</span>'
      '<span class="token literal-property property">borderRadius</span>'
      '<span class="token string-property property">\'&amp; .MuiSlider-thumb\'</span>'
      '<span class="token operator">:</span>'
      '<span class="token punctuation">,</span>'
      '<span class="token plain-text">&lt;Slider</span>'
      '</code>',
    );

    final extraction = renderer.extract(fragment.querySelector('code')!);

    ReaderCodeTokenRole roleFor(String text) {
      return extraction.tokens.firstWhere((token) => token.text == text).role;
    }

    expect(roleFor('import'), ReaderCodeTokenRole.keyword);
    expect(roleFor('Box'), ReaderCodeTokenRole.type);
    expect(roleFor('borderRadius'), ReaderCodeTokenRole.property);
    expect(roleFor("'& .MuiSlider-thumb'"), ReaderCodeTokenRole.string);
    expect(roleFor(':'), ReaderCodeTokenRole.operator);
    expect(roleFor(','), ReaderCodeTokenRole.punctuation);
    expect(roleFor('<Slider'), ReaderCodeTokenRole.plain);
  });
}
