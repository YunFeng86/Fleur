import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/theme/app_typography.dart';
import 'package:fleur/theme/fleur_icons.dart';
import 'package:fleur/theme/fleur_theme_extensions.dart';
import 'package:fleur/utils/platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('App theme exposes Fleur semantic tokens for desktop and mobile', () {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final desktopTheme = AppTheme.light();
    expect(desktopTheme.fleurSurface.nav, isNotNull);
    expect(desktopTheme.fleurState.selectionTint, isNotNull);
    expect(desktopTheme.fleurReader.maxWidth, greaterThan(0));
    expect(
      desktopTheme.scrollbarTheme.thumbVisibility?.resolve(<WidgetState>{}),
      isTrue,
    );
    expect(desktopTheme.scrollbarTheme.thickness?.resolve(<WidgetState>{}), 6);
    expect(
      desktopTheme.scrollbarTheme.thickness?.resolve(<WidgetState>{
        WidgetState.hovered,
      }),
      6,
    );
    expect(
      desktopTheme.scrollbarTheme.thickness?.resolve(<WidgetState>{
        WidgetState.dragged,
      }),
      6,
    );
    expect(
      desktopTheme.iconButtonTheme.style?.shape?.resolve(<WidgetState>{}),
      isNull,
    );
    expect(
      desktopTheme.scrollbarTheme.thumbColor?.resolve(<WidgetState>{}),
      desktopTheme.fleurState.scrollbarIdle,
    );
    expect(
      desktopTheme.scrollbarTheme.thumbColor?.resolve(<WidgetState>{
        WidgetState.hovered,
      }),
      desktopTheme.fleurState.scrollbarHover,
    );
    expect(
      desktopTheme.scrollbarTheme.thumbColor?.resolve(<WidgetState>{
        WidgetState.dragged,
      }),
      desktopTheme.fleurState.scrollbarDrag,
    );

    debugFleurTargetPlatformOverride = TargetPlatform.android;
    final mobileTheme = AppTheme.light();
    expect(
      mobileTheme.scrollbarTheme.thumbVisibility?.resolve(<WidgetState>{}),
      isFalse,
    );
    expect(mobileTheme.scrollbarTheme.thickness?.resolve(<WidgetState>{}), 8);
    expect(desktopTheme.navigationRailTheme.labelType, isNull);
    expect(desktopTheme.navigationBarTheme.height, isNull);
    expect(mobileTheme.navigationBarTheme.height, isNull);
  });

  test('Windows typography uses the shared weight scale', () {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final windowsTheme = AppTheme.light();
    expect(AppTypography.fontFamily(), 'Segoe UI');
    expect(
      AppTypography.fontFallback().first,
      AppTypography.bundledCjkSansFamily,
    );
    expect(AppTypography.fontFallback()[1], 'Microsoft YaHei UI');
    expect(AppTypography.fontFallback()[2], 'Microsoft YaHei');
    expect(AppTypography.fontFallback(), isNot(contains('DengXian Light')));
    expect(windowsTheme.textTheme.titleLarge?.fontWeight, FontWeight.w700);
    expect(windowsTheme.textTheme.titleMedium?.fontWeight, FontWeight.w600);
    expect(windowsTheme.fleurReader.titleStyle.fontWeight, FontWeight.w700);
    expect(windowsTheme.fleurReader.metaStyle.fontWeight, FontWeight.w500);

    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    final macTheme = AppTheme.light();
    expect(AppTypography.fontFamily(), isNull);
    expect(macTheme.textTheme.titleLarge?.fontWeight, FontWeight.w700);
    expect(macTheme.textTheme.titleMedium?.fontWeight, FontWeight.w600);
    expect(macTheme.fleurReader.titleStyle.fontWeight, FontWeight.w700);
    expect(macTheme.fleurReader.metaStyle.fontWeight, FontWeight.w500);
    expect(macTheme.fleurReader.metaStyle.fontSize, 12);
  });

  test('Fleur iconography keeps a restrained optical hierarchy', () {
    expect(FleurIconMetrics.small, 16);
    expect(FleurIconMetrics.compact, 18);
    expect(FleurIconMetrics.standard, 20);
    expect(FleurIcons.search.fontFamily, 'Lucide');
    expect(FleurIcons.searchSelected.fontFamily, 'Lucide500');
    expect(FleurIcons.back.fontFamily, 'Lucide');
  });

  test('bundled CJK sans font exposes explicit static weight faces', () async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    final family = manifest.cast<Map<String, dynamic>>().singleWhere(
      (entry) => entry['family'] == AppTypography.bundledCjkSansFamily,
    );
    final fonts = (family['fonts'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    expect(fonts.map((font) => font['weight']), [400, 500, 600, 700]);
    expect(
      fonts.map((font) => font['asset']),
      everyElement(isNot(contains('VariableFont'))),
    );
  });

  test('Reader title scale stays above body text and caps growth', () {
    final theme = AppTheme.light();
    final defaultTitle = theme.fleurReader.titleStyleForBodyFontSize(16);
    final largeTitle = theme.fleurReader.titleStyleForBodyFontSize(28);

    expect(defaultTitle.fontSize, greaterThan(16));
    expect(largeTitle.fontSize, greaterThan(28));
    expect(largeTitle.fontSize, lessThanOrEqualTo(40));
    expect(largeTitle.height, greaterThanOrEqualTo(defaultTitle.height ?? 0));
  });
}
