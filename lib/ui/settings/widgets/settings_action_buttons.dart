import 'package:flutter/material.dart';

import '../../../theme/fleur_theme_extensions.dart';

enum SettingsActionButtonVariant { outline, filled, text }

class SettingsActionButton extends StatelessWidget {
  const SettingsActionButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.variant = SettingsActionButtonVariant.outline,
  });

  final VoidCallback? onPressed;
  final Widget label;
  final Widget? icon;
  final SettingsActionButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final states = theme.fleurState;
    final surfaces = theme.fleurSurface;
    final enabled = onPressed != null;
    final foreground = switch (variant) {
      SettingsActionButtonVariant.filled => scheme.onPrimary,
      SettingsActionButtonVariant.outline ||
      SettingsActionButtonVariant.text => scheme.primary,
    };
    final background = switch (variant) {
      SettingsActionButtonVariant.filled => scheme.primary,
      SettingsActionButtonVariant.outline ||
      SettingsActionButtonVariant.text => Colors.transparent,
    };
    final border = variant == SettingsActionButtonVariant.outline
        ? Border.all(color: surfaces.subtleDivider)
        : null;
    final content = IconTheme.merge(
      data: IconThemeData(
        size: 16,
        color: enabled ? foreground : scheme.onSurface.withValues(alpha: 0.38),
      ),
      child: DefaultTextStyle.merge(
        style: theme.textTheme.labelMedium?.copyWith(
          color: enabled
              ? foreground
              : scheme.onSurface.withValues(alpha: 0.38),
          fontWeight: FontWeight.w600,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 6)],
            Flexible(child: label),
          ],
        ),
      ),
    );

    return Material(
      color: enabled ? background : surfaces.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: border?.top ?? BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        hoverColor: states.hoverTint,
        splashColor: states.pressedTint,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(widthFactor: 1, child: content),
          ),
        ),
      ),
    );
  }
}

class SettingsIconActionButton extends StatelessWidget {
  const SettingsIconActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final states = theme.fleurState;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      style: ButtonStyle(
        fixedSize: const WidgetStatePropertyAll(Size.square(32)),
        minimumSize: const WidgetStatePropertyAll(Size.square(32)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        overlayColor: WidgetStateProperty.resolveWith((stateSet) {
          if (stateSet.contains(WidgetState.pressed)) return states.pressedTint;
          if (stateSet.contains(WidgetState.hovered) ||
              stateSet.contains(WidgetState.focused)) {
            return states.hoverTint;
          }
          return null;
        }),
      ),
    );
  }
}
