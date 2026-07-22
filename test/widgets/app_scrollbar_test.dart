import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/theme/fleur_theme_extensions.dart';
import 'package:fleur/utils/platform.dart';
import 'package:fleur/widgets/app_scrollbar.dart';

void main() {
  testWidgets('AppScrollbar darkens when hovering the scrollable region', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 240,
            child: AppScrollbar(
              controller: controller,
              thumbVisibility: true,
              interactive: true,
              child: ListView.builder(
                controller: controller,
                itemCount: 50,
                itemBuilder: (context, index) =>
                    SizedBox(height: 40, child: Text('Item $index')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Scrollbar), findsOneWidget);
    ScrollbarTheme scrollbarTheme() =>
        tester.widget<ScrollbarTheme>(find.byType(ScrollbarTheme).first);

    final idleThumbColor = scrollbarTheme().data.thumbColor?.resolve(
      <WidgetState>{},
    );
    final idleThickness = scrollbarTheme().data.thickness?.resolve(
      <WidgetState>{},
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(tester.getCenter(find.byType(AppScrollbar)));
    await tester.pumpAndSettle();

    final hoveredThumbColor = scrollbarTheme().data.thumbColor?.resolve(
      <WidgetState>{},
    );
    final draggedThumbColor = scrollbarTheme().data.thumbColor?.resolve(
      <WidgetState>{WidgetState.dragged},
    );
    final hoveredThickness = scrollbarTheme().data.thickness?.resolve(
      <WidgetState>{},
    );
    final theme = Theme.of(tester.element(find.byType(AppScrollbar)));

    expect(idleThumbColor, theme.fleurState.scrollbarIdle);
    expect(hoveredThumbColor, isNot(idleThumbColor));
    expect(draggedThumbColor, theme.fleurState.scrollbarDrag);
    expect(hoveredThickness, idleThickness);
  });

  testWidgets(
    'AppScrollbar defers interactive behavior to Flutter by default',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugFleurTargetPlatformOverride = null);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 240,
              child: AppScrollbar(
                child: ListView.builder(
                  itemCount: 20,
                  itemBuilder: (context, index) =>
                      SizedBox(height: 40, child: Text('Item $index')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scrollbar), findsOneWidget);
      final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar).first);
      expect(scrollbar.controller, isNotNull);
      expect(scrollbar.interactive, isNull);
    },
  );

  testWidgets(
    'AppScrollbar safely falls back when the child scroll view opts out of primary binding',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugFleurTargetPlatformOverride = null);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 240,
              child: AppScrollbar(
                child: ListView.builder(
                  primary: false,
                  itemCount: 20,
                  itemBuilder: (context, index) =>
                      SizedBox(height: 40, child: Text('Item $index')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scrollbar), findsOneWidget);
      final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar).first);
      expect(scrollbar.controller, isNull);
      expect(scrollbar.thumbVisibility, isFalse);
      expect(scrollbar.interactive, isFalse);
    },
  );
}
