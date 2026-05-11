import 'package:flutter/material.dart';

import '../utils/platform.dart' as platform;

enum AppThemePlatformClass { desktop, mobile }

@immutable
class AppThemeProfile {
  const AppThemeProfile({
    required this.platformClass,
    required this.visualDensity,
    required this.cardRadius,
    required this.fieldRadius,
    required this.persistentScrollbar,
    required this.centerCupertinoStyleTitles,
    required this.readerHorizontalPadding,
    required this.readerTopPadding,
    required this.readerBottomPadding,
  });

  final AppThemePlatformClass platformClass;
  final VisualDensity visualDensity;
  final double cardRadius;
  final double fieldRadius;
  final bool persistentScrollbar;
  final bool centerCupertinoStyleTitles;
  final double readerHorizontalPadding;
  final double readerTopPadding;
  final double readerBottomPadding;

  bool get isDesktop => platformClass == AppThemePlatformClass.desktop;

  static AppThemeProfile resolve() {
    if (platform.isDesktop) {
      return const AppThemeProfile(
        platformClass: AppThemePlatformClass.desktop,
        visualDensity: VisualDensity.compact,
        cardRadius: 8,
        fieldRadius: 10,
        persistentScrollbar: true,
        centerCupertinoStyleTitles: false,
        readerHorizontalPadding: 20,
        readerTopPadding: 28,
        readerBottomPadding: 116,
      );
    }

    return const AppThemeProfile(
      platformClass: AppThemePlatformClass.mobile,
      visualDensity: VisualDensity.standard,
      cardRadius: 8,
      fieldRadius: 10,
      persistentScrollbar: false,
      centerCupertinoStyleTitles: false,
      readerHorizontalPadding: 16,
      readerTopPadding: 24,
      readerBottomPadding: 108,
    );
  }
}
