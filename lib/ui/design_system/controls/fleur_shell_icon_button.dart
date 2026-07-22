import 'package:flutter/material.dart';

import '../../../theme/fleur_theme_extensions.dart';
import '../../motion.dart';

class FleurShellIconButton extends StatefulWidget {
  const FleurShellIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.selected = false,
    this.size = 32,
    this.iconSize,
    this.focusNode,
    this.disabledOpacity = 0.38,
    this.borderRadius,
    this.selectedBackgroundColor,
    this.selectedForegroundColor,
    this.unselectedForegroundColor,
    this.adaptiveTapTarget = false,
    this.interactionMode,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget icon;
  final bool selected;
  final double size;
  final double? iconSize;
  final FocusNode? focusNode;
  final double disabledOpacity;
  final BorderRadius? borderRadius;
  final Color? selectedBackgroundColor;
  final Color? selectedForegroundColor;
  final Color? unselectedForegroundColor;
  final bool adaptiveTapTarget;
  final FocusHighlightMode? interactionMode;

  @override
  State<FleurShellIconButton> createState() => _FleurShellIconButtonState();
}

class _FleurShellIconButtonState extends State<FleurShellIconButton> {
  late FocusHighlightMode _interactionMode;

  @override
  void initState() {
    super.initState();
    _interactionMode = FocusManager.instance.highlightMode;
    FocusManager.instance.addHighlightModeListener(_handleInteractionMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleInteractionMode);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.tooltip,
      button: true,
      enabled: widget.onPressed != null,
      selected: widget.selected ? true : null,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: IconButton(
        focusNode: widget.focusNode,
        tooltip: widget.tooltip,
        onPressed: widget.onPressed,
        icon: widget.icon,
        iconSize: widget.iconSize,
        style: FleurShellIconButtonStyle.styleFor(
          context,
          selected: widget.selected,
          size: widget.size,
          disabledOpacity: widget.disabledOpacity,
          borderRadius: widget.borderRadius,
          selectedBackgroundColor: widget.selectedBackgroundColor,
          selectedForegroundColor: widget.selectedForegroundColor,
          unselectedForegroundColor: widget.unselectedForegroundColor,
          adaptiveTapTarget: widget.adaptiveTapTarget,
          interactionMode: widget.interactionMode ?? _interactionMode,
        ),
      ),
    );
  }

  void _handleInteractionMode(FocusHighlightMode value) {
    if (_interactionMode == value) return;
    setState(() => _interactionMode = value);
  }
}

class FleurShellIconButtonStyle {
  const FleurShellIconButtonStyle._();

  static ButtonStyle styleFor(
    BuildContext context, {
    bool selected = false,
    double size = 32,
    double disabledOpacity = 0.38,
    BorderRadius? borderRadius,
    Color? selectedBackgroundColor,
    Color? selectedForegroundColor,
    Color? unselectedForegroundColor,
    bool adaptiveTapTarget = false,
    FocusHighlightMode? interactionMode,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final states = theme.fleurState;
    final radius = borderRadius ?? BorderRadius.circular(size / 2);
    final touchMode =
        adaptiveTapTarget &&
        (interactionMode ?? FocusManager.instance.highlightMode) ==
            FocusHighlightMode.touch;

    return ButtonStyle(
      fixedSize: WidgetStatePropertyAll(Size.square(size)),
      minimumSize: WidgetStatePropertyAll(Size.square(size)),
      maximumSize: WidgetStatePropertyAll(Size.square(size)),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      tapTargetSize: touchMode
          ? MaterialTapTargetSize.padded
          : MaterialTapTargetSize.shrinkWrap,
      visualDensity: touchMode ? VisualDensity.standard : VisualDensity.compact,
      animationDuration: AppMotion.effectiveDuration(
        context,
        AppMotion.selectionTransitionDuration,
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: radius),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((stateSet) {
        if (stateSet.contains(WidgetState.disabled)) {
          return Colors.transparent;
        }
        return selected
            ? selectedBackgroundColor ?? states.selectionTint
            : Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((stateSet) {
        if (stateSet.contains(WidgetState.disabled)) {
          return scheme.onSurface.withValues(alpha: disabledOpacity);
        }
        return selected
            ? selectedForegroundColor ?? scheme.primary
            : unselectedForegroundColor ?? scheme.onSurfaceVariant;
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

  static double tapTargetExtent({
    double size = 32,
    bool adaptiveTapTarget = false,
    FocusHighlightMode? interactionMode,
  }) {
    final touchMode =
        adaptiveTapTarget &&
        (interactionMode ?? FocusManager.instance.highlightMode) ==
            FocusHighlightMode.touch;
    return touchMode && size < 48 ? 48 : size;
  }
}
