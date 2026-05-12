import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/translation_ai_settings_providers.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/translation_ai_settings.dart';
import 'package:fleur/theme/fleur_icons.dart';
import 'package:fleur/ui/settings/translation_ai/ai_service_editor_dialog.dart';
import 'package:fleur/ui/settings/translation_ai/ai_service_templates.dart';
import 'package:fleur/ui/settings/tabs/translation_ai_services_tab.dart';
import 'package:fleur/widgets/app_scrollbar.dart';

import '../../test_utils/critical_workflow_test_support.dart';

void main() {
  Future<void> pumpTab(
    WidgetTester tester, {
    required FakeTranslationAiSettingsStore store,
    FakeTranslationAiSecretStore? secrets,
    AppSettings? appSettings,
    Locale locale = const Locale('en'),
    Size size = const Size(900, 1200),
  }) async {
    await pumpLocalizedTestApp(
      tester,
      home: const Scaffold(body: TranslationAiServicesTab()),
      overrides: [
        appSettingsStoreProvider.overrideWithValue(
          FakeAppSettingsStore(appSettings ?? AppSettings.defaults()),
        ),
        translationAiSettingsStoreProvider.overrideWithValue(store),
        translationAiSecretStoreProvider.overrideWithValue(
          secrets ?? FakeTranslationAiSecretStore(),
        ),
      ],
      locale: locale,
      size: size,
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpEditorLauncher(
    WidgetTester tester, {
    required FakeTranslationAiSettingsStore store,
    FakeTranslationAiSecretStore? secrets,
    Locale locale = const Locale('en'),
    AiServiceTemplate? template,
  }) async {
    await pumpLocalizedTestApp(
      tester,
      locale: locale,
      home: Scaffold(
        body: Center(
          child: Consumer(
            builder: (context, ref, _) {
              return FilledButton(
                onPressed: () async {
                  await showAiServiceEditorDialog(
                    context,
                    ref,
                    template: template ?? aiServiceTemplates.first,
                  );
                },
                child: const Text('open ai editor'),
              );
            },
          ),
        ),
      ),
      overrides: [
        appSettingsStoreProvider.overrideWithValue(
          FakeAppSettingsStore(AppSettings.defaults()),
        ),
        translationAiSettingsStoreProvider.overrideWithValue(store),
        translationAiSecretStoreProvider.overrideWithValue(
          secrets ?? FakeTranslationAiSecretStore(),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('updates translation provider and target language selections', (
    tester,
  ) async {
    final store = FakeTranslationAiSettingsStore(
      TranslationAiSettings.defaults(),
    );

    await pumpTab(tester, store: store);

    await tester.tap(find.text('Translation provider'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bing Translate (web)').last);
    await tester.pumpAndSettle();

    expect(
      store.settings.translationProvider.kind,
      TranslationProviderKind.bingWeb,
    );

    await tester.tap(find.text('Target language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Japanese').last);
    await tester.pumpAndSettle();

    expect(store.settings.targetLanguageTag, 'ja');
  });

  testWidgets('translation provider sheet uses AppScrollbar', (tester) async {
    final store = FakeTranslationAiSettingsStore(
      TranslationAiSettings.defaults(),
    );

    await pumpTab(tester, store: store);

    await tester.tap(find.text('Translation provider'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(AppScrollbar),
      ),
      findsOneWidget,
    );
  });

  testWidgets('resets custom AI translation prompt to default', (tester) async {
    final store = FakeTranslationAiSettingsStore(
      TranslationAiSettings.defaults().copyWith(
        aiTranslationPrompt: 'Translate this in a custom way.',
      ),
    );

    await pumpTab(tester, store: store);

    await tester.tap(find.text('AI translation prompt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset to default'));
    await tester.pumpAndSettle();

    expect(store.settings.aiTranslationPrompt, isNull);
  });

  testWidgets('shows error for invalid DeepLX base URL and keeps settings', (
    tester,
  ) async {
    final store = FakeTranslationAiSettingsStore(
      TranslationAiSettings.defaults().copyWith(
        deepLX: const DeepLXSettings(baseUrl: 'https://deeplx.initial'),
      ),
    );

    await pumpTab(tester, store: store);

    await tester.tap(find.text('DeepLX'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'notaurl');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid base URL'), findsOneWidget);
    expect(store.settings.deepLX.baseUrl, 'https://deeplx.initial');
  });

  testWidgets('saves DeepL endpoint and API key from dialog', (tester) async {
    final store = FakeTranslationAiSettingsStore(
      TranslationAiSettings.defaults(),
    );
    final secrets = FakeTranslationAiSecretStore();

    await pumpTab(tester, store: store, secrets: secrets);

    await tester.tap(find.text('DeepL (API)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pro'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'deep-key');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(store.settings.deepL.endpoint, DeepLEndpoint.pro);
    expect(await secrets.getDeepLApiKey(), 'deep-key');
  });

  testWidgets('shows canonical target language name instead of raw tag', (
    tester,
  ) async {
    final store = FakeTranslationAiSettingsStore(
      TranslationAiSettings.defaults().copyWith(
        targetLanguageTag: 'zh-Hans-CN',
      ),
    );

    await pumpTab(tester, store: store);

    expect(find.text('Chinese (Simplified)'), findsOneWidget);
    expect(find.text('zh-Hans-CN'), findsNothing);
  });

  testWidgets(
    'follow app language uses resolved target identity instead of fallback UI locale',
    (tester) async {
      final store = FakeTranslationAiSettingsStore(
        TranslationAiSettings.defaults(),
      );

      await pumpTab(
        tester,
        store: store,
        appSettings: AppSettings.defaults().copyWith(localeTag: 'fr-FR'),
        locale: const Locale('en'),
      );

      expect(find.text('Follow app language · French'), findsOneWidget);
    },
  );

  testWidgets('localizes translation provider labels in zh_Hant', (
    tester,
  ) async {
    final store = FakeTranslationAiSettingsStore(
      TranslationAiSettings.defaults().copyWith(
        translationProvider: const TranslationProviderSelection.aiService(
          'svc-1',
        ),
        aiServices: const [
          AiServiceConfig(
            id: 'svc-1',
            name: '主要服務',
            apiType: AiServiceApiType.openAiResponses,
            baseUrl: 'https://api.example.com/v1',
            defaultModel: 'gpt-test',
            enabled: true,
          ),
        ],
      ),
    );

    await pumpTab(
      tester,
      store: store,
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );

    expect(find.text('AI：主要服務'), findsOneWidget);

    await tester.tap(find.text('翻譯提供方'));
    await tester.pumpAndSettle();

    expect(find.text('Google 翻譯（網頁）'), findsWidgets);
    expect(find.text('Bing 翻譯（網頁）'), findsWidgets);
    expect(find.text('百度翻譯（API）'), findsWidgets);
    expect(find.text('DeepL（API）'), findsWidgets);
    expect(find.text('DeepLX'), findsWidgets);
    expect(find.text('Bing Translate (web)'), findsNothing);
  });

  testWidgets(
    'ai service rows stay operable without overflow on narrow widths',
    (tester) async {
      final store = FakeTranslationAiSettingsStore(
        TranslationAiSettings.defaults().copyWith(
          aiServices: const [
            AiServiceConfig(
              id: 'svc-1',
              name: 'Primary AI Service',
              apiType: AiServiceApiType.openAiResponses,
              baseUrl: 'https://api.example.com/v1',
              defaultModel: 'gpt-5-mini-long-model-name',
              enabled: true,
            ),
          ],
          defaultAiServiceId: 'svc-1',
        ),
      );

      final errors = <FlutterErrorDetails>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        oldOnError?.call(details);
      };

      try {
        await pumpTab(tester, store: store, size: const Size(320, 900));

        await tester.scrollUntilVisible(
          find.text('Primary AI Service'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.tap(find.byType(Switch).last);
        await tester.pumpAndSettle();

        expect(store.settings.aiServices.single.enabled, isFalse);
        expect(find.byIcon(FleurIcons.moreVertical), findsWidgets);
      } finally {
        FlutterError.onError = oldOnError;
      }

      expect(tester.takeException(), isNull);
      expect(errors, isEmpty);
    },
  );

  testWidgets('AI service editor shows inline URL errors and refocuses URL', (
    tester,
  ) async {
    final store = FakeTranslationAiSettingsStore(
      TranslationAiSettings.defaults(),
    );

    await pumpEditorLauncher(tester, store: store);

    await tester.tap(find.text('open ai editor'));
    await tester.pumpAndSettle();
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

        await pumpEditorLauncher(tester, store: store, locale: testCase.locale);

        await tester.tap(find.text('open ai editor'));
        await tester.pumpAndSettle();

        expect(find.text(testCase.nameLabel), findsOneWidget);
        expect(find.text(testCase.defaultModelLabel), findsOneWidget);
        expect(find.text(testCase.helperText), findsOneWidget);
        expect(find.text(testCase.unexpectedLabel), findsNothing);
        expect(find.text(testCase.unexpectedHelper), findsNothing);
      },
    );
  }
}
