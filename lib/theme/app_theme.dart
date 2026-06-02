import 'package:flutter/material.dart';

import 'app_component_themes.dart';
import 'app_theme_profile.dart';
import 'app_typography.dart';
import 'fleur_color_engine.dart';
import 'fleur_theme_extensions.dart';
import 'seed_color_presets.dart';

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

  static ThemeData readerScene(ThemeData base) {
    final surfaces = base.fleurSurface;
    final states = base.fleurState;
    final reader = base.fleurReader;
    final dynamicColor = base.fleurDynamicColor;
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
