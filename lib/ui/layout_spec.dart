import 'package:flutter/widgets.dart';

import '../utils/platform.dart';
import 'global_nav.dart';
import 'layout.dart';

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
  });

  factory LayoutSpec.fromTotalSize({
    required double totalWidth,
    required double totalHeight,
    SidebarPresentationMode sidebarPresentationMode =
        SidebarPresentationMode.expanded,
  }) {
    return LayoutSpec._(
      totalWidth: totalWidth,
      totalHeight: totalHeight,
      contentWidth: effectiveContentWidth(
        totalWidth,
        sidebarPresentationMode: sidebarPresentationMode,
      ),
      contentHeight: totalHeight,
      sidebarLayoutMode: sidebarLayoutModeForWidth(totalWidth),
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
  }) {
    return LayoutSpec._(
      totalWidth: contentWidth,
      totalHeight: contentHeight,
      contentWidth: contentWidth,
      contentHeight: contentHeight,
      sidebarLayoutMode: sidebarLayoutModeForWidth(contentWidth),
    );
  }

  factory LayoutSpec.fromContext(BuildContext context) {
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

  bool get isDesktopPlatform => isDesktop;

  bool get hasInlineSidebar => sidebarLayoutMode == SidebarLayoutMode.inline;

  DesktopPaneMode get desktopPaneMode => desktopModeForWidth(contentWidth);

  bool get desktopEmbedsReader => desktopReaderEmbedded(desktopPaneMode);

  bool canEmbedReader({
    required double listWidth,
    double minReaderWidth = kMinReadingWidth,
  }) {
    return contentWidth >= (listWidth + minReaderWidth + kPaneGap);
  }

  bool get isCompact => contentWidth < kCompactWidth;

  bool get canSwipeToDelete => !isDesktopPlatform;
}
