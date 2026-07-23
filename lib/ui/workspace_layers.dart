import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../utils/macos_window_chrome_bridge.dart';
import '../utils/platform.dart';
import 'adaptive_workspace_layout.dart';
import 'shell_chrome_layout.dart';
import 'shell_frame_geometry.dart';
import 'shell_frame_topology.dart';
import 'sidebar_layout.dart';

const BorderRadius kWorkspaceLayerRadius = BorderRadius.only(
  topLeft: Radius.circular(16),
  bottomLeft: Radius.circular(16),
);

const BorderRadius kConnectedWorkspaceLayerRadius = BorderRadius.only(
  topLeft: Radius.circular(12),
);

enum WorkspaceLayerEdge { none, level1, level2 }

@immutable
class WorkspaceLayerSurfaceAppearance {
  const WorkspaceLayerSurfaceAppearance({
    required this.borderRadius,
    required this.showShadow,
    required this.leadingEdge,
  });

  final BorderRadius borderRadius;
  final bool showShadow;
  final WorkspaceLayerEdge leadingEdge;

  static WorkspaceLayerSurfaceAppearance resolve(
    ShellChromeLayout shellChromeLayout, {
    WorkspaceLayerEdge floatingLeadingEdge = WorkspaceLayerEdge.none,
  }) {
    return switch (shellChromeLayout.contentSurfaceStyle) {
      ShellContentSurfaceStyle.floatingRounded =>
        WorkspaceLayerSurfaceAppearance(
          borderRadius: kWorkspaceLayerRadius,
          showShadow: true,
          leadingEdge: floatingLeadingEdge,
        ),
      ShellContentSurfaceStyle.connectedSoft =>
        const WorkspaceLayerSurfaceAppearance(
          borderRadius: kConnectedWorkspaceLayerRadius,
          showShadow: false,
          leadingEdge: WorkspaceLayerEdge.none,
        ),
      ShellContentSurfaceStyle.plain => const WorkspaceLayerSurfaceAppearance(
        borderRadius: BorderRadius.zero,
        showShadow: false,
        leadingEdge: WorkspaceLayerEdge.none,
      ),
    };
  }
}

class ShellLayerScope extends InheritedWidget {
  const ShellLayerScope({
    super.key,
    required this.frameGeometry,
    required this.totalSize,
    required this.sidebarLayoutMode,
    required this.sidebarWidth,
    required this.listWidth,
    required this.headerLeadingInset,
    required this.macOSWindowChromeMetrics,
    this.shellChromeLayout,
    this.navigationToggleFocusNode,
    this.temporaryNavigationFocusNode,
    this.preferredSidebarPresentationMode = SidebarPresentationMode.expanded,
    this.workspaceArrangement,
    required super.child,
  });

  final ShellFrameGeometry frameGeometry;
  final Size totalSize;
  final SidebarLayoutMode sidebarLayoutMode;
  final double sidebarWidth;
  final double listWidth;
  final double headerLeadingInset;
  final MacOSWindowChromeMetrics macOSWindowChromeMetrics;
  final ShellChromeLayout? shellChromeLayout;
  final FocusNode? navigationToggleFocusNode;
  final FocusScopeNode? temporaryNavigationFocusNode;
  final SidebarPresentationMode preferredSidebarPresentationMode;
  final AdaptiveWorkspaceArrangement? workspaceArrangement;

  ShellFrameTopology get topology => frameGeometry.topology;
  Size get contentSize =>
      Size(frameGeometry.contentWidth, frameGeometry.workspaceHeight);
  double get contentLeft => frameGeometry.contentLeft;
  double get contentLeadingInset => frameGeometry.contentLeadingInset;
  bool get railOverlayVisible => frameGeometry.railOverlayVisible;

  static ShellLayerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellLayerScope>();
  }

  @override
  bool updateShouldNotify(ShellLayerScope oldWidget) {
    return frameGeometry != oldWidget.frameGeometry ||
        totalSize != oldWidget.totalSize ||
        sidebarLayoutMode != oldWidget.sidebarLayoutMode ||
        sidebarWidth != oldWidget.sidebarWidth ||
        listWidth != oldWidget.listWidth ||
        headerLeadingInset != oldWidget.headerLeadingInset ||
        macOSWindowChromeMetrics != oldWidget.macOSWindowChromeMetrics ||
        shellChromeLayout != oldWidget.shellChromeLayout ||
        navigationToggleFocusNode != oldWidget.navigationToggleFocusNode ||
        temporaryNavigationFocusNode !=
            oldWidget.temporaryNavigationFocusNode ||
        preferredSidebarPresentationMode !=
            oldWidget.preferredSidebarPresentationMode ||
        workspaceArrangement != oldWidget.workspaceArrangement;
  }
}

