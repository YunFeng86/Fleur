import 'package:flutter/material.dart';

import 'app_component_themes.dart';
import 'app_theme_profile.dart';
import 'app_typography.dart';
import 'fleur_theme_extensions.dart';
import 'seed_color_presets.dart';

class AppTheme {
  static const double radiusCard = 8;
  static const double radiusField = 10;
  static const double desktopTitleBarHeight = 40;

  static ThemeData light({
    ColorScheme? scheme,
    SeedColorPreset? seedColorPreset,
  }) => _build(
    Brightness.light,
    dynamicScheme: scheme,
    seedColor: (seedColorPreset ?? SeedColorPreset.blue).seedColor, // default
  );

  static ThemeData dark({
    ColorScheme? scheme,
    SeedColorPreset? seedColorPreset,
  }) => _build(
    Brightness.dark,
    dynamicScheme: scheme,
    seedColor: (seedColorPreset ?? SeedColorPreset.blue).seedColor, // default
  );

  static ThemeData readerScene(ThemeData base) {
    final surfaces = base.fleurSurface;
    final states = base.fleurState;
    final reader = base.fleurReader;
    return base.copyWith(
      scaffoldBackgroundColor: surfaces.reader,
      canvasColor: surfaces.reader,
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
          reader: surfaces.reader,
        ),
        states,
        reader,
      ],
    );
  }

  static ThemeData _build(
    Brightness brightness, {
    ColorScheme? dynamicScheme,
    required Color seedColor,
  }) {
    final profile = AppThemeProfile.resolve();
    final cs =
        dynamicScheme ??
        ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
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
    final surfaces = FleurSurfaceTheme.fromScheme(cs, brightness: brightness);
    final states = FleurStateTheme.fromScheme(cs, brightness: brightness);
    final reader = FleurReaderTheme.fromTheme(
      textTheme: baseTheme.textTheme,
      scheme: cs,
      profile: profile,
    );

    return AppComponentThemes.apply(
      base: baseTheme,
      profile: profile,
      surfaces: surfaces,
      states: states,
      reader: reader,
    );
  }
}
