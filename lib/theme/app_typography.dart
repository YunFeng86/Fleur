import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/platform.dart' as platform;

class AppTypography {
  const AppTypography._();

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
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.12,
      ),
      titleLarge: applied.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        height: 1.18,
      ),
      titleMedium: applied.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.24,
      ),
      titleSmall: applied.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
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
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      labelMedium: applied.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.18,
      ),
      labelSmall: applied.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}
