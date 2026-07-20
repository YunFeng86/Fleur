import 'package:flutter/material.dart';

import '../ui/motion.dart';

typedef FleurSelectionTransitionBuilder =
    Widget Function(BuildContext context, double selection, Widget? child);

/// Converts a boolean selection state into one shared animation progress.
///
/// Components keep ownership of their colors and geometry while using the same
/// progress for every visual property that represents selection.
class FleurSelectionTransition extends StatelessWidget {
  const FleurSelectionTransition({
    super.key,
    required this.selected,
    required this.builder,
    this.child,
  });

  final bool selected;
  final FleurSelectionTransitionBuilder builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: selected ? 1 : 0),
      duration: AppMotion.effectiveDuration(
        context,
        AppMotion.selectionTransitionDuration,
      ),
      curve: AppMotion.selectionTransitionCurve,
      builder: builder,
      child: child,
    );
  }
}

/// Cross-fades icon glyph changes without changing the button's dimensions.
class FleurAnimatedIcon extends StatelessWidget {
  const FleurAnimatedIcon({
    super.key,
    required this.icon,
    this.size,
    this.color,
  });

  final IconData icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.effectiveDuration(
        context,
        AppMotion.selectionTransitionDuration,
      ),
      switchInCurve: AppMotion.selectionTransitionCurve,
      switchOutCurve: AppMotion.selectionTransitionCurve,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: [...previousChildren, ?currentChild],
        );
      },
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Icon(
        icon,
        key: ValueKey<IconData>(icon),
        size: size,
        color: color,
      ),
    );
  }
}
