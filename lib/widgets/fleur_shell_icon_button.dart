import 'package:flutter/material.dart';

import '../theme/fleur_theme_extensions.dart';

class FleurShellIconButtonStyle {
  const FleurShellIconButtonStyle._();

  static ButtonStyle styleFor(
    BuildContext context, {
    bool selected = false,
    double size = 32,
    double disabledOpacity = 0.38,
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
          return scheme.onSurface.withValues(alpha: disabledOpacity);
        }
        return selected ? scheme.primary : scheme.onSurfaceVariant;
      }),
      overlayColor: WidgetStateProperty.resolveWith((stateSet) {
        if (stateSet.contains(WidgetState.disabled)) {
          return Colors.transparent;
        }
        if (stateSet.contains(WidgetState.pressed)) return states.pressedTint;
        if (stateSet.contains(WidgetState.hovered) ||
            stateSet.contains(WidgetState.focused)) {
          return states.hoverTint;
        }
        return null;
      }),
    );
  }
}
