import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

import 'package:fleur/providers/app_update_providers.dart';
import 'package:fleur/providers/core_providers.dart';
import 'package:fleur/services/update/app_update_manifest.dart';
import 'package:fleur/theme/fleur_icons.dart';
import 'package:fleur/ui/adaptive_workspace_layout.dart';
import 'package:fleur/ui/shell_chrome_layout.dart';
import 'package:fleur/ui/shell_frame_topology.dart';
import 'package:fleur/ui/sidebar/sidebar.dart';
import 'package:fleur/ui/sidebar_layout.dart';
import 'package:fleur/ui/workspace_layers.dart';
import 'package:fleur/utils/desktop_window_options.dart';
import 'package:fleur/utils/platform.dart';

import '../test_utils/app_shell_test_support.dart';

AppUpdateManifest _buildUpdateManifest() {
  return AppUpdateManifest(
    schemaVersion: 1,
    channel: AppUpdateChannel.stable,
    version: '9.9.9',
    tag: 'v9.9.9',
    publishedAt: DateTime.utc(2026, 1, 1),
    releaseUrl: Uri.parse('https://example.com/releases/v9.9.9'),
    notes: const {'en': 'Test update'},
    assets: const {},
  );
}

class _TestAppUpdateController extends AppUpdateController {
  _TestAppUpdateController(this.initialState);

  final AppUpdateState initialState;

  @override
  AppUpdateState build() => initialState;
}

