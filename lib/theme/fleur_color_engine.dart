import 'package:flutter/material.dart';

import 'fleur_theme_extensions.dart';
import 'seed_color_presets.dart';

@immutable
class FleurColorTokens {
  const FleurColorTokens({
    required this.materialScheme,
    required this.surfaces,
    required this.states,
    required this.readerColors,
  });

  final ColorScheme materialScheme;
  final FleurSurfaceTheme surfaces;
  final FleurStateTheme states;
  final FleurReaderColorTokens readerColors;
}

class FleurColorEngine {
  const FleurColorEngine._();

  static FleurColorTokens resolve({
    required Brightness brightness,
    ColorScheme? dynamicScheme,
    required SeedColorPreset seedColorPreset,
  }) {
    final accentScheme =
        dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: seedColorPreset.seedColor,
          brightness: brightness,
        );
    final materialScheme = _neutralizeScheme(accentScheme, brightness);
    final surfaces = _buildSurfaces(materialScheme, brightness);
    final states = FleurStateTheme.fromScheme(
      materialScheme,
      brightness: brightness,
    );
    final readerColors = _buildReaderColors(materialScheme, surfaces);

    return FleurColorTokens(
      materialScheme: materialScheme,
      surfaces: surfaces,
      states: states,
      readerColors: readerColors,
    );
  }

  static ColorScheme _neutralizeScheme(
    ColorScheme scheme,
    Brightness brightness,
  ) {
    final dark = brightness == Brightness.dark;
    final neutral = _NeutralPalette.forBrightness(brightness);

    return scheme.copyWith(
      brightness: brightness,
      surface: neutral.surface,
      onSurface: neutral.onSurface,
      surfaceDim: neutral.surfaceDim,
      surfaceBright: neutral.surfaceBright,
      surfaceContainerLowest: neutral.surfaceContainerLowest,
      surfaceContainerLow: neutral.surfaceContainerLow,
      surfaceContainer: neutral.surfaceContainer,
      surfaceContainerHigh: neutral.surfaceContainerHigh,
      surfaceContainerHighest: neutral.surfaceContainerHighest,
      onSurfaceVariant: neutral.onSurfaceVariant,
      outline: neutral.outline,
      outlineVariant: neutral.outlineVariant,
      inverseSurface: dark ? const Color(0xFFE8EAED) : const Color(0xFF202124),
      onInverseSurface: dark
          ? const Color(0xFF202124)
          : const Color(0xFFF8F9FA),
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
    );
  }

  static FleurSurfaceTheme _buildSurfaces(
    ColorScheme scheme,
    Brightness brightness,
  ) {
    final dark = brightness == Brightness.dark;

    return FleurSurfaceTheme(
      chrome: dark ? const Color(0xFF1F2023) : const Color(0xFFF1F3F4),
      nav: dark ? const Color(0xFF202124) : const Color(0xFFF8F9FA),
      sidebar: dark ? const Color(0xFF202124) : const Color(0xFFF8F9FA),
      list: dark ? const Color(0xFF17181B) : const Color(0xFFFFFFFF),
      reader: dark ? const Color(0xFF17181B) : const Color(0xFFFFFFFF),
      card: dark ? const Color(0xFF242529) : const Color(0xFFFFFFFF),
      cardSelected: Color.alphaBlend(
        scheme.primary.withAlpha(dark ? 54 : 28),
        dark ? const Color(0xFF242529) : const Color(0xFFFFFFFF),
      ),
      floating: dark ? const Color(0xFF2B2C31) : const Color(0xFFFFFFFF),
      subtleDivider: dark ? const Color(0xFF3C4043) : const Color(0xFFDADCE0),
    );
  }

  static FleurReaderColorTokens _buildReaderColors(
    ColorScheme scheme,
    FleurSurfaceTheme surfaces,
  ) {
    final dark = scheme.brightness == Brightness.dark;

    return FleurReaderColorTokens(
      summarySurface: dark ? const Color(0xFF242529) : const Color(0xFFF8F9FA),
      toolbarSurface: dark ? const Color(0xFF242529) : const Color(0xFFF8F9FA),
      searchBarSurface: surfaces.floating,
      bannerSurface: dark ? const Color(0xFF242529) : const Color(0xFFF1F3F4),
      blockquoteAccent: scheme.primary,
      codeBlockSurface: dark
          ? const Color(0xFF202124)
          : const Color(0xFFF1F3F4),
    );
  }
}

@immutable
class _NeutralPalette {
  const _NeutralPalette({
    required this.surface,
    required this.surfaceDim,
    required this.surfaceBright,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
  });

  final Color surface;
  final Color surfaceDim;
  final Color surfaceBright;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;

  static _NeutralPalette forBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _NeutralPalette(
        surface: Color(0xFF17181B),
        surfaceDim: Color(0xFF111214),
        surfaceBright: Color(0xFF2B2C31),
        surfaceContainerLowest: Color(0xFF111214),
        surfaceContainerLow: Color(0xFF202124),
        surfaceContainer: Color(0xFF242529),
        surfaceContainerHigh: Color(0xFF2B2C31),
        surfaceContainerHighest: Color(0xFF333438),
        onSurface: Color(0xFFE8EAED),
        onSurfaceVariant: Color(0xFFBDC1C6),
        outline: Color(0xFF5F6368),
        outlineVariant: Color(0xFF3C4043),
      );
    }

    return const _NeutralPalette(
      surface: Color(0xFFFFFFFF),
      surfaceDim: Color(0xFFEDEFF1),
      surfaceBright: Color(0xFFFFFFFF),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF8F9FA),
      surfaceContainer: Color(0xFFF1F3F4),
      surfaceContainerHigh: Color(0xFFEDEFF1),
      surfaceContainerHighest: Color(0xFFE8EAED),
      onSurface: Color(0xFF202124),
      onSurfaceVariant: Color(0xFF5F6368),
      outline: Color(0xFF9AA0A6),
      outlineVariant: Color(0xFFDADCE0),
    );
  }
}
