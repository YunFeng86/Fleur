import 'package:flutter/widgets.dart';

import 'adaptive_workspace_layout.dart';
import 'shell_chrome_layout.dart';
import 'shell_frame_topology.dart';
import 'sidebar_layout.dart';

@immutable
class ShellFrameGeometry {
  const ShellFrameGeometry({
    required this.topology,
    required this.titleBarHeight,
    required this.workspaceHeight,
    required this.leftChromeWidth,
    required this.contentLeft,
    required this.contentWidth,
    required this.contentLeadingInset,
    required this.contentTranslation,
    required this.dividerLeadingInset,
    required this.railOverlayVisible,
    required this.structuralRailVisible,
  });

  final ShellFrameTopology topology;
  final double titleBarHeight;
  final double workspaceHeight;
  final double leftChromeWidth;
  final double contentLeft;
  final double contentWidth;
  final double contentLeadingInset;
  final double contentTranslation;
  final double dividerLeadingInset;
  final bool railOverlayVisible;
  final bool structuralRailVisible;

  double get translatedContentLeft => contentLeft + contentTranslation;

  static ShellFrameGeometry resolve({
    required Size size,
    required ShellChromeLayout shellChromeLayout,
    required WorkspaceNavigationPresentation navigationPresentation,
    required bool temporaryNavigationOpen,
    required double expandedNavigationWidth,
    required double railWidth,
    required double temporaryNavigationWidth,
  }) {
    final topology = ShellFrameTopology.resolve(
      shellChromeLayout: shellChromeLayout,
      navigationPresentation: navigationPresentation,
      temporaryNavigationOpen: temporaryNavigationOpen,
    );
    final usesTitleBar = shellChromeLayout.placesControlsInTitleBar;
    final titleBarHeight = usesTitleBar ? kWorkspaceHeaderHeight : 0.0;
    final workspaceHeight = (size.height - titleBarHeight)
        .clamp(0.0, double.infinity)
        .toDouble();
    final expanded =
        navigationPresentation == WorkspaceNavigationPresentation.expanded;
    final rail = navigationPresentation == WorkspaceNavigationPresentation.rail;
    final structuralRail =
        rail &&
        shellChromeLayout.profile != ShellChromeProfile.integratedCorner;
    final railOverlay =
        rail &&
        shellChromeLayout.profile == ShellChromeProfile.integratedCorner;
    final leftChromeWidth = expanded
        ? expandedNavigationWidth + kSidebarContentDividerWidth
        : structuralRail
        ? railWidth
        : 0.0;
    final contentWidth = (size.width - leftChromeWidth)
        .clamp(0.0, double.infinity)
        .toDouble();
    final contentLeadingInset = railOverlay && !temporaryNavigationOpen
        ? railWidth + kRailOverlayContentGap
        : 0.0;
    final contentTranslation = temporaryNavigationOpen
        ? (temporaryNavigationWidth - leftChromeWidth)
              .clamp(0.0, double.infinity)
              .toDouble()
        : 0.0;
    final dividerLeadingInset = usesTitleBar
        ? temporaryNavigationOpen
              ? temporaryNavigationWidth
              : leftChromeWidth
        : 0.0;

    return ShellFrameGeometry(
      topology: topology,
      titleBarHeight: titleBarHeight,
      workspaceHeight: workspaceHeight,
      leftChromeWidth: leftChromeWidth,
      contentLeft: leftChromeWidth,
      contentWidth: contentWidth,
      contentLeadingInset: contentLeadingInset,
      contentTranslation: contentTranslation,
      dividerLeadingInset: dividerLeadingInset,
      railOverlayVisible: railOverlay && !temporaryNavigationOpen,
      structuralRailVisible: structuralRail && !temporaryNavigationOpen,
    );
  }
}
