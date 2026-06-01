import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/theme/fleur_color_engine.dart';
import 'package:fleur/theme/fleur_theme_extensions.dart';
import 'package:fleur/theme/seed_color_presets.dart';

double _contrastRatio(Color a, Color b) {
  final aLum = a.computeLuminance();
  final bLum = b.computeLuminance();
  final lighter = aLum > bLum ? aLum : bLum;
  final darker = aLum > bLum ? bLum : aLum;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('seed presets change accent while structural surfaces stay neutral', () {
    final blue = FleurColorEngine.resolve(
      brightness: Brightness.light,
      seedColorPreset: SeedColorPreset.blue,
    );
    final pink = FleurColorEngine.resolve(
      brightness: Brightness.light,
      seedColorPreset: SeedColorPreset.pink,
    );

    expect(blue.materialScheme.primary, isNot(pink.materialScheme.primary));
    expect(blue.states.focusRing, blue.materialScheme.primary);
    expect(pink.states.focusRing, pink.materialScheme.primary);
    expect(blue.surfaces.reader, pink.surfaces.reader);
    expect(blue.surfaces.list, pink.surfaces.list);
    expect(blue.surfaces.sidebar, pink.surfaces.sidebar);
    expect(
      blue.readerColors.codeBlockSurface,
      pink.readerColors.codeBlockSurface,
    );
  });

  test('dynamic scheme wins for accents without tinting large surfaces', () {
    final dynamicScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00BFA5),
      brightness: Brightness.light,
    );
    final resolved = FleurColorEngine.resolve(
      brightness: Brightness.light,
      dynamicScheme: dynamicScheme,
      seedColorPreset: SeedColorPreset.pink,
    );
    final seedOnly = FleurColorEngine.resolve(
      brightness: Brightness.light,
      seedColorPreset: SeedColorPreset.pink,
    );

    expect(resolved.materialScheme.primary, dynamicScheme.primary);
    expect(
      resolved.materialScheme.primary,
      isNot(seedOnly.materialScheme.primary),
    );
    expect(resolved.surfaces.reader, seedOnly.surfaces.reader);
    expect(resolved.surfaces.sidebar, seedOnly.surfaces.sidebar);
    expect(resolved.materialScheme.surface, const Color(0xFFFFFFFF));
  });

  test('light and dark themes keep readable neutral surfaces', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final scheme = theme.colorScheme;
      final surfaces = theme.fleurSurface;

      expect(
        _contrastRatio(scheme.onSurface, surfaces.reader),
        greaterThan(4.5),
      );
      expect(_contrastRatio(scheme.onSurface, surfaces.card), greaterThan(4.5));
      expect(
        _contrastRatio(scheme.onSurfaceVariant, surfaces.sidebar),
        greaterThan(4.5),
      );
    }
  });
}
