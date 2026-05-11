import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/services/settings/translation_ai_settings.dart';

void main() {
  test('fromJson trims optional strings and service fields', () {
    final settings = TranslationAiSettings.fromJson(<String, Object?>{
      'aiSummaryServiceId': ' svc-1 ',
      'targetLanguageTag': ' zh-Hant-HK ',
      'aiSummaryPrompt': ' summarize ',
      'aiTranslationPrompt': ' translate ',
      'tpmLimit': 120,
      'aiServices': [
        <String, Object?>{
          'id': ' svc-1 ',
          'name': ' Service ',
          'apiType': 'openAiResponses',
          'baseUrl': ' https://api.example.com ',
          'defaultModel': ' gpt-5-mini ',
          'enabled': true,
        },
      ],
      'defaultAiServiceId': ' svc-1 ',
      'deepLX': <String, Object?>{'baseUrl': ' https://deeplx.example.com '},
    });

    expect(settings.aiSummaryServiceId, 'svc-1');
    expect(settings.targetLanguageTag, 'zh-Hant');
    expect(settings.aiSummaryPrompt, 'summarize');
    expect(settings.aiTranslationPrompt, 'translate');
    expect(settings.defaultAiServiceId, 'svc-1');
    expect(settings.aiServices.single.id, 'svc-1');
    expect(settings.aiServices.single.name, 'Service');
    expect(
      settings.aiServices.single.apiType,
      AiServiceApiType.openAiResponses,
    );
    expect(settings.aiServices.single.baseUrl, 'https://api.example.com');
    expect(settings.aiServices.single.defaultModel, 'gpt-5-mini');
    expect(settings.deepLX.baseUrl, 'https://deeplx.example.com');
  });

  test(
    'normalized drops invalid service references and duplicate languages',
    () {
      final settings = TranslationAiSettings.fromJson(<String, Object?>{
        'translationProvider': <String, Object?>{
          'kind': 'aiService',
          'aiServiceId': ' disabled ',
        },
        'aiSummaryServiceId': 'missing',
        'defaultAiServiceId': 'disabled',
        'disabledTranslationReminderLanguages': [
          ' en-GB ',
          ' en ',
          '',
          'und',
          'zh-Hans-CN',
          'zh',
        ],
        'aiServices': [
          <String, Object?>{'id': 'disabled', 'enabled': false},
          <String, Object?>{'id': ' enabled ', 'enabled': true},
          <String, Object?>{'id': 'enabled', 'name': 'Duplicate'},
        ],
      });

      expect(
        settings.translationProvider,
        const TranslationProviderSelection.googleWeb(),
      );
      expect(settings.aiSummaryServiceId, isNull);
      expect(settings.defaultAiServiceId, isNull);
      expect(settings.aiServices.map((s) => s.id), <String>[
        'disabled',
        'enabled',
      ]);
      expect(settings.disabledTranslationReminderLanguages, <String>[
        'en',
        'zh-Hans',
      ]);
    },
  );

  test('fromJson preserves legacy provider string and endpoint fallbacks', () {
    final deepL = TranslationAiSettings.fromJson(<String, Object?>{
      'translationProvider': 'deepLApi',
      'deepL': <String, Object?>{'endpoint': 'pro'},
    });
    final fallback = TranslationAiSettings.fromJson(<String, Object?>{
      'translationProvider': <String, Object?>{'kind': 'not-a-provider'},
      'deepL': <String, Object?>{'endpoint': 'enterprise'},
    });

    expect(
      deepL.translationProvider,
      const TranslationProviderSelection.deepLApi(),
    );
    expect(deepL.deepL.endpoint, DeepLEndpoint.pro);
    expect(
      fallback.translationProvider,
      const TranslationProviderSelection.googleWeb(),
    );
    expect(fallback.deepL.endpoint, DeepLEndpoint.free);
  });
}
