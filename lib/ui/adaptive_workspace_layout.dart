import 'package:flutter/foundation.dart';

import 'layout.dart';
import 'sidebar_layout.dart';

enum WorkspaceNavigationPresentation { expanded, rail, offCanvas }

enum WorkspaceReaderPresentation { none, embedded, secondaryPage }

@immutable
class WorkspaceNavigationToggleResult {
  const WorkspaceNavigationToggleResult({
    required this.preferredNavigation,
    required this.temporaryNavigationOpen,
  });

  final SidebarPresentationMode preferredNavigation;
  final bool temporaryNavigationOpen;

  static WorkspaceNavigationToggleResult resolve({
    required WorkspaceNavigationPresentation presentation,
    required SidebarPresentationMode preferredNavigation,
    required bool temporaryNavigationOpen,
    required bool canExpandInline,
  }) {
    if (presentation != WorkspaceNavigationPresentation.expanded &&
        temporaryNavigationOpen) {
      return WorkspaceNavigationToggleResult(
        preferredNavigation: preferredNavigation,
        temporaryNavigationOpen: false,
      );
    }

    if (presentation == WorkspaceNavigationPresentation.expanded) {
      return const WorkspaceNavigationToggleResult(
        preferredNavigation: SidebarPresentationMode.collapsed,
        temporaryNavigationOpen: false,
      );
    }

    if (preferredNavigation == SidebarPresentationMode.collapsed) {
      return WorkspaceNavigationToggleResult(
        preferredNavigation: SidebarPresentationMode.expanded,
        temporaryNavigationOpen: !canExpandInline,
      );
    }

    return WorkspaceNavigationToggleResult(
      preferredNavigation: preferredNavigation,
      temporaryNavigationOpen: true,
    );
  }
}

@immutable
class WorkspaceNavigationMetrics {
  const WorkspaceNavigationMetrics({
    required this.expandedExtent,
    required this.railExtent,
  });

  final double expandedExtent;
  final double railExtent;
}

@immutable
class WorkspaceLayoutRequirements {
  const WorkspaceLayoutRequirements({
    required this.expandedContentWidth,
    required this.railContentWidth,
    this.listWidth = 0,
    this.readerWidth = 0,
    this.splitHandleExtent = 0,
  });

  const WorkspaceLayoutRequirements.feed({required double listWidth})
    : this(
        expandedContentWidth: kCompactWorkspacePrimaryWidth,
        railContentWidth: kCompactWorkspacePrimaryWidth,
        listWidth: listWidth,
        readerWidth: kMinAdaptiveReaderWidth,
        splitHandleExtent: kWorkspaceSplitHandleHitWidth,
      );

  static const settings = WorkspaceLayoutRequirements(
    expandedContentWidth: kSettingsPinnedContentWidth,
    railContentWidth: kSettingsRailContentWidth,
  );

  final double expandedContentWidth;
  final double railContentWidth;
  final double listWidth;
  final double readerWidth;
  final double splitHandleExtent;

  bool get supportsReader => readerWidth > 0;

  double get embeddedReaderWidth => listWidth + readerWidth + splitHandleExtent;
}

@immutable
class AdaptiveWorkspaceArrangement {
  const AdaptiveWorkspaceArrangement({
    required this.navigationPresentation,
    required this.readerPresentation,
    required this.navigationTemporarilyCollapsed,
    required this.canExpandInline,
  });

  final WorkspaceNavigationPresentation navigationPresentation;
  final WorkspaceReaderPresentation readerPresentation;
  final bool navigationTemporarilyCollapsed;
  final bool canExpandInline;

  bool get readerEmbedded =>
      readerPresentation == WorkspaceReaderPresentation.embedded;

  bool get showsSecondaryReader =>
      readerPresentation == WorkspaceReaderPresentation.secondaryPage;

  bool get navigationVisible => !showsSecondaryReader;

