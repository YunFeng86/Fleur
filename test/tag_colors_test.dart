import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_reader/utils/tag_colors.dart';

void main() {
  test('normalizeTagColor accepts valid hex and normalizes', () {
    expect(normalizeTagColor('#a1b2c3'), '#A1B2C3');
    expect(normalizeTagColor('A1B2C3'), '#A1B2C3');
    expect(normalizeTagColor(''), isNull);
    expect(normalizeTagColor('#12345'), isNull);
    expect(normalizeTagColor('#12345G'), isNull);
  });

  test('tagColorFromHex returns an ARGB color', () {
    final color = tagColorFromHex('#ffffff');
    expect(color, isNotNull);
    expect(color!.toARGB32(), 0xFFFFFFFF);
  });

  test('pickTagColorForName is stable and uses palette', () {
    final a = pickTagColorForName('Flutter');
    final b = pickTagColorForName('Flutter');
    expect(a, b);
    expect(kTagColorPalette, contains(a));
  });

  test('ensureTagColor uses provided value or falls back', () {
    final explicit = ensureTagColor('Tag', '#112233');
    expect(explicit, '#112233');
    final fallback = ensureTagColor('Tag', 'invalid');
    expect(kTagColorPalette, contains(fallback));
  });

  test('resolveTagColor always returns a color', () {
    final color = resolveTagColor('Tag', 'invalid');
    expect(color, isA<Color>());
  });
}
