import 'package:flutter/material.dart';

import '../services/update/app_update_manifest.dart';
import '../theme/fleur_theme_extensions.dart';
import 'shell_chrome_layout.dart';
import 'shell_frame_geometry.dart';
import 'shell_title_bar.dart';
import 'sidebar_layout.dart';

/// Composes native window chrome around one active product scene.
///
/// Product panes remain owned by the scene. This frame owns only the fixed
/// title bar, the workspace viewport below it, and window-level floating
/// controls used by integrated-corner hosts.
class ShellWindowFrame extends StatelessWidget {
  const ShellWindowFrame({
    super.key,
    required this.geometry,
    required this.shellChromeLayout,
    required this.macOSWindowChromeMetrics,
    required this.titleBarCommands,
    required this.controlsPresentationMode,
    required this.searchSelected,
    required this.updateManifest,
    required this.controlsLeading,
    required this.navigationToggleFocusNode,
    required this.floatingLeadingControls,
    required this.child,
  });

  final ShellFrameGeometry geometry;
  final ShellChromeLayout shellChromeLayout;
  final MacOSWindowChromeMetrics macOSWindowChromeMetrics;
  final ShellWindowTitleBarCommands titleBarCommands;
  final SidebarPresentationMode controlsPresentationMode;
  final bool searchSelected;
  final AppUpdateManifest? updateManifest;
  final double controlsLeading;
  final FocusNode navigationToggleFocusNode;
  final Widget? floatingLeadingControls;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).fleurSurface;
    return DecoratedBox(
      decoration: BoxDecoration(color: surfaces.chrome),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          if (shellChromeLayout.placesControlsInTitleBar)
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: geometry.titleBarHeight,
              child: ShellWindowTitleBar(
                commands: titleBarCommands,
                presentationMode: controlsPresentationMode,
                searchSelected: searchSelected,
                updateManifest: updateManifest,
                leadingLeft: controlsLeading,
                dividerLeadingInset: geometry.dividerLeadingInset,
                navigationToggleFocusNode: navigationToggleFocusNode,
              ),
            ),
          Positioned(
            left: 0,
            top: geometry.titleBarHeight,
            right: 0,
            bottom: 0,
            child: child,
          ),
          if (floatingLeadingControls != null)
            Positioned(
              left: controlsLeading,
              top: _floatingControlsTop,
              child: floatingLeadingControls!,
            ),
        ],
      ),
    );
  }

  double get _floatingControlsTop {
    if (shellChromeLayout.profile != ShellChromeProfile.integratedCorner) {
      return kShellControlTopInset;
    }
    return macOSWindowChromeMetrics.shellControlTopInset;
  }
}