  static AdaptiveWorkspaceArrangement resolve({
    required double totalWidth,
    required SidebarPresentationMode preferredNavigation,
    required WorkspaceNavigationMetrics navigationMetrics,
    required WorkspaceLayoutRequirements requirements,
    required bool hasReader,
  }) {
    final width = totalWidth.isFinite
        ? totalWidth.clamp(0.0, double.infinity).toDouble()
        : 0.0;
    final preferredPresentation = _preferredNavigationPresentation(
      width: width,
      preferredNavigation: preferredNavigation,
      navigationMetrics: navigationMetrics,
      requirements: requirements,
    );

    final expandedFits =
        width >=
        navigationMetrics.expandedExtent + requirements.expandedContentWidth;
    final expandedReaderFits =
        !hasReader ||
        !requirements.supportsReader ||
        _readerFits(
          width: width,
          presentation: WorkspaceNavigationPresentation.expanded,
          navigationMetrics: navigationMetrics,
          requirements: requirements,
        );
    final canExpandInline = expandedFits && expandedReaderFits;

    if (!hasReader || !requirements.supportsReader) {
      return AdaptiveWorkspaceArrangement(
        navigationPresentation: preferredPresentation,
        readerPresentation: WorkspaceReaderPresentation.none,
        navigationTemporarilyCollapsed: false,
        canExpandInline: canExpandInline,
      );
    }

    if (_readerFits(
      width: width,
      presentation: preferredPresentation,
      navigationMetrics: navigationMetrics,
      requirements: requirements,
    )) {
      return AdaptiveWorkspaceArrangement(
        navigationPresentation: preferredPresentation,
        readerPresentation: WorkspaceReaderPresentation.embedded,
        navigationTemporarilyCollapsed: false,
        canExpandInline: canExpandInline,
      );
    }

    if (preferredPresentation == WorkspaceNavigationPresentation.expanded &&
        _railFitsPrimary(
          width: width,
          navigationMetrics: navigationMetrics,
          requirements: requirements,
        ) &&
        _readerFits(
          width: width,
          presentation: WorkspaceNavigationPresentation.rail,
          navigationMetrics: navigationMetrics,
          requirements: requirements,
        )) {
      return AdaptiveWorkspaceArrangement(
        navigationPresentation: WorkspaceNavigationPresentation.rail,
        readerPresentation: WorkspaceReaderPresentation.embedded,
        navigationTemporarilyCollapsed: true,
        canExpandInline: canExpandInline,
      );
    }

    return AdaptiveWorkspaceArrangement(
      navigationPresentation: preferredPresentation,
      readerPresentation: WorkspaceReaderPresentation.secondaryPage,
      navigationTemporarilyCollapsed: false,
      canExpandInline: canExpandInline,
    );
  }

  static WorkspaceNavigationPresentation _preferredNavigationPresentation({
    required double width,
    required SidebarPresentationMode preferredNavigation,
    required WorkspaceNavigationMetrics navigationMetrics,
    required WorkspaceLayoutRequirements requirements,
  }) {
    if (preferredNavigation == SidebarPresentationMode.expanded &&
        width >=
            navigationMetrics.expandedExtent +
                requirements.expandedContentWidth) {
      return WorkspaceNavigationPresentation.expanded;
    }
    if (_railFitsPrimary(
      width: width,
      navigationMetrics: navigationMetrics,
      requirements: requirements,
    )) {
      return WorkspaceNavigationPresentation.rail;
    }
    return WorkspaceNavigationPresentation.offCanvas;
  }

  static bool _railFitsPrimary({
    required double width,
    required WorkspaceNavigationMetrics navigationMetrics,
    required WorkspaceLayoutRequirements requirements,
  }) {
    return width >=
        navigationMetrics.railExtent + requirements.railContentWidth;
  }

  static bool _readerFits({
    required double width,
    required WorkspaceNavigationPresentation presentation,
    required WorkspaceNavigationMetrics navigationMetrics,
    required WorkspaceLayoutRequirements requirements,
  }) {
    final navigationExtent = switch (presentation) {
      WorkspaceNavigationPresentation.expanded =>
        navigationMetrics.expandedExtent,
      WorkspaceNavigationPresentation.rail => navigationMetrics.railExtent,
      WorkspaceNavigationPresentation.offCanvas => 0.0,
    };
    return width >= navigationExtent + requirements.embeddedReaderWidth;
  }
}

const double kCompactWorkspacePrimaryWidth = kHomeListWidth;
const double kMinAdaptiveReaderWidth = kMinReadingWidth;
const double kSettingsPinnedContentWidth = 720;
const double kSettingsRailContentWidth = 600;
