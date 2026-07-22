import 'package:flutter/material.dart';

import 'settings_controls.dart';

class SliderTile extends StatelessWidget {
  const SliderTile({
    super.key,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.format,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String Function(double v) format;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SettingsControlRow(
      padding: padding,
      title: Text(title),
      controlWidth: 280,
      control: SettingsSliderControl(
        value: value,
        min: min,
        max: max,
        onChanged: onChanged,
        format: format,
      ),
    );
  }
}
