import 'settings_json.dart';

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 16,
    this.lineHeight = 1.5,
    this.horizontalPadding = 16,
  });

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
      fontSize: readDoubleOr(json['fontSize'], 16),
      lineHeight: readDoubleOr(json['lineHeight'], 1.5),
      horizontalPadding: readDoubleOr(json['horizontalPadding'], 16),
    );
  }
}
