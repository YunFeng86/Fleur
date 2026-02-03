import 'package:flutter/widgets.dart';

import 'layout.dart';

// Global (leftmost) navigation rail sizing/breakpoints.
//
// NOTE: NavigationRail defaults to a 72px min width; keep this constant in sync
// with the rail widget so width-based layout decisions stay correct.
const double kGlobalNavRailWidth = 72;
const double kGlobalNavBreakpoint = 900;

enum GlobalNavMode { rail, bottom }

GlobalNavMode globalNavModeForWidth(double totalWidth) =>
    (totalWidth >= kGlobalNavBreakpoint)
    ? GlobalNavMode.rail
    : GlobalNavMode.bottom;

bool showGlobalNavRailForWidth(double totalWidth) =>
    globalNavModeForWidth(totalWidth) == GlobalNavMode.rail;

double effectiveContentWidth(double totalWidth) {
  // Only the rail consumes horizontal space.
  if (!showGlobalNavRailForWidth(totalWidth)) return totalWidth;
  return totalWidth - kGlobalNavRailWidth - kDividerWidth;
}

class GlobalNavScope extends InheritedWidget {
  const GlobalNavScope({
    super.key,
    required this.hasGlobalNav,
    required super.child,
  });

  final bool hasGlobalNav;

  static GlobalNavScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlobalNavScope>();
  }

  @override
  bool updateShouldNotify(GlobalNavScope oldWidget) =>
      oldWidget.hasGlobalNav != hasGlobalNav;
}
