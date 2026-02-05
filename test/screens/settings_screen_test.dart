import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';
import 'package:flutter_reader/screens/settings_screen.dart';

void main() {
  // Helper to pump the Settings Screen with a specific width
  Future<void> pumpSettingsScreen(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Settings Screen starts with List in Narrow Mode', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 400); // Narrow

    // Should see "Settings" title
    expect(find.text('Settings'), findsOneWidget);
    // Should find App Preferences in the list
    expect(find.text('App Preferences'), findsOneWidget);
    // Should NOT see detail content (e.g. "System Language" dropdown from App Preferences)
    // Note: App Preferences tab has "Language" header.
    expect(find.text('System Language'), findsNothing);
  });

  testWidgets('Settings Screen navigates to Detail in Narrow Mode', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 400);

    // Tap App Preferences
    await tester.tap(find.text('App Preferences'));
    await tester.pumpAndSettle();

    // Should now see Detail Content
    expect(find.text('System language'), findsOneWidget);

    // Verify Back Button works
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Back to list
    expect(find.text('System Language'), findsNothing);
    expect(find.text('App Preferences'), findsOneWidget);
  });

  testWidgets('Settings Screen restores state when resizing Narrow -> Wide', (
    tester,
  ) async {
    // Start Narrow
    await pumpSettingsScreen(tester, 400);

    // Select App Preferences
    await tester.tap(find.text('App Preferences'));
    await tester.pumpAndSettle();
    expect(find.text('System language'), findsOneWidget);

    // Resize to Wide
    tester.view.physicalSize = const Size(1000, 800);
    await tester.pumpAndSettle();

    // Should see Split View
    // Sidebar item should be selected (visual check hard in test, but we check content presence)
    // Content should be visible
    expect(find.text('System language'), findsOneWidget);

    // Check if Sidebar is also visible (Wide mode has both)
    // Sidebar list item "App Preferences" should exist
    expect(
      find.text('App Preferences'),
      findsAny,
    ); // Might find 2 (sidebar + header?) or just 1
  });

  testWidgets('Settings Screen defaults to first item in Wide Mode', (
    tester,
  ) async {
    await pumpSettingsScreen(tester, 1000); // Wide

    // Uses default selection (index 0 -> App Preferences)
    expect(find.text('System language'), findsOneWidget);
  });

  testWidgets('AppLocalizations uses strict pathNotFound message in English', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            expect(
              l10n.pathNotFound('/tmp/example'),
              'Path does not exist: /tmp/example',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('AppLocalizations uses strict pathNotFound message in Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            expect(l10n.pathNotFound('/tmp/example'), '路径不存在：/tmp/example');
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets(
    'AppLocalizations uses strict pathNotFound message in Chinese Traditional',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              expect(l10n.pathNotFound('/tmp/example'), '路徑不存在：/tmp/example');
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    },
  );

  testWidgets('AppLocalizations uses strict openFailedGeneral in English', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            expect(
              l10n.openFailedGeneral,
              'Couldn\'t open this location. Check permissions and try again.',
            );
            expect(
              l10n.macosMenuLanguageRestartHint,
              'Menu bar language may require restarting the app to fully apply.',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('AppLocalizations uses strict openFailedGeneral in Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            expect(l10n.openFailedGeneral, '无法打开该位置，请检查权限或稍后重试。');
            expect(l10n.macosMenuLanguageRestartHint, '菜单栏语言可能需要重启应用才能完全生效。');
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets(
    'AppLocalizations uses strict openFailedGeneral in Chinese Traditional',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              expect(l10n.openFailedGeneral, '無法打開該位置，請檢查權限或稍後重試。');
              expect(
                l10n.macosMenuLanguageRestartHint,
                '選單列語言可能需要重新啟動應用程式才能完全生效。',
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    },
  );
}
