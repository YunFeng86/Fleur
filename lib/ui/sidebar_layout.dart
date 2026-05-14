import 'layout.dart';

// App-wide sidebar sizing/breakpoints.
//
// Expanded mode intentionally reuses the existing desktop sidebar width so the
// sidebar migration does not change the reading workspace's visual rhythm yet.
const double kSidebarExpandedWidth = kDesktopSidebarWidth;
const double kSidebarRailWidth = 64;
const double kSidebarCollapsedWidth = kSidebarRailWidth;
const double kSidebarBreakpoint = 900;
const double kSidebarContentDividerWidth = 1;
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
}) {
  // Only an inline sidebar consumes horizontal space. Drawer mode overlays it.
  if (!showInlineSidebarForWidth(totalWidth)) return totalWidth;
  return totalWidth -
      sidebarWidthForPresentationMode(sidebarPresentationMode) -
      kSidebarContentDividerWidth;
}
