import 'package:flutter/foundation.dart';

import '../utils/platform.dart';

enum ShellChromeProfile { integratedCorner, titleBarExpected, contentOnly }

enum ShellControlsPlacement { floatingLeading, titleBarLeading, railLeading }

enum SidebarRailSurfaceStyle { capsule, plain }

const double kShellWindowCaptionButtonWidth = 46;
const double kShellWindowCaptionControlsWidth =
    kShellWindowCaptionButtonWidth * 3;

class ShellChromeLayout {
  const ShellChromeLayout({
    required this.profile,
    required this.controlsPlacement,
    required this.railSurfaceStyle,
  });

  final ShellChromeProfile profile;
  final ShellControlsPlacement controlsPlacement;
  final SidebarRailSurfaceStyle railSurfaceStyle;

  static const integratedCorner = ShellChromeLayout(
    profile: ShellChromeProfile.integratedCorner,
    controlsPlacement: ShellControlsPlacement.floatingLeading,
    railSurfaceStyle: SidebarRailSurfaceStyle.capsule,
  );

  static const titleBarExpected = ShellChromeLayout(
    profile: ShellChromeProfile.titleBarExpected,
    controlsPlacement: ShellControlsPlacement.titleBarLeading,
    railSurfaceStyle: SidebarRailSurfaceStyle.plain,
  );

  static const contentOnly = ShellChromeLayout(
    profile: ShellChromeProfile.contentOnly,
    controlsPlacement: ShellControlsPlacement.railLeading,
    railSurfaceStyle: SidebarRailSurfaceStyle.plain,
  );

  static ShellChromeLayout resolve({TargetPlatform? platform}) {
    final targetPlatform = platform ?? effectiveTargetPlatform;
    if (kIsWeb) return contentOnly;
    return switch (targetPlatform) {
      TargetPlatform.macOS => integratedCorner,
      TargetPlatform.windows || TargetPlatform.linux => titleBarExpected,
      _ => contentOnly,
    };
  }

  bool get placesControlsInTitleBar =>
      controlsPlacement == ShellControlsPlacement.titleBarLeading;

  bool get usesFloatingLeadingControls =>
      controlsPlacement == ShellControlsPlacement.floatingLeading;
}
