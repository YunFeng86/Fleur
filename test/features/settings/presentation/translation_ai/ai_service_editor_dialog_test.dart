import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/features/settings/settings.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/translation_ai_settings_providers.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/translation_ai_settings.dart';
import 'package:fleur/ui/settings/settings_targets.dart';

import '../../../../test_utils/critical_workflow_test_support.dart';

void main() {
  Future<void> pumpTab(
    WidgetTester tester, {
    required FakeTranslationAiSettingsStore store,
    Locale locale = const Locale('en'),
  }) async {
    await pumpLocalizedTestApp(
      tester,
      locale: locale,
      home: Scaffold(
        body: TranslationAiServicesTab(
          targetController: SettingsTargetController(),
        ),
      ),
      overrides: [
        appSettingsStoreProvider.overrideWithValue(
          FakeAppSettingsStore(AppSettings.defaults()),
        ),
        translationAiSettingsStoreProvider.overrideWithValue(store),
        translationAiSecretStoreProvider.overrideWithValue(
          FakeTranslationAiSecretStore(),
        ),
      ],
      size: const Size(900, 1200),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAiServiceEditor(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const Key('translation_ai_add_service_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom: OpenAI (Chat Completions)'));
    await tester.pumpAndSettle();
  }

  testWidgets('adds a service through the template and editor workflow', (
    tester,
  ) async {
    final store = FakeTranslationAiSettingsStore(
      TranslationAiSettings.defaults(),
    );

    await pumpTab(tester, store: store);
    await openAiServiceEditor(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    expect(store.settings.aiServices, hasLength(1));
    expect(
      store.settings.aiServices.single.name,
      'Custom: OpenAI (Chat Completions)',
    );
    expect(find.text('Custom: OpenAI (Chat Completions)'), findsWidgets);
  });

  testWidgets('AI service editor shows inline URL errors and refocuses URL', (
    tester,
  ) async {
    final store = FakeTranslationAiSettingsStore(
      TranslationAiSettings.defaults(),
    );

    await pumpTab(tester, store: store);
    await openAiServiceEditor(tester);
    await tester.enterText(find.byType(TextField).at(1), 'notaurl');
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid base URL'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byType(TextField).at(1))
          .focusNode
          ?.hasFocus,
      isTrue,
    );
  });

  for (final testCase
      in <
        ({
          Locale locale,
          String languageTag,
          String nameLabel,
          String defaultModelLabel,
          String helperText,
          String unexpectedLabel,
          String unexpectedHelper,
        })
      >[
        (
          locale: const Locale('en'),
          languageTag: 'en',
          nameLabel: 'Name',
          defaultModelLabel: 'Default model',
          helperText: 'Leave blank to clear the saved API key.',
          unexpectedLabel: 'Default Model',
          unexpectedHelper: '留空将清除已保存的 API Key。',
        ),
        (
          locale: const Locale('zh'),
          languageTag: 'zh',
          nameLabel: '名称',
          defaultModelLabel: '默认模型',
          helperText: '留空会清除已保存的 API Key。',
          unexpectedLabel: 'Name',
          unexpectedHelper: 'Leave blank to clear the saved API key.',
        ),
        (
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
          ),
          languageTag: 'zh_Hant',
          nameLabel: '名稱',
          defaultModelLabel: '預設模型',
          helperText: '留空會清除已儲存的 API Key。',
          unexpectedLabel: '名称',
          unexpectedHelper: '留空将清除已保存的 API Key。',
        ),
      ]) {
    testWidgets(
      'AI service editor localizes labels in ${testCase.languageTag}',
      (tester) async {
        final store = FakeTranslationAiSettingsStore(
          TranslationAiSettings.defaults(),
        );

        await pumpTab(tester, store: store, locale: testCase.locale);
        await openAiServiceEditor(tester);

        expect(find.text(testCase.nameLabel), findsOneWidget);
        expect(find.text(testCase.defaultModelLabel), findsOneWidget);
        expect(find.text(testCase.helperText), findsOneWidget);
        expect(find.text(testCase.unexpectedLabel), findsNothing);
        expect(find.text(testCase.unexpectedHelper), findsNothing);
      },
    );
  }
}
