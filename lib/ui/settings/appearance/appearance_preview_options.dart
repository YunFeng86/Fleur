import 'package:flutter/material.dart';

import '../../../theme/fleur_icons.dart';
import '../../../theme/fleur_theme_extensions.dart';
import '../../design_system/design_system.dart';

class AppearancePreviewOption<T> {
  const AppearancePreviewOption({
    required this.value,
    required this.semanticLabel,
    required this.child,
    this.key,
    this.width,
    this.minHeight = 64,
  });

  final Key? key;
  final T value;
  final String semanticLabel;
  final Widget child;
  final double? width;
  final double minHeight;
}

class AppearancePreviewOptionGroup<T> extends StatelessWidget {
  const AppearancePreviewOptionGroup({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<AppearancePreviewOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          for (final option in options)
            _AppearancePreviewOptionButton<T>(
              key: option.key,
              option: option,
              selected: option.value == value,
              onTap: () => onChanged(option.value),
            ),
        ],
      ),
    );
  }
}

class _AppearancePreviewOptionButton<T> extends StatelessWidget {
  const _AppearancePreviewOptionButton({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppearancePreviewOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final states = theme.fleurState;
    final surfaces = theme.fleurSurface;

    return Semantics(
      button: true,
      selected: selected,
      label: option.semanticLabel,
      child: SizedBox(
        width: option.width,
        child: FleurSelectableButton(
          selected: selected,
          onPressed: onTap,
          minimumHeight: option.minHeight,
          borderRadius: BorderRadius.circular(8),
          selectedBackgroundColor: states.selectionTint,
          unselectedBackgroundColor: surfaces.card,
          selectedForegroundColor: scheme.primary,
          unselectedForegroundColor: scheme.onSurfaceVariant,
          selectedSide: BorderSide(color: scheme.primary, width: 1.6),
          unselectedSide: BorderSide(color: surfaces.subtleDivider),
          child: SizedBox(
            width: double.infinity,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: DefaultTextStyle.merge(
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                    child: option.child,
                  ),
                ),
                if (selected)
                  const PositionedDirectional(
                    top: 5,
                    end: 5,
                    child: Icon(FleurIcons.check, size: 14),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
