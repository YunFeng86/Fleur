import 'package:flutter/foundation.dart';

import '../utils/platform.dart';
import 'adaptive_workspace_layout.dart';
import 'sidebar_layout.dart';

enum ShellChromeProfile { integratedCorner, titleBarExpected, contentOnly }

enum ShellControlsPlacement { floatingLeading, titleBarLeading, railLeading }

enum SidebarRailSurfaceStyle { capsule, plain }

enum ShellContentSurfaceStyle { floatingRounded, connectedSoft, plain }

const double kShellWindowCaptionButtonWidth = 46;
const double kShellWindowCaptionControlsWidth =
    kShellWindowCaptionButtonWidth * 3;
const double kTitleBarExpectedSidebarRailWidth = 56;

class ShellChromeLayout {
  const ShellChromeLayout({
    required this.profile,
    required this.controlsPlacement,
    required this.railSurfaceStyle,
    required this.contentSurfaceStyle,
  });

  final ShellChromeProfile profile;
  final ShellControlsPlacement controlsPlacement;
  final SidebarRailSurfaceStyle railSurfaceStyle;
  final ShellContentSurfaceStyle contentSurfaceStyle;

  static const integratedCorner = ShellChromeLayout(
    profile: ShellChromeProfile.integratedCorner,
    controlsPlacement: ShellControlsPlacement.floatingLeading,
    railSurfaceStyle: SidebarRailSurfaceStyle.capsule,
    contentSurfaceStyle: ShellContentSurfaceStyle.floatingRounded,
  );

  static const titleBarExpected = ShellChromeLayout(
    profile: ShellChromeProfile.titleBarExpected,
    controlsPlacement: ShellControlsPlacement.titleBarLeading,
    railSurfaceStyle: SidebarRailSurfaceStyle.plain,
    contentSurfaceStyle: ShellContentSurfaceStyle.connectedSoft,
  );

  static const contentOnly = ShellChromeLayout(
    profile: ShellChromeProfile.contentOnly,
    controlsPlacement: ShellControlsPlacement.railLeading,
    railSurfaceStyle: SidebarRailSurfaceStyle.plain,
    contentSurfaceStyle: ShellContentSurfaceStyle.plain,
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

  double get sidebarRailWidth => switch (profile) {
    ShellChromeProfile.titleBarExpected => kTitleBarExpectedSidebarRailWidth,
    ShellChromeProfile.integratedCorner ||
    ShellChromeProfile.contentOnly => kSidebarRailWidth,
  };

  double get titleBarHeight => switch (profile) {
    ShellChromeProfile.titleBarExpected => kWindowsTitleBarHeight,
    ShellChromeProfile.integratedCorner || ShellChromeProfile.contentOnly => 0,
  };

  double get contentBoundaryRadius => switch (profile) {
    ShellChromeProfile.titleBarExpected => 12,
    ShellChromeProfile.integratedCorner || ShellChromeProfile.contentOnly => 0,
  };

  bool get usesContinuousNavigationSurface =>
      profile == ShellChromeProfile.titleBarExpected;

  WorkspaceNavigationMetrics get workspaceNavigationMetrics {
    final railExtent = switch (profile) {
      ShellChromeProfile.integratedCorner =>
        sidebarRailWidth + kRailOverlayContentGap,
      ShellChromeProfile.titleBarExpected ||
      ShellChromeProfile.contentOnly => sidebarRailWidth,
    };
    return WorkspaceNavigationMetrics(
      expandedExtent:
          kDefaultWorkspaceSidebarWidth + kSidebarContentDividerWidth,
      railExtent: railExtent,
    );
  }
}
