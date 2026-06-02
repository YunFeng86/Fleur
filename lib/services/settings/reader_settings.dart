import 'settings_json.dart';

enum ReaderThemePreset { defaultLightAware, paper, sepia, dim, dark }

enum ReaderFontFamily { system, serif, sans, mono }

enum ReaderContentWidthPreset { narrow, standard, wide }

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = defaultFontSize,
    this.lineHeight = defaultLineHeight,
    this.horizontalPadding = 16,
    this.readerTheme = ReaderThemePreset.defaultLightAware,
    this.fontFamily = ReaderFontFamily.system,
    this.contentWidthPreset = ReaderContentWidthPreset.standard,
  });

  static const double defaultFontSize = 15;
  static const double defaultLineHeight = 1.6;
  static const double defaultHorizontalPadding = 16;

  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;
  final ReaderThemePreset readerTheme;
  final ReaderFontFamily fontFamily;
  final ReaderContentWidthPreset contentWidthPreset;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? horizontalPadding,
    ReaderThemePreset? readerTheme,
    ReaderFontFamily? fontFamily,
    ReaderContentWidthPreset? contentWidthPreset,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      readerTheme: readerTheme ?? this.readerTheme,
      fontFamily: fontFamily ?? this.fontFamily,
      contentWidthPreset: contentWidthPreset ?? this.contentWidthPreset,
    );
  }

  Map<String, Object?> toJson() => {
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'horizontalPadding': horizontalPadding,
    'readerTheme': readerTheme.name,
    'fontFamily': fontFamily.name,
    'contentWidthPreset': contentWidthPreset.name,
  };

  static ReaderSettings fromJson(Map<String, Object?> json) {
    return ReaderSettings(
      fontSize: readDoubleOr(json['fontSize'], defaultFontSize),
      lineHeight: readDoubleOr(json['lineHeight'], defaultLineHeight),
      horizontalPadding: readDoubleOr(
        json['horizontalPadding'],
        defaultHorizontalPadding,
      ),
      readerTheme: readEnumByNameOr(
        ReaderThemePreset.values,
        json['readerTheme'],
        ReaderThemePreset.defaultLightAware,
        trim: false,
      ),
      fontFamily: readEnumByNameOr(
        ReaderFontFamily.values,
        json['fontFamily'],
        ReaderFontFamily.system,
        trim: false,
      ),
      contentWidthPreset: _readContentWidthPreset(json),
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
}
