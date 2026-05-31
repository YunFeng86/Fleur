import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/html_sanitizer.dart';

void main() {
  test('keeps article wrapper and its content', () {
    const html = '''
<article>
  <h1>Hello</h1>
  <p>World</p>
</article>
''';
    final sanitized = HtmlSanitizer.sanitize(html);
    expect(sanitized, contains('<article'));
    expect(sanitized, contains('<h1>Hello</h1>'));
    expect(sanitized, contains('<p>World</p>'));
  });

  test('removes disallowed tags (script) and event handler attributes', () {
    const html = '''
<article>
  <p onclick="alert(1)">Hi</p>
  <script>alert("x")</script>
</article>
''';
    final sanitized = HtmlSanitizer.sanitize(html);
    expect(sanitized, isNot(contains('script')));
    expect(sanitized, isNot(contains('onclick')));
    expect(sanitized, contains('<p>Hi</p>'));
  });

  test('unwraps unknown non-dangerous structural tags', () {
    const html = '''
<article>
  <main>
    <custom-wrapper>
      <section><p>Keep this body paragraph.</p></section>
    </custom-wrapper>
  </main>
</article>
''';
    final sanitized = HtmlSanitizer.sanitize(html);
    expect(sanitized, contains('<p>Keep this body paragraph.</p>'));
    expect(sanitized, isNot(contains('<custom-wrapper')));
  });

  test('allows trusted iframe embeds', () {
    const html = '''
<article>
  <iframe src="https://www.youtube.com/embed/abc" width="560" height="315" onload="x()"></iframe>
</article>
''';
    final sanitized = HtmlSanitizer.sanitize(html);
    expect(sanitized, contains('<iframe'));
    expect(sanitized, contains('src="https://www.youtube.com/embed/abc"'));
    expect(sanitized, contains('frameborder="0"'));
    expect(sanitized, contains('allowfullscreen="true"'));
    expect(sanitized, isNot(contains('onload')));
    expect(sanitized, isNot(contains('width=')));
  });

  test('rejects iframe domains that contain allowed domains as substrings', () {
    const html = '''
<article>
  <iframe src="https://youtube.com.evil.com/embed/abc"></iframe>
</article>
''';
    final sanitized = HtmlSanitizer.sanitize(html);
    expect(sanitized, isNot(contains('<iframe')));
  });

  test('rejects iframe domains that look like allowed domains', () {
    const html = '''
<article>
  <iframe src="https://myyoutube.com/embed/abc"></iframe>
</article>
''';
    final sanitized = HtmlSanitizer.sanitize(html);
    expect(sanitized, isNot(contains('<iframe')));
  });

  test('allows trusted iframe domains case-insensitively', () {
    const html = '''
<article>
  <iframe src="https://WWW.YouTube.Com/embed/abc"></iframe>
</article>
''';
    final sanitized = HtmlSanitizer.sanitize(html);
    expect(sanitized, contains('<iframe'));
    expect(sanitized, contains('src="https://WWW.YouTube.Com/embed/abc"'));
  });

  test('keeps normalized lazy image src', () {
    const html = '''
<article>
  <p>
    <img src="https://cdn.example.com/real.webp" alt="Real image">
  </p>
</article>
''';
    final sanitized = HtmlSanitizer.sanitize(html);
    expect(sanitized, contains('src="https://cdn.example.com/real.webp"'));
    expect(sanitized, contains('alt="Real image"'));
  });

  test(
    'keeps media tags with safe attributes and strips unsafe media URLs',
    () {
      const html = '''
<article>
  <video src="https://cdn.example.com/movie.mp4" poster="javascript:bad()" controls autoplay onplay="x()">
    <source src="https://cdn.example.com/movie.webm" type="video/webm">
    <track src="https://cdn.example.com/captions.vtt" kind="subtitles" srclang="en" label="English" default>
  </video>
  <audio src="javascript:alert(1)" controls preload="eager"></audio>
</article>
''';
      final sanitized = HtmlSanitizer.sanitize(html);
      expect(sanitized, contains('<video'));
      expect(sanitized, contains('src="https://cdn.example.com/movie.mp4"'));
      expect(sanitized, contains('<source'));
      expect(sanitized, contains('type="video/webm"'));
      expect(sanitized, contains('<track'));
      expect(sanitized, contains('kind="subtitles"'));
      expect(sanitized, contains('controls'));
      expect(sanitized, isNot(contains('onplay')));
      expect(sanitized, isNot(contains('autoplay')));
      expect(sanitized, isNot(contains('poster=')));
      expect(sanitized, isNot(contains('javascript:')));
      expect(sanitized, isNot(contains('preload=')));
    },
  );

  test('keeps code language markers and removes unsafe classes', () {
    const html =
        '<article><pre class="x"><code class="language-dart evil()" data-language="dart">final x = 1;</code></pre></article>';
    final sanitized = HtmlSanitizer.sanitize(html);
    expect(sanitized, contains('class="language-dart"'));
    expect(sanitized, contains('data-language="dart"'));
    expect(sanitized, isNot(contains('evil')));
  });

  test('keeps reader math marker attributes', () {
    const html =
        '<article><fleur-math data-fleur-math="x^2" data-fleur-math-display="inline" onclick="bad()">x^2</fleur-math></article>';
    final sanitized = HtmlSanitizer.sanitize(html);
    expect(sanitized, contains('<fleur-math'));
    expect(sanitized, contains('data-fleur-math="x^2"'));
    expect(sanitized, contains('data-fleur-math-display="inline"'));
    expect(sanitized, isNot(contains('onclick')));
  });

  group('CSS property filtering', () {
    test('preserves allowed layout CSS properties', () {
      const html = '''
<article>
  <p style="text-align: center; margin: 10px; padding: 5px; border: 1px solid red">Text</p>
</article>
''';
      final sanitized = HtmlSanitizer.sanitize(html);
      expect(sanitized, contains('text-align: center'));
      expect(sanitized, contains('margin: 10px'));
      expect(sanitized, contains('padding: 5px'));
      expect(sanitized, contains('border: 1px solid red'));
    });

    test('strips typography CSS properties', () {
      const html = '''
<article>
  <p style="font-size: 18px; font-family: Arial; color: red; line-height: 1.8">Text</p>
</article>
''';
      final sanitized = HtmlSanitizer.sanitize(html);
      expect(sanitized, isNot(contains('font-size')));
      expect(sanitized, isNot(contains('font-family')));
      expect(sanitized, isNot(contains('color: red')));
      expect(sanitized, isNot(contains('line-height')));
    });

    test('preserves background-color', () {
      const html =
          '<article><p style="background-color: #f0f0f0">Text</p></article>';
      final sanitized = HtmlSanitizer.sanitize(html);
      expect(sanitized, contains('background-color: #f0f0f0'));
    });

    test('mixes allowed and denied properties', () {
      const html =
          '<article><p style="font-size: 20px; text-align: right; color: blue; margin: 8px">Text</p></article>';
      final sanitized = HtmlSanitizer.sanitize(html);
      expect(sanitized, isNot(contains('font-size')));
      expect(sanitized, isNot(contains('color: blue')));
      expect(sanitized, contains('text-align: right'));
      expect(sanitized, contains('margin: 8px'));
    });

    test('removes style attribute entirely when nothing is allowed', () {
      const html =
          '<article><p style="font-size: 14px; color: black">Text</p></article>';
      final sanitized = HtmlSanitizer.sanitize(html);
      expect(sanitized, isNot(contains('style=')));
    });

    test('blocks dangerous CSS values', () {
      const html =
          '<article><p style="background-color: expression(alert(1))">Text</p></article>';
      final sanitized = HtmlSanitizer.sanitize(html);
      expect(sanitized, isNot(contains('expression')));
    });

    test('blocks url() in CSS values', () {
      const html =
          '<article><p style="background-color: url(javascript:evil)">Text</p></article>';
      final sanitized = HtmlSanitizer.sanitize(html);
      expect(sanitized, isNot(contains('url(')));
    });

    test('only allows safe display values', () {
      const html = '<article><div style="display: flex">Flex</div></article>';
      final sanitized = HtmlSanitizer.sanitize(html);
      expect(sanitized, isNot(contains('display')));

      const html2 =
          '<article><div style="display: block">Block</div></article>';
      final sanitized2 = HtmlSanitizer.sanitize(html2);
      expect(sanitized2, contains('display: block'));
    });

    test('clamps oversized width', () {
      const html = '<article><div style="width: 2000px">Wide</div></article>';
      final sanitized = HtmlSanitizer.sanitize(html);
      expect(sanitized, contains('width: 1200px'));
    });

    test('passes through percentage and auto width', () {
      const html =
          '<article><div style="width: 100%; max-width: auto">Auto</div></article>';
      final sanitized = HtmlSanitizer.sanitize(html);
      expect(sanitized, contains('width: 100%'));
      expect(sanitized, contains('max-width: auto'));
    });
  });

  group('extended attribute support', () {
    test('preserves target and rel on links', () {
      const html =
          '<article><a href="https://example.com" target="_blank" rel="noopener">Link</a></article>';
      final sanitized = HtmlSanitizer.sanitize(html);
      expect(sanitized, contains('target="_blank"'));
      expect(sanitized, contains('rel="noopener"'));
    });

    test('preserves width and height on images', () {
      const html =
          '<article><img src="https://example.com/img.png" width="800" height="600"></article>';
      final sanitized = HtmlSanitizer.sanitize(html);
      expect(sanitized, contains('width="800"'));
      expect(sanitized, contains('height="600"'));
    });

    test('preserves data-src on images', () {
      const html =
          '<article><img src="" data-src="https://example.com/lazy.png" data-lazy-src="https://example.com/lazy2.png" data-original="https://example.com/orig.png"></article>';
      final sanitized = HtmlSanitizer.sanitize(html);
      expect(sanitized, contains('data-src="https://example.com/lazy.png"'));
      expect(
        sanitized,
        contains('data-lazy-src="https://example.com/lazy2.png"'),
      );
      expect(
        sanitized,
        contains('data-original="https://example.com/orig.png"'),
      );
    });

    test('preserves table layout attributes', () {
      const html =
          '<article><table cellpadding="4" cellspacing="2" border="1"><tr><td>Cell</td></tr></table></article>';
      final sanitized = HtmlSanitizer.sanitize(html);
      expect(sanitized, contains('cellpadding="4"'));
      expect(sanitized, contains('cellspacing="2"'));
      expect(sanitized, contains('border="1"'));
    });

    test('preserves extended table structure tags', () {
      const html =
          '<article><table><caption>Cap</caption><colgroup><col span="2"></colgroup><tfoot><tr><td>Foot</td></tr></tfoot></table></article>';
      final sanitized = HtmlSanitizer.sanitize(html);
      expect(sanitized, contains('<caption>Cap</caption>'));
      expect(sanitized, contains('<colgroup>'));
      expect(sanitized, contains('<col span="2">'));
      expect(sanitized, contains('<tfoot>'));
    });
  });
}
