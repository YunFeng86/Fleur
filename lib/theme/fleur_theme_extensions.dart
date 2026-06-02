import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../ui/layout.dart';
import '../services/settings/reader_settings.dart';
import 'app_theme_profile.dart';
import 'app_typography.dart';

Color _blend(Color base, Color tint, int alpha) {
  return Color.alphaBlend(tint.withAlpha(alpha), base);
}

double _clampDouble(double value, double min, double max) {
  return value.clamp(min, max).toDouble();
}

@immutable
class FleurDynamicColorTheme extends ThemeExtension<FleurDynamicColorTheme> {
  const FleurDynamicColorTheme({required this.available});

  final bool available;

  @override
  FleurDynamicColorTheme copyWith({bool? available}) {
    return FleurDynamicColorTheme(available: available ?? this.available);
  }

  @override
  FleurDynamicColorTheme lerp(
    covariant ThemeExtension<FleurDynamicColorTheme>? other,
    double t,
  ) {
    if (other is! FleurDynamicColorTheme) return this;
    return t < 0.5 ? this : other;
  }
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
    final chrome = _blend(baseSurface, scheme.primary, dark ? 10 : 3);
    final nav = _blend(
      scheme.surfaceContainerLow,
      scheme.primary,
      dark ? 10 : 4,
    );
    final sidebar = _blend(
      scheme.surfaceContainerLow,
      scheme.secondary,
      dark ? 10 : 4,
    );
    final list = dark ? scheme.surface : scheme.surfaceContainerLowest;
    final reader = _blend(baseSurface, scheme.secondary, dark ? 5 : 2);
    final card = scheme.surfaceContainerLow;
    final cardSelected = _blend(card, scheme.primaryContainer, dark ? 60 : 52);
    final floating = dark ? scheme.surfaceContainerHigh : scheme.surface;

    return FleurSurfaceTheme(
      chrome: chrome,
      nav: nav,
      sidebar: sidebar,
      list: list,
      reader: reader,
      card: card,
      cardSelected: cardSelected,
      floating: floating,
      subtleDivider: scheme.outlineVariant.withAlpha(dark ? 80 : 92),
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
    required this.scrollbarIdle,
    required this.scrollbarRegionHover,
    required this.scrollbarHover,
    required this.scrollbarDrag,
  });

  final Color unreadAccent;
  final Color savedAccent;
  final Color syncAccent;
  final Color focusRing;
  final Color hoverTint;
  final Color pressedTint;
  final Color selectionTint;
  final Color errorAccent;
  final Color scrollbarIdle;
  final Color scrollbarRegionHover;
  final Color scrollbarHover;
  final Color scrollbarDrag;

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
      hoverTint: scheme.primary.withAlpha(dark ? 30 : 14),
      pressedTint: scheme.primary.withAlpha(dark ? 44 : 22),
      selectionTint: scheme.primary.withAlpha(dark ? 62 : 40),
      errorAccent: scheme.error,
      scrollbarIdle: scheme.outlineVariant.withAlpha(dark ? 84 : 72),
      scrollbarRegionHover: scheme.onSurfaceVariant.withAlpha(dark ? 120 : 88),
      scrollbarHover: scheme.onSurfaceVariant.withAlpha(dark ? 144 : 112),
      scrollbarDrag: scheme.primary.withAlpha(dark ? 176 : 148),
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
    Color? scrollbarIdle,
    Color? scrollbarRegionHover,
    Color? scrollbarHover,
    Color? scrollbarDrag,
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
      scrollbarIdle: scrollbarIdle ?? this.scrollbarIdle,
      scrollbarRegionHover: scrollbarRegionHover ?? this.scrollbarRegionHover,
      scrollbarHover: scrollbarHover ?? this.scrollbarHover,
      scrollbarDrag: scrollbarDrag ?? this.scrollbarDrag,
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
      scrollbarIdle:
          Color.lerp(scrollbarIdle, other.scrollbarIdle, t) ?? scrollbarIdle,
      scrollbarRegionHover:
          Color.lerp(scrollbarRegionHover, other.scrollbarRegionHover, t) ??
          scrollbarRegionHover,
      scrollbarHover:
          Color.lerp(scrollbarHover, other.scrollbarHover, t) ?? scrollbarHover,
      scrollbarDrag:
          Color.lerp(scrollbarDrag, other.scrollbarDrag, t) ?? scrollbarDrag,
    );
  }
}

