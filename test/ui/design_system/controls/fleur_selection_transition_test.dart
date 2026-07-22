import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/motion.dart';
import 'package:fleur/ui/design_system/design_system.dart';

void main() {
  testWidgets('selection transition starts settled and shares one progress', (
    tester,
  ) async {
    final selected = ValueNotifier<bool>(true);
    addTearDown(selected.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ValueListenableBuilder<bool>(
          valueListenable: selected,
          builder: (context, value, _) {
            return FleurSelectionTransition(
              selected: value,
              builder: (context, selection, _) {
                return Opacity(
                  key: const Key('selection_progress'),
                  opacity: selection,
                  child: const SizedBox.square(dimension: 40),
                );
              },
            );
          },
        ),
      ),
    );

    double progress() => tester
        .widget<Opacity>(find.byKey(const Key('selection_progress')))
        .opacity;

    expect(progress(), 1);

    selected.value = false;
    await tester.pump();
    expect(progress(), 1);

    await tester.pump(AppMotion.selectionTransitionDuration ~/ 2);
    expect(progress(), greaterThan(0));
    expect(progress(), lessThan(1));

    await tester.pumpAndSettle();
    expect(progress(), 0);
  });

  testWidgets('selection transition respects reduced motion', (tester) async {
    final selected = ValueNotifier<bool>(false);
    addTearDown(selected.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ValueListenableBuilder<bool>(
            valueListenable: selected,
            builder: (context, value, _) {
              return FleurSelectionTransition(
                selected: value,
                builder: (context, selection, _) {
                  return Opacity(
                    key: const Key('selection_progress'),
                    opacity: selection,
                    child: const SizedBox.square(dimension: 40),
                  );
                },
              );
            },
          ),
        ),
      ),
    );

    selected.value = true;
    await tester.pump();

    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('selection_progress')))
          .opacity,
      1,
    );
  });

  testWidgets('shell icon button uses the shared selection duration', (
    tester,
  ) async {
    late BuildContext buttonContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            buttonContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final style = FleurShellIconButtonStyle.styleFor(buttonContext);
    expect(style.animationDuration, AppMotion.selectionTransitionDuration);
  });

  testWidgets('animated icon cross-fades without resizing its button', (
    tester,
  ) async {
    final icon = ValueNotifier<IconData>(Icons.search);
    addTearDown(icon.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.square(
            key: const Key('icon_button_bounds'),
            dimension: 40,
            child: ValueListenableBuilder<IconData>(
              valueListenable: icon,
              builder: (context, value, _) {
                return FleurAnimatedIcon(icon: value, size: 18);
              },
            ),
          ),
        ),
      ),
    );

    final initialSize = tester.getSize(
      find.byKey(const Key('icon_button_bounds')),
    );
    expect(find.byIcon(Icons.search), findsOneWidget);

    icon.value = Icons.search_off;
    await tester.pump();

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.search_off), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('icon_button_bounds'))),
      initialSize,
    );

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.byIcon(Icons.search_off), findsOneWidget);
  });
}
