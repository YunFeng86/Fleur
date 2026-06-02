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
        surfaces.copyWith(
          card: reader.summarySurface,
          floating: reader.searchBarSurface,
          reader: readerSurface,
        ),
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

  final values = switch (preset) {
    ReaderThemePreset.paper => (
      brightness: Brightness.light,
      surface: const Color(0xFFFBF7EF),
      container: const Color(0xFFF2E9DC),
      onSurface: const Color(0xFF2E261F),
      onVariant: const Color(0xFF6D6256),
      outline: const Color(0xFFCDBEA9),
      accent: const Color(0xFF7D5A2E),
    ),
    ReaderThemePreset.sepia => (
      brightness: Brightness.light,
      surface: const Color(0xFFF3E7D2),
      container: const Color(0xFFEBD9BD),
      onSurface: const Color(0xFF2F2419),
      onVariant: const Color(0xFF735F48),
      outline: const Color(0xFFC7A97E),
      accent: const Color(0xFF8A5A24),
    ),
    ReaderThemePreset.dim => (
      brightness: Brightness.dark,
      surface: const Color(0xFF222426),
      container: const Color(0xFF2B2E31),
      onSurface: const Color(0xFFE5E1DA),
      onVariant: const Color(0xFFBEB7AE),
      outline: const Color(0xFF555B60),
      accent: const Color(0xFF9DB7FF),
    ),
    ReaderThemePreset.dark => (
      brightness: Brightness.dark,
      surface: const Color(0xFF111214),
      container: const Color(0xFF1B1D20),
      onSurface: const Color(0xFFECEFF1),
      onVariant: const Color(0xFFBDC1C6),
      outline: const Color(0xFF4B5055),
      accent: const Color(0xFFAECBFA),
    ),
    ReaderThemePreset.defaultLightAware => throw StateError('handled above'),
  };

  return base.copyWith(
    brightness: values.brightness,
    primary: values.accent,
    secondary: values.accent,
    tertiary: values.accent,
    surface: values.surface,
    surfaceDim: values.surface,
    surfaceBright: values.surface,
    surfaceContainerLowest: values.surface,
    surfaceContainerLow: values.container,
    surfaceContainer: values.container,
    surfaceContainerHigh: values.container,
    surfaceContainerHighest: values.container,
    onSurface: values.onSurface,
    onSurfaceVariant: values.onVariant,
    outline: values.outline,
    outlineVariant: values.outline.withValues(alpha: 0.64),
    primaryContainer: values.container,
    onPrimaryContainer: values.onSurface,
    secondaryContainer: values.container,
    onSecondaryContainer: values.onSurface,
  );
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
    ReaderThemePreset.dim ||
    ReaderThemePreset.dark => scheme.surface,
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
    toolbarSurface: scheme.surfaceContainerLow,
    searchBarSurface: scheme.surfaceContainerHigh,
    bannerSurface: scheme.surfaceContainer,
    blockquoteAccent: scheme.primary,
    codeBlockSurface: scheme.surfaceContainerHighest,
  );
}
