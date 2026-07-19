import 'package:flutter/widgets.dart';

import '../utils/platform.dart';
import 'adaptive_workspace_layout.dart';
import 'layout.dart';
import 'shell_chrome_layout.dart';
import 'sidebar_layout.dart';
import 'workspace_layers.dart';

/// A single source of truth for responsive/layout decisions.
///
/// Important: [contentWidth] is the width available to page content after
/// subtracting inline app sidebar chrome.
@immutable
class LayoutSpec {
  const LayoutSpec._({
    required this.totalWidth,
    required this.totalHeight,
    required this.contentWidth,
    required this.contentHeight,
    required this.sidebarLayoutMode,
    required this.sidebarWidth,
    required this.listWidth,
    required this.preferredSidebarPresentationMode,
    required this.shellChromeLayout,
    required bool arrangementUsesTotalWidth,
    this.workspaceArrangement,
  }) : _arrangementUsesTotalWidth = arrangementUsesTotalWidth;

  factory LayoutSpec.fromTotalSize({
    required double totalWidth,
    required double totalHeight,
    SidebarPresentationMode sidebarPresentationMode =
        SidebarPresentationMode.expanded,
    double sidebarWidth = kDefaultWorkspaceSidebarWidth,
    double listWidth = kDefaultWorkspaceListWidth,
    ShellChromeLayout? shellChromeLayout,
  }) {
    final effectiveSidebarWidth = clampWorkspaceSidebarWidth(
      sidebarWidth,
      totalWidth,
    );
    final contentWidth = effectiveContentWidth(
      totalWidth,
      sidebarPresentationMode: sidebarPresentationMode,
      sidebarWidth: effectiveSidebarWidth,
    );
    return LayoutSpec._(
      totalWidth: totalWidth,
      totalHeight: totalHeight,
      contentWidth: contentWidth,
      contentHeight: totalHeight,
      sidebarLayoutMode: sidebarLayoutModeForWidth(totalWidth),
      sidebarWidth: effectiveSidebarWidth,
      listWidth: clampWorkspaceListWidth(listWidth, contentWidth),
      preferredSidebarPresentationMode: sidebarPresentationMode,
      shellChromeLayout: shellChromeLayout ?? ShellChromeLayout.resolve(),
      arrangementUsesTotalWidth: true,
    );
  }

  /// Use this when you're already inside the content area (e.g. ShellRoute child
  /// where the app sidebar has already consumed horizontal space).
  ///
  /// Note: [sidebarLayoutMode] is best-effort here and should not be relied on for
  /// outer-chrome decisions.
  factory LayoutSpec.fromContentSize({
    required double contentWidth,
    required double contentHeight,
    double listWidth = kDefaultWorkspaceListWidth,
    ShellChromeLayout? shellChromeLayout,
  }) {
    return LayoutSpec._(
      totalWidth: contentWidth,
      totalHeight: contentHeight,
      contentWidth: contentWidth,
      contentHeight: contentHeight,
      sidebarLayoutMode: sidebarLayoutModeForWidth(contentWidth),
      sidebarWidth: kDefaultWorkspaceSidebarWidth,
      listWidth: clampWorkspaceListWidth(listWidth, contentWidth),
      preferredSidebarPresentationMode: SidebarPresentationMode.collapsed,
      shellChromeLayout: shellChromeLayout ?? ShellChromeLayout.resolve(),
      arrangementUsesTotalWidth: false,
    );
  }

