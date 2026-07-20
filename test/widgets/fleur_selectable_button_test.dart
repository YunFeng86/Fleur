import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/theme/fleur_theme_extensions.dart';
import 'package:fleur/ui/motion.dart';
import 'package:fleur/widgets/fleur_selectable_button.dart';

void main() {
  testWidgets('keeps selection persistent and press in the state layer', (
    tester,
  ) async {
    final selected = ValueNotifier<bool>(false);
    addTearDown(selected.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Center(
          child: ValueListenableBuilder<bool>(
            valueListenable: selected,
            builder: (context, value, _) {
              return FleurSelectableButton(
                key: const Key('selectable_button'),
                selected: value,
                onPressed: () => selected.value = !selected.value,
                child: const Text('Option'),
              );
            },
          ),
        ),
      ),
    );

    ButtonStyle style() => tester
        .widget<TextButton>(
          find.descendant(
            of: find.byKey(const Key('selectable_button')),
            matching: find.byType(TextButton),
          ),
        )
        .style!;

    final context = tester.element(find.byKey(const Key('selectable_button')));
    final theme = Theme.of(context);
    expect(
      style().backgroundColor!.resolve(<WidgetState>{}),
      Colors.transparent,
    );
    expect(
      style().overlayColor!.resolve(<WidgetState>{WidgetState.pressed}),
      theme.fleurState.pressedTint,
    );
    expect(style().overlayColor!.resolve(<WidgetState>{}), isNull);
    expect(style().splashFactory, theme.splashFactory);
    expect(style().splashFactory, isNot(NoSplash.splashFactory));
    expect(style().animationDuration, AppMotion.selectionTransitionDuration);

    await tester.tap(find.byKey(const Key('selectable_button')));
    await tester.pump();

    expect(
      style().backgroundColor!.resolve(<WidgetState>{}),
      theme.fleurState.selectionTint,
    );
    expect(
      style().backgroundColor!.resolve(<WidgetState>{WidgetState.pressed}),
      theme.fleurState.selectionTint,
    );
    expect(
      style().overlayColor!.resolve(<WidgetState>{WidgetState.pressed}),
      theme.fleurState.pressedTint,
    );
  });

  testWidgets('respects reduced motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: FleurSelectableButton(
            selected: true,
            onPressed: null,
            child: Text('Option'),
          ),
        ),
      ),
    );

    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.style?.animationDuration, Duration.zero);
  });
}
