import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../ui/layout.dart';
import 'app_theme_profile.dart';
import 'app_typography.dart';

Color _blend(Color base, Color tint, int alpha) {
  return Color.alphaBlend(tint.withAlpha(alpha), base);
}

double _clampDouble(double value, double min, double max) {
  return value.clamp(min, max).toDouble();
}

@immutable
class FleurSurfaceTheme extends ThemeExtension<FleurSurfaceTheme> {
  const FleurSurfaceTheme({
    required this.chrome,
    required this.nav,
    required this.sidebar,
    required this.list,
    required this.reader,
    required this.card,
    required this.cardSelected,
    required this.floating,
    required this.subtleDivider,
  });

  final Color chrome;
  final Color nav;
  final Color sidebar;
  final Color list;
  final Color reader;
  final Color card;
  final Color cardSelected;
  final Color floating;
  final Color subtleDivider;

  factory FleurSurfaceTheme.fromScheme(
    ColorScheme scheme, {
    required Brightness brightness,
  }) {
    final dark = brightness == Brightness.dark;
    final baseSurface = scheme.surface;
    final chrome = _blend(baseSurface, scheme.primary, dark ? 16 : 6);
    final nav = _blend(
      scheme.surfaceContainerLow,
      scheme.primary,
      dark ? 18 : 8,
    );
    final sidebar = _blend(
      scheme.surfaceContainerLow,
      scheme.secondary,
      dark ? 18 : 8,
    );
    final list = dark ? scheme.surface : scheme.surfaceContainerLowest;
    final reader = _blend(baseSurface, scheme.secondary, dark ? 8 : 3);
    final card = dark
        ? scheme.surfaceContainerLow
        : scheme.surfaceContainerHigh;
    final cardSelected = _blend(
      card,
      scheme.secondaryContainer,
      dark ? 108 : 148,
    );
    final floating = dark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerHighest;

    return FleurSurfaceTheme(
      chrome: chrome,
      nav: nav,
      sidebar: sidebar,
      list: list,
      reader: reader,
      card: card,
      cardSelected: cardSelected,
      floating: floating,
      subtleDivider: scheme.outlineVariant.withAlpha(dark ? 112 : 132),
    );
  }

  @override
  FleurSurfaceTheme copyWith({
    Color? chrome,
    Color? nav,
    Color? sidebar,
    Color? list,
    Color? reader,
    Color? card,
    Color? cardSelected,
    Color? floating,
    Color? subtleDivider,
  }) {
    return FleurSurfaceTheme(
      chrome: chrome ?? this.chrome,
      nav: nav ?? this.nav,
      sidebar: sidebar ?? this.sidebar,
      list: list ?? this.list,
      reader: reader ?? this.reader,
      card: card ?? this.card,
      cardSelected: cardSelected ?? this.cardSelected,
      floating: floating ?? this.floating,
      subtleDivider: subtleDivider ?? this.subtleDivider,
    );
  }

  @override
  FleurSurfaceTheme lerp(
    covariant ThemeExtension<FleurSurfaceTheme>? other,
    double t,
  ) {
    if (other is! FleurSurfaceTheme) return this;
    return FleurSurfaceTheme(
      chrome: Color.lerp(chrome, other.chrome, t) ?? chrome,
      nav: Color.lerp(nav, other.nav, t) ?? nav,
      sidebar: Color.lerp(sidebar, other.sidebar, t) ?? sidebar,
      list: Color.lerp(list, other.list, t) ?? list,
      reader: Color.lerp(reader, other.reader, t) ?? reader,
      card: Color.lerp(card, other.card, t) ?? card,
      cardSelected:
          Color.lerp(cardSelected, other.cardSelected, t) ?? cardSelected,
      floating: Color.lerp(floating, other.floating, t) ?? floating,
      subtleDivider:
          Color.lerp(subtleDivider, other.subtleDivider, t) ?? subtleDivider,
    );
  }
}

@immutable
class FleurStateTheme extends ThemeExtension<FleurStateTheme> {
  const FleurStateTheme({
    required this.unreadAccent,
    required this.savedAccent,
    required this.syncAccent,
    required this.focusRing,
    required this.hoverTint,
    required this.pressedTint,
    required this.selectionTint,
    required this.errorAccent,
  });

  final Color unreadAccent;
  final Color savedAccent;
  final Color syncAccent;
  final Color focusRing;
  final Color hoverTint;
  final Color pressedTint;
  final Color selectionTint;
  final Color errorAccent;

  factory FleurStateTheme.fromScheme(
    ColorScheme scheme, {
    required Brightness brightness,
  }) {
    final dark = brightness == Brightness.dark;
    return FleurStateTheme(
      unreadAccent: scheme.primary,
      savedAccent: scheme.tertiary,
      syncAccent: scheme.primary,
      focusRing: scheme.primary,
      hoverTint: scheme.primary.withAlpha(dark ? 38 : 18),
      pressedTint: scheme.primary.withAlpha(dark ? 56 : 28),
      selectionTint: scheme.primary.withAlpha(dark ? 92 : 68),
      errorAccent: scheme.error,
    );
  }

