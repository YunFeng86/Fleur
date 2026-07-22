import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

typedef SettingsSelectOption<T> = FleurSelectOption<T>;

class SettingsSelectField<T> extends FleurSelectField<T> {
  const SettingsSelectField({
    super.key,
    required super.value,
    required super.options,
    required super.onChanged,
    super.hint,
  });
}

class SettingsSliderControl extends StatelessWidget {
  const SettingsSliderControl({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.format,
    this.minLabel,
    this.maxLabel,
    this.valueLabel,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final String Function(double value) format;
  final String? minLabel;
  final String? maxLabel;
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sliderTheme = SliderTheme.of(context).copyWith(
      trackHeight: 2.5,
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.primary.withValues(alpha: 0.18),
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.14),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
    );
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (valueLabel != null) ...[
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(valueLabel!, style: labelStyle),
          ),
          const SizedBox(height: 2),
        ],
        SizedBox(
          height: 28,
          child: SliderTheme(
            data: sliderTheme,
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              Text(minLabel ?? format(min), style: labelStyle),
              const Spacer(),
              Text(maxLabel ?? format(max), style: labelStyle),
            ],
          ),
        ),
      ],
    );
  }
}
