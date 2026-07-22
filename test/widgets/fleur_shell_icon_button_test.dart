import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/widgets/fleur_shell_icon_button.dart';

Future<void> _pumpButton(
  WidgetTester tester, {
  required VoidCallback onPressed,
  bool adaptiveTapTarget = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: FleurShellIconButton(
            key: const Key('shell_button'),
            tooltip: 'Search articles',
            onPressed: onPressed,
            icon: const Icon(Icons.search, size: 16),
            selected: true,
            adaptiveTapTarget: adaptiveTapTarget,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('adapts its hit target while preserving compact visual size', (
    tester,
  ) async {
    final focusManager = FocusManager.instance;
    final previousStrategy = focusManager.highlightStrategy;
    addTearDown(() => focusManager.highlightStrategy = previousStrategy);
    var pressCount = 0;

    focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    await _pumpButton(
      tester,
      onPressed: () => pressCount++,
      adaptiveTapTarget: true,
    );
    expect(
      tester.getSize(find.byKey(const Key('shell_button'))),
      const Size.square(32),
    );

    focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
    await tester.pump();

    final button = find.byKey(const Key('shell_button'));
    final inkWell = find.descendant(of: button, matching: find.byType(InkWell));
    expect(tester.getSize(button), const Size.square(48));
    expect(tester.getSize(inkWell), const Size.square(32));

    final buttonRect = tester.getRect(button);
    final inkRect = tester.getRect(inkWell);
    expect(
      inkRect.contains(buttonRect.centerLeft + const Offset(2, 0)),
      isFalse,
    );
    await tester.tapAt(buttonRect.centerLeft + const Offset(2, 0));
    await tester.pump();
    expect(pressCount, 1);
  });

  testWidgets('keeps fixed shell geometry compact unless explicitly adaptive', (
    tester,
  ) async {
    final focusManager = FocusManager.instance;
    final previousStrategy = focusManager.highlightStrategy;
    addTearDown(() => focusManager.highlightStrategy = previousStrategy);
    focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTouch;

    await _pumpButton(tester, onPressed: () {});

    expect(
      tester.getSize(find.byKey(const Key('shell_button'))),
      const Size.square(32),
    );
  });

  testWidgets('exposes its tooltip and selected state to semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpButton(tester, onPressed: () {});

      final node = tester.getSemantics(find.byKey(const Key('shell_button')));
      expect(node.label, 'Search articles');
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    } finally {
      semantics.dispose();
    }
  });
}
