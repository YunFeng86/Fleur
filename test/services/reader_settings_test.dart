import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/services/settings/reader_settings.dart';

void main() {
  test('ReaderSettings.fromJson restores numeric values', () {
    final settings = ReaderSettings.fromJson(<String, Object?>{
      'fontSize': 18,
      'lineHeight': 1.7,
      'horizontalPadding': 24,
    });

    expect(settings.fontSize, 18);
    expect(settings.lineHeight, 1.7);
    expect(settings.horizontalPadding, 24);
  });

  test('ReaderSettings.fromJson defaults invalid values', () {
    final settings = ReaderSettings.fromJson(<String, Object?>{
      'fontSize': '18',
      'lineHeight': null,
      'horizontalPadding': true,
    });

    expect(settings.fontSize, ReaderSettings.defaultFontSize);
    expect(settings.lineHeight, ReaderSettings.defaultLineHeight);
    expect(settings.horizontalPadding, 16);
  });

  test('ReaderSettings.fromJson defaults non-finite values', () {
    final settings = ReaderSettings.fromJson(<String, Object?>{
      'fontSize': double.nan,
      'lineHeight': double.infinity,
      'horizontalPadding': double.negativeInfinity,
    });

    expect(settings.fontSize, ReaderSettings.defaultFontSize);
    expect(settings.lineHeight, ReaderSettings.defaultLineHeight);
    expect(settings.horizontalPadding, 16);
  });
}
