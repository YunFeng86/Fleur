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
    expect(settings.readerFontStack, isEmpty);
    expect(settings.contentWidthPreset, ReaderContentWidthPreset.standard);
    expect(settings.codeFontFamily, CodeFontFamilyPreset.systemMono);
    expect(settings.codeFontStack, isEmpty);
    expect(settings.codeFontSizeMode, CodeFontSizeMode.oneStepDown);
    expect(settings.codeFontSize, ReaderSettings.defaultCodeFontSize);
    expect(settings.codeLineHeight, ReaderSettings.defaultCodeLineHeight);
    expect(settings.codeSoftWrap, isFalse);
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
      fontFamily: ReaderFontFamily.custom,
      readerFontStack:
          '"PingFang SC", "Noto Sans CJK SC", system-ui, sans-serif',
      contentWidthPreset: ReaderContentWidthPreset.wide,
      codeFontFamily: CodeFontFamilyPreset.custom,
      codeFontStack: '"JetBrains Mono", "SF Mono", monospace',
      codeFontSizeMode: CodeFontSizeMode.custom,
      codeFontSize: 16,
      codeLineHeight: 1.7,
      codeSoftWrap: true,
    );

    final restored = ReaderSettings.fromJson(
      settings.toJson().cast<String, Object?>(),
    );

    expect(restored.readerTheme, ReaderThemePreset.sepia);
    expect(restored.fontFamily, ReaderFontFamily.custom);
    expect(restored.readerFontStack, settings.readerFontStack);
    expect(restored.contentWidthPreset, ReaderContentWidthPreset.wide);
    expect(restored.codeFontFamily, CodeFontFamilyPreset.custom);
    expect(restored.codeFontStack, settings.codeFontStack);
    expect(restored.codeFontSizeMode, CodeFontSizeMode.custom);
    expect(restored.codeFontSize, 16);
    expect(restored.codeLineHeight, 1.7);
    expect(restored.codeSoftWrap, isTrue);
  });

  test('ReaderSettings defaults unknown reader appearance fields', () {
    final settings = ReaderSettings.fromJson(<String, Object?>{
      'readerTheme': 'neon',
      'fontFamily': 'comic',
      'contentWidthPreset': 'huge',
      'codeFontFamily': 'proportional',
      'codeFontSizeMode': 'huge',
    });

    expect(settings.readerTheme, ReaderThemePreset.defaultLightAware);
    expect(settings.fontFamily, ReaderFontFamily.system);
    expect(settings.contentWidthPreset, ReaderContentWidthPreset.standard);
    expect(settings.codeFontFamily, CodeFontFamilyPreset.systemMono);
    expect(settings.codeFontSizeMode, CodeFontSizeMode.oneStepDown);
  });

  test('ReaderSettings loads old json without new appearance fields', () {
    final settings = ReaderSettings.fromJson(<String, Object?>{
      'fontSize': 17,
      'lineHeight': 1.8,
      'horizontalPadding': 16,
    });

    expect(settings.fontSize, 17);
    expect(settings.lineHeight, 1.8);
    expect(settings.readerFontStack, isEmpty);
    expect(settings.codeFontFamily, CodeFontFamilyPreset.systemMono);
    expect(settings.codeFontStack, isEmpty);
    expect(settings.codeFontSizeMode, CodeFontSizeMode.oneStepDown);
    expect(settings.codeFontSize, ReaderSettings.defaultCodeFontSize);
    expect(settings.codeLineHeight, ReaderSettings.defaultCodeLineHeight);
    expect(settings.codeSoftWrap, isFalse);
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
