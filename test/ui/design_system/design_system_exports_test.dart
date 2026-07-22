import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/ui/design_system/design_system.dart';
import 'package:fleur/widgets/fleur_select_field.dart' as legacy_select;
import 'package:fleur/widgets/fleur_selectable_button.dart' as legacy_button;

void main() {
  test('facade and legacy shims expose the shared selection controls', () {
    const option = legacy_select.FleurSelectOption<int>(
      value: 1,
      label: Text('One'),
    );
    const FleurSelectField<int> field = legacy_select.FleurSelectField<int>(
      value: 1,
      options: [option],
      onChanged: null,
    );
    const FleurSelectableButton button = legacy_button.FleurSelectableButton(
      selected: false,
      onPressed: null,
      child: Text('Option'),
    );

    expect(option, isA<FleurSelectOption<int>>());
    expect(field, isA<FleurSelectField<int>>());
    expect(button, isA<FleurSelectableButton>());
    expect(legacy_select.kFleurSelectFieldHeight, kFleurSelectFieldHeight);
    expect(legacy_select.kFleurSelectItemHeight, kFleurSelectItemHeight);
    expect(legacy_select.kFleurSelectMenuMaxHeight, kFleurSelectMenuMaxHeight);
  });
}
