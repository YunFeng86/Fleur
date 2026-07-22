import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/features/settings/settings.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/translation_ai_settings_providers.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/settings/translation_ai_settings.dart';
import 'package:fleur/theme/fleur_icons.dart';
import 'package:fleur/ui/settings/settings_targets.dart';
import 'package:fleur/widgets/app_scrollbar.dart';

import '../../../../test_utils/critical_workflow_test_support.dart';

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
      home: Scaffold(
        body: TranslationAiServicesTab(
          targetController: SettingsTargetController(),
        ),
      ),
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

  testWidgets(
    'only enabled services appear in translation and summary pickers',
    (tester) async {
      final store = FakeTranslationAiSettingsStore(
        TranslationAiSettings.defaults().copyWith(
          aiServices: const [
            AiServiceConfig(
              id: 'enabled',
              name: 'Enabled service',
              apiType: AiServiceApiType.openAiResponses,
              baseUrl: 'https://enabled.example.com',
              defaultModel: 'model',
              enabled: true,
            ),
            AiServiceConfig(
              id: 'disabled',
              name: 'Disabled service',
              apiType: AiServiceApiType.openAiResponses,
              baseUrl: 'https://disabled.example.com',
              defaultModel: 'model',
              enabled: false,
            ),
          ],
        ),
      );

      await pumpTab(tester, store: store);

      await tester.tap(find.text('Translation provider'));
      await tester.pumpAndSettle();
      expect(find.text('AI: Enabled service'), findsOneWidget);
      expect(find.text('AI: Disabled service'), findsNothing);
      await tester.tap(find.text('AI: Enabled service'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('AI summary service'));
      await tester.pumpAndSettle();
      final summarySheet = find.byType(BottomSheet);
      expect(
        find.descendant(
          of: summarySheet,
          matching: find.text('Enabled service'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: summarySheet,
          matching: find.text('Disabled service'),
        ),
        findsNothing,
      );
    },
  );

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

      expect(find.text('Follow app language \u00B7 French'), findsOneWidget);
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
    'AI service rows stay operable without overflow on narrow widths',
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
}