  factory LayoutSpec.fromContext(BuildContext context) {
    final shellLayer = ShellLayerScope.maybeOf(context);
    if (shellLayer != null) {
      return LayoutSpec._(
        totalWidth: shellLayer.totalSize.width,
        totalHeight: shellLayer.totalSize.height,
        contentWidth: shellLayer.contentSize.width,
        contentHeight: shellLayer.contentSize.height,
        sidebarLayoutMode: shellLayer.sidebarLayoutMode,
        sidebarWidth: shellLayer.sidebarWidth,
        listWidth: clampWorkspaceListWidth(
          shellLayer.listWidth,
          shellLayer.contentSize.width,
        ),
        preferredSidebarPresentationMode:
            shellLayer.preferredSidebarPresentationMode,
        shellChromeLayout:
            shellLayer.shellChromeLayout ?? ShellChromeLayout.resolve(),
        arrangementUsesTotalWidth: true,
        workspaceArrangement: shellLayer.workspaceArrangement,
      );
    }

    final size = MediaQuery.sizeOf(context);
    return LayoutSpec.fromTotalSize(
      totalWidth: size.width,
      totalHeight: size.height,
    );
  }

  final double totalWidth;
  final double totalHeight;
  final double contentWidth;
  final double contentHeight;
  final SidebarLayoutMode sidebarLayoutMode;
  final double sidebarWidth;
  final double listWidth;
  final SidebarPresentationMode preferredSidebarPresentationMode;
  final ShellChromeLayout shellChromeLayout;
  final AdaptiveWorkspaceArrangement? workspaceArrangement;
  final bool _arrangementUsesTotalWidth;

  bool get isDesktopPlatform => isDesktop;

  bool get hasInlineSidebar => sidebarLayoutMode == SidebarLayoutMode.inline;

  bool get usesCompactListActions => contentWidth < kCompactWidth;

  bool get showsListSyncStatusCapsule => !usesCompactListActions;

  DesktopPaneMode get desktopPaneMode => desktopModeForWidth(
    contentWidth - kWorkspaceSplitHandleHitWidth,
    listWidth: listWidth,
  );

  bool get desktopEmbedsReader => desktopReaderEmbedded(desktopPaneMode);

  bool canEmbedReader({
    required double listWidth,
    double minReaderWidth = kMinReadingWidth,
  }) {
    return contentWidth >=
        (listWidth + minReaderWidth + kPaneGap + kWorkspaceSplitHandleHitWidth);
  }

  bool get isCompact => contentWidth < kCompactWidth;

  bool get canSwipeToDelete => !isDesktopPlatform;

  AdaptiveWorkspaceArrangement resolveFeedArrangement({
    required double listWidth,
    required bool hasReader,
  }) {
    final existing = workspaceArrangement;
    if (existing != null) {
      final existingHasReader =
          existing.readerPresentation != WorkspaceReaderPresentation.none;
      if (existingHasReader == hasReader) return existing;
    }
    final navigationMetrics = _arrangementUsesTotalWidth
        ? shellChromeLayout.workspaceNavigationMetrics
        : const WorkspaceNavigationMetrics(expandedExtent: 0, railExtent: 0);
    return AdaptiveWorkspaceArrangement.resolve(
      totalWidth: _arrangementUsesTotalWidth ? totalWidth : contentWidth,
      preferredNavigation: preferredSidebarPresentationMode,
      navigationMetrics: navigationMetrics,
      requirements: WorkspaceLayoutRequirements.feed(listWidth: listWidth),
      hasReader: hasReader,
    );
  }
}

bool shouldEmbedReaderForLayout(LayoutSpec spec, {required double listWidth}) {
  return spec
      .resolveFeedArrangement(listWidth: listWidth, hasReader: true)
      .readerEmbedded;
}

bool canEmbedDesktopReaderForContentWidth(
  double contentWidth, {
  required double preferredListWidth,
  double minReaderWidth = kMinReadingWidth,
}) {
  if (contentWidth <= 0) return false;
  final listWidth = clampWorkspaceListWidth(preferredListWidth, contentWidth);
  return contentWidth >=
      (listWidth + minReaderWidth + kPaneGap + kWorkspaceSplitHandleHitWidth);
}

bool shouldCollapseSidebarForReaderLayout(
  LayoutSpec spec, {
  required double preferredListWidth,
}) {
  return spec
      .resolveFeedArrangement(listWidth: preferredListWidth, hasReader: true)
      .navigationTemporarilyCollapsed;
}
