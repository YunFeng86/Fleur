import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/fleur_theme_extensions.dart';
import 'sidebar_layout.dart';

const BorderRadius kWorkspaceLayerRadius = BorderRadius.only(
  topLeft: Radius.circular(16),
  bottomLeft: Radius.circular(16),
);

class ShellLayerScope extends InheritedWidget {
  const ShellLayerScope({
    super.key,
    required this.totalSize,
    required this.contentSize,
    required this.sidebarLayoutMode,
    required this.contentLeft,
    required this.headerLeadingInset,
    required this.macOSWindowChromeMetrics,
    required super.child,
  });

  final Size totalSize;
  final Size contentSize;
  final SidebarLayoutMode sidebarLayoutMode;
  final double contentLeft;
  final double headerLeadingInset;
  final MacOSWindowChromeMetrics macOSWindowChromeMetrics;

  static ShellLayerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellLayerScope>();
  }

  @override
  bool updateShouldNotify(ShellLayerScope oldWidget) {
    return totalSize != oldWidget.totalSize ||
        contentSize != oldWidget.contentSize ||
        sidebarLayoutMode != oldWidget.sidebarLayoutMode ||
        contentLeft != oldWidget.contentLeft ||
        headerLeadingInset != oldWidget.headerLeadingInset ||
        macOSWindowChromeMetrics != oldWidget.macOSWindowChromeMetrics;
  }
}

class WorkspaceLayerSurface extends StatelessWidget {
  const WorkspaceLayerSurface({
    super.key,
    required this.child,
    this.color,
    this.borderRadius = kWorkspaceLayerRadius,
    this.showShadow = true,
  });

  final Widget child;
  final Color? color;
  final BorderRadius borderRadius;
  final bool showShadow;

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
        child: ColoredBox(color: color ?? surfaces.list, child: child),
      ),
    );
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
                  final leadingInset = math.max(
                    leadingPadding,
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
                      if (titlePlacement != null)
                        Positioned(
                          left: titlePlacement.left,
                          top: 0,
                          width: titlePlacement.width,
                          height: kWorkspaceHeaderHeight,
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
                      Positioned(
                        right: trailingPadding,
                        top: (kWorkspaceHeaderHeight - kShellControlSize) / 2,
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
