import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/ui/design_system/design_system.dart';

void main() {
  test('facade exposes the shared selection controls', () {
    const option = FleurSelectOption<int>(value: 1, label: Text('One'));
    const FleurSelectField<int> field = FleurSelectField<int>(
      value: 1,
      options: [option],
      onChanged: null,
    );
    const FleurSelectableButton button = FleurSelectableButton(
      selected: false,
      onPressed: null,
      child: Text('Option'),
    );

    expect(option, isA<FleurSelectOption<int>>());
    expect(field, isA<FleurSelectField<int>>());
    expect(button, isA<FleurSelectableButton>());
    expect(kFleurSelectFieldHeight, isPositive);
    expect(kFleurSelectItemHeight, isPositive);
    expect(kFleurSelectMenuMaxHeight, isPositive);
  });
}
