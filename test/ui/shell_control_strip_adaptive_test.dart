import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/shell_chrome_layout.dart';
import 'package:fleur/ui/shell_title_bar.dart';
import 'package:fleur/ui/sidebar_layout.dart';

void main() {
  testWidgets('title bar and overflow share the adaptive control extent', (
    tester,
  ) async {
    final focusManager = FocusManager.instance;
    final previousStrategy = focusManager.highlightStrategy;
    addTearDown(() => focusManager.highlightStrategy = previousStrategy);
    focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTouch;

    const controlsWidth = 160.0;
    const titleBarWidth =
        controlsWidth +
        kShellWindowCaptionControlsWidth +
        kShellTitleBarMinimumDragWidth;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: titleBarWidth,
            height: kWorkspaceHeaderHeight,
            child: ShellWindowTitleBar(
              commands: ShellWindowTitleBarCommands(
                onToggleSidebar: _noop,
                onBack: _noop,
                onForward: _noop,
                onSearch: _noop,
                canGoBack: true,
                canGoForward: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final toggle = find.byKey(const Key('shell_sidebar_button'));
    expect(tester.getSize(toggle), const Size.square(48));
    expect(tester.getTopLeft(toggle).dy, 0);
    expect(
      find.byKey(const Key('shell_control_overflow_button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('shell_search_button')), findsNothing);
    expect(tester.takeException(), isNull);

    focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    await tester.pump();

    expect(tester.getSize(toggle), const Size.square(kShellControlSize));
    expect(tester.getTopLeft(toggle).dy, kShellControlTopInset);
    expect(
      find.byKey(const Key('shell_control_overflow_button')),
      findsNothing,
    );
    expect(find.byKey(const Key('shell_search_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
