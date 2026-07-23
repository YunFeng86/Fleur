import 'package:flutter/foundation.dart';

import 'adaptive_workspace_layout.dart';
import 'shell_chrome_layout.dart';

/// Describes whether the visible L1 shell material is one continuous surface
/// or is presented through separate fragments over the scene canvas.
enum ShellFrameSurfaceMode { continuous, fragmented }

/// Describes the L1 fragment that presents workspace navigation.
enum ShellNavigationSurface {
  inline,
  structuralRail,
  floatingIsland,
  temporaryOverlay,
  absent,
}

/// Describes the L1 fragment that presents shell-owned global tools.
enum ShellGlobalToolSurface { integrated, windowFrame, floatingIsland }

/// Resolves the semantic L1 topology for one shell layout pass.
///
/// This model deliberately describes only surface relationships. Geometry,
/// colors, radii, animation, and widget composition remain separate concerns.
@immutable
class ShellFrameTopology {
  const ShellFrameTopology({
    required this.surfaceMode,
    required this.navigationSurface,
    required this.globalToolSurface,
    required this.temporaryNavigationOpen,
    required this.shellCanvasPaintsFullViewport,
  });

  final ShellFrameSurfaceMode surfaceMode;
  final ShellNavigationSurface navigationSurface;
  final ShellGlobalToolSurface globalToolSurface;
  final bool temporaryNavigationOpen;
  final bool shellCanvasPaintsFullViewport;

  bool get hasPersistentNavigationSurface =>
      navigationSurface != ShellNavigationSurface.absent &&
      navigationSurface != ShellNavigationSurface.temporaryOverlay;

  bool get hasTemporaryNavigationOverlay =>
      navigationSurface == ShellNavigationSurface.temporaryOverlay;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ShellFrameTopology &&
            surfaceMode == other.surfaceMode &&
            navigationSurface == other.navigationSurface &&
            globalToolSurface == other.globalToolSurface &&
            temporaryNavigationOpen == other.temporaryNavigationOpen &&
            shellCanvasPaintsFullViewport ==
                other.shellCanvasPaintsFullViewport;
  }

  @override
  int get hashCode => Object.hash(
    surfaceMode,
    navigationSurface,
    globalToolSurface,
    temporaryNavigationOpen,
    shellCanvasPaintsFullViewport,
  );

  static ShellFrameTopology resolve({
    required ShellChromeLayout shellChromeLayout,
    required WorkspaceNavigationPresentation navigationPresentation,
    required bool temporaryNavigationOpen,
  }) {
    final navigationSurface = _resolveNavigationSurface(
      shellChromeLayout: shellChromeLayout,
      navigationPresentation: navigationPresentation,
      temporaryNavigationOpen: temporaryNavigationOpen,
    );
    return ShellFrameTopology(
      surfaceMode: _resolveSurfaceMode(
        shellChromeLayout: shellChromeLayout,
        navigationPresentation: navigationPresentation,
        temporaryNavigationOpen: temporaryNavigationOpen,
      ),
      navigationSurface: navigationSurface,
      globalToolSurface: _resolveGlobalToolSurface(
        shellChromeLayout: shellChromeLayout,
        navigationPresentation: navigationPresentation,
        temporaryNavigationOpen: temporaryNavigationOpen,
      ),
      temporaryNavigationOpen: temporaryNavigationOpen,
      shellCanvasPaintsFullViewport: true,
    );
  }

  static ShellFrameSurfaceMode _resolveSurfaceMode({
    required ShellChromeLayout shellChromeLayout,
    required WorkspaceNavigationPresentation navigationPresentation,
    required bool temporaryNavigationOpen,
  }) {
    if (temporaryNavigationOpen) return ShellFrameSurfaceMode.continuous;
    if (navigationPresentation == WorkspaceNavigationPresentation.expanded) {
      return ShellFrameSurfaceMode.continuous;
    }
    if (navigationPresentation == WorkspaceNavigationPresentation.rail) {
      return ShellFrameSurfaceMode.fragmented;
    }
    return shellChromeLayout.profile == ShellChromeProfile.integratedCorner
        ? ShellFrameSurfaceMode.fragmented
        : ShellFrameSurfaceMode.continuous;
  }

  static ShellNavigationSurface _resolveNavigationSurface({
    required ShellChromeLayout shellChromeLayout,
    required WorkspaceNavigationPresentation navigationPresentation,
    required bool temporaryNavigationOpen,
  }) {
    if (temporaryNavigationOpen) {
      return ShellNavigationSurface.temporaryOverlay;
    }

    return switch (navigationPresentation) {
      WorkspaceNavigationPresentation.expanded => ShellNavigationSurface.inline,
      WorkspaceNavigationPresentation.rail =>
        shellChromeLayout.profile == ShellChromeProfile.integratedCorner
            ? ShellNavigationSurface.floatingIsland
            : ShellNavigationSurface.structuralRail,
      WorkspaceNavigationPresentation.offCanvas =>
        ShellNavigationSurface.absent,
    };
  }

  static ShellGlobalToolSurface _resolveGlobalToolSurface({
    required ShellChromeLayout shellChromeLayout,
    required WorkspaceNavigationPresentation navigationPresentation,
    required bool temporaryNavigationOpen,
  }) {
    return switch (shellChromeLayout.profile) {
      ShellChromeProfile.integratedCorner =>
        temporaryNavigationOpen ||
                navigationPresentation ==
                    WorkspaceNavigationPresentation.expanded
            ? ShellGlobalToolSurface.integrated
            : ShellGlobalToolSurface.floatingIsland,
      ShellChromeProfile.titleBarExpected => ShellGlobalToolSurface.windowFrame,
      ShellChromeProfile.contentOnly => ShellGlobalToolSurface.integrated,
    };
  }
}
