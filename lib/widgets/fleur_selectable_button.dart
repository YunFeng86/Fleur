import 'package:flutter/material.dart';

import '../theme/fleur_theme_extensions.dart';
import '../ui/motion.dart';

/// A menu-like button whose interaction and persistent selection states are
/// resolved by one [ButtonStyle].
class FleurSelectableButton extends StatelessWidget {
  const FleurSelectableButton({
    super.key,
    required this.selected,
    required this.onPressed,
    required this.child,
    this.minimumHeight = 40,
    this.padding = EdgeInsets.zero,
    this.alignment = Alignment.center,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.selectedBackgroundColor,
    this.unselectedBackgroundColor = Colors.transparent,
    this.selectedForegroundColor,
    this.unselectedForegroundColor,
    this.selectedSide = BorderSide.none,
    this.unselectedSide = BorderSide.none,
    this.focusNode,
    this.autofocus = false,
  });

  final bool selected;
  final VoidCallback? onPressed;
  final Widget child;
  final double minimumHeight;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;
  final BorderRadiusGeometry borderRadius;
  final Color? selectedBackgroundColor;
  final Color unselectedBackgroundColor;
  final Color? selectedForegroundColor;
  final Color? unselectedForegroundColor;
  final BorderSide selectedSide;
  final BorderSide unselectedSide;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final states = theme.fleurState;
    final baseBackground = selected
        ? selectedBackgroundColor ?? states.selectionTint
        : unselectedBackgroundColor;
    final foreground = selected
        ? selectedForegroundColor ?? theme.colorScheme.primary
        : unselectedForegroundColor ?? theme.colorScheme.onSurfaceVariant;

    Color backgroundFor(Set<WidgetState> stateSet) {
      if (stateSet.contains(WidgetState.pressed)) {
        return Color.alphaBlend(states.pressedTint, baseBackground);
      }
      if (stateSet.contains(WidgetState.hovered)) {
        return Color.alphaBlend(states.hoverTint, baseBackground);
      }
      if (stateSet.contains(WidgetState.focused)) {
        return Color.alphaBlend(states.focusRing.withAlpha(32), baseBackground);
      }
      return baseBackground;
    }

    return TextButton(
      onPressed: onPressed,
      focusNode: focusNode,
      autofocus: autofocus,
      style: ButtonStyle(
        animationDuration: AppMotion.effectiveDuration(
          context,
          AppMotion.selectionTransitionDuration,
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        backgroundColor: WidgetStateProperty.resolveWith(backgroundFor),
        foregroundColor: WidgetStatePropertyAll(foreground),
        minimumSize: WidgetStatePropertyAll(Size(0, minimumHeight)),
        padding: WidgetStatePropertyAll(padding),
        alignment: alignment,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        side: WidgetStatePropertyAll(selected ? selectedSide : unselectedSide),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      child: child,
    );
  }
}
