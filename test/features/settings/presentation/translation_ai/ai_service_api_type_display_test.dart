import 'package:flutter/widgets.dart' show IconData;
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/features/settings/presentation/translation_ai/ai_service_api_type_display.dart';
import 'package:fleur/services/settings/translation_ai_settings.dart';
import 'package:fleur/theme/fleur_icons.dart';

void main() {
  const expectedDisplays = <AiServiceApiType, ({String label, IconData icon})>{
    AiServiceApiType.openAiChatCompletions: (
      label: 'OpenAI (Chat Completions)',
      icon: FleurIcons.aiChat,
    ),
    AiServiceApiType.openAiResponses: (
      label: 'OpenAI (Responses)',
      icon: FleurIcons.aiResponses,
    ),
    AiServiceApiType.gemini: (label: 'Gemini', icon: FleurIcons.aiGemini),
    AiServiceApiType.anthropic: (
      label: 'Anthropic',
      icon: FleurIcons.aiAnthropic,
    ),
  };

  test('provides stable display metadata for every AI service API type', () {
    expect(expectedDisplays.keys, unorderedEquals(AiServiceApiType.values));

    for (final apiType in AiServiceApiType.values) {
      final expected = expectedDisplays[apiType];

      expect(
        expected,
        isNotNull,
        reason: 'Missing display expectation for $apiType',
      );
      expect(apiTypeLabel(apiType), expected!.label);
      expect(apiTypeIcon(apiType), expected.icon);
    }
  });
}
