import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/features/accounts/accounts.dart';
import 'package:fleur/ui/settings/settings_screen.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/settings/tabs/about_tab.dart';
import 'package:fleur/utils/path_manager.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform({
    required String documentsPath,
    required String supportPath,
    required String cachePath,
  }) : _documentsPath = documentsPath,
       _supportPath = supportPath,
       _cachePath = cachePath;

  final String _documentsPath;
  final String _supportPath;
  final String _cachePath;

  @override
  Future<String?> getApplicationDocumentsPath() async => _documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async => _supportPath;

  @override
  Future<String?> getApplicationCachePath() async => _cachePath;
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  required Widget home,
  required Size size,
  double textScale = 2.0,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(textScale)),
              child: home,
            );
          },
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

Widget _buildAccountDialogLauncher() {
  return Scaffold(
    body: Center(
      child: Consumer(
        builder: (context, ref, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                key: const Key('open_fever'),
                onPressed: () async {
                  await showAddFeverAccountDialog(context, ref);
                },
                child: const Text('open fever'),
              ),
              ElevatedButton(
                key: const Key('open_miniflux'),
                onPressed: () async {
                  await showAddMinifluxAccountDialog(context, ref);
                },
                child: const Text('open miniflux'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Add account dialogs: no overflow on small screens', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
      oldOnError?.call(details);
    };

    try {
      await _pumpTestApp(
        tester,
        size: const Size(320, 640),
        textScale: 2.0,
        home: _buildAccountDialogLauncher(),
      );

      await tester.tap(find.byKey(const Key('open_fever')));
      await tester.pump(); // start push animation
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pump(); // start pop animation
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      await tester.tap(find.byKey(const Key('open_miniflux')));
      await tester.pump(); // start push animation
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pump(); // start pop animation
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    } finally {
      FlutterError.onError = oldOnError;
    }

    expect(tester.takeException(), isNull);
    expect(errors, isEmpty);
  });

  testWidgets('Fever dialog shows inline errors and focuses base URL first', (
    tester,
  ) async {
    await _pumpTestApp(
      tester,
      size: const Size(360, 720),
      textScale: 1.0,
      home: _buildAccountDialogLauncher(),
    );

    await tester.tap(find.byKey(const Key('open_fever')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Enter base URL'), findsOneWidget);
    expect(find.text('Enter API key'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byType(TextField).at(1))
          .focusNode
          ?.hasFocus,
      isTrue,
    );
  });

  testWidgets(
    'Miniflux dialog shows inline errors and focuses base URL first',
    (tester) async {
      await _pumpTestApp(
        tester,
        size: const Size(360, 720),
        textScale: 1.0,
        home: _buildAccountDialogLauncher(),
      );

      await tester.tap(find.byKey(const Key('open_miniflux')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('Enter base URL'), findsOneWidget);
      expect(find.text('Enter API token'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byType(TextField).at(1))
            .focusNode
            ?.hasFocus,
        isTrue,
      );
    },
  );

  testWidgets('SettingsScreen: header does not overflow at large text scale', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
      oldOnError?.call(details);
    };

    try {
      await _pumpTestApp(
        tester,
        size: const Size(320, 800),
        textScale: 2.0,
        home: const SettingsScreen(),
      );

      await tester.tap(find.text('Grouping & Sorting'));
      await tester.pump(const Duration(milliseconds: 50));
    } finally {
      FlutterError.onError = oldOnError;
    }

    expect(tester.takeException(), isNull);
    expect(errors, isEmpty);
  });

  testWidgets(
    'SettingsScreen: services detail does not overflow at large text scale',
    (tester) async {
      final errors = <FlutterErrorDetails>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        oldOnError?.call(details);
      };

      try {
        await _pumpTestApp(
          tester,
          size: const Size(320, 800),
          textScale: 2.0,
          home: const SettingsScreen(),
        );

        await tester.tap(find.text('Services'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      } finally {
        FlutterError.onError = oldOnError;
      }

      expect(tester.takeException(), isNull);
      expect(errors, isEmpty);
    },
  );

  group('AboutTab', () {
    late PathProviderPlatform originalPlatform;
    late Directory tempDir;

    setUpAll(() {
      originalPlatform = PathProviderPlatform.instance;
      PackageInfo.setMockInitialValues(
        appName: 'Fleur',
        packageName: 'fleur',
        version: '0.0.0',
        buildNumber: '0',
        buildSignature: '',
        installerStore: null,
      );
    });

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fleur_layout_test_');
      final docs = await Directory(
        '${tempDir.path}/documents',
      ).create(recursive: true);
      final support = await Directory(
        '${tempDir.path}/support',
      ).create(recursive: true);
      final cache = await Directory(
        '${tempDir.path}/cache',
      ).create(recursive: true);

      PathProviderPlatform.instance = _FakePathProviderPlatform(
        documentsPath: docs.path,
        supportPath: support.path,
        cachePath: cache.path,
      );
      PathManager.resetForTests();
    });

    tearDown(() async {
      PathProviderPlatform.instance = originalPlatform;
      await tempDir.delete(recursive: true);
    });

    testWidgets('License dialog: no overflow on small screens', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        oldOnError?.call(details);
      };

      try {
        await _pumpTestApp(
          tester,
          size: const Size(320, 640),
          textScale: 2.0,
          home: const Scaffold(body: AboutTab()),
        );

        final viewLicenseButton = find.byKey(
          const Key('about_view_license_button'),
        );
        await tester.scrollUntilVisible(
          viewLicenseButton,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(viewLicenseButton);
        await tester.pump(); // start dialog animation
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(AlertDialog), findsOneWidget);
      } finally {
        FlutterError.onError = oldOnError;
      }

      expect(tester.takeException(), isNull);
      expect(errors, isEmpty);
    });

    testWidgets('About actions align to the right on wide screens', (
      tester,
    ) async {
      await _pumpTestApp(
        tester,
        size: const Size(900, 760),
        textScale: 1.0,
        home: const Scaffold(body: AboutTab()),
      );

      final licenseTitle = find.text('MIT License');
      final viewLicenseButton = find.byKey(
        const Key('about_view_license_button'),
      );
      await tester.scrollUntilVisible(
        viewLicenseButton,
        200,
        scrollable: find.byType(Scrollable).first,
      );

      final titleRight = tester.getTopRight(licenseTitle).dx;
      final buttonLeft = tester.getTopLeft(viewLicenseButton).dx;
      expect(buttonLeft, greaterThan(titleRight));
    });

    testWidgets('localizes AboutTab license and shortcuts in zh', (
      tester,
    ) async {
      await _pumpTestApp(
        tester,
        size: const Size(800, 900),
        textScale: 1.0,
        locale: const Locale('zh'),
        home: const Scaffold(body: AboutTab()),
      );

      await tester.scrollUntilVisible(
        find.text('MIT 许可证'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('MIT 许可证'), findsOneWidget);
      expect(find.text('J / K：下一篇 / 上一篇文章'), findsOneWidget);
      expect(find.text('MIT License'), findsNothing);
      expect(find.text('J / K: Next / previous article'), findsNothing);
    });
  });
}
