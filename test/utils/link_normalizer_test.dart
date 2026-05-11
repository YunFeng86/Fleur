import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/utils/link_normalizer.dart';

void main() {
  group('LinkNormalizer', () {
    test(
      'trims URL, removes tracking params, fragments, and trailing slash',
      () {
        expect(
          LinkNormalizer.normalize(
            ' https://example.com/articles/1/?utm_source=newsletter#top ',
          ),
          'https://example.com/articles/1',
        );
      },
    );

    test('keeps non-tracking query params', () {
      expect(
        LinkNormalizer.normalize(
          'https://example.com/search/?q=flutter&utm_medium=email',
        ),
        'https://example.com/search?q=flutter',
      );
    });

    test('keeps repeated non-tracking query params', () {
      expect(
        LinkNormalizer.normalize(
          'https://example.com/search?tag=flutter&tag=dart&utm_source=rss',
        ),
        'https://example.com/search?tag=flutter&tag=dart',
      );
    });
  });
}
