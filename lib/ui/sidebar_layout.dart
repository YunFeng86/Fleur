import 'layout.dart';

// App-wide sidebar sizing/breakpoints.
//
// Expanded mode intentionally reuses the existing desktop sidebar width so the
// sidebar migration does not change the reading workspace's visual rhythm yet.
const double kDefaultWorkspaceSidebarWidth = kDesktopSidebarWidth;
const double kMinWorkspaceSidebarWidth = 220;
const double kMaxWorkspaceSidebarWidth = 360;
const double kDefaultWorkspaceListWidth = kDesktopListWidth;
const double kMinWorkspaceListWidth = 360;
const double kMaxWorkspaceListWidth = 560;
const double kSidebarExpandedWidth = kDefaultWorkspaceSidebarWidth;
const double kSidebarRailWidth = 64;
const double kSidebarCollapsedWidth = kSidebarRailWidth;
const double kSidebarBreakpoint = 900;
const double kSidebarContentDividerWidth = 1;
const double kWorkspaceSplitHandleHitWidth = 8;
const double kWorkspaceHeaderHeight = 48;
const double kShellControlSize = 32;
const double kShellControlIconSize = 16;
const double kShellControlCapsuleHeight = kShellControlSize;
const double kShellControlTopInset =
    (kWorkspaceHeaderHeight - kShellControlSize) / 2;
const double kMacOSTrafficLightTargetCenterY = kWorkspaceHeaderHeight / 2;
const double kMacOSShellControlTopInset =
    kMacOSTrafficLightTargetCenterY - (kShellControlSize / 2);
const double kMacOSTrafficLightSafeInset = 72;

class MacOSWindowChromeMetrics {
  const MacOSWindowChromeMetrics({
    required this.trafficLightsVisible,
    required this.centerY,
    required this.safeInset,
    required this.isFullScreen,
  });

  static const fallback = MacOSWindowChromeMetrics(
    trafficLightsVisible: true,
    centerY: kMacOSTrafficLightTargetCenterY,
    safeInset: kMacOSTrafficLightSafeInset,
    isFullScreen: false,
  );

  final bool trafficLightsVisible;
  final double centerY;
  final double safeInset;
  final bool isFullScreen;

  double get shellControlTopInset => centerY - (kShellControlSize / 2);

  factory MacOSWindowChromeMetrics.fromMap(Object? value) {
    if (value is! Map) return fallback;
    return MacOSWindowChromeMetrics(
      trafficLightsVisible: _boolValue(
        value['trafficLightsVisible'],
        fallback.trafficLightsVisible,
      ),
      centerY: _doubleValue(value['centerY'], fallback.centerY),
      safeInset: _doubleValue(value['safeInset'], fallback.safeInset),
      isFullScreen: _boolValue(value['isFullScreen'], fallback.isFullScreen),
    );
  }

  static bool _boolValue(Object? value, bool fallback) {
    if (value is bool) return value;
    return fallback;
  }

  static double _doubleValue(Object? value, double fallback) {
    if (value is num) {
      final doubleValue = value.toDouble();
      if (doubleValue.isFinite) return doubleValue;
    }
    return fallback;
  }
}

enum SidebarPresentationMode { expanded, collapsed }

enum SidebarLayoutMode { inline, drawer }

SidebarLayoutMode sidebarLayoutModeForWidth(double totalWidth) =>
    (totalWidth >= kSidebarBreakpoint)
    ? SidebarLayoutMode.inline
    : SidebarLayoutMode.drawer;

bool showInlineSidebarForWidth(double totalWidth) =>
    sidebarLayoutModeForWidth(totalWidth) == SidebarLayoutMode.inline;

double sidebarWidthForPresentationMode(SidebarPresentationMode mode) =>
    switch (mode) {
      SidebarPresentationMode.expanded => kSidebarExpandedWidth,
      SidebarPresentationMode.collapsed => kSidebarCollapsedWidth,
    };

double effectiveContentWidth(
  double totalWidth, {
  SidebarPresentationMode sidebarPresentationMode =
      SidebarPresentationMode.expanded,
  double sidebarWidth = kDefaultWorkspaceSidebarWidth,
}) {
  // Only an inline sidebar consumes horizontal space. Drawer mode overlays it.
  if (!showInlineSidebarForWidth(totalWidth)) return totalWidth;
  if (sidebarPresentationMode != SidebarPresentationMode.expanded) {
    return totalWidth;
  }
  return totalWidth - sidebarWidth - kSidebarContentDividerWidth;
}
