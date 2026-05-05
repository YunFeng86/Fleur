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
}