  @override
  FleurStateTheme copyWith({
    Color? unreadAccent,
    Color? savedAccent,
    Color? syncAccent,
    Color? focusRing,
    Color? hoverTint,
    Color? pressedTint,
    Color? selectionTint,
    Color? errorAccent,
  }) {
    return FleurStateTheme(
      unreadAccent: unreadAccent ?? this.unreadAccent,
      savedAccent: savedAccent ?? this.savedAccent,
      syncAccent: syncAccent ?? this.syncAccent,
      focusRing: focusRing ?? this.focusRing,
      hoverTint: hoverTint ?? this.hoverTint,
      pressedTint: pressedTint ?? this.pressedTint,
      selectionTint: selectionTint ?? this.selectionTint,
      errorAccent: errorAccent ?? this.errorAccent,
    );
  }

  @override
  FleurStateTheme lerp(
    covariant ThemeExtension<FleurStateTheme>? other,
    double t,
  ) {
    if (other is! FleurStateTheme) return this;
    return FleurStateTheme(
      unreadAccent:
          Color.lerp(unreadAccent, other.unreadAccent, t) ?? unreadAccent,
      savedAccent: Color.lerp(savedAccent, other.savedAccent, t) ?? savedAccent,
      syncAccent: Color.lerp(syncAccent, other.syncAccent, t) ?? syncAccent,
      focusRing: Color.lerp(focusRing, other.focusRing, t) ?? focusRing,
      hoverTint: Color.lerp(hoverTint, other.hoverTint, t) ?? hoverTint,
      pressedTint: Color.lerp(pressedTint, other.pressedTint, t) ?? pressedTint,
      selectionTint:
          Color.lerp(selectionTint, other.selectionTint, t) ?? selectionTint,
      errorAccent: Color.lerp(errorAccent, other.errorAccent, t) ?? errorAccent,
    );
  }
}

@immutable
class FleurReaderTheme extends ThemeExtension<FleurReaderTheme> {
  const FleurReaderTheme({
    required this.maxWidth,
    required this.contentPaddingHorizontal,
    required this.contentPaddingTop,
    required this.contentPaddingBottom,
    required this.titleStyle,
    required this.metaStyle,
    required this.bodyStyle,
    required this.summaryStyle,
    required this.summarySurface,
    required this.toolbarSurface,
    required this.searchBarSurface,
    required this.bannerSurface,
    required this.blockquoteAccent,
    required this.codeBlockSurface,
  });

  final double maxWidth;
  final double contentPaddingHorizontal;
  final double contentPaddingTop;
  final double contentPaddingBottom;
  final TextStyle titleStyle;
  final TextStyle metaStyle;
  final TextStyle bodyStyle;
  final TextStyle summaryStyle;
  final Color summarySurface;
  final Color toolbarSurface;
  final Color searchBarSurface;
  final Color bannerSurface;
  final Color blockquoteAccent;
  final Color codeBlockSurface;

  TextStyle titleStyleForBodyFontSize(double bodyFontSize) {
    final baseFontSize = titleStyle.fontSize ?? 28;
    final effectiveTitleSize = _clampDouble(
      math.max(baseFontSize, bodyFontSize + 10),
      baseFontSize,
      40,
    );
    final height = lerpDouble(
      titleStyle.height ?? 1.12,
      1.16,
      ((effectiveTitleSize - baseFontSize) / 12).clamp(0.0, 1.0),
    );
    return titleStyle.copyWith(
      fontSize: effectiveTitleSize,
      height: height ?? titleStyle.height,
    );
  }

