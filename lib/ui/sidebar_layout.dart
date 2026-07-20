import 'package:flutter/widgets.dart';

import 'layout.dart';

// App-wide sidebar sizing/breakpoints.
//
// Expanded mode intentionally reuses the existing desktop sidebar width so the
// sidebar migration does not change the reading workspace's visual rhythm yet.
const double kDefaultWorkspaceSidebarWidth = kDesktopSidebarWidth;
const double kMinWorkspaceSidebarWidth = 256;
const double kMaxWorkspaceSidebarWidth = 360;
const double kTemporaryWorkspaceSidebarWidth = kDefaultWorkspaceSidebarWidth;
const double kDefaultWorkspaceListWidth = kDesktopListWidth;
const double kMinWorkspaceListWidth = 360;
const double kMinWorkspaceContentWidth = kMinWorkspaceListWidth;
const double kSidebarExpandedWidth = kDefaultWorkspaceSidebarWidth;
const double kSidebarRailWidth = 64;
const double kSidebarCollapsedWidth = kSidebarRailWidth;
const double kRailOverlayContentGap = 8;
const double kSidebarBreakpoint = 900;
const double kSidebarContentDividerWidth = 1;
const double kWorkspaceSplitHandleHitWidth = 12;
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
const double kMacOSFullscreenClickSafeTopInset = 8;

class SidebarRailLayoutScope extends InheritedWidget {
  const SidebarRailLayoutScope({
    super.key,
    required this.railWidth,
    required super.child,
  });

  final double railWidth;

  static double widthOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<SidebarRailLayoutScope>()
            ?.railWidth ??
        kSidebarRailWidth;
  }

  @override
  bool updateShouldNotify(SidebarRailLayoutScope oldWidget) =>
      oldWidget.railWidth != railWidth;
}

class MacOSWindowChromeMetrics {
  const MacOSWindowChromeMetrics({
    required this.trafficLightsVisible,
    required this.centerY,
    required this.safeInset,
    required this.isFullScreen,
    this.clickSafeTopInset = 0,
    this.titlebarDragHeight = kWorkspaceHeaderHeight,
    this.contentLayoutTopInset = 0,
  });

  static const fallback = MacOSWindowChromeMetrics(
    trafficLightsVisible: true,
    centerY: kMacOSTrafficLightTargetCenterY,
    safeInset: kMacOSTrafficLightSafeInset,
    isFullScreen: false,
    clickSafeTopInset: 0,
    titlebarDragHeight: kWorkspaceHeaderHeight,
    contentLayoutTopInset: 0,
  );

  final bool trafficLightsVisible;
  final double centerY;
  final double safeInset;
  final bool isFullScreen;
  final double clickSafeTopInset;
  final double titlebarDragHeight;
  final double contentLayoutTopInset;

  double get shellControlTopInset => (centerY - (kShellControlSize / 2))
      .clamp(clickSafeTopInset, double.infinity)
      .toDouble();

  factory MacOSWindowChromeMetrics.fromMap(Object? value) {
    if (value is! Map) return fallback;
    final isFullScreen = _boolValue(
      value['isFullScreen'],
      fallback.isFullScreen,
    );
    return MacOSWindowChromeMetrics(
      trafficLightsVisible: _boolValue(
        value['trafficLightsVisible'],
        fallback.trafficLightsVisible,
      ),
      centerY: _doubleValue(value['centerY'], fallback.centerY),
      safeInset: _doubleValue(value['safeInset'], fallback.safeInset),
      isFullScreen: isFullScreen,
      clickSafeTopInset: _doubleValue(
        value['clickSafeTopInset'],
        isFullScreen ? kMacOSFullscreenClickSafeTopInset : 0,
      ),
      titlebarDragHeight: _doubleValue(
        value['titlebarDragHeight'],
        fallback.titlebarDragHeight,
      ),
      contentLayoutTopInset: _doubleValue(
        value['contentLayoutTopInset'],
        fallback.contentLayoutTopInset,
      ),
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

double maxWorkspaceSidebarWidthForWindow(double totalWidth) {
  final maxWidth =
      totalWidth - kMinWorkspaceContentWidth - kSidebarContentDividerWidth;
  if (maxWidth < kMinWorkspaceSidebarWidth) {
    return kMinWorkspaceSidebarWidth;
  }
  return maxWidth > kMaxWorkspaceSidebarWidth
      ? kMaxWorkspaceSidebarWidth
      : maxWidth;
}

double clampWorkspaceSidebarWidth(double width, double totalWidth) {
  return width
      .clamp(
        kMinWorkspaceSidebarWidth,
        maxWorkspaceSidebarWidthForWindow(totalWidth),
      )
      .toDouble();
}

double maxWorkspaceListWidthForContent(double contentWidth) {
  final maxWidth =
      contentWidth - kWorkspaceSplitHandleHitWidth - kMinReadingWidth;
  return maxWidth < kMinWorkspaceListWidth ? kMinWorkspaceListWidth : maxWidth;
}

double clampWorkspaceListWidth(double width, double contentWidth) {
  return width
      .clamp(
        kMinWorkspaceListWidth,
        maxWorkspaceListWidthForContent(contentWidth),
      )
      .toDouble();
}

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
