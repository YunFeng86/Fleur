import 'settings_json.dart';

enum ReaderThemePreset { defaultLightAware, paper, sepia, dim }

enum ReaderFontFamily { system, serif, sans, mono, custom }

enum ReaderContentWidthPreset { narrow, standard, wide }

enum CodeFontFamilyPreset { systemMono, custom }

enum CodeFontSizeMode { followReader, oneStepDown, custom }

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = defaultFontSize,
    this.minimumFontSize = defaultMinimumFontSize,
    this.lineHeight = defaultLineHeight,
    this.horizontalPadding = 16,
    this.readerTheme = ReaderThemePreset.defaultLightAware,
    this.fontFamily = ReaderFontFamily.system,
    this.readerFontStack = '',
    this.standardFontStack = '',
    this.serifFontStack = '',
    this.sansFontStack = '',
    this.monoFontStack = '',
    this.mathFontStack = '',
    this.contentWidthPreset = ReaderContentWidthPreset.standard,
    this.codeFontFamily = CodeFontFamilyPreset.systemMono,
    this.codeFontStack = '',
    this.codeFontSizeMode = CodeFontSizeMode.oneStepDown,
    this.codeFontSize = defaultCodeFontSize,
    this.codeLineHeight = defaultCodeLineHeight,
    this.codeSoftWrap = false,
  });

  static const double defaultFontSize = 15;
  static const double defaultMinimumFontSize = 12;
  static const double defaultLineHeight = 1.6;
  static const double defaultHorizontalPadding = 16;
  static const double defaultCodeFontSize = 14;
  static const double defaultCodeLineHeight = 1.45;

  final double fontSize;
  final double minimumFontSize;
  final double lineHeight;
  final double horizontalPadding;
  final ReaderThemePreset readerTheme;
  final ReaderFontFamily fontFamily;
  final String readerFontStack;
  final String standardFontStack;
  final String serifFontStack;
  final String sansFontStack;
  final String monoFontStack;
  final String mathFontStack;
  final ReaderContentWidthPreset contentWidthPreset;
  final CodeFontFamilyPreset codeFontFamily;
  final String codeFontStack;
  final CodeFontSizeMode codeFontSizeMode;
  final double codeFontSize;
  final double codeLineHeight;
  final bool codeSoftWrap;

  ReaderSettings copyWith({
    double? fontSize,
    double? minimumFontSize,
    double? lineHeight,
    double? horizontalPadding,
    ReaderThemePreset? readerTheme,
    ReaderFontFamily? fontFamily,
    String? readerFontStack,
    String? standardFontStack,
    String? serifFontStack,
    String? sansFontStack,
    String? monoFontStack,
    String? mathFontStack,
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
      minimumFontSize: minimumFontSize ?? this.minimumFontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      readerTheme: readerTheme ?? this.readerTheme,
      fontFamily: fontFamily ?? this.fontFamily,
      readerFontStack: readerFontStack ?? this.readerFontStack,
      standardFontStack: standardFontStack ?? this.standardFontStack,
      serifFontStack: serifFontStack ?? this.serifFontStack,
      sansFontStack: sansFontStack ?? this.sansFontStack,
      monoFontStack: monoFontStack ?? this.monoFontStack,
      mathFontStack: mathFontStack ?? this.mathFontStack,
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
    'minimumFontSize': minimumFontSize,
    'lineHeight': lineHeight,
    'horizontalPadding': horizontalPadding,
    'readerTheme': readerTheme.name,
    'fontFamily': fontFamily.name,
    'readerFontStack': readerFontStack,
    'standardFontStack': standardFontStack,
    'serifFontStack': serifFontStack,
    'sansFontStack': sansFontStack,
    'monoFontStack': monoFontStack,
    'mathFontStack': mathFontStack,
    'contentWidthPreset': contentWidthPreset.name,
    'codeFontFamily': codeFontFamily.name,
    'codeFontStack': codeFontStack,
    'codeFontSizeMode': codeFontSizeMode.name,
    'codeFontSize': codeFontSize,
    'codeLineHeight': codeLineHeight,
    'codeSoftWrap': codeSoftWrap,
  };

  static ReaderSettings fromJson(Map<String, Object?> json) {
    final rawFontFamily = readEnumByNameOr(
      ReaderFontFamily.values,
      json['fontFamily'],
      ReaderFontFamily.system,
      trim: false,
    );
    final legacyReaderFontStack = readStringOrEmpty(json['readerFontStack']);
    final hasStandardFontStack = json.containsKey('standardFontStack');
    final standardFontStack = hasStandardFontStack
        ? readStringOrEmpty(json['standardFontStack'])
        : rawFontFamily == ReaderFontFamily.custom
        ? legacyReaderFontStack
        : '';

    final rawCodeFontFamily = readEnumByNameOr(
      CodeFontFamilyPreset.values,
      json['codeFontFamily'],
      CodeFontFamilyPreset.systemMono,
      trim: false,
    );
    final legacyCodeFontStack = readStringOrEmpty(json['codeFontStack']);
    final hasMonoFontStack = json.containsKey('monoFontStack');
    final monoFontStack = hasMonoFontStack
        ? readStringOrEmpty(json['monoFontStack'])
        : rawCodeFontFamily == CodeFontFamilyPreset.custom
        ? legacyCodeFontStack
        : '';

    return ReaderSettings(
      fontSize: readDoubleOr(json['fontSize'], defaultFontSize),
      minimumFontSize: readDoubleOr(
        json['minimumFontSize'],
        defaultMinimumFontSize,
      ),
      lineHeight: readDoubleOr(json['lineHeight'], defaultLineHeight),
      horizontalPadding: readDoubleOr(
        json['horizontalPadding'],
        defaultHorizontalPadding,
      ),
      readerTheme: _readReaderThemePreset(json['readerTheme']),
      fontFamily: rawFontFamily == ReaderFontFamily.custom
          ? ReaderFontFamily.system
          : rawFontFamily,
      readerFontStack: legacyReaderFontStack,
      standardFontStack: standardFontStack,
      serifFontStack: readStringOrEmpty(json['serifFontStack']),
      sansFontStack: readStringOrEmpty(json['sansFontStack']),
      monoFontStack: monoFontStack,
      mathFontStack: readStringOrEmpty(json['mathFontStack']),
      contentWidthPreset: _readContentWidthPreset(json),
      codeFontFamily: rawCodeFontFamily == CodeFontFamilyPreset.custom
          ? CodeFontFamilyPreset.systemMono
          : rawCodeFontFamily,
      codeFontStack: legacyCodeFontStack,
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
