import 'package:flutter/material.dart';

import 'app_component_themes.dart';
import 'app_theme_profile.dart';
import 'app_typography.dart';
import 'fleur_color_engine.dart';
import 'fleur_theme_extensions.dart';
import 'seed_color_presets.dart';
import '../services/settings/reader_settings.dart';

class AppTheme {
  static const double radiusCard = 8;
  static const double radiusField = 10;

  static ThemeData light({
    ColorScheme? scheme,
    SeedColorPreset? seedColorPreset,
    bool dynamicColorAvailable = false,
  }) => _build(
    Brightness.light,
    dynamicScheme: scheme,
    seedColorPreset: seedColorPreset ?? SeedColorPreset.blue,
    dynamicColorAvailable: dynamicColorAvailable,
  );

  static ThemeData dark({
    ColorScheme? scheme,
    SeedColorPreset? seedColorPreset,
    bool dynamicColorAvailable = false,
  }) => _build(
    Brightness.dark,
    dynamicScheme: scheme,
    seedColorPreset: seedColorPreset ?? SeedColorPreset.blue,
    dynamicColorAvailable: dynamicColorAvailable,
  );

  static ThemeData readerScene(
    ThemeData base, {
    ReaderSettings settings = const ReaderSettings(),
  }) {
    final scheme = _readerScheme(base.colorScheme, settings.readerTheme);
    final surfaces = base.fleurSurface;
    final states = base.fleurState;
    final readerColors = _readerColorsFor(
      scheme: scheme,
      base: base.fleurReader,
      preset: settings.readerTheme,
    );
    final reader = FleurReaderTheme.fromTheme(
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      scheme: scheme,
      profile: AppThemeProfile.resolve(),
      colors: readerColors,
      settings: settings,
    );
    final dynamicColor = base.fleurDynamicColor;
    final readerSurface = _readerSurfaceFor(
      scheme: scheme,
      base: surfaces.reader,
      preset: settings.readerTheme,
    );
    final textTheme = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: readerSurface,
      canvasColor: readerSurface,
      dividerTheme: DividerThemeData(
        color: surfaces.subtleDivider,
        thickness: 1,
        space: 1,
      ),
      cardTheme: base.cardTheme.copyWith(color: reader.summarySurface),
      textSelectionTheme: base.textSelectionTheme.copyWith(
        selectionColor: states.selectionTint,
      ),
      extensions: <ThemeExtension<dynamic>>[
        surfaces.copyWith(reader: readerSurface),
        states,
        reader,
        dynamicColor,
      ],
    );
  }

  static ThemeData _build(
    Brightness brightness, {
    ColorScheme? dynamicScheme,
    required SeedColorPreset seedColorPreset,
    required bool dynamicColorAvailable,
  }) {
    final profile = AppThemeProfile.resolve();
    final colorTokens = FleurColorEngine.resolve(
      brightness: brightness,
      dynamicScheme: dynamicScheme,
      seedColorPreset: seedColorPreset,
    );
    final cs = colorTokens.materialScheme;
    final baseMaterialTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      fontFamily: AppTypography.fontFamily(),
      fontFamilyFallback: AppTypography.fontFallback(),
    );

    final baseTheme = baseMaterialTheme.copyWith(
      visualDensity: profile.visualDensity,
      textTheme: AppTypography.buildTextTheme(baseMaterialTheme.textTheme, cs),
    );
    final surfaces = colorTokens.surfaces;
    final states = colorTokens.states;
    final dynamicColor = FleurDynamicColorTheme(
      available: dynamicColorAvailable,
    );
    final reader = FleurReaderTheme.fromTheme(
      textTheme: baseTheme.textTheme,
      scheme: cs,
      profile: profile,
      colors: colorTokens.readerColors,
    );

    return AppComponentThemes.apply(
      base: baseTheme,
      profile: profile,
      surfaces: surfaces,
      states: states,
      reader: reader,
      dynamicColor: dynamicColor,
    );
  }
}

