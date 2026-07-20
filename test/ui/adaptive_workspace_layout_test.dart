import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/ui/adaptive_workspace_layout.dart';
import 'package:fleur/ui/sidebar_layout.dart';

void main() {
  const windowsNavigation = WorkspaceNavigationMetrics(
    expandedExtent: kDefaultWorkspaceSidebarWidth + kSidebarContentDividerWidth,
    railExtent: 56,
  );

  group('WorkspaceNavigationToggleResult', () {
    test('collapses expanded navigation and preserves a collapsed rail', () {
      final collapse = WorkspaceNavigationToggleResult.resolve(
        presentation: WorkspaceNavigationPresentation.expanded,
        preferredNavigation: SidebarPresentationMode.expanded,
        temporaryNavigationOpen: false,
        canExpandInline: true,
      );
      expect(collapse.preferredNavigation, SidebarPresentationMode.collapsed);
      expect(collapse.temporaryNavigationOpen, isFalse);

      final expand = WorkspaceNavigationToggleResult.resolve(
        presentation: WorkspaceNavigationPresentation.rail,
        preferredNavigation: SidebarPresentationMode.collapsed,
        temporaryNavigationOpen: false,
        canExpandInline: true,
      );
      expect(expand.preferredNavigation, SidebarPresentationMode.expanded);
      expect(expand.temporaryNavigationOpen, isFalse);
    });

    test('opens and closes temporary navigation when inline cannot fit', () {
      final open = WorkspaceNavigationToggleResult.resolve(
        presentation: WorkspaceNavigationPresentation.offCanvas,
        preferredNavigation: SidebarPresentationMode.expanded,
        temporaryNavigationOpen: false,
        canExpandInline: false,
      );
      expect(open.preferredNavigation, SidebarPresentationMode.expanded);
      expect(open.temporaryNavigationOpen, isTrue);

      final close = WorkspaceNavigationToggleResult.resolve(
        presentation: WorkspaceNavigationPresentation.offCanvas,
        preferredNavigation: SidebarPresentationMode.expanded,
        temporaryNavigationOpen: true,
        canExpandInline: false,
      );
      expect(close.preferredNavigation, SidebarPresentationMode.expanded);
      expect(close.temporaryNavigationOpen, isFalse);
    });
  });

  group('AdaptiveWorkspaceArrangement feed', () {
    test('resolves expanded, rail, and off-canvas from total width', () {
      AdaptiveWorkspaceArrangement resolve(double width) {
        return AdaptiveWorkspaceArrangement.resolve(
          totalWidth: width,
          preferredNavigation: SidebarPresentationMode.expanded,
          navigationMetrics: windowsNavigation,
          requirements: const WorkspaceLayoutRequirements.feed(listWidth: 420),
          hasReader: false,
        );
      }

      expect(
        resolve(1200).navigationPresentation,
        WorkspaceNavigationPresentation.expanded,
      );
      expect(
        resolve(680).navigationPresentation,
        WorkspaceNavigationPresentation.rail,
      );
      expect(
        resolve(475).navigationPresentation,
        WorkspaceNavigationPresentation.offCanvas,
      );
    });

    test('keeps a collapsed preference as a rail when it fits', () {
      final arrangement = AdaptiveWorkspaceArrangement.resolve(
        totalWidth: 1200,
        preferredNavigation: SidebarPresentationMode.collapsed,
        navigationMetrics: windowsNavigation,
        requirements: const WorkspaceLayoutRequirements.feed(listWidth: 420),
        hasReader: false,
      );

      expect(
        arrangement.navigationPresentation,
        WorkspaceNavigationPresentation.rail,
      );
    });

    test(
      'temporarily collapses navigation when that preserves reader split',
      () {
        final arrangement = AdaptiveWorkspaceArrangement.resolve(
          totalWidth: 1000,
          preferredNavigation: SidebarPresentationMode.expanded,
          navigationMetrics: windowsNavigation,
          requirements: const WorkspaceLayoutRequirements.feed(listWidth: 420),
          hasReader: true,
        );

        expect(
          arrangement.navigationPresentation,
          WorkspaceNavigationPresentation.rail,
        );
        expect(
          arrangement.readerPresentation,
          WorkspaceReaderPresentation.embedded,
        );
        expect(arrangement.navigationTemporarilyCollapsed, isTrue);
      },
    );

    test('uses a secondary reader when no valid split fits', () {
      final arrangement = AdaptiveWorkspaceArrangement.resolve(
        totalWidth: 900,
        preferredNavigation: SidebarPresentationMode.expanded,
        navigationMetrics: windowsNavigation,
        requirements: const WorkspaceLayoutRequirements.feed(listWidth: 420),
        hasReader: true,
      );

      expect(
        arrangement.readerPresentation,
        WorkspaceReaderPresentation.secondaryPage,
      );
      expect(arrangement.navigationVisible, isFalse);
    });
  });

  group('AdaptiveWorkspaceArrangement settings', () {
    test(
      'uses settings-specific expanded, rail, and off-canvas requirements',
      () {
        AdaptiveWorkspaceArrangement resolve(double width) {
          return AdaptiveWorkspaceArrangement.resolve(
            totalWidth: width,
            preferredNavigation: SidebarPresentationMode.expanded,
            navigationMetrics: windowsNavigation,
            requirements: WorkspaceLayoutRequirements.settings,
            hasReader: false,
          );
        }

        expect(
          resolve(1000).navigationPresentation,
          WorkspaceNavigationPresentation.expanded,
        );
        expect(
          resolve(800).navigationPresentation,
          WorkspaceNavigationPresentation.rail,
        );
        expect(
          resolve(650).navigationPresentation,
          WorkspaceNavigationPresentation.offCanvas,
        );
      },
    );
  });
}
