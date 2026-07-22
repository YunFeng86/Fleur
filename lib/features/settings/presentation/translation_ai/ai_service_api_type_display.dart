import 'package:flutter/material.dart';

import 'package:fleur/services/settings/translation_ai_settings.dart';
import 'package:fleur/theme/fleur_icons.dart';

String apiTypeLabel(AiServiceApiType apiType) => switch (apiType) {
  AiServiceApiType.openAiChatCompletions => 'OpenAI (Chat Completions)',
  AiServiceApiType.openAiResponses => 'OpenAI (Responses)',
  AiServiceApiType.gemini => 'Gemini',
  AiServiceApiType.anthropic => 'Anthropic',
};

IconData apiTypeIcon(AiServiceApiType apiType) => switch (apiType) {
  AiServiceApiType.openAiChatCompletions => FleurIcons.aiChat,
  AiServiceApiType.openAiResponses => FleurIcons.aiResponses,
  AiServiceApiType.gemini => FleurIcons.aiGemini,
  AiServiceApiType.anthropic => FleurIcons.aiAnthropic,
};
