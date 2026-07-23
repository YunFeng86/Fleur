import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/ui/adaptive_workspace_layout.dart';
import 'package:fleur/ui/shell_chrome_layout.dart';
import 'package:fleur/ui/shell_frame_topology.dart';

void main() {
  ShellFrameTopology resolve({
    required ShellChromeLayout shellChromeLayout,
    required WorkspaceNavigationPresentation navigationPresentation,
    bool temporaryNavigationOpen = false,
  }) {
    return ShellFrameTopology.resolve(
      shellChromeLayout: shellChromeLayout,
      navigationPresentation: navigationPresentation,
      temporaryNavigationOpen: temporaryNavigationOpen,
    );
  }

  group('macOS shell frame topology', () {
    test('keeps expanded navigation and global tools on one L1 surface', () {
      final topology = resolve(
        shellChromeLayout: ShellChromeLayout.integratedCorner,
        navigationPresentation: WorkspaceNavigationPresentation.expanded,
      );

      expect(topology.surfaceMode, ShellFrameSurfaceMode.continuous);
      expect(topology.navigationSurface, ShellNavigationSurface.inline);
      expect(topology.globalToolSurface, ShellGlobalToolSurface.integrated);
      expect(topology.shellCanvasPaintsFullViewport, isTrue);
    });

    test('uses separate tool and navigation fragments for a rail', () {
      final topology = resolve(
        shellChromeLayout: ShellChromeLayout.integratedCorner,
        navigationPresentation: WorkspaceNavigationPresentation.rail,
      );

      expect(topology.surfaceMode, ShellFrameSurfaceMode.fragmented);
      expect(topology.navigationSurface, ShellNavigationSurface.floatingIsland);
      expect(topology.globalToolSurface, ShellGlobalToolSurface.floatingIsland);
      expect(topology.hasPersistentNavigationSurface, isTrue);
    });

    test(
      'keeps only the floating tool fragment when navigation is off-canvas',
      () {
        final topology = resolve(
          shellChromeLayout: ShellChromeLayout.integratedCorner,
          navigationPresentation: WorkspaceNavigationPresentation.offCanvas,
        );

        expect(topology.surfaceMode, ShellFrameSurfaceMode.fragmented);
        expect(topology.navigationSurface, ShellNavigationSurface.absent);
        expect(
          topology.globalToolSurface,
          ShellGlobalToolSurface.floatingIsland,
        );
        expect(topology.hasPersistentNavigationSurface, isFalse);
      },
    );

    test(
      'prefers a temporary navigation overlay without moving global tools',
      () {
        final topology = resolve(
          shellChromeLayout: ShellChromeLayout.integratedCorner,
          navigationPresentation: WorkspaceNavigationPresentation.rail,
          temporaryNavigationOpen: true,
        );

        expect(topology.surfaceMode, ShellFrameSurfaceMode.continuous);
        expect(
          topology.navigationSurface,
          ShellNavigationSurface.temporaryOverlay,
        );
        expect(topology.globalToolSurface, ShellGlobalToolSurface.integrated);
        expect(topology.temporaryNavigationOpen, isTrue);
        expect(topology.hasTemporaryNavigationOverlay, isTrue);
      },
    );
  });

  group('Windows shell frame topology', () {
    test('keeps expanded navigation connected to the window frame', () {
      final topology = resolve(
        shellChromeLayout: ShellChromeLayout.titleBarExpected,
        navigationPresentation: WorkspaceNavigationPresentation.expanded,
      );

      expect(topology.surfaceMode, ShellFrameSurfaceMode.continuous);
      expect(topology.navigationSurface, ShellNavigationSurface.inline);
      expect(topology.globalToolSurface, ShellGlobalToolSurface.windowFrame);
      expect(topology.shellCanvasPaintsFullViewport, isTrue);
    });

    test('keeps a rail as a structural window-frame fragment', () {
      final topology = resolve(
        shellChromeLayout: ShellChromeLayout.titleBarExpected,
        navigationPresentation: WorkspaceNavigationPresentation.rail,
      );

      expect(topology.surfaceMode, ShellFrameSurfaceMode.fragmented);
      expect(topology.navigationSurface, ShellNavigationSurface.structuralRail);
      expect(topology.globalToolSurface, ShellGlobalToolSurface.windowFrame);
      expect(topology.hasPersistentNavigationSurface, isTrue);
    });

    test('retains the window frame when navigation is off-canvas', () {
      final topology = resolve(
        shellChromeLayout: ShellChromeLayout.titleBarExpected,
        navigationPresentation: WorkspaceNavigationPresentation.offCanvas,
      );

      expect(topology.surfaceMode, ShellFrameSurfaceMode.continuous);
      expect(topology.navigationSurface, ShellNavigationSurface.absent);
      expect(topology.globalToolSurface, ShellGlobalToolSurface.windowFrame);
      expect(topology.hasPersistentNavigationSurface, isFalse);
    });

    test(
      'uses a temporary overlay without changing the global tool attachment',
      () {
        final topology = resolve(
          shellChromeLayout: ShellChromeLayout.titleBarExpected,
          navigationPresentation: WorkspaceNavigationPresentation.rail,
          temporaryNavigationOpen: true,
        );

        expect(topology.surfaceMode, ShellFrameSurfaceMode.continuous);
        expect(
          topology.navigationSurface,
          ShellNavigationSurface.temporaryOverlay,
        );
        expect(topology.globalToolSurface, ShellGlobalToolSurface.windowFrame);
        expect(topology.temporaryNavigationOpen, isTrue);
        expect(topology.hasTemporaryNavigationOverlay, isTrue);
      },
    );
  });
}
