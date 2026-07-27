import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/theme/fleur_icons.dart';
import 'package:fleur/theme/fleur_theme_extensions.dart';
import 'package:fleur/ui/design_system/controls/fleur_select_field.dart';
import 'package:fleur/ui/settings/widgets/section_header.dart' as legacy;
import 'package:fleur/ui/settings/widgets/settings_controls.dart';
import 'package:fleur/ui/settings/widgets/slider_tile.dart';

Future<void> _pumpControl(
  WidgetTester tester, {
  required Widget child,
  Size size = const Size(900, 600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('settings facade preserves the legacy section-header export', () {
    expect(const legacy.SectionHeader(title: 'Legacy'), isA<SectionHeader>());
    expect(
      const legacy.SettingsCompactSwitch(value: false, onChanged: null),
      isA<SettingsCompactSwitch>(),
    );
  });

  testWidgets('Fleur menu theme keeps popover height content-sized', (
    tester,
  ) async {
    await _pumpControl(tester, child: const SizedBox.shrink());

    final theme = Theme.of(tester.element(find.byType(Scaffold)));
    final minimumSize = theme.menuTheme.style?.minimumSize?.resolve({});

    expect(minimumSize?.width, 156);
    expect(minimumSize?.height, 0);
    expect(minimumSize?.height.isFinite, isTrue);
  });

  testWidgets('SettingsControlRow aligns control to the right on wide widths', (
    tester,
  ) async {
    await _pumpControl(
      tester,
      child: const SizedBox(
        width: 760,
        child: SettingsControlRow(
          title: Text('Control title', key: Key('control_title')),
          control: SizedBox(
            key: Key('control_box'),
            height: 48,
            child: ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    );

    final titleRight = tester
        .getTopRight(find.byKey(const Key('control_title')))
        .dx;
    final controlLeft = tester
        .getTopLeft(find.byKey(const Key('control_box')))
        .dx;
    final controlSize = tester.getSize(find.byKey(const Key('control_box')));

    expect(controlLeft, greaterThan(titleRight));
    expect(controlSize.width, lessThanOrEqualTo(320));
  });

  testWidgets(
    'SettingsControlRow stacks control below title on narrow widths',
    (tester) async {
      await _pumpControl(
        tester,
        size: const Size(360, 600),
        child: const SizedBox(
          width: 320,
          child: SettingsControlRow(
            key: Key('control_row'),
            title: Text('Control title', key: Key('control_title')),
            control: SizedBox(
              key: Key('control_box'),
              height: 48,
              child: ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      );

      final titleBottom = tester
          .getBottomLeft(find.byKey(const Key('control_title')))
          .dy;
      final controlTop = tester
          .getTopLeft(find.byKey(const Key('control_box')))
          .dy;
      final controlSize = tester.getSize(find.byKey(const Key('control_box')));
      final rowSize = tester.getSize(find.byKey(const Key('control_row')));

      expect(controlTop, greaterThan(titleBottom));
      expect(controlSize.width, rowSize.width - 32);
    },
  );

  testWidgets('SettingsSelectField opens menu and selects a value', (
    tester,
  ) async {
    var selected = 1;

    await _pumpControl(
      tester,
      child: StatefulBuilder(
        builder: (context, setState) {
          return SizedBox(
            width: 360,
            child: SettingsSelectField<int>(
              key: const Key('settings_select'),
              value: selected,
              options: const [
                SettingsSelectOption(value: 1, label: Text('One')),
                SettingsSelectOption(value: 2, label: Text('Two')),
              ],
              onChanged: (value) => setState(() => selected = value),
            ),
          );
        },
      ),
    );

    await tester.tap(find.byKey(const Key('settings_select')));
    await tester.pumpAndSettle();
    expect(find.byIcon(FleurIcons.check), findsOneWidget);
    await tester.tap(find.text('Two').last);
    await tester.pumpAndSettle();

    expect(selected, 2);
    expect(tester.getSize(find.byKey(const Key('settings_select'))).height, 36);
    expect(find.text('Two'), findsOneWidget);
  });

  testWidgets('FleurSelectField shows scrollbar for padding-only overflow', (
    tester,
  ) async {
    await _pumpControl(
      tester,
      child: SizedBox(
        width: 360,
        child: FleurSelectField<int>(
          key: const Key('boundary_select'),
          value: 1,
          options: const [
            FleurSelectOption(value: 1, label: Text('One')),
            FleurSelectOption(value: 2, label: Text('Two')),
          ],
          onChanged: (_) {},
          itemHeight: 36,
          menuMaxHeight: 76,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('boundary_select')));
    await tester.pumpAndSettle();

    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(Scrollbar),
        matching: find.byType(Scrollable),
      ),
    );

    expect(scrollbar.thumbVisibility, isTrue);
    expect(scrollable.position.maxScrollExtent, 4);
  });

  testWidgets('SliderTile drag reports changed value', (tester) async {
    var latest = 16.0;

    await _pumpControl(
      tester,
      child: SizedBox(
        width: 760,
        child: SliderTile(
          title: 'Font size',
          value: latest,
          min: 12,
          max: 28,
          format: (value) => value.toStringAsFixed(0),
          onChanged: (value) => latest = value,
        ),
      ),
    );

    await tester.drag(find.byType(Slider), const Offset(140, 0));
    await tester.pump();

    expect(latest, isNot(16.0));
  });

  testWidgets('SettingsActionButton outline border uses Fleur divider token', (
    tester,
  ) async {
    await _pumpControl(
      tester,
      child: SettingsActionButton(
        onPressed: () {},
        label: const Text('Outline'),
      ),
    );

    final theme = Theme.of(tester.element(find.byType(SettingsActionButton)));
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(SettingsActionButton),
        matching: find.byType(Material),
      ),
    );
    final shape = material.shape! as RoundedRectangleBorder;

    expect(shape.side.color, theme.fleurSurface.subtleDivider);
    expect(
      theme.extension<FleurSurfaceTheme>(),
      isNotNull,
      reason: 'Settings control tests should use production AppTheme.',
    );
  });
}