void main() {
  test('Desktop window options hide native chrome for Flutter titlebars', () {
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    expect(desktopWindowOptions().titleBarStyle, TitleBarStyle.hidden);

    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    expect(desktopWindowOptions().titleBarStyle, TitleBarStyle.hidden);

    debugFleurTargetPlatformOverride = TargetPlatform.linux;
    expect(desktopWindowOptions().titleBarStyle, TitleBarStyle.hidden);
  });

  testWidgets('Windows shell keeps update and search actions in titlebar', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      buildShellHarness(
        overrides: [
          appUpdateControllerProvider.overrideWith(
            () => _TestAppUpdateController(
              AppUpdateState(
                status: AppUpdateStatus.updateAvailable,
                manifest: _buildUpdateManifest(),
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell_search_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_update_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_global_tool_area')), findsOneWidget);
    expect(find.byKey(const Key('shell_window_close_button')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_update_button')), findsNothing);
    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);

    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pump();

    expect(find.byKey(const Key('shell_search_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_update_button')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_update_button')), findsNothing);
    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
    expect(find.byKey(const Key('app_shell_connected_rail')), findsOneWidget);
    expect(find.byKey(const Key('app_shell_rail_overlay')), findsNothing);
    expect(
      find.byKey(const Key('sidebar_collapsed_rail_surface')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('sidebar_collapsed_rail_divider')),
      findsOneWidget,
    );
  });

  testWidgets('macOS expanded sidebar keeps update in global tools', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      buildShellHarness(
        overrides: [
          appUpdateControllerProvider.overrideWith(
            () => _TestAppUpdateController(
              AppUpdateState(
                status: AppUpdateStatus.updateAvailable,
                manifest: _buildUpdateManifest(),
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell_update_button')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_update_button')), findsNothing);
    expect(find.byKey(const Key('shell_global_tool_area')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('shell_update_button')),
        matching: find.text('Update'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('shell_update_button')),
        matching: find.byIcon(FleurIcons.download),
      ),
      findsOneWidget,
    );
  });

  testWidgets('macOS sidebar width does not move update ownership', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      buildShellHarness(
        overrides: [
          workspaceSidebarWidthProvider.overrideWith(
            (ref) => kMaxWorkspaceSidebarWidth,
          ),
          appUpdateControllerProvider.overrideWith(
            () => _TestAppUpdateController(
              AppUpdateState(
                status: AppUpdateStatus.updateAvailable,
                manifest: _buildUpdateManifest(),
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell_update_button')), findsOneWidget);
    expect(find.byKey(const Key('sidebar_update_button')), findsNothing);
    expect(find.byKey(const Key('shell_global_tool_area')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('shell_update_button')),
        matching: find.text('Update'),
      ),
      findsNothing,
    );
  });

  testWidgets('Linux shell uses titlebar controls and a plain collapsed rail', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildShellHarness());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell_search_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
    expect(find.byKey(const Key('shell_window_close_button')), findsOneWidget);
    expectWorkspaceSurfaceAppearance(
      tester,
      const Key('app_shell_content_layer'),
      borderRadius: kConnectedWorkspaceLayerRadius,
      showShadow: false,
      leadingEdge: WorkspaceLayerEdge.none,
    );

    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell_search_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
    expect(
      find.byKey(const Key('sidebar_collapsed_rail_surface')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('sidebar_collapsed_rail_divider')),
      findsOneWidget,
    );
    expectWorkspaceSurfaceAppearance(
      tester,
      const Key('app_shell_content_layer'),
      borderRadius: kConnectedWorkspaceLayerRadius,
      showShadow: false,
      leadingEdge: WorkspaceLayerEdge.none,
    );
  });

  testWidgets('Windows shell titlebar sits above shifted workspace content', (
    tester,
  ) async {
    final focusManager = FocusManager.instance;
    final previousStrategy = focusManager.highlightStrategy;
    focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => focusManager.highlightStrategy = previousStrategy);
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      buildShellHarness(
        child: const Column(
          children: [
            SizedBox(
              key: Key('home_scope_header'),
              height: kWorkspaceHeaderHeight,
            ),
            Expanded(
              child: ColoredBox(
                key: Key('app_shell_child'),
                color: Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final shellCenter = tester
        .getCenter(find.byKey(const Key('shell_sidebar_button')))
        .dy;
    final shellCenterX = tester
        .getCenter(find.byKey(const Key('shell_sidebar_button')))
        .dx;
    final headerTop = tester
        .getTopLeft(find.byKey(const Key('home_scope_header')))
        .dy;
    final headerCenter = tester
        .getCenter(find.byKey(const Key('home_scope_header')))
        .dy;

    expect(shellCenter, kWorkspaceHeaderHeight / 2);
    expect(shellCenterX, kTitleBarExpectedSidebarRailWidth / 2);
    expect(headerTop, kWorkspaceHeaderHeight);
    expect(headerCenter, kWorkspaceHeaderHeight + kWorkspaceHeaderHeight / 2);
  });

  testWidgets('Windows connected rail gives content headers their full width', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      buildShellHarness(
        child: Column(
          children: [
            WorkspaceHeader(
              title: 'All Articles',
              trailingWidth: kShellControlSize,
              trailing: const SizedBox.square(
                dimension: kShellControlSize,
                key: Key('rail_clear_trailing'),
              ),
            ),
            Builder(
              builder: (context) {
                final scope = ShellLayerScope.maybeOf(context);
                return Text(
                  'leading:${scope?.contentLeadingInset}',
                  key: const Key('content_leading_inset_probe'),
                );
              },
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app_shell_rail_overlay')), findsNothing);
    expect(find.byKey(const Key('app_shell_connected_rail')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('app_shell_content_layer'))).dx,
      kTitleBarExpectedSidebarRailWidth,
    );
    expect(find.text('leading:0.0'), findsOneWidget);
  });

  testWidgets('App shell keeps macOS traffic lights clear of sidebar items', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildShellHarness());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell_title_bar')), findsNothing);
    expect(find.byKey(const Key('shell_window_close_button')), findsNothing);

    final allButtonTop = tester
        .getTopLeft(find.byKey(const Key('sidebar_all_button')))
        .dy;
    final shellButtonLeft = tester
        .getTopLeft(find.byKey(const Key('shell_sidebar_button')))
        .dx;
    final shellButtonTop = tester
        .getTopLeft(find.byKey(const Key('shell_sidebar_button')))
        .dy;
    final shellButtonCenter = tester
        .getCenter(find.byKey(const Key('shell_sidebar_button')))
        .dy;

    expect(kMacOSTrafficLightTargetCenterY, kWorkspaceHeaderHeight / 2);
    expect(shellButtonLeft, greaterThanOrEqualTo(kMacOSTrafficLightSafeInset));
    expect(shellButtonTop, kMacOSShellControlTopInset);
    expect(shellButtonCenter, kMacOSTrafficLightTargetCenterY);
    expect(
      tester.getSize(find.byKey(const Key('shell_sidebar_button'))),
      const Size.square(kShellControlSize),
    );
    expect(allButtonTop, greaterThanOrEqualTo(kWorkspaceHeaderHeight));
    expect(
      tester.getSize(find.byKey(const Key('app_shell_child'))).height,
      900,
    );
  });

  testWidgets('App shell follows macOS traffic light metrics', (tester) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      buildShellHarness(
        overrides: [
          macOSWindowChromeMetricsProvider.overrideWith(
            (ref) => const MacOSWindowChromeMetrics(
              trafficLightsVisible: true,
              centerY: 26,
              safeInset: 96,
              isFullScreen: false,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final shellButtonLeft = tester
        .getTopLeft(find.byKey(const Key('shell_sidebar_button')))
        .dx;
    final shellButtonTop = tester
        .getTopLeft(find.byKey(const Key('shell_sidebar_button')))
        .dy;
    final shellButtonCenter = tester
        .getCenter(find.byKey(const Key('shell_sidebar_button')))
        .dy;
    final shellSearchCenter = tester
        .getCenter(find.byKey(const Key('shell_search_button')))
        .dy;

    expect(shellButtonLeft, 96);
    expect(shellButtonTop, 26 - (kShellControlSize / 2));
    expect(shellButtonCenter, 26);
    expect(shellSearchCenter, 26);
  });

  testWidgets(
    'App shell returns inline controls to the leading edge fullscreen',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugFleurTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildShellHarness(
          overrides: [
            macOSWindowChromeMetricsProvider.overrideWith(
              (ref) => const MacOSWindowChromeMetrics(
                trafficLightsVisible: false,
                centerY: kMacOSTrafficLightTargetCenterY,
                safeInset: 0,
                isFullScreen: true,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final shellButtonLeft = tester
          .getTopLeft(find.byKey(const Key('shell_sidebar_button')))
          .dx;
      final shellButtonCenter = tester
          .getCenter(find.byKey(const Key('shell_sidebar_button')))
          .dy;

      expect(shellButtonLeft, 12);
      expect(shellButtonCenter, kMacOSTrafficLightTargetCenterY);
    },
  );

  testWidgets('App shell fullscreen controls respect click-safe top inset', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      buildShellHarness(
        overrides: [
          macOSWindowChromeMetricsProvider.overrideWith(
            (ref) => const MacOSWindowChromeMetrics(
              trafficLightsVisible: false,
              centerY: kMacOSTrafficLightTargetCenterY,
              safeInset: 0,
              isFullScreen: true,
              clickSafeTopInset: 12,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const Key('shell_sidebar_button'))).dx,
      12,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('shell_sidebar_button'))).dy,
      12,
    );
  });

  testWidgets(
    'App shell returns narrow layered controls to the leading edge fullscreen',
    (tester) async {
      debugFleurTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugFleurTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(640, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildShellHarness(
          overrides: [
            macOSWindowChromeMetricsProvider.overrideWith(
              (ref) => const MacOSWindowChromeMetrics(
                trafficLightsVisible: false,
                centerY: kMacOSTrafficLightTargetCenterY,
                safeInset: 0,
                isFullScreen: true,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell_drawer_controls')), findsNothing);
      expect(find.byKey(const Key('shell_controls_capsule')), findsOneWidget);
      expect(find.byKey(const Key('app_shell_rail_overlay')), findsOneWidget);
      expect(
        find.byKey(const Key('sidebar_collapsed_rail_surface')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('sidebar_collapsed_rail_divider')),
        findsNothing,
      );
      expectWorkspaceSurfaceAppearance(
        tester,
        const Key('app_shell_content_layer'),
        borderRadius: kWorkspaceLayerRadius,
        showShadow: true,
        leadingEdge: WorkspaceLayerEdge.level1,
      );

      final shellButtonLeft = tester
          .getTopLeft(find.byKey(const Key('shell_sidebar_button')))
          .dx;

      expect(shellButtonLeft, 12);
    },
  );

  testWidgets('App shell keeps window controls on dedicated reader pages', (
    tester,
  ) async {
    debugFleurTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugFleurTargetPlatformOverride = null);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(640, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    ShellLayerScope? readerScope;
    await tester.pumpWidget(
      buildShellHarness(
        currentUri: Uri(path: '/all/article/42'),
        child: Builder(
          builder: (context) {
            readerScope = ShellLayerScope.maybeOf(context);
            return const ColoredBox(
              key: Key('app_shell_child'),
              color: Colors.transparent,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(readerScope, isNotNull);
    expect(
      readerScope!.workspaceArrangement!.navigationPresentation,
      WorkspaceNavigationPresentation.offCanvas,
    );
    expect(
      readerScope!.workspaceArrangement!.readerPresentation,
      WorkspaceReaderPresentation.secondaryPage,
    );
    expect(
      readerScope!.frameGeometry.topology.navigationSurface,
      ShellNavigationSurface.absent,
    );
    expect(readerScope!.frameGeometry.contentLeft, 0);
    expect(readerScope!.frameGeometry.contentWidth, 640);

    expect(find.byKey(const Key('shell_controls_capsule')), findsNothing);
    expect(find.byKey(const Key('shell_drawer_controls')), findsNothing);
    expect(find.byKey(const Key('shell_sidebar_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_back_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_forward_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_search_button')), findsOneWidget);
    expect(find.byKey(const Key('shell_window_close_button')), findsOneWidget);
    expect(find.byType(Sidebar), findsNothing);
    expect(find.byKey(const Key('app_shell_child')), findsOneWidget);

    final sceneCanvas = find.byKey(
      const Key('app_shell_secondary_scene_canvas'),
    );
    expect(sceneCanvas, findsOneWidget);
    final canvasTopLeft = tester.getTopLeft(sceneCanvas);
    final canvasSize = tester.getSize(sceneCanvas);
    expect(canvasTopLeft.dx, 0);
    expect(canvasSize.width, 640);
    expect(canvasSize.height, readerScope!.frameGeometry.workspaceHeight);

    final titleBarLeft = tester
        .getTopLeft(find.byKey(const Key('shell_title_bar')))
        .dx;
    final globalToolAreaTopLeft = tester.getTopLeft(
      find.byKey(const Key('shell_global_tool_area')),
    );
    await tester.tap(find.byKey(const Key('shell_sidebar_button')));
    await tester.pumpAndSettle();

    expect(find.byType(Sidebar), findsOneWidget);
    expect(find.byKey(const Key('app_shell_navigation_scrim')), findsOneWidget);
    expect(
      readerScope!.workspaceArrangement!.navigationPresentation,
      WorkspaceNavigationPresentation.offCanvas,
    );
    expect(readerScope!.frameGeometry.topology.temporaryNavigationOpen, isTrue);
    expect(
      readerScope!.frameGeometry.topology.navigationSurface,
      ShellNavigationSurface.temporaryOverlay,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('app_shell_secondary_layer'))).dx,
      kTemporaryWorkspaceSidebarWidth,
    );
    expect(tester.getTopLeft(sceneCanvas), canvasTopLeft);
    expect(tester.getSize(sceneCanvas), canvasSize);
    expect(
      tester.getTopLeft(find.byKey(const Key('shell_title_bar'))).dx,
      titleBarLeft,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('shell_global_tool_area'))),
      globalToolAreaTopLeft,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Sidebar), findsNothing);
    expect(
      readerScope!.frameGeometry.topology.temporaryNavigationOpen,
      isFalse,
    );
    expect(
      readerScope!.frameGeometry.topology.navigationSurface,
      ShellNavigationSurface.absent,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('app_shell_secondary_layer'))).dx,
      0,
    );
    expect(tester.getTopLeft(sceneCanvas), canvasTopLeft);
    expect(tester.getSize(sceneCanvas), canvasSize);
    expect(
      tester.getTopLeft(find.byKey(const Key('shell_global_tool_area'))).dx,
      globalToolAreaTopLeft.dx,
    );
  });
}
