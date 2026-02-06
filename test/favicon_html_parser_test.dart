import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_reader/services/network/favicon_service.dart';

void main() {
  test('FaviconHtmlParser extracts and resolves icon hrefs', () {
    const html = '''
<!doctype html>
<html>
  <head>
    <link rel="icon" sizes="32x32" href="/icon-32.png">
    <link rel="icon" sizes="180x180" href="https://cdn.example.com/icon-180.png">
    <link rel="apple-touch-icon" sizes="180x180" href="/apple-180.png">
  </head>
  <body>ok</body>
</html>
''';

    final out = FaviconHtmlParser.extractCandidates(
      html: html,
      baseUri: Uri.parse('https://example.com/some/path'),
    );

    // Prefer rel="icon" and then larger size within the same rel group.
    expect(out.first, 'https://cdn.example.com/icon-180.png');

    // Ensure relative URLs are resolved against the response URI.
    expect(out, contains('https://example.com/icon-32.png'));
    expect(out, contains('https://example.com/apple-180.png'));

    // Always includes /favicon.ico fallback.
    expect(out, contains('https://example.com/favicon.ico'));
  });
}