class WorkspaceLayerSurface extends StatelessWidget {
  const WorkspaceLayerSurface({
    super.key,
    required this.child,
    this.color,
    this.borderRadius = kWorkspaceLayerRadius,
    this.showShadow = true,
    this.leadingEdge = WorkspaceLayerEdge.none,
  });

  final Widget child;
  final Color? color;
  final BorderRadius borderRadius;
  final bool showShadow;
  final WorkspaceLayerEdge leadingEdge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;
    final shadowColor = theme.shadowColor.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.22 : 0.12,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? surfaces.list,
        borderRadius: borderRadius,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(-4, 0),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            ColoredBox(color: color ?? surfaces.list, child: child),
            if (leadingEdge != WorkspaceLayerEdge.none)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const Key('workspace_layer_leading_edge'),
                    painter: _WorkspaceLeadingEdgePainter(
                      borderRadius: borderRadius,
                      color: _leadingEdgeColor(theme, surfaces, leadingEdge),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Color _leadingEdgeColor(
  ThemeData theme,
  FleurSurfaceTheme surfaces,
  WorkspaceLayerEdge edge,
) {
  final dark = theme.brightness == Brightness.dark;
  final baseColor = dark
      ? Color.alphaBlend(
          theme.colorScheme.onSurface.withValues(
            alpha: edge == WorkspaceLayerEdge.level2 ? 0.10 : 0.06,
          ),
          surfaces.subtleDivider,
        )
      : surfaces.subtleDivider;
  final alpha = switch ((theme.brightness, edge)) {
    (_, WorkspaceLayerEdge.none) => 0.0,
    (Brightness.dark, WorkspaceLayerEdge.level1) => 0.94,
    (Brightness.dark, WorkspaceLayerEdge.level2) => 1.0,
    (Brightness.light, WorkspaceLayerEdge.level1) => 0.72,
    (Brightness.light, WorkspaceLayerEdge.level2) => 0.86,
  };
  return baseColor.withValues(alpha: alpha);
}

class _WorkspaceLeadingEdgePainter extends CustomPainter {
  const _WorkspaceLeadingEdgePainter({
    required this.borderRadius,
    required this.color,
  });

  final BorderRadius borderRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final strokeWidth = kSidebarContentDividerWidth;
    final inset = strokeWidth / 2;
    final topRadius = math.min(
      borderRadius.topLeft.x,
      math.min(size.width, size.height) / 2,
    );
    final bottomRadius = math.min(
      borderRadius.bottomLeft.x,
      math.min(size.width, size.height) / 2,
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;
    final path = Path();

    if (topRadius > 0) {
      path
        ..moveTo(topRadius, inset)
        ..quadraticBezierTo(inset, inset, inset, topRadius);
    } else {
      path.moveTo(inset, inset);
    }

    final bottomStart = math.max(topRadius, size.height - bottomRadius);
    path.lineTo(inset, bottomStart);

    if (bottomRadius > 0) {
      path.quadraticBezierTo(
        inset,
        size.height - inset,
        bottomRadius,
        size.height - inset,
      );
    } else {
      path.lineTo(inset, size.height - inset);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WorkspaceLeadingEdgePainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.color != color;
  }
}

class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.title,
    required this.trailing,
    required this.trailingWidth,
    this.leadingPadding = 14,
    this.trailingPadding = 8,
  });

  static const double minVisibleTitleWidth = 72;

