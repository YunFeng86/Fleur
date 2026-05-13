import 'layout.dart';

// App-wide sidebar sizing/breakpoints.
//
// Expanded mode intentionally reuses the existing desktop sidebar width so the
// sidebar migration does not change the reading workspace's visual rhythm yet.
const double kSidebarExpandedWidth = kDesktopSidebarWidth;
const double kSidebarCollapsedWidth = 64;
const double kSidebarBreakpoint = 900;
const double kSidebarContentDividerWidth = 1;

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