@immutable
class FleurReaderColorTokens {
  const FleurReaderColorTokens({
    required this.summarySurface,
    required this.toolbarSurface,
    required this.searchBarSurface,
    required this.bannerSurface,
    required this.blockquoteAccent,
    required this.codeBlockSurface,
  });

  final Color summarySurface;
  final Color toolbarSurface;
  final Color searchBarSurface;
  final Color bannerSurface;
  final Color blockquoteAccent;
  final Color codeBlockSurface;
}

@immutable
class FleurFontStack {
  const FleurFontStack({this.fontFamily, this.fontFamilyFallback});

  final String? fontFamily;
  final List<String>? fontFamilyFallback;

  TextStyle applyTo(TextStyle style) {
    return style.copyWith(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
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
    required this.codeStyle,
    required this.codeSoftWrap,
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
  final TextStyle codeStyle;
  final bool codeSoftWrap;
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
    FleurReaderColorTokens? colors,
    ReaderSettings settings = const ReaderSettings(),
  }) {
    final bodyColor = scheme.onSurface.withValues(
      alpha: scheme.brightness == Brightness.dark ? 0.92 : 0.88,
    );
    final readerColors =
        colors ??
        FleurReaderColorTokens(
          summarySurface: _blend(
            scheme.surfaceContainerLow,
            scheme.secondary,
            8,
          ),
          toolbarSurface: _blend(scheme.surfaceContainerLow, scheme.primary, 4),
          searchBarSurface: _blend(
            scheme.surfaceContainerHigh,
            scheme.primary,
            6,
          ),
          bannerSurface: _blend(
            scheme.surfaceContainerHigh,
            scheme.secondary,
            6,
          ),
          blockquoteAccent: scheme.primary,
          codeBlockSurface: scheme.surfaceContainerHigh,
        );

    final readerFontStack = readerFontStackFor(settings);
    TextStyle applyReaderFont(TextStyle style) {
      return readerFontStack.applyTo(style);
    }

    final codeFontStack = codeFontStackFor(settings);
    final codeFontSize = codeFontSizeFor(settings);

    return FleurReaderTheme(
      maxWidth: _readerMaxWidth(settings.contentWidthPreset),
      contentPaddingHorizontal: profile.readerHorizontalPadding,
      contentPaddingTop: profile.readerTopPadding,
      contentPaddingBottom: profile.readerBottomPadding,
      titleStyle: applyReaderFont(
        (textTheme.headlineMedium ?? const TextStyle()).copyWith(
          fontWeight: AppTypography.platformWeight(FontWeight.w700),
          letterSpacing: 0,
          height: 1.12,
          color: scheme.onSurface,
        ),
      ),
      metaStyle: (textTheme.labelLarge ?? const TextStyle()).copyWith(
        color: scheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: AppTypography.platformWeight(FontWeight.w500),
        letterSpacing: 0,
        height: 1.2,
      ),
      bodyStyle: applyReaderFont(
        (textTheme.bodyMedium ?? const TextStyle()).copyWith(
          color: bodyColor,
          fontWeight: FontWeight.w400,
          height: ReaderSettings.defaultLineHeight,
          letterSpacing: 0,
        ),
      ),
      summaryStyle: applyReaderFont(
        (textTheme.bodyMedium ?? const TextStyle()).copyWith(
          color: scheme.onSurface,
          height: 1.56,
        ),
      ),
      codeStyle: codeFontStack.applyTo(
        const TextStyle().copyWith(
          color: scheme.onSurface,
          decoration: TextDecoration.none,
          fontSize: codeFontSize,
          fontStyle: FontStyle.normal,
          fontWeight: FontWeight.w400,
          height: _clampDouble(settings.codeLineHeight, 1.1, 2.0),
        ),
      ),
      codeSoftWrap: settings.codeSoftWrap,
      summarySurface: readerColors.summarySurface,
      toolbarSurface: readerColors.toolbarSurface,
      searchBarSurface: readerColors.searchBarSurface,
      bannerSurface: readerColors.bannerSurface,
      blockquoteAccent: readerColors.blockquoteAccent,
      codeBlockSurface: readerColors.codeBlockSurface,
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
    TextStyle? codeStyle,
    bool? codeSoftWrap,
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
      codeStyle: codeStyle ?? this.codeStyle,
      codeSoftWrap: codeSoftWrap ?? this.codeSoftWrap,
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
      codeStyle: TextStyle.lerp(codeStyle, other.codeStyle, t) ?? codeStyle,
      codeSoftWrap: t < 0.5 ? codeSoftWrap : other.codeSoftWrap,
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

double _readerMaxWidth(ReaderContentWidthPreset preset) {
  return switch (preset) {
    ReaderContentWidthPreset.narrow => 620,
    ReaderContentWidthPreset.standard => kMaxReadingWidth,
    ReaderContentWidthPreset.wide => 860,
  };
}

FleurFontStack readerFontStackFor(ReaderSettings settings) {
  if (settings.fontFamily == ReaderFontFamily.custom) {
    final custom = parseFontStack(settings.readerFontStack);
    if (custom.fontFamily != null) return custom;
  }
  return FleurFontStack(
    fontFamily: _readerFontFamily(settings.fontFamily),
    fontFamilyFallback: _readerFontFallback(settings.fontFamily),
  );
}

FleurFontStack codeFontStackFor(ReaderSettings settings) {
  if (settings.codeFontFamily == CodeFontFamilyPreset.custom) {
    final custom = parseFontStack(settings.codeFontStack);
    if (custom.fontFamily != null) return custom;
  }
  return const FleurFontStack(
    fontFamily: 'SF Mono',
    fontFamilyFallback: [
      'Menlo',
      'Consolas',
      'Cascadia Mono',
      'Noto Sans Mono CJK SC',
      'Noto Sans Mono',
      'monospace',
    ],
  );
}

double codeFontSizeFor(ReaderSettings settings) {
  return switch (settings.codeFontSizeMode) {
    CodeFontSizeMode.followReader => settings.fontSize,
    CodeFontSizeMode.oneStepDown => math.max(12, settings.fontSize - 1),
    CodeFontSizeMode.custom => _clampDouble(settings.codeFontSize, 11, 24),
  };
}

FleurFontStack parseFontStack(String value) {
  final rawItems = value.split(',');
  final fonts = <String>[];
  for (final raw in rawItems) {
    var item = raw.trim();
    if (item.length >= 2) {
      final quote = item[0];
      final endQuote = item[item.length - 1];
      if ((quote == '"' && endQuote == '"') ||
          (quote == '\'' && endQuote == '\'')) {
        item = item.substring(1, item.length - 1).trim();
      }
    }
    if (item.isEmpty) continue;
    if (item == 'system-ui') {
      final systemFamily = AppTypography.fontFamily();
      if (systemFamily != null && systemFamily.isNotEmpty) {
        fonts.add(systemFamily);
      }
      fonts.addAll(AppTypography.fontFallback());
      continue;
    }
    fonts.add(item);
  }

  final deduped = <String>[];
  for (final font in fonts) {
    if (!deduped.contains(font)) deduped.add(font);
  }
  if (deduped.isEmpty) return const FleurFontStack();
  return FleurFontStack(
    fontFamily: deduped.first,
    fontFamilyFallback: deduped.length > 1 ? deduped.sublist(1) : null,
  );
}

String? _readerFontFamily(ReaderFontFamily family) {
  return switch (family) {
    ReaderFontFamily.system => AppTypography.fontFamily(),
    ReaderFontFamily.serif => 'Georgia',
    ReaderFontFamily.sans => AppTypography.fontFamily(),
    ReaderFontFamily.mono => 'SF Mono',
    ReaderFontFamily.custom => AppTypography.fontFamily(),
  };
}

List<String>? _readerFontFallback(ReaderFontFamily family) {
  return switch (family) {
    ReaderFontFamily.system => AppTypography.fontFallback(),
    ReaderFontFamily.serif => const [
      'Songti SC',
      'Songti TC',
      'SimSun',
      'Noto Serif CJK SC',
      'Noto Serif SC',
      'Noto Serif',
      'Times New Roman',
      'serif',
    ],
    ReaderFontFamily.sans => AppTypography.fontFallback(),
    ReaderFontFamily.mono => const [
      'SF Mono',
      'Menlo',
      'Consolas',
      'Cascadia Mono',
      'Noto Sans Mono CJK SC',
      'Noto Sans Mono',
      'monospace',
    ],
    ReaderFontFamily.custom => AppTypography.fontFallback(),
  };
}

extension FleurThemeDataX on ThemeData {
  FleurDynamicColorTheme get fleurDynamicColor =>
      extension<FleurDynamicColorTheme>() ??
      const FleurDynamicColorTheme(available: false);

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
