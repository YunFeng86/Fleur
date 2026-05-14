import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/sidebar_layout.dart';
import 'package:fleur/ui/workspace_layers.dart';

Future<void> _pumpHeader(
  WidgetTester tester, {
  required Size size,
  required String title,
  double leadingInset = 14,
  double trailingWidth = 98,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: ShellLayerScope(
          totalSize: size,
          contentSize: size,
          sidebarLayoutMode: SidebarLayoutMode.inline,
          contentLeft: 0,
          headerLeadingInset: leadingInset,
          macOSWindowChromeMetrics: MacOSWindowChromeMetrics.fallback,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: size.width,
              height: kWorkspaceHeaderHeight,
              child: WorkspaceHeader(
                title: title,
                trailingWidth: trailingWidth,
                trailing: ColoredBox(
                  key: const Key('test_header_trailing'),
                  color: Colors.transparent,
                  child: SizedBox(
                    width: trailingWidth,
                    height: kShellControlSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('centers the title when both button groups have room', (
    tester,
  ) async {
    await _pumpHeader(tester, size: const Size(520, 120), title: 'All');

    final titleCenter = tester.getCenter(
      find.byKey(const Key('workspace_header_title')),
    );

    expect((titleCenter.dx - 260).abs(), lessThan(1));
    expect(find.byKey(const Key('workspace_header_title_fade')), findsNothing);
  });

  testWidgets('left-aligns title beside leading controls after collision', (
    tester,
  ) async {
    await _pumpHeader(
      tester,
      size: const Size(620, 120),
      title: 'Scope title wide',
      leadingInset: 280,
    );

    final titleLeft = tester.getTopLeft(
      find.byKey(const Key('workspace_header_title')),
    );

    expect(titleLeft.dx, 280);
    expect(find.byKey(const Key('workspace_header_title_fade')), findsNothing);
  });

  testWidgets('fades the title before it reaches trailing controls', (
    tester,
  ) async {
    await _pumpHeader(
      tester,
      size: const Size(420, 120),
      title: 'A very long feed title that cannot fit in the header',
      leadingInset: 160,
    );

    expect(find.byKey(const Key('workspace_header_title')), findsOneWidget);
    expect(
      find.byKey(const Key('workspace_header_title_fade')),
      findsOneWidget,
    );
    expect(
      tester.getRect(find.byKey(const Key('workspace_header_title'))).right,
      lessThan(
        tester.getRect(find.byKey(const Key('test_header_trailing'))).left,
      ),
    );
  });

  testWidgets('hides title when controls leave too little space', (
    tester,
  ) async {
    await _pumpHeader(
      tester,
      size: const Size(260, 120),
      title: 'Tiny',
      leadingInset: 160,
    );

    expect(find.byKey(const Key('workspace_header_title')), findsNothing);
    expect(find.byKey(const Key('test_header_trailing')), findsOneWidget);
  });
}
