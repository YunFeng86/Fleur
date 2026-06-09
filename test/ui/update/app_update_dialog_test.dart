import 'dart:async';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/services/update/app_update_manifest.dart';
import 'package:fleur/theme/app_theme.dart';
import 'package:fleur/ui/update/app_update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows English notes when locale-specific notes are missing', (
    tester,
  ) async {
    await _pumpDialogLauncher(tester, locale: const Locale('fr'));

    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle version 0.1.5 disponible'), findsOneWidget);
    expect(find.text('Notes de version'), findsOneWidget);
    expect(find.text('- Fixed a startup issue.'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Ouvrir la page de la version'), findsOneWidget);
  });

  testWidgets('shows localized notes when matching update notes exist', (
    tester,
  ) async {
    await _pumpDialogLauncher(tester, locale: const Locale('zh'));

    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本 0.1.5'), findsOneWidget);
    expect(find.text('更新日志'), findsOneWidget);
    expect(find.text('- 修复启动问题。'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('去官网更新'), findsOneWidget);
  });
}

Future<void> _pumpDialogLauncher(
  WidgetTester tester, {
  required Locale locale,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  unawaited(
                    showAppUpdateDialog(context, manifest: _manifest()),
                  );
                },
                child: const Text('open dialog'),
              ),
            ),
          );
        },
      ),
    ),
  );
}

AppUpdateManifest _manifest() {
  return AppUpdateManifest.fromJson({
    'schemaVersion': 1,
    'channel': 'stable',
    'version': '0.1.5',
    'tag': 'v0.1.5',
    'releaseUrl': 'https://github.com/ZeyrMe/Fleur/releases/tag/v0.1.5',
    'notes': {'en': '- Fixed a startup issue.', 'zh': '- 修复启动问题。'},
  });
}
