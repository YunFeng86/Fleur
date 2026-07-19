import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/ui/adaptive_workspace_layout.dart';
import 'package:fleur/ui/shell_chrome_layout.dart';
import 'package:fleur/ui/shell_frame_geometry.dart';
import 'package:fleur/ui/sidebar_layout.dart';

void main() {
  const size = Size(1000, 800);

  test('Windows rail is structural and title bar stays outside content', () {
    final geometry = ShellFrameGeometry.resolve(
      size: size,
      shellChromeLayout: ShellChromeLayout.titleBarExpected,
      navigationPresentation: WorkspaceNavigationPresentation.rail,
      temporaryNavigationOpen: false,
      expandedNavigationWidth: kDefaultWorkspaceSidebarWidth,
      railWidth: kTitleBarExpectedSidebarRailWidth,
      temporaryNavigationWidth: kTemporaryWorkspaceSidebarWidth,
    );

    expect(geometry.titleBarHeight, kWorkspaceHeaderHeight);
    expect(geometry.contentLeft, kTitleBarExpectedSidebarRailWidth);
    expect(geometry.contentWidth, 944);
    expect(geometry.structuralRailVisible, isTrue);
    expect(geometry.railOverlayVisible, isFalse);
  });

  test('temporary navigation translates content without relayout', () {
    final closed = ShellFrameGeometry.resolve(
      size: size,
      shellChromeLayout: ShellChromeLayout.titleBarExpected,
      navigationPresentation: WorkspaceNavigationPresentation.rail,
      temporaryNavigationOpen: false,
      expandedNavigationWidth: kDefaultWorkspaceSidebarWidth,
      railWidth: kTitleBarExpectedSidebarRailWidth,
      temporaryNavigationWidth: kTemporaryWorkspaceSidebarWidth,
    );
    final open = ShellFrameGeometry.resolve(
      size: size,
      shellChromeLayout: ShellChromeLayout.titleBarExpected,
      navigationPresentation: WorkspaceNavigationPresentation.rail,
      temporaryNavigationOpen: true,
      expandedNavigationWidth: kDefaultWorkspaceSidebarWidth,
      railWidth: kTitleBarExpectedSidebarRailWidth,
      temporaryNavigationWidth: kTemporaryWorkspaceSidebarWidth,
    );

    expect(open.contentWidth, closed.contentWidth);
    expect(open.contentLeft, closed.contentLeft);
    expect(open.translatedContentLeft, kTemporaryWorkspaceSidebarWidth);
    expect(open.dividerLeadingInset, kTemporaryWorkspaceSidebarWidth);
    expect(open.structuralRailVisible, isFalse);
  });

  test('macOS rail remains an overlay with a content inset', () {
    final geometry = ShellFrameGeometry.resolve(
      size: size,
      shellChromeLayout: ShellChromeLayout.integratedCorner,
      navigationPresentation: WorkspaceNavigationPresentation.rail,
      temporaryNavigationOpen: false,
      expandedNavigationWidth: kDefaultWorkspaceSidebarWidth,
      railWidth: kSidebarRailWidth,
      temporaryNavigationWidth: kTemporaryWorkspaceSidebarWidth,
    );

    expect(geometry.titleBarHeight, 0);
    expect(geometry.contentLeft, 0);
    expect(geometry.contentWidth, size.width);
    expect(
      geometry.contentLeadingInset,
      kSidebarRailWidth + kRailOverlayContentGap,
    );
    expect(geometry.railOverlayVisible, isTrue);
  });

  test('content-only off-canvas reserves no closed navigation width', () {
    final geometry = ShellFrameGeometry.resolve(
      size: size,
      shellChromeLayout: ShellChromeLayout.contentOnly,
      navigationPresentation: WorkspaceNavigationPresentation.offCanvas,
      temporaryNavigationOpen: false,
      expandedNavigationWidth: kDefaultWorkspaceSidebarWidth,
      railWidth: kSidebarRailWidth,
      temporaryNavigationWidth: kTemporaryWorkspaceSidebarWidth,
    );

    expect(geometry.contentLeft, 0);
    expect(geometry.contentWidth, size.width);
    expect(geometry.structuralRailVisible, isFalse);
    expect(geometry.railOverlayVisible, isFalse);
  });
}
