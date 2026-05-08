import 'package:flutter/material.dart';

import '../utils/platform.dart';

const Set<TargetPlatform> _kScrollbarAutoInheritPlatforms = <TargetPlatform>{
  TargetPlatform.android,
  TargetPlatform.iOS,
  TargetPlatform.fuchsia,
  TargetPlatform.linux,
  TargetPlatform.macOS,
  TargetPlatform.windows,
};

class AppScrollbar extends StatefulWidget {
  const AppScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.thumbVisibility,
    this.interactive,
  });

  final Widget child;
  final ScrollController? controller;
  final bool? thumbVisibility;
  final bool? interactive;

  @override
  State<AppScrollbar> createState() => _AppScrollbarState();
}

class _AppScrollbarState extends State<AppScrollbar> {
  bool _regionHovered = false;
  ScrollController? _localPrimaryController;

  ScrollController get _resolvedLocalPrimaryController =>
      _localPrimaryController ??= ScrollController();

  ScrollView? get _directChildScrollView =>
      widget.child is ScrollView ? widget.child as ScrollView : null;

  @override
  void dispose() {
    _localPrimaryController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final baseScrollbarTheme = theme.scrollbarTheme;
    final directChildScrollView = _directChildScrollView;
    final directChildController = directChildScrollView?.controller;
    final canUseLocalPrimaryController =
        isDesktop &&
        widget.controller == null &&
        directChildController == null &&
        directChildScrollView != null &&
        directChildScrollView.primary != false;
    final effectiveController =
        widget.controller ??
        directChildController ??
        (canUseLocalPrimaryController ? _resolvedLocalPrimaryController : null);
    final hasReliableDesktopBinding = !isDesktop || effectiveController != null;
    final effectiveThumbVisibility = hasReliableDesktopBinding
        ? widget.thumbVisibility
        : false;
    final effectiveInteractive = hasReliableDesktopBinding
        ? widget.interactive
        : false;

    Widget scrollableChild = widget.child;
    if (canUseLocalPrimaryController) {
      scrollableChild = PrimaryScrollController(
        controller: _resolvedLocalPrimaryController,
        automaticallyInheritForPlatforms: _kScrollbarAutoInheritPlatforms,
        scrollDirection: directChildScrollView.scrollDirection,
        child: scrollableChild,
      );
    }
    scrollableChild = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: scrollableChild,
    );

    Widget buildScrollbar() {
      return Scrollbar(
        controller: effectiveController,
        thumbVisibility: effectiveThumbVisibility,
        interactive: effectiveInteractive,
        child: scrollableChild,
      );
    }

    if (!isDesktop) return buildScrollbar();

    final idleThumbColor = scheme.outlineVariant.withAlpha(72);
    final regionThumbColor = scheme.onSurfaceVariant.withAlpha(88);
    final thumbHoverColor = scheme.onSurfaceVariant.withAlpha(112);
    final thumbDragColor = scheme.primary.withAlpha(148);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: _regionHovered ? 1 : 0),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      builder: (context, regionHoverT, child) {
        final animatedIdleColor = Color.lerp(
          idleThumbColor,
          regionThumbColor,
          regionHoverT,
        )!;
        final scrollbarTheme = baseScrollbarTheme.copyWith(
          thickness: WidgetStatePropertyAll(
            baseScrollbarTheme.thickness?.resolve(<WidgetState>{}) ?? 6,
          ),
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.dragged)) {
              return thumbDragColor;
            }
            if (states.contains(WidgetState.hovered)) {
              return Color.lerp(animatedIdleColor, thumbHoverColor, 0.9)!;
            }
            return animatedIdleColor;
          }),
        );

        return ScrollbarTheme(
          data: scrollbarTheme,
          child: MouseRegion(
            opaque: false,
            onEnter: (_) => setState(() => _regionHovered = true),
            onExit: (_) => setState(() => _regionHovered = false),
            child: child,
          ),
        );
      },
      child: buildScrollbar(),
    );
  }
}
