import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/platform.dart' as platform;

class AppTypography {
  const AppTypography._();

  /// Keep the common Windows title weights aligned with the cross-platform
  /// hierarchy. Only the uncommon heavy extremes are softened; lowering w700
  /// to w600 makes CJK titles visibly too light beside the macOS equivalent.
  static FontWeight platformWeight(FontWeight weight) {
    if (!platform.isWindows) return weight;
    if (weight == FontWeight.w900) return FontWeight.w800;
    return weight;
  }

  static String? fontFamily() {
    if (platform.isWindows) return 'Segoe UI';
    return null;
  }

  static List<String> fontFallback() {
    if (kIsWeb) {
      return const [
        'PingFang SC',
        'PingFang TC',
        'Microsoft YaHei UI',
        'Microsoft YaHei',
        'Noto Sans CJK SC',
        'Noto Sans SC',
        'Source Han Sans SC',
        'WenQuanYi Micro Hei',
        'Noto Sans',
        'system-ui',
        'Arial',
        'sans-serif',
      ];
    }

    return switch (platform.effectiveTargetPlatform) {
      TargetPlatform.macOS || TargetPlatform.iOS => const [
        'PingFang SC',
        'PingFang TC',
        'Heiti SC',
        'Heiti TC',
        'Songti SC',
        'Hiragino Sans GB',
        '.SF Pro Text',
        '.SF UI Text',
      ],
      TargetPlatform.windows => const [
        'Microsoft YaHei UI',
        'Microsoft YaHei',
        'DengXian',
        'SimHei',
        'SimSun',
        'Noto Sans SC',
        'Noto Sans CJK SC',
        'Arial',
      ],
      TargetPlatform.linux => const [
        'Noto Sans CJK SC',
        'Noto Sans SC',
        'Source Han Sans SC',
        'WenQuanYi Micro Hei',
        'Noto Sans',
        'DejaVu Sans',
      ],
      _ => const [
        'Roboto',
        'Noto Sans CJK SC',
        'Noto Sans SC',
        'Noto Sans',
        'Droid Sans Fallback',
      ],
    };
  }

  static TextTheme buildTextTheme(TextTheme base, ColorScheme scheme) {
    final applied = base.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return applied.copyWith(
      headlineMedium: applied.headlineMedium?.copyWith(
        fontWeight: platformWeight(FontWeight.w700),
        letterSpacing: -0.6,
        height: 1.12,
      ),
      titleLarge: applied.titleLarge?.copyWith(
        fontWeight: platformWeight(FontWeight.w700),
        letterSpacing: -0.25,
        height: 1.18,
      ),
      titleMedium: applied.titleMedium?.copyWith(
        fontWeight: platformWeight(FontWeight.w600),
        letterSpacing: -0.1,
        height: 1.24,
      ),
      titleSmall: applied.titleSmall?.copyWith(
        fontWeight: platformWeight(FontWeight.w600),
        height: 1.25,
      ),
      bodyLarge: applied.bodyLarge?.copyWith(height: 1.52, letterSpacing: 0.05),
      bodyMedium: applied.bodyMedium?.copyWith(
        height: 1.46,
        letterSpacing: 0.05,
      ),
      bodySmall: applied.bodySmall?.copyWith(
        height: 1.38,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: applied.labelLarge?.copyWith(
        fontWeight: platformWeight(FontWeight.w600),
        letterSpacing: 0.15,
      ),
      labelMedium: applied.labelMedium?.copyWith(
        fontWeight: platformWeight(FontWeight.w600),
        letterSpacing: 0.18,
      ),
      labelSmall: applied.labelSmall?.copyWith(
        fontWeight: platformWeight(FontWeight.w600),
        letterSpacing: 0.2,
      ),
    );
  }
}
