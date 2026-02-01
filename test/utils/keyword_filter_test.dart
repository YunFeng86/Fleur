import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_reader/utils/keyword_filter.dart';

void main() {
  test('empty pattern matches (no filtering)', () {
    expect(
      ReservedKeywordFilter.matches(pattern: '   ', fields: const ['hello']),
      isTrue,
    );
  });

  test('OR groups separated by ;', () {
    expect(
      ReservedKeywordFilter.matches(pattern: 'dart;flutter', fields: const ['I like Dart']),
      isTrue,
    );
    expect(
      ReservedKeywordFilter.matches(pattern: 'dart;flutter', fields: const ['Flutter is great']),
      isTrue,
    );
    expect(
      ReservedKeywordFilter.matches(pattern: 'dart;flutter', fields: const ['Riverpod']),
      isFalse,
    );
  });

  test('AND tokens separated by +', () {
    expect(
      ReservedKeywordFilter.matches(
        pattern: 'dart+flutter',
        fields: const ['Dart and Flutter'],
      ),
      isTrue,
    );
    expect(
      ReservedKeywordFilter.matches(
        pattern: 'dart+flutter',
        fields: const ['Dart only'],
      ),
      isFalse,
    );
  });

  test('matches across multiple fields', () {
    expect(
      ReservedKeywordFilter.matches(
        pattern: 'dart+riverpod',
        fields: const ['Dart', 'Riverpod'],
      ),
      isTrue,
    );
  });
}

