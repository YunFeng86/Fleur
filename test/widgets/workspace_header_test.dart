import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/services/update/app_update_manifest.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/shell_chrome_layout.dart';
import 'package:fleur/ui/shell_title_bar.dart';
import 'package:fleur/ui/sidebar_layout.dart';
import 'package:fleur/ui/workspace_layers.dart';
import 'package:fleur/utils/platform.dart';

Future<void> _pumpHeader(
  WidgetTester tester, {
  required Size size,
  required String title,
  double leadingInset = 14,
  double contentLeadingInset = 0,
  double trailingWidth = 98,
  MacOSWindowChromeMetrics metrics = MacOSWindowChromeMetrics.fallback,
  Widget? trailing,
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
          contentLeadingInset: contentLeadingInset,
          railOverlayVisible: false,
          sidebarWidth: kDefaultWorkspaceSidebarWidth,
          listWidth: kDefaultWorkspaceListWidth,
          headerLeadingInset: leadingInset,
          macOSWindowChromeMetrics: metrics,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: size.width,
              height: kWorkspaceHeaderHeight,
              child: WorkspaceHeader(
                title: title,
                trailingWidth: trailingWidth,
                trailing:
                    trailing ??
                    ColoredBox(
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
    final trailingCenter = tester.getCenter(
      find.byKey(const Key('test_header_trailing')),
    );

    expect((titleCenter.dx - 260).abs(), lessThan(1));
    expect(titleCenter.dy, closeTo(kWorkspaceHeaderHeight / 2, 0.1));
    expect(trailingCenter.dy, closeTo(kWorkspaceHeaderHeight / 2, 0.1));
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

  testWidgets('keeps the title clear of the content rail overlay', (
    tester,
  ) async {
    await _pumpHeader(
      tester,
      size: const Size(520, 120),
      title: 'All',
      contentLeadingInset: kSidebarRailWidth + kRailOverlayContentGap,
    );

    expect(
      tester.getTopLeft(find.byKey(const Key('workspace_header_title'))).dx,
      greaterThanOrEqualTo(kSidebarRailWidth + kRailOverlayContentGap),
    );
  });

  testWidgets(
    'page header follows macOS chrome metrics and fullscreen return',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugFleurTargetPlatformOverride = null);

      await _pumpHeader(
        tester,
        size: const Size(520, 120),
        title: 'All',
        metrics: const MacOSWindowChromeMetrics(
          trafficLightsVisible: true,
          centerY: 26,
          safeInset: 96,
          isFullScreen: false,
        ),
      );
      final headerTitleCenterY = tester
          .getCenter(find.byKey(const Key('workspace_header_title')))
          .dy;
      final headerTrailingCenterY = tester
          .getCenter(find.byKey(const Key('test_header_trailing')))
          .dy;

      expect(headerTitleCenterY, closeTo(26, 0.1));
      expect(headerTrailingCenterY, closeTo(26, 0.1));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ShellLayerScope(
            totalSize: const Size(520, 120),
            contentSize: const Size(520, 120),
            sidebarLayoutMode: SidebarLayoutMode.inline,
            contentLeft: 0,
            contentLeadingInset: 0,
            railOverlayVisible: false,
            sidebarWidth: kDefaultWorkspaceSidebarWidth,
            listWidth: kDefaultWorkspaceListWidth,
            headerLeadingInset: 14,
            macOSWindowChromeMetrics: const MacOSWindowChromeMetrics(
              trafficLightsVisible: true,
              centerY: 26,
              safeInset: 96,
              isFullScreen: false,
            ),
            child: WorkspacePageHeader(title: 'Settings', onBack: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getTopLeft(find.byKey(const Key('workspace_page_back_button')))
            .dx,
        96,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ShellLayerScope(
            totalSize: const Size(520, 120),
            contentSize: const Size(520, 120),
            sidebarLayoutMode: SidebarLayoutMode.inline,
            contentLeft: 0,
            contentLeadingInset: 0,
            railOverlayVisible: false,
            sidebarWidth: kDefaultWorkspaceSidebarWidth,
            listWidth: kDefaultWorkspaceListWidth,
            headerLeadingInset: 14,
            macOSWindowChromeMetrics: const MacOSWindowChromeMetrics(
              trafficLightsVisible: false,
              centerY: kMacOSTrafficLightTargetCenterY,
              safeInset: 0,
              isFullScreen: true,
            ),
            child: WorkspacePageHeader(title: 'Settings', onBack: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getTopLeft(find.byKey(const Key('workspace_page_back_button')))
            .dx,
        8,
      );
    },
  );

  testWidgets('macOS fullscreen controls respect the click-safe top inset', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    await _pumpHeader(
      tester,
      size: const Size(520, 120),
      title: 'All',
      metrics: const MacOSWindowChromeMetrics(
        trafficLightsVisible: false,
        centerY: kMacOSTrafficLightTargetCenterY,
        safeInset: 0,
        isFullScreen: true,
        clickSafeTopInset: 12,
      ),
    );

    expect(
      tester.getTopLeft(find.byKey(const Key('test_header_trailing'))).dy,
      12,
    );
    expect(find.byKey(const Key('window_drag_surface')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ShellLayerScope(
          totalSize: const Size(520, 120),
          contentSize: const Size(520, 120),
          sidebarLayoutMode: SidebarLayoutMode.inline,
          contentLeft: 0,
          contentLeadingInset: 0,
          railOverlayVisible: false,
          sidebarWidth: kDefaultWorkspaceSidebarWidth,
          listWidth: kDefaultWorkspaceListWidth,
          headerLeadingInset: 14,
          macOSWindowChromeMetrics: const MacOSWindowChromeMetrics(
            trafficLightsVisible: false,
            centerY: kMacOSTrafficLightTargetCenterY,
            safeInset: 0,
            isFullScreen: true,
            clickSafeTopInset: 12,
          ),
          child: WorkspacePageHeader(title: 'Settings', onBack: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const Key('workspace_page_back_button'))).dy,
      12,
    );
  });

  testWidgets('header buttons stay above the macOS drag and zoom surface', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.cloudwind.fleur/window_controls'),
          (call) async {
            calls.add(call.method);
            return null;
          },
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.cloudwind.fleur/window_controls'),
            null,
          );
    });

    var buttonTapCount = 0;
    await _pumpHeader(
      tester,
      size: const Size(520, 120),
      title: 'All',
      trailingWidth: kShellControlSize,
      trailing: IconButton(
        key: const Key('test_header_action_button'),
        onPressed: () => buttonTapCount++,
        icon: const Icon(Icons.refresh),
      ),
    );

    await tester.tap(find.byKey(const Key('test_header_action_button')));
    await tester.tap(find.byKey(const Key('test_header_action_button')));
    await tester.pump();

    expect(buttonTapCount, 2);
    expect(calls, isNot(contains('performWindowZoom')));
    expect(calls, isNot(contains('performWindowDrag')));
  });

  testWidgets('titlebar preserves drag space and overflows lower priorities', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(352, 120);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final manifest = AppUpdateManifest(
      schemaVersion: 1,
      channel: AppUpdateChannel.stable,
      version: '9.9.9',
      tag: 'v9.9.9',
      publishedAt: DateTime.utc(2026, 1, 1),
      releaseUrl: Uri.parse('https://example.com/releases/v9.9.9'),
      notes: const {'en': 'Test update'},
      assets: const {},
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 352,
            child: ShellWindowTitleBar(
              leadingLeft: 12,
              commands: ShellWindowTitleBarCommands(
                onToggleSidebar: () {},
                onBack: () {},
                onForward: () {},
                onSearch: () {},
                canGoBack: true,
                canGoForward: true,
              ),
              updateManifest: manifest,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('shell_sidebar_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_back_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_search_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_forward_button')), findsNothing);
    expect(find.byKey(const Key('shell_update_button')), findsNothing);
    expect(
      find.byKey(const Key('shell_control_overflow_button')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('shell_search_button'))).dx,
      tester.getTopLeft(find.byKey(const Key('shell_back_button'))).dx +
          kShellControlSize,
    );
    expect(
      find.byKey(const Key('shell_title_bar_drag_surface')),
      findsOneWidget,
    );
    expect(
      tester.getSize(
        find.byKey(const Key('shell_window_caption_controls_host')),
      ),
      const Size(kShellWindowCaptionControlsWidth, kWorkspaceHeaderHeight),
    );
  });
}