ColorScheme _readerScheme(ColorScheme base, ReaderThemePreset preset) {
  if (preset == ReaderThemePreset.defaultLightAware) return base;

  final dark = base.brightness == Brightness.dark;
  final textureTint = _readerTextureTint(base, preset);
  final surfaceWeight = switch (preset) {
    ReaderThemePreset.paper => dark ? 0.10 : 0.16,
    ReaderThemePreset.sepia => dark ? 0.14 : 0.24,
    ReaderThemePreset.dim => dark ? 0.08 : 0.05,
    ReaderThemePreset.defaultLightAware => throw StateError('handled above'),
  };
  final containerWeight = (surfaceWeight + (dark ? 0.04 : 0.03)).clamp(
    0.0,
    1.0,
  );

  return base.copyWith(
    surface: _blend(base.surface, textureTint, surfaceWeight),
    surfaceDim: _blend(base.surfaceDim, textureTint, surfaceWeight),
    surfaceBright: _blend(base.surfaceBright, textureTint, surfaceWeight),
    surfaceContainerLowest: _blend(
      base.surfaceContainerLowest,
      textureTint,
      surfaceWeight,
    ),
    surfaceContainerLow: _blend(
      base.surfaceContainerLow,
      textureTint,
      containerWeight,
    ),
    surfaceContainer: _blend(
      base.surfaceContainer,
      textureTint,
      containerWeight,
    ),
    surfaceContainerHigh: _blend(
      base.surfaceContainerHigh,
      textureTint,
      containerWeight,
    ),
    surfaceContainerHighest: _blend(
      base.surfaceContainerHighest,
      textureTint,
      containerWeight,
    ),
    outlineVariant: _blend(
      base.outlineVariant,
      textureTint,
      dark ? 0.18 : 0.12,
    ),
  );
}

Color _readerTextureTint(ColorScheme base, ReaderThemePreset preset) {
  final dark = base.brightness == Brightness.dark;
  final accent = base.primary;
  final warmPaper = dark ? const Color(0xFFFFE8C7) : const Color(0xFFFFF3DE);
  final warmSepia = dark ? const Color(0xFFFFC777) : const Color(0xFFE2A75A);
  final neutral = dark ? base.onSurface : const Color(0xFF66707A);

  return switch (preset) {
    ReaderThemePreset.paper => _blend(warmPaper, accent, dark ? 0.18 : 0.12),
    ReaderThemePreset.sepia => _blend(warmSepia, accent, dark ? 0.16 : 0.10),
    ReaderThemePreset.dim => _blend(neutral, accent, dark ? 0.22 : 0.12),
    ReaderThemePreset.defaultLightAware => accent,
  };
}

Color _blend(Color base, Color tint, double opacity) {
  return Color.alphaBlend(tint.withValues(alpha: opacity), base);
}

Color _readerSurfaceFor({
  required ColorScheme scheme,
  required Color base,
  required ReaderThemePreset preset,
}) {
  return switch (preset) {
    ReaderThemePreset.defaultLightAware => base,
    ReaderThemePreset.paper ||
    ReaderThemePreset.sepia ||
    ReaderThemePreset.dim => scheme.surface,
  };
}

FleurReaderColorTokens _readerColorsFor({
  required ColorScheme scheme,
  required FleurReaderTheme base,
  required ReaderThemePreset preset,
}) {
  if (preset == ReaderThemePreset.defaultLightAware) {
    return FleurReaderColorTokens(
      summarySurface: base.summarySurface,
      toolbarSurface: base.toolbarSurface,
      searchBarSurface: base.searchBarSurface,
      bannerSurface: base.bannerSurface,
      blockquoteAccent: base.blockquoteAccent,
      codeBlockSurface: base.codeBlockSurface,
    );
  }

  return FleurReaderColorTokens(
    summarySurface: scheme.surfaceContainerLow,
    toolbarSurface: base.toolbarSurface,
    searchBarSurface: base.searchBarSurface,
    bannerSurface: scheme.surfaceContainer,
    blockquoteAccent: scheme.primary,
    codeBlockSurface: scheme.surfaceContainerHighest,
  );
}
