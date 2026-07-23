import 'package:flutter/material.dart';

import '../services/update/app_update_manifest.dart';
import 'design_system/controls/fleur_shell_icon_button.dart';
import 'shell_control_strip.dart';
import 'shell_frame_topology.dart';
import 'sidebar_layout.dart';

/// Owns the stable global command and focus surface for the application shell.
///
/// Its visual treatment is inherited from the active L1 fragment. It does not
/// introduce another material layer.
class ShellGlobalToolArea extends StatelessWidget {
  const ShellGlobalToolArea({
    super.key,
    required this.commands,
    required this.presentationMode,
    required this.surface,
    this.searchSelected = false,
    this.showSearch = true,
    this.updateManifest,
    this.updateBeforeSearch = false,
    this.navigationToggleFocusNode,
    this.availableWidth,
    this.adaptiveTapTargets = false,
    this.interactionMode,
  });

  final ShellWindowTitleBarCommands commands;
  final SidebarPresentationMode presentationMode;
  final ShellGlobalToolSurface surface;
  final bool searchSelected;
  final bool showSearch;
  final AppUpdateManifest? updateManifest;
  final bool updateBeforeSearch;
  final FocusNode? navigationToggleFocusNode;
  final double? availableWidth;
  final bool adaptiveTapTargets;
  final FocusHighlightMode? interactionMode;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      key: const Key('shell_global_tool_area'),
      child: ShellControlStrip(
        commands: commands,
        presentationMode: presentationMode,
        surface: surface == ShellGlobalToolSurface.floatingIsland
            ? ShellControlStripSurface.capsule
            : ShellControlStripSurface.flat,
        buttonShape: surface == ShellGlobalToolSurface.windowFrame
            ? FleurShellIconButtonShape.roundedSquare
            : FleurShellIconButtonShape.circular,
        searchSelected: searchSelected,
        showSearch: showSearch,
        updateManifest: updateManifest,
        updateBeforeSearch: updateBeforeSearch,
        navigationToggleFocusNode: navigationToggleFocusNode,
        availableWidth: availableWidth,
        adaptiveTapTargets: adaptiveTapTargets,
        interactionMode: interactionMode,
      ),
    );
  }
}
