import 'package:flutter/widgets.dart';

import '../utils/platform.dart';
import 'sidebar_layout.dart';
import 'layout.dart';
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
  });

  factory LayoutSpec.fromTotalSize({
    required double totalWidth,
    required double totalHeight,
    SidebarPresentationMode sidebarPresentationMode =
        SidebarPresentationMode.expanded,
    double sidebarWidth = kDefaultWorkspaceSidebarWidth,
    double listWidth = kDefaultWorkspaceListWidth,
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
  }) {
    return LayoutSpec._(
      totalWidth: contentWidth,
      totalHeight: contentHeight,
      contentWidth: contentWidth,
      contentHeight: contentHeight,
      sidebarLayoutMode: sidebarLayoutModeForWidth(contentWidth),
      sidebarWidth: kDefaultWorkspaceSidebarWidth,
      listWidth: clampWorkspaceListWidth(listWidth, contentWidth),
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
}

bool shouldEmbedReaderForLayout(LayoutSpec spec, {required double listWidth}) {
  return spec.isDesktopPlatform
      ? spec.desktopEmbedsReader
      : spec.canEmbedReader(listWidth: listWidth);
}
