import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_reader/services/html_sanitizer.dart';

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
}
