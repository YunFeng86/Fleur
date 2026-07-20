import 'package:flutter/material.dart';

import '../theme/fleur_theme_extensions.dart';
import 'fleur_shell_icon_button.dart';
import 'fleur_selection_transition.dart';

class FleurCapsuleButtonGroup extends StatelessWidget {
  const FleurCapsuleButtonGroup({
    super.key,
    required this.children,
    this.height = 32,
    this.elevation = 1,
    this.padding = const EdgeInsets.symmetric(horizontal: 1),
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
    this.size = 32,
    this.iconSize = 16,
    this.focusNode,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;
  final double size;
  final double iconSize;
  final FocusNode? focusNode;

  static ButtonStyle styleFor(
    BuildContext context, {
    bool selected = false,
    double size = 32,
  }) {
    return FleurShellIconButtonStyle.styleFor(
      context,
      selected: selected,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      focusNode: focusNode,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: FleurAnimatedIcon(icon: icon, size: iconSize),
      iconSize: iconSize,
      style: styleFor(context, selected: selected, size: size),
    );
  }
}
