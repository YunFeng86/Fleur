import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/ui/shell_temporary_navigation.dart';

void main() {
  testWidgets('open navigation excludes the background semantics', (
    tester,
  ) async {
    var dismissCount = 0;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Stack(
          children: [
            ShellTemporarySceneGate(
              navigationOpen: true,
              child: Semantics(
                label: 'Background scene',
                child: SizedBox.expand(),
              ),
            ),
            Positioned.fill(
              child: ShellNavigationDismissScrim(
                onDismiss: () => dismissCount++,
                color: Colors.black12,
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.bySemanticsLabel('Background scene'), findsNothing);
    final scrim = find.byKey(const Key('shell_navigation_dismiss_scrim'));
    expect(scrim, findsOneWidget);
    expect(
      tester
          .getSemantics(scrim)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );

    await tester.tap(scrim);
    expect(dismissCount, 1);
    semantics.dispose();
  });

  testWidgets('closed navigation keeps the background semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: ShellTemporarySceneGate(
          navigationOpen: false,
          child: Semantics(label: 'Background scene', child: SizedBox.expand()),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Background scene'), findsOneWidget);
    semantics.dispose();
  });
}
