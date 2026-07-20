import 'package:flutter/material.dart';

import '../services/update/app_update_manifest.dart';
import '../theme/fleur_theme_extensions.dart';
import 'adaptive_workspace_layout.dart';
import 'app_drawer_scope.dart';
import 'app_menu.dart';
import 'motion.dart';
import 'shell_chrome_layout.dart';
import 'shell_frame_geometry.dart';
import 'shell_title_bar.dart';
import 'shell_window_frame.dart';
import 'sidebar_layout.dart';
import 'workspace_layers.dart';

/// Owns the window-frame composition for reader routes that replace the
/// primary workspace instead of opening an embedded reader pane.
class ShellSecondarySceneFrame extends StatelessWidget {
  const ShellSecondarySceneFrame({
    super.key,
    required this.shellChromeLayout,
    required this.macOSWindowChromeMetrics,
    required this.sidebarWidth,
    required this.listWidth,
    required this.preferredNavigation,
    required this.arrangement,
    required this.temporaryNavigationOpen,
    required this.titleBarCommands,
    required this.controlsLeading,
    required this.updateManifest,
    required this.navigationToggleFocusNode,
    required this.temporaryNavigationFocusNode,
    required this.navigationPane,
    required this.floatingLeadingControls,
    required this.onDismissNavigation,
    required this.child,
  });

  final ShellChromeLayout shellChromeLayout;
  final MacOSWindowChromeMetrics macOSWindowChromeMetrics;
  final double sidebarWidth;
  final double listWidth;
  final SidebarPresentationMode preferredNavigation;
  final AdaptiveWorkspaceArrangement arrangement;
  final bool temporaryNavigationOpen;
  final ShellWindowTitleBarCommands titleBarCommands;
  final double controlsLeading;
  final AppUpdateManifest? updateManifest;
  final FocusNode navigationToggleFocusNode;
  final FocusScopeNode temporaryNavigationFocusNode;
  final Widget navigationPane;
  final Widget? floatingLeadingControls;
  final VoidCallback onDismissNavigation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final temporaryNavigationWidth = kTemporaryWorkspaceSidebarWidth;
    final geometry = ShellFrameGeometry.resolve(
      size: size,
      shellChromeLayout: shellChromeLayout,
      navigationPresentation: WorkspaceNavigationPresentation.offCanvas,
      temporaryNavigationOpen: temporaryNavigationOpen,
      expandedNavigationWidth: sidebarWidth,
      railWidth: shellChromeLayout.sidebarRailWidth,
      temporaryNavigationWidth: temporaryNavigationWidth,
    );
    final controlsPresentationMode = temporaryNavigationOpen
        ? SidebarPresentationMode.expanded
        : SidebarPresentationMode.collapsed;
    final surfaceAppearance = WorkspaceLayerSurfaceAppearance.resolve(
      shellChromeLayout,
    );
    final surfaces = Theme.of(context).fleurSurface;

    return AppMenuHost(
      child: ShellLayerScope(
        totalSize: size,
        contentSize: Size(geometry.contentWidth, geometry.workspaceHeight),
        sidebarLayoutMode: sidebarLayoutModeForWidth(size.width),
        contentLeft: geometry.contentLeft,
        contentLeadingInset: geometry.contentLeadingInset,
        railOverlayVisible: geometry.railOverlayVisible,
        sidebarWidth: sidebarWidth,
        listWidth: listWidth,
        headerLeadingInset: 14,
        macOSWindowChromeMetrics: macOSWindowChromeMetrics,
        shellChromeLayout: shellChromeLayout,
        navigationToggleFocusNode: navigationToggleFocusNode,
        temporaryNavigationFocusNode: temporaryNavigationFocusNode,
        preferredSidebarPresentationMode: preferredNavigation,
        workspaceArrangement: arrangement,
        child: AppDrawerScope(
          hasAppDrawer: true,
          openDrawer: titleBarCommands.onToggleSidebar,
          child: ShellWindowFrame(
            geometry: geometry,
            shellChromeLayout: shellChromeLayout,
            macOSWindowChromeMetrics: macOSWindowChromeMetrics,
            titleBarCommands: titleBarCommands,
            controlsPresentationMode: controlsPresentationMode,
            searchSelected: false,
            updateManifest: updateManifest,
            controlsLeading: controlsLeading,
            navigationToggleFocusNode: navigationToggleFocusNode,
            floatingLeadingControls: floatingLeadingControls,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (temporaryNavigationOpen)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: temporaryNavigationWidth,
                    child: FocusScope.withExternalFocusNode(
                      focusScopeNode: temporaryNavigationFocusNode,
                      autofocus: true,
                      child: navigationPane,
                    ),
                  ),
                AnimatedPositioned(
                  left: geometry.translatedContentLeft,
                  top: 0,
                  bottom: 0,
                  width: geometry.contentWidth,
                  duration: AppMotion.effectiveDuration(
                    context,
                    kShellContentTranslationDuration,
                  ),
                  curve: Curves.easeOutCubic,
                  child: WorkspaceLayerSurface(
                    key: const Key('app_shell_secondary_layer'),
                    color: surfaces.reader,
                    borderRadius: surfaceAppearance.borderRadius,
                    showShadow: surfaceAppearance.showShadow,
                    leadingEdge: surfaceAppearance.leadingEdge,
                    child: child,
                  ),
                ),
                if (temporaryNavigationOpen)
                  Positioned(
                    key: const Key('app_shell_navigation_scrim'),
                    left: temporaryNavigationWidth,
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onDismissNavigation,
                      child: ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.scrim.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
