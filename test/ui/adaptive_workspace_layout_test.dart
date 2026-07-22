import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/ui/adaptive_workspace_layout.dart';
import 'package:fleur/ui/layout.dart';
import 'package:fleur/ui/layout_spec.dart';
import 'package:fleur/ui/sidebar_layout.dart';
import 'package:fleur/utils/platform.dart';

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
      expect(resolve(1200).canExpandInline, isTrue);
      expect(
        resolve(680).navigationPresentation,
        WorkspaceNavigationPresentation.rail,
      );
      expect(resolve(680).canExpandInline, isFalse);
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
        expect(arrangement.canExpandInline, isFalse);
      },
    );

    test('includes reader requirements when resolving inline expansion', () {
      final withoutReader = AdaptiveWorkspaceArrangement.resolve(
        totalWidth: 1000,
        preferredNavigation: SidebarPresentationMode.expanded,
        navigationMetrics: windowsNavigation,
        requirements: const WorkspaceLayoutRequirements.feed(listWidth: 420),
        hasReader: false,
      );
      final withReader = AdaptiveWorkspaceArrangement.resolve(
        totalWidth: 1000,
        preferredNavigation: SidebarPresentationMode.expanded,
        navigationMetrics: windowsNavigation,
        requirements: const WorkspaceLayoutRequirements.feed(listWidth: 420),
        hasReader: true,
      );

      expect(withoutReader.canExpandInline, isTrue);
      expect(withReader.canExpandInline, isFalse);
    });

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

  test('collapsed desktop sidebar does not consume content width', () {
    expect(
      effectiveContentWidth(
        1200,
        sidebarPresentationMode: SidebarPresentationMode.collapsed,
      ),
      1200,
    );
    expect(
      effectiveContentWidth(
        1200,
        sidebarPresentationMode: SidebarPresentationMode.expanded,
        sidebarWidth: kDefaultWorkspaceSidebarWidth,
      ),
      1200 - kDefaultWorkspaceSidebarWidth - kSidebarContentDividerWidth,
    );
  });

  test('workspace sidebar width clamps to window and app maximums', () {
    expect(clampWorkspaceSidebarWidth(999, 1200), kMaxWorkspaceSidebarWidth);
    expect(
      clampWorkspaceSidebarWidth(999, 700),
      700 - kMinWorkspaceContentWidth - kSidebarContentDividerWidth,
    );
    expect(clampWorkspaceSidebarWidth(999, 500), kMinWorkspaceSidebarWidth);
  });

  test('reader embedding stays monotonic while desktop width narrows', () {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    LayoutSpec specFor(double width) => LayoutSpec.fromTotalSize(
      totalWidth: width,
      totalHeight: 800,
      sidebarPresentationMode: SidebarPresentationMode.expanded,
      sidebarWidth: kDefaultWorkspaceSidebarWidth,
      listWidth: kDefaultWorkspaceListWidth,
    );

    const widths = <double>[1200, 1078, 1000, 899, 822, 821];

    expect(
      widths
          .map(
            (width) => shouldEmbedReaderForLayout(
              specFor(width),
              listWidth: kHomeListWidth,
            ),
          )
          .toList(),
      <bool>[true, true, true, false, false, false],
    );
    expect(
      widths
          .map(
            (width) => shouldEmbedReaderForLayout(
              specFor(width),
              listWidth: kDesktopListWidth,
            ),
          )
          .toList(),
      <bool>[true, true, true, false, false, false],
    );
    expect(
      widths
          .map(
            (width) => shouldCollapseSidebarForReaderLayout(
              specFor(width),
              preferredListWidth: kHomeListWidth,
            ),
          )
          .toList(),
      <bool>[false, true, true, false, false, false],
    );
  });
}