  factory FleurReaderTheme.fromTheme({
    required TextTheme textTheme,
    required ColorScheme scheme,
    required AppThemeProfile profile,
  }) {
    return FleurReaderTheme(
      maxWidth: kMaxReadingWidth,
      contentPaddingHorizontal: profile.readerHorizontalPadding,
      contentPaddingTop: profile.readerTopPadding,
      contentPaddingBottom: profile.readerBottomPadding,
      titleStyle: (textTheme.headlineMedium ?? const TextStyle()).copyWith(
        fontWeight: AppTypography.platformWeight(FontWeight.w700),
        letterSpacing: -0.7,
        height: 1.12,
        color: scheme.onSurface,
      ),
      metaStyle: (textTheme.labelLarge ?? const TextStyle()).copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: AppTypography.platformWeight(FontWeight.w600),
      ),
      bodyStyle: (textTheme.bodyLarge ?? const TextStyle()).copyWith(
        color: scheme.onSurface,
        height: 1.72,
        letterSpacing: 0.08,
      ),
      summaryStyle: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
        color: scheme.onSurface,
        height: 1.56,
      ),
      summarySurface: _blend(scheme.surfaceContainerLow, scheme.secondary, 18),
      toolbarSurface: _blend(scheme.surfaceContainerLow, scheme.primary, 10),
      searchBarSurface: _blend(scheme.surfaceContainerHigh, scheme.primary, 12),
      bannerSurface: _blend(scheme.surfaceContainerHigh, scheme.secondary, 14),
      blockquoteAccent: scheme.primary,
      codeBlockSurface: scheme.surfaceContainerHigh,
    );
  }

  @override
  FleurReaderTheme copyWith({
    double? maxWidth,
    double? contentPaddingHorizontal,
    double? contentPaddingTop,
    double? contentPaddingBottom,
    TextStyle? titleStyle,
    TextStyle? metaStyle,
    TextStyle? bodyStyle,
    TextStyle? summaryStyle,
    Color? summarySurface,
    Color? toolbarSurface,
    Color? searchBarSurface,
    Color? bannerSurface,
    Color? blockquoteAccent,
    Color? codeBlockSurface,
  }) {
    return FleurReaderTheme(
      maxWidth: maxWidth ?? this.maxWidth,
      contentPaddingHorizontal:
          contentPaddingHorizontal ?? this.contentPaddingHorizontal,
      contentPaddingTop: contentPaddingTop ?? this.contentPaddingTop,
      contentPaddingBottom: contentPaddingBottom ?? this.contentPaddingBottom,
      titleStyle: titleStyle ?? this.titleStyle,
      metaStyle: metaStyle ?? this.metaStyle,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      summaryStyle: summaryStyle ?? this.summaryStyle,
      summarySurface: summarySurface ?? this.summarySurface,
      toolbarSurface: toolbarSurface ?? this.toolbarSurface,
      searchBarSurface: searchBarSurface ?? this.searchBarSurface,
      bannerSurface: bannerSurface ?? this.bannerSurface,
      blockquoteAccent: blockquoteAccent ?? this.blockquoteAccent,
      codeBlockSurface: codeBlockSurface ?? this.codeBlockSurface,
    );
  }

  @override
  FleurReaderTheme lerp(
    covariant ThemeExtension<FleurReaderTheme>? other,
    double t,
  ) {
    if (other is! FleurReaderTheme) return this;
    return FleurReaderTheme(
      maxWidth: lerpDouble(maxWidth, other.maxWidth, t) ?? maxWidth,
      contentPaddingHorizontal:
          lerpDouble(
            contentPaddingHorizontal,
            other.contentPaddingHorizontal,
            t,
          ) ??
          contentPaddingHorizontal,
      contentPaddingTop:
          lerpDouble(contentPaddingTop, other.contentPaddingTop, t) ??
          contentPaddingTop,
      contentPaddingBottom:
          lerpDouble(contentPaddingBottom, other.contentPaddingBottom, t) ??
          contentPaddingBottom,
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t) ?? titleStyle,
      metaStyle: TextStyle.lerp(metaStyle, other.metaStyle, t) ?? metaStyle,
      bodyStyle: TextStyle.lerp(bodyStyle, other.bodyStyle, t) ?? bodyStyle,
      summaryStyle:
          TextStyle.lerp(summaryStyle, other.summaryStyle, t) ?? summaryStyle,
      summarySurface:
          Color.lerp(summarySurface, other.summarySurface, t) ?? summarySurface,
      toolbarSurface:
          Color.lerp(toolbarSurface, other.toolbarSurface, t) ?? toolbarSurface,
      searchBarSurface:
          Color.lerp(searchBarSurface, other.searchBarSurface, t) ??
          searchBarSurface,
      bannerSurface:
          Color.lerp(bannerSurface, other.bannerSurface, t) ?? bannerSurface,
      blockquoteAccent:
          Color.lerp(blockquoteAccent, other.blockquoteAccent, t) ??
          blockquoteAccent,
      codeBlockSurface:
          Color.lerp(codeBlockSurface, other.codeBlockSurface, t) ??
          codeBlockSurface,
    );
  }
}

extension FleurThemeDataX on ThemeData {
  FleurSurfaceTheme get fleurSurface =>
      extension<FleurSurfaceTheme>() ??
      FleurSurfaceTheme.fromScheme(colorScheme, brightness: brightness);

  FleurStateTheme get fleurState =>
      extension<FleurStateTheme>() ??
      FleurStateTheme.fromScheme(colorScheme, brightness: brightness);

  FleurReaderTheme get fleurReader =>
      extension<FleurReaderTheme>() ??
      FleurReaderTheme.fromTheme(
        textTheme: textTheme,
        scheme: colorScheme,
        profile: AppThemeProfile.resolve(),
      );
}
