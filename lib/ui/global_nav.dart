import 'package:flutter/material.dart';

import 'layout.dart';

// App-wide sidebar sizing/breakpoints.
//
// Expanded mode intentionally reuses the existing desktop sidebar width so the
// second-round navigation rewrite does not change the reading workspace's
// visual rhythm yet.
const double kSidebarExpandedWidth = kDesktopSidebarWidth;
const double kSidebarCollapsedWidth = 64;
const double kSidebarBreakpoint = 900;

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
      kPaneGap;
}

class GlobalNavScope extends InheritedWidget {
  const GlobalNavScope({
    super.key,
    required this.hasGlobalNav,
    this.openDrawer,
    required super.child,
  });

  final bool hasGlobalNav;
  final VoidCallback? openDrawer;

  bool get canOpenDrawer => openDrawer != null;

  static GlobalNavScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlobalNavScope>();
  }

  static VoidCallback? drawerOpenerOf(BuildContext context) {
    return maybeOf(context)?.openDrawer;
  }

  static Widget? drawerLeading(BuildContext context) {
    final openDrawer = drawerOpenerOf(context);
    if (openDrawer == null) return null;
    return IconButton(
      tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      onPressed: openDrawer,
      icon: const Icon(Icons.menu),
    );
  }

  @override
  bool updateShouldNotify(GlobalNavScope oldWidget) =>
      oldWidget.hasGlobalNav != hasGlobalNav ||
      oldWidget.openDrawer != openDrawer;
}
