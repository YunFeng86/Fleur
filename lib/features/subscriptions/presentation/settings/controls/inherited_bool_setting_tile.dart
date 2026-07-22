import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/fleur_icons.dart';
import '../../../../../ui/design_system/design_system.dart';
import '../../../../../ui/settings/widgets/settings_controls.dart';

class InheritedBoolSettingTile extends StatefulWidget {
  const InheritedBoolSettingTile({
    super.key,
    required this.title,
    required this.currentValue,
    required this.effectiveValue,
    required this.isGlobal,
    required this.onChanged,
  });

  final String title;
  final bool? currentValue;
  final bool effectiveValue;
  final bool isGlobal;
  final ValueChanged<bool?> onChanged;

  @override
  State<InheritedBoolSettingTile> createState() =>
      _InheritedBoolSettingTileState();
}

enum _InheritedBoolAction { auto, on, off }

class _InheritedBoolSettingTileState extends State<InheritedBoolSettingTile> {
  _InheritedBoolAction _actionForValue(bool? value) {
    if (value == null) return _InheritedBoolAction.auto;
    return value ? _InheritedBoolAction.on : _InheritedBoolAction.off;
  }

  bool? _valueForAction(_InheritedBoolAction action) {
    return switch (action) {
      _InheritedBoolAction.auto => null,
      _InheritedBoolAction.on => true,
      _InheritedBoolAction.off => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.isGlobal) {
      return SettingsSwitchTile(
        title: Text(widget.title),
        value: widget.currentValue ?? widget.effectiveValue,
        onChanged: widget.onChanged,
      );
    }

    final isSpecific = widget.currentValue != null;
    final isOn = isSpecific ? widget.currentValue! : widget.effectiveValue;
    final stateColor = isOn ? colorScheme.primary : colorScheme.error;
    final stateText = isOn ? l10n.enabled : l10n.off;
    final suffixText = isSpecific ? '' : '  ${l10n.defaultValue}';

    return SettingsTile(
      title: Text(widget.title),
      subtitle: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: stateText,
              style: TextStyle(color: stateColor, fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: suffixText,
              style: TextStyle(color: colorScheme.outline),
            ),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSpecific)
            IconButton(
              icon: const Icon(FleurIcons.inherit),
              tooltip: l10n.inherit,
              onPressed: () => widget.onChanged(null),
            ),
          SizedBox(
            width: 168,
            child: FleurSelectField<_InheritedBoolAction>(
              value: _actionForValue(widget.currentValue),
              options: [
                FleurSelectOption(
                  value: _InheritedBoolAction.auto,
                  label: Text(
                    '${l10n.auto} (${widget.effectiveValue ? l10n.autoOn : l10n.autoOff})',
                  ),
                ),
                FleurSelectOption(
                  value: _InheritedBoolAction.on,
                  label: Text(l10n.enabled),
                ),
                FleurSelectOption(
                  value: _InheritedBoolAction.off,
                  label: Text(l10n.off),
                ),
              ],
              onChanged: (action) => widget.onChanged(_valueForAction(action)),
            ),
          ),
        ],
      ),
    );
  }
}
