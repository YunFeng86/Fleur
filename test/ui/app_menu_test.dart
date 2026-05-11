import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/ui/app_menu.dart';

void main() {
  testWidgets('outside click closes context menu and reaches target', (
    tester,
  ) async {
    var outsideTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AppMenuHost(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    ElevatedButton(
                      key: const Key('open_context_menu'),
                      onPressed: () {
                        unawaited(
                          AppMenuHost.showAt<String>(
                            context,
                            position: const Offset(40, 40),
                            items: const [
                              AppMenuItem(value: 'copy', label: 'Copy'),
                            ],
                          ),
                        );
                      },
                      child: const Text('Open'),
                    ),
                    ElevatedButton(
                      key: const Key('outside_target'),
                      onPressed: () => outsideTaps++,
                      child: const Text('Outside target'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_context_menu')));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);

    await tester.tap(find.byKey(const Key('outside_target')));
    await tester.pumpAndSettle();

    expect(outsideTaps, 1);
    expect(find.text('Copy'), findsNothing);
  });

  testWidgets('blank click closes context menu without selecting an item', (
    tester,
  ) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: AppMenuHost(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    unawaited(
                      AppMenuHost.showAt<String>(
                        context,
                        position: const Offset(40, 40),
                        items: const [
                          AppMenuItem(value: 'archive', label: 'Archive'),
                        ],
                      ).then((value) => selected = value),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsOneWidget);

    await tester.tapAt(const Offset(390, 390));
    await tester.pumpAndSettle();

    expect(selected, isNull);
    expect(find.text('Archive'), findsNothing);
  });

  testWidgets('context menu item click completes with selected value', (
    tester,
  ) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: AppMenuHost(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    unawaited(
                      AppMenuHost.showAt<String>(
                        context,
                        position: const Offset(40, 40),
                        items: const [
                          AppMenuItem(value: 'copy', label: 'Copy'),
                        ],
                      ).then((value) => selected = value),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(selected, 'copy');
    expect(find.text('Copy'), findsNothing);
  });

  testWidgets('menu button outside click closes menu and reaches target', (
    tester,
  ) async {
    var outsideTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 8,
                top: 8,
                child: AppMenuButton<String>(
                  buttonKey: const Key('menu_button'),
                  tooltip: 'More',
                  icon: Icons.more_vert,
                  items: const [
                    AppMenuItem(value: 'archive', label: 'Archive'),
                  ],
                  onSelected: (_) {},
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: ElevatedButton(
                  key: const Key('outside_target'),
                  onPressed: () => outsideTaps++,
                  child: const Text('Outside target'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('menu_button')));
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsOneWidget);

    await tester.tap(find.byKey(const Key('outside_target')));
    await tester.pumpAndSettle();

    expect(outsideTaps, 1);
    expect(find.text('Archive'), findsNothing);
  });

  testWidgets('menu buttons switch and render item states', (tester) async {
    var selected = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AppMenuButton<String>(
                buttonKey: const Key('first_menu'),
                tooltip: 'First',
                icon: Icons.more_vert,
                items: const [AppMenuItem(value: 'first', label: 'First item')],
                onSelected: (value) => selected = value,
              ),
              AppMenuButton<String>(
                buttonKey: const Key('second_menu'),
                tooltip: 'Second',
                icon: Icons.more_vert,
                items: [
                  AppMenuItem(
                    key: const Key('disabled_delete'),
                    value: 'delete',
                    label: 'Delete',
                    destructive: true,
                    enabled: false,
                    leadingBuilder: (context) => const Icon(Icons.delete),
                  ),
                  const AppMenuItem(value: 'edit', label: 'Edit'),
                ],
                onSelected: (value) => selected = value,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('first_menu')));
    await tester.pumpAndSettle();
    expect(find.text('First item'), findsOneWidget);

    await tester.tap(find.byKey(const Key('second_menu')));
    await tester.pumpAndSettle();
    expect(find.text('First item'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);

    final deleteButton = tester.widget<MenuItemButton>(
      find.byKey(const Key('disabled_delete')),
    );
    expect(deleteButton.onPressed, isNull);
    final deleteText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('disabled_delete')),
        matching: find.text('Delete'),
      ),
    );
    final errorColor = Theme.of(
      tester.element(find.byKey(const Key('disabled_delete'))),
    ).colorScheme.error;
    expect(deleteText.style?.color, errorColor);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(selected, 'edit');
  });
}
