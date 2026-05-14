import 'settings_json.dart';

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = defaultFontSize,
    this.lineHeight = defaultLineHeight,
    this.horizontalPadding = 16,
  });

  static const double defaultFontSize = 15;
  static const double defaultLineHeight = 1.6;

  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? horizontalPadding,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
    );
  }

  Map<String, Object?> toJson() => {
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'horizontalPadding': horizontalPadding,
  };

  static ReaderSettings fromJson(Map<String, Object?> json) {
    return ReaderSettings(
      fontSize: readDoubleOr(json['fontSize'], defaultFontSize),
      lineHeight: readDoubleOr(json['lineHeight'], defaultLineHeight),
      horizontalPadding: readDoubleOr(json['horizontalPadding'], 16),
    );
  }
}
