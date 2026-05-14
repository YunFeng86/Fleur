import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/utils/html_utils.dart';

void main() {
  group('extractFirstImageSrc', () {
    test('returns null for null/empty', () {
      expect(extractFirstImageSrc(null), isNull);
      expect(extractFirstImageSrc(''), isNull);
      expect(extractFirstImageSrc('   '), isNull);
    });

    test('extracts first img src', () {
      const html =
          '<p>Hello</p><img src="https://a.example/x.png"><img src="https://b.example/y.png">';
      expect(extractFirstImageSrc(html), 'https://a.example/x.png');
    });

    test('supports single quotes', () {
      const html = "<img src='https://a.example/x.png'>";
      expect(extractFirstImageSrc(html), 'https://a.example/x.png');
    });

    test('falls back to data-src', () {
      const html = "<img data-src='https://a.example/x.png'>";
      expect(extractFirstImageSrc(html), 'https://a.example/x.png');
    });

    test('is case-insensitive', () {
      const html = '<IMG SRC="https://a.example/x.png">';
      expect(extractFirstImageSrc(html), 'https://a.example/x.png');
    });
  });

  group('extractPreviewText', () {
    test('strips tags and normalizes whitespace', () {
      const html =
          '<p>Hello&nbsp;<strong>world</strong></p><script>ignored()</script>';
      expect(extractPreviewText(html), 'Hello world');
    });

    test('returns empty for empty content', () {
      expect(extractPreviewText(null), '');
      expect(extractPreviewText('   '), '');
    });
  });

  group('extractPreviewImageSrc', () {
    test('accepts image with unknown dimensions', () {
      const html = '<p>Hello</p><img src="https://example.com/photo.jpg">';
      expect(extractPreviewImageSrc(html), 'https://example.com/photo.jpg');
    });

    test('skips small declared images', () {
      const html =
          '<img src="https://example.com/icon.png" width="32" height="32">'
          '<img src="https://example.com/photo.jpg" width="640" height="360">';
      expect(extractPreviewImageSrc(html), 'https://example.com/photo.jpg');
    });

    test('skips decorative tracking and avatar images', () {
      const html =
          '<img src="https://example.com/tracking-pixel.gif">'
          '<img class="avatar" src="https://example.com/user.jpg">'
          '<img src="https://example.com/article/photo.jpg">';
      expect(
        extractPreviewImageSrc(html),
        'https://example.com/article/photo.jpg',
      );
    });

    test('uses cached dimensions when available', () {
      const html =
          '<img src="https://example.com/first.jpg">'
          '<img src="https://example.com/second.jpg">';
      expect(
        extractPreviewImageSrc(
          html,
          metaLookup: (url) => url.endsWith('first.jpg')
              ? const PreviewImageSize(width: 120, height: 80)
              : const PreviewImageSize(width: 640, height: 360),
        ),
        'https://example.com/second.jpg',
      );
    });
  });
}
