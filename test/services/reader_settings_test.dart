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
    expect(settings.contentWidthPreset, ReaderContentWidthPreset.narrow);
  });

  test('ReaderSettings.fromJson defaults invalid values', () {
    final settings = ReaderSettings.fromJson(<String, Object?>{
      'fontSize': '18',
      'lineHeight': null,
      'horizontalPadding': true,
    });

    expect(settings.fontSize, ReaderSettings.defaultFontSize);
    expect(settings.lineHeight, ReaderSettings.defaultLineHeight);
    expect(settings.horizontalPadding, ReaderSettings.defaultHorizontalPadding);
    expect(settings.readerTheme, ReaderThemePreset.defaultLightAware);
    expect(settings.fontFamily, ReaderFontFamily.system);
    expect(settings.contentWidthPreset, ReaderContentWidthPreset.standard);
  });

  test('ReaderSettings.fromJson defaults non-finite values', () {
    final settings = ReaderSettings.fromJson(<String, Object?>{
      'fontSize': double.nan,
      'lineHeight': double.infinity,
      'horizontalPadding': double.negativeInfinity,
    });

    expect(settings.fontSize, ReaderSettings.defaultFontSize);
    expect(settings.lineHeight, ReaderSettings.defaultLineHeight);
    expect(settings.horizontalPadding, ReaderSettings.defaultHorizontalPadding);
  });

  test('ReaderSettings persists reader appearance fields', () {
    const settings = ReaderSettings(
      readerTheme: ReaderThemePreset.sepia,
      fontFamily: ReaderFontFamily.serif,
      contentWidthPreset: ReaderContentWidthPreset.wide,
    );

    final restored = ReaderSettings.fromJson(
      settings.toJson().cast<String, Object?>(),
    );

    expect(restored.readerTheme, ReaderThemePreset.sepia);
    expect(restored.fontFamily, ReaderFontFamily.serif);
    expect(restored.contentWidthPreset, ReaderContentWidthPreset.wide);
  });

  test('ReaderSettings defaults unknown reader appearance fields', () {
    final settings = ReaderSettings.fromJson(<String, Object?>{
      'readerTheme': 'neon',
      'fontFamily': 'comic',
      'contentWidthPreset': 'huge',
    });

    expect(settings.readerTheme, ReaderThemePreset.defaultLightAware);
    expect(settings.fontFamily, ReaderFontFamily.system);
    expect(settings.contentWidthPreset, ReaderContentWidthPreset.standard);
  });

  test('ReaderSettings maps legacy dark reader theme to dim texture', () {
    final settings = ReaderSettings.fromJson(<String, Object?>{
      'readerTheme': 'dark',
    });

    expect(settings.readerTheme, ReaderThemePreset.dim);
  });

  test('ReaderSettings maps legacy horizontal padding to width preset', () {
    final wide = ReaderSettings.fromJson(<String, Object?>{
      'horizontalPadding': 8,
    });
    final standard = ReaderSettings.fromJson(<String, Object?>{
      'horizontalPadding': 16,
    });
    final narrow = ReaderSettings.fromJson(<String, Object?>{
      'horizontalPadding': 32,
    });

    expect(wide.contentWidthPreset, ReaderContentWidthPreset.wide);
    expect(standard.contentWidthPreset, ReaderContentWidthPreset.standard);
    expect(narrow.contentWidthPreset, ReaderContentWidthPreset.narrow);
  });
}
