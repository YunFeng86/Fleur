import 'package:flutter/material.dart';

import '../theme/fleur_theme_extensions.dart';

class FleurCapsuleButtonGroup extends StatelessWidget {
  const FleurCapsuleButtonGroup({
    super.key,
    required this.children,
    this.height = 40,
    this.elevation = 2,
    this.padding = const EdgeInsets.symmetric(horizontal: 2),
  });

  final List<Widget> children;
  final double height;
  final double elevation;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;
    final shadowColor = theme.shadowColor.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.22 : 0.10,
    );

    return Material(
      elevation: elevation,
      shadowColor: shadowColor,
      color: surfaces.floating,
      shape: StadiumBorder(side: BorderSide(color: surfaces.subtleDivider)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: padding,
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class FleurCapsuleIconButton extends StatelessWidget {
  const FleurCapsuleIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.size = 36,
    this.iconSize = 18,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;
  final double size;
  final double iconSize;

  static ButtonStyle styleFor(
    BuildContext context, {
    bool selected = false,
    double size = 36,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final states = theme.fleurState;
    final radius = BorderRadius.circular(size / 2);

    return ButtonStyle(
      fixedSize: WidgetStatePropertyAll(Size.square(size)),
      minimumSize: WidgetStatePropertyAll(Size.square(size)),
      maximumSize: WidgetStatePropertyAll(Size.square(size)),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: radius),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((stateSet) {
        if (stateSet.contains(WidgetState.disabled)) {
          return Colors.transparent;
        }
        return selected ? states.selectionTint : Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((stateSet) {
        if (stateSet.contains(WidgetState.disabled)) {
          return scheme.onSurface.withValues(alpha: 0.38);
        }
        return selected ? scheme.primary : scheme.onSurfaceVariant;
      }),
      overlayColor: WidgetStateProperty.resolveWith((stateSet) {
        if (stateSet.contains(WidgetState.pressed)) return states.pressedTint;
        if (stateSet.contains(WidgetState.hovered) ||
            stateSet.contains(WidgetState.focused)) {
          return states.hoverTint;
        }
        return null;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: iconSize,
      style: styleFor(context, selected: selected, size: size),
    );
  }
}
