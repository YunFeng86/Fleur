import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/utils/date_parse.dart';

void main() {
  group('tryParseFeedDate', () {
    test('parses RSS RFC822 date with numeric timezone', () {
      final parsed = tryParseFeedDate('Tue, 06 Aug 2024 18:30:00 +0800');

      expect(parsed, DateTime.utc(2024, 8, 6, 10, 30));
    });

    test('rejects overflowing RSS day values', () {
      final parsed = tryParseFeedDate('Tue, 32 Jan 2024 10:00:00 +0000');

      expect(parsed, isNull);
    });

    test('rejects overflowing RSS time values', () {
      final parsed = tryParseFeedDate('Tue, 06 Aug 2024 25:00:00 +0000');

      expect(parsed, isNull);
    });
  });
}