  final String title;
  final Widget trailing;
  final double trailingWidth;
  final double leadingPadding;
  final double trailingPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      key: const Key('home_scope_header'),
      type: MaterialType.transparency,
      child: ClipRect(
        child: Stack(
          children: [
            const Positioned.fill(child: WorkspaceHeaderSurface()),
            SizedBox(
              height: kWorkspaceHeaderHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final scope = ShellLayerScope.maybeOf(context);
                  final shellChromeLayout =
                      scope?.shellChromeLayout ?? ShellChromeLayout.resolve();
                  final hasIntegratedCorner =
                      shellChromeLayout.profile ==
                      ShellChromeProfile.integratedCorner;
                  final metrics =
                      scope?.macOSWindowChromeMetrics ??
                      MacOSWindowChromeMetrics.fallback;
                  final dragHeight = hasIntegratedCorner
                      ? math.min(
                          kWorkspaceHeaderHeight,
                          math.max(0.0, metrics.titlebarDragHeight),
                        )
                      : 0.0;
                  final dragLeft =
                      hasIntegratedCorner &&
                          metrics.trafficLightsVisible &&
                          (scope?.contentLeft ?? 0) <= 0
                      ? metrics.safeInset
                      : 0.0;
                  final controlTop = hasIntegratedCorner
                      ? metrics.shellControlTopInset
                      : kShellControlTopInset;
                  final rowCenterY = controlTop + kShellControlSize / 2;
                  final titleTop = rowCenterY - kWorkspaceHeaderHeight / 2;
                  final leadingInset = math.max(
                    leadingPadding + (scope?.contentLeadingInset ?? 0),
                    scope?.headerLeadingInset ?? leadingPadding,
                  );
                  final rightInset = trailingPadding + trailingWidth + 8;
                  final titlePlacement = _titlePlacement(
                    context: context,
                    width: width,
                    leadingInset: leadingInset,
                    rightInset: rightInset,
                    title: title,
                  );

                  return Stack(
                    children: [
                      if (dragHeight > 0 && dragLeft < width)
                        Positioned(
                          left: dragLeft,
                          top: 0,
                          right: 0,
                          height: dragHeight,
                          child: const WindowDragSurface(
                            key: Key('window_drag_surface'),
                          ),
                        ),
                      if (titlePlacement != null)
                        Positioned(
                          left: titlePlacement.left,
                          top: titleTop,
                          width: titlePlacement.width,
                          height: kWorkspaceHeaderHeight,
                          child: IgnorePointer(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _HeaderTitle(
                                title: title,
                                faded: titlePlacement.faded,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: scheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: trailingPadding,
                        top: controlTop,
                        width: trailingWidth,
                        height: kShellControlSize,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: trailing,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  _TitlePlacement? _titlePlacement({
    required BuildContext context,
    required double width,
    required double leadingInset,
    required double rightInset,
    required String title,
  }) {
    final available = width - leadingInset - rightInset;
    if (available < minVisibleTitleWidth) return null;

    final textWidth = _measureTitle(context, title);
    final centerLeft = (width - textWidth) / 2;
    final centerRight = centerLeft + textWidth;
    final safeRight = width - rightInset;

    if (centerLeft >= leadingInset && centerRight <= safeRight) {
      return _TitlePlacement(
        left: centerLeft,
        width: math.min(textWidth, available),
        faded: false,
      );
    }

    final left = leadingInset;
    final fittedWidth = math.min(textWidth, available);
    if (fittedWidth < minVisibleTitleWidth) return null;
    return _TitlePlacement(
      left: left,
      width: fittedWidth,
      faded: textWidth > available,
    );
  }

  double _measureTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1.2,
        ),
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    return painter.width;
  }
}

class WorkspaceSplitHandle extends StatelessWidget {
  const WorkspaceSplitHandle({
    super.key,
    required this.onDragDelta,
    this.onDragStart,
    this.onDragEnd,
    this.onDragCancel,
    this.color,
    this.showDivider = true,
  });

  final ValueChanged<double> onDragDelta;
  final GestureDragStartCallback? onDragStart;
  final GestureDragEndCallback? onDragEnd;
  final GestureDragCancelCallback? onDragCancel;
  final Color? color;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).fleurSurface;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: onDragStart,
        onHorizontalDragUpdate: (details) => onDragDelta(details.delta.dx),
        onHorizontalDragEnd: onDragEnd,
        onHorizontalDragCancel: onDragCancel,
        child: SizedBox(
          width: kWorkspaceSplitHandleHitWidth,
          child: showDivider
              ? Center(
                  child: SizedBox(
                    width: kSidebarContentDividerWidth,
                    height: double.infinity,
                    child: ColoredBox(color: color ?? surfaces.subtleDivider),
                  ),
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }
}

class WindowDragSurface extends StatelessWidget {
  const WindowDragSurface({super.key});

  @override
  Widget build(BuildContext context) {
    if (isMacOS) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => MacOSWindowChromeBridge.performWindowDrag(),
        onDoubleTap: () => MacOSWindowChromeBridge.performWindowZoom(),
        child: const SizedBox.expand(),
      );
    }

    if (!isWindows && !isLinux) return const SizedBox.expand();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => unawaited(_startDesktopWindowDrag()),
      onDoubleTap: () => unawaited(_toggleDesktopWindowMaximize()),
      child: const SizedBox.expand(),
    );
  }

  static Future<void> _startDesktopWindowDrag() async {
    try {
      await windowManager.startDragging();
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> _toggleDesktopWindowMaximize() async {
    try {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } on MissingPluginException {
      return;
    }
  }
}

class WorkspacePageHeader extends StatelessWidget {
  const WorkspacePageHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.backgroundColor,
  });

  final String title;
  final VoidCallback onBack;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scope = ShellLayerScope.maybeOf(context);
        final shellChromeLayout =
            scope?.shellChromeLayout ?? ShellChromeLayout.resolve();
        final hasIntegratedCorner =
            shellChromeLayout.profile == ShellChromeProfile.integratedCorner;
        final hasTitleBarDrag =
            shellChromeLayout.profile == ShellChromeProfile.titleBarExpected;
        final metrics =
            scope?.macOSWindowChromeMetrics ??
            MacOSWindowChromeMetrics.fallback;
        final avoidTrafficLights =
            hasIntegratedCorner && metrics.trafficLightsVisible;
        final leadingLeft = avoidTrafficLights ? metrics.safeInset : 8.0;
        final controlTop = hasIntegratedCorner
            ? metrics.shellControlTopInset
            : kShellControlTopInset;
        final captionInset = shellChromeLayout.placesControlsInTitleBar
            ? kShellWindowCaptionControlsWidth
            : 0.0;
        final minTitleWidth = title.isEmpty ? 0.0 : 96.0;
        final needsSecondRow =
            avoidTrafficLights &&
            constraints.maxWidth <
                leadingLeft + kShellControlSize + 12 + minTitleWidth;
        final rowTop = needsSecondRow
            ? kWorkspaceHeaderHeight + controlTop
            : controlTop;
        final rowLeft = needsSecondRow ? 8.0 : leadingLeft;
        final height = needsSecondRow
            ? kWorkspaceHeaderHeight * 2
            : kWorkspaceHeaderHeight;
        final theme = Theme.of(context);

        return ColoredBox(
          key: const Key('workspace_page_header'),
          color: backgroundColor ?? theme.fleurSurface.list,
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                if (hasIntegratedCorner || hasTitleBarDrag)
                  Positioned(
                    left: avoidTrafficLights ? metrics.safeInset : 0,
                    top: 0,
                    right: 0,
                    height: hasIntegratedCorner
                        ? math.min(
                            height,
                            math.max(0.0, metrics.titlebarDragHeight),
                          )
                        : kWorkspaceHeaderHeight,
                    child: const WindowDragSurface(
                      key: Key('window_page_drag_surface'),
                    ),
                  ),
                Positioned(
                  left: rowLeft,
                  top: rowTop,
                  width: kShellControlSize,
                  height: kShellControlSize,
                  child: IconButton(
                    key: const Key('workspace_page_back_button'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    icon: const Icon(FleurIcons.back),
                    onPressed: onBack,
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(kShellControlSize),
                      minimumSize: const Size.square(kShellControlSize),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                if (title.isNotEmpty)
                  Positioned(
                    left: rowLeft + kShellControlSize + 8,
                    top: needsSecondRow ? kWorkspaceHeaderHeight : 0,
                    right: 12 + captionInset,
                    height: kWorkspaceHeaderHeight,
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class WorkspaceHeaderSurface extends StatelessWidget {
  const WorkspaceHeaderSurface({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.fleurSurface.list;
    final topAlpha = theme.brightness == Brightness.dark ? 0.52 : 0.62;

    return IgnorePointer(
      key: const ValueKey('article-list-top-fade'),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.transparent],
        ).createShader(bounds),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 0, sigmaY: 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surface.withValues(alpha: topAlpha),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({
    required this.title,
    required this.faded,
    required this.style,
  });

  final String title;
  final bool faded;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      title,
      key: const Key('workspace_header_title'),
      maxLines: 1,
      overflow: TextOverflow.clip,
      softWrap: false,
      style: style,
    );

    if (!faded) return text;

    return ShaderMask(
      key: const Key('workspace_header_title_fade'),
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0, 0.78, 1],
      ).createShader(bounds),
      child: text,
    );
  }
}

class _TitlePlacement {
  const _TitlePlacement({
    required this.left,
    required this.width,
    required this.faded,
  });

  final double left;
  final double width;
  final bool faded;
}
