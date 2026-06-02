import 'settings_json.dart';

enum ReaderThemePreset { defaultLightAware, paper, sepia, dim }

enum ReaderFontFamily { system, serif, sans, mono, custom }

enum ReaderContentWidthPreset { narrow, standard, wide }

enum CodeFontFamilyPreset { systemMono, custom }

enum CodeFontSizeMode { followReader, oneStepDown, custom }

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = defaultFontSize,
    this.lineHeight = defaultLineHeight,
    this.horizontalPadding = 16,
    this.readerTheme = ReaderThemePreset.defaultLightAware,
    this.fontFamily = ReaderFontFamily.system,
    this.readerFontStack = '',
    this.contentWidthPreset = ReaderContentWidthPreset.standard,
    this.codeFontFamily = CodeFontFamilyPreset.systemMono,
    this.codeFontStack = '',
    this.codeFontSizeMode = CodeFontSizeMode.oneStepDown,
    this.codeFontSize = defaultCodeFontSize,
    this.codeLineHeight = defaultCodeLineHeight,
    this.codeSoftWrap = false,
  });

  static const double defaultFontSize = 15;
  static const double defaultLineHeight = 1.6;
  static const double defaultHorizontalPadding = 16;
  static const double defaultCodeFontSize = 14;
  static const double defaultCodeLineHeight = 1.45;

  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;
  final ReaderThemePreset readerTheme;
  final ReaderFontFamily fontFamily;
  final String readerFontStack;
  final ReaderContentWidthPreset contentWidthPreset;
  final CodeFontFamilyPreset codeFontFamily;
  final String codeFontStack;
  final CodeFontSizeMode codeFontSizeMode;
  final double codeFontSize;
  final double codeLineHeight;
  final bool codeSoftWrap;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? horizontalPadding,
    ReaderThemePreset? readerTheme,
    ReaderFontFamily? fontFamily,
    String? readerFontStack,
    ReaderContentWidthPreset? contentWidthPreset,
    CodeFontFamilyPreset? codeFontFamily,
    String? codeFontStack,
    CodeFontSizeMode? codeFontSizeMode,
    double? codeFontSize,
    double? codeLineHeight,
    bool? codeSoftWrap,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      readerTheme: readerTheme ?? this.readerTheme,
      fontFamily: fontFamily ?? this.fontFamily,
      readerFontStack: readerFontStack ?? this.readerFontStack,
      contentWidthPreset: contentWidthPreset ?? this.contentWidthPreset,
      codeFontFamily: codeFontFamily ?? this.codeFontFamily,
      codeFontStack: codeFontStack ?? this.codeFontStack,
      codeFontSizeMode: codeFontSizeMode ?? this.codeFontSizeMode,
      codeFontSize: codeFontSize ?? this.codeFontSize,
      codeLineHeight: codeLineHeight ?? this.codeLineHeight,
      codeSoftWrap: codeSoftWrap ?? this.codeSoftWrap,
    );
  }

  Map<String, Object?> toJson() => {
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'horizontalPadding': horizontalPadding,
    'readerTheme': readerTheme.name,
    'fontFamily': fontFamily.name,
    'readerFontStack': readerFontStack,
    'contentWidthPreset': contentWidthPreset.name,
    'codeFontFamily': codeFontFamily.name,
    'codeFontStack': codeFontStack,
    'codeFontSizeMode': codeFontSizeMode.name,
    'codeFontSize': codeFontSize,
    'codeLineHeight': codeLineHeight,
    'codeSoftWrap': codeSoftWrap,
  };

  static ReaderSettings fromJson(Map<String, Object?> json) {
    return ReaderSettings(
      fontSize: readDoubleOr(json['fontSize'], defaultFontSize),
      lineHeight: readDoubleOr(json['lineHeight'], defaultLineHeight),
      horizontalPadding: readDoubleOr(
        json['horizontalPadding'],
        defaultHorizontalPadding,
      ),
      readerTheme: _readReaderThemePreset(json['readerTheme']),
      fontFamily: readEnumByNameOr(
        ReaderFontFamily.values,
        json['fontFamily'],
        ReaderFontFamily.system,
        trim: false,
      ),
      readerFontStack: readStringOrEmpty(json['readerFontStack']),
      contentWidthPreset: _readContentWidthPreset(json),
      codeFontFamily: readEnumByNameOr(
        CodeFontFamilyPreset.values,
        json['codeFontFamily'],
        CodeFontFamilyPreset.systemMono,
        trim: false,
      ),
      codeFontStack: readStringOrEmpty(json['codeFontStack']),
      codeFontSizeMode: readEnumByNameOr(
        CodeFontSizeMode.values,
        json['codeFontSizeMode'],
        CodeFontSizeMode.oneStepDown,
        trim: false,
      ),
      codeFontSize: readDoubleOr(json['codeFontSize'], defaultCodeFontSize),
      codeLineHeight: readDoubleOr(
        json['codeLineHeight'],
        defaultCodeLineHeight,
      ),
      codeSoftWrap: readBoolOr(json['codeSoftWrap'], fallback: false),
    );
  }

  static ReaderContentWidthPreset _readContentWidthPreset(
    Map<String, Object?> json,
  ) {
    final explicit = json['contentWidthPreset'];
    if (explicit != null) {
      return readEnumByNameOr(
        ReaderContentWidthPreset.values,
        explicit,
        ReaderContentWidthPreset.standard,
        trim: false,
      );
    }

    final legacyPadding = readDoubleOr(json['horizontalPadding'], double.nan);
    if (!legacyPadding.isFinite) return ReaderContentWidthPreset.standard;
    if (legacyPadding <= 12) return ReaderContentWidthPreset.wide;
    if (legacyPadding >= 24) return ReaderContentWidthPreset.narrow;
    return ReaderContentWidthPreset.standard;
  }

  static ReaderThemePreset _readReaderThemePreset(Object? value) {
    if (value == 'dark') return ReaderThemePreset.dim;
    return readEnumByNameOr(
      ReaderThemePreset.values,
      value,
      ReaderThemePreset.defaultLightAware,
      trim: false,
    );
  }
}
