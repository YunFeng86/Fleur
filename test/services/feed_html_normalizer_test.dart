import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/feed_html_normalizer.dart';

void main() {
  test('normalizes protocol-relative image urls with the article scheme', () {
    final normalized = FeedHtmlNormalizer.normalize(
      '<p><img src="//image.example/a.png"></p>',
      baseUrl: Uri.parse('https://site.example/post'),
    );

    expect(normalized, contains('src="https://image.example/a.png"'));
  });

  test(
    'uses https for protocol-relative images when base url is unavailable',
    () {
      final normalized = FeedHtmlNormalizer.normalize(
        '<p><img src="//image.example/a.png"></p>',
      );

      expect(normalized, contains('src="https://image.example/a.png"'));
    },
  );

  test('promotes lazy image attributes to src', () {
    final normalized = FeedHtmlNormalizer.normalize(
      '<p>'
      '<img src="" data-src="https://cdn.example/data.png">'
      '<img src="about:blank" data-lazy-src="/lazy.png">'
      '<img src="placeholder.gif" data-original="https://cdn.example/orig.png">'
      '<img data-srcset="/from-srcset.png 1x, /second.png 2x">'
      '</p>',
      baseUrl: Uri.parse('https://site.example/articles/one/'),
    );

    expect(normalized, contains('src="https://cdn.example/data.png"'));
    expect(normalized, contains('src="https://site.example/lazy.png"'));
    expect(normalized, contains('src="https://cdn.example/orig.png"'));
    expect(normalized, contains('src="https://site.example/from-srcset.png"'));
  });

  test('resolves relative image and link urls against article url', () {
    final normalized = FeedHtmlNormalizer.normalize(
      '<p><a href="../demo">Demo</a><img src="./img.png"></p>',
      baseUrl: Uri.parse('https://site.example/blog/post/'),
    );

    expect(normalized, contains('href="https://site.example/blog/demo"'));
    expect(
      normalized,
      contains('src="https://site.example/blog/post/img.png"'),
    );
  });

  test('removes unusable image sources from src', () {
    final normalized = FeedHtmlNormalizer.normalize(
      '<p>'
      '<img src="">'
      '<img src="data:image/png;base64,abc">'
      '<img src="about:blank">'
      '<img src="/placeholder.png">'
      '</p>',
      baseUrl: Uri.parse('https://site.example/post'),
    );

    expect(normalized, isNot(contains('src=""')));
    expect(normalized, isNot(contains('data:image')));
    expect(normalized, isNot(contains('about:blank')));
    expect(normalized, isNot(contains('placeholder.png')));
  });
}
