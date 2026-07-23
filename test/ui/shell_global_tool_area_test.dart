import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/shell_control_strip.dart';
import 'package:fleur/ui/shell_frame_topology.dart';
import 'package:fleur/ui/shell_global_tool_area.dart';
import 'package:fleur/ui/sidebar_layout.dart';

void main() {
  BorderRadius buttonRadius(WidgetTester tester, Key key) {
    final button = tester.widget<IconButton>(
      find.descendant(of: find.byKey(key), matching: find.byType(IconButton)),
    );
    final shape = button.style!.shape!.resolve(const <WidgetState>{});
    return (shape! as RoundedRectangleBorder).borderRadius.resolve(
      TextDirection.ltr,
    );
  }

  Future<void> pumpArea(
    WidgetTester tester, {
    required ShellGlobalToolSurface surface,
    bool showSearch = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Align(
          alignment: Alignment.topLeft,
          child: ShellGlobalToolArea(
            commands: const ShellWindowTitleBarCommands(
              onToggleSidebar: _noop,
              onBack: _noop,
              onForward: _noop,
              onSearch: _noop,
              canGoBack: true,
              canGoForward: true,
            ),
            presentationMode: SidebarPresentationMode.expanded,
            surface: surface,
            showSearch: showSearch,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('integrated presentation keeps one flat global tool area', (
    tester,
  ) async {
    await pumpArea(tester, surface: ShellGlobalToolSurface.integrated);

    expect(find.byKey(const Key('shell_global_tool_area')), findsOneWidget);
    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
    expect(find.byKey(const Key('shell_sidebar_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_search_button')), findsOneWidget);
    expect(
      buttonRadius(tester, const Key('shell_sidebar_button')),
      BorderRadius.circular(16),
    );
  });

  testWidgets('window-frame presentation keeps circular controls', (
    tester,
  ) async {
    await pumpArea(tester, surface: ShellGlobalToolSurface.windowFrame);

    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
    expect(
      buttonRadius(tester, const Key('shell_sidebar_button')),
      BorderRadius.circular(16),
    );
  });

  testWidgets('floating presentation uses the L1 island treatment', (
    tester,
  ) async {
    await pumpArea(
      tester,
      surface: ShellGlobalToolSurface.floatingIsland,
      showSearch: false,
    );

    expect(find.byKey(const Key('shell_global_tool_area')), findsOneWidget);
    expect(find.byKey(const Key('shell_controls_capsule')), findsOneWidget);
    expect(find.byKey(const Key('shell_search_button')), findsNothing);
    expect(
      buttonRadius(tester, const Key('shell_sidebar_button')),
      BorderRadius.circular(16),
    );
  });

  testWidgets('caller key is not reused by the internal focus group', (
    tester,
  ) async {
    final areaKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ShellGlobalToolArea(
          key: areaKey,
          commands: const ShellWindowTitleBarCommands(
            onToggleSidebar: _noop,
            onBack: _noop,
            onForward: _noop,
            onSearch: _noop,
            canGoBack: true,
            canGoForward: true,
          ),
          presentationMode: SidebarPresentationMode.expanded,
          surface: ShellGlobalToolSurface.integrated,
        ),
      ),
    );

    expect(areaKey.currentContext, isNotNull);
    expect(find.byKey(const Key('shell_global_tool_area')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
