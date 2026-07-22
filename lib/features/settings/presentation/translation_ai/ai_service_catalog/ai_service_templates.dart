import 'package:flutter/material.dart';

import 'package:fleur/services/settings/translation_ai_settings.dart';
import 'package:fleur/theme/fleur_icons.dart';

class AiServiceTemplate {
  const AiServiceTemplate({
    required this.name,
    required this.apiType,
    required this.baseUrl,
    this.defaultModel = '',
  });

  final String name;
  final AiServiceApiType apiType;
  final String baseUrl;
  final String defaultModel;
}

const List<AiServiceTemplate> aiServiceTemplates = <AiServiceTemplate>[
  AiServiceTemplate(
    name: 'Custom: OpenAI (Chat Completions)',
    apiType: AiServiceApiType.openAiChatCompletions,
    baseUrl: '',
  ),
  AiServiceTemplate(
    name: 'Custom: OpenAI (Responses)',
    apiType: AiServiceApiType.openAiResponses,
    baseUrl: '',
  ),
  AiServiceTemplate(
    name: 'Custom: Gemini',
    apiType: AiServiceApiType.gemini,
    baseUrl: '',
  ),
  AiServiceTemplate(
    name: 'Custom: Anthropic',
    apiType: AiServiceApiType.anthropic,
    baseUrl: '',
  ),
  AiServiceTemplate(
    name: 'OpenAI',
    apiType: AiServiceApiType.openAiChatCompletions,
    baseUrl: 'https://api.openai.com/v1',
  ),
  AiServiceTemplate(
    name: 'Gemini',
    apiType: AiServiceApiType.gemini,
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
  ),
  AiServiceTemplate(
    name: 'Anthropic',
    apiType: AiServiceApiType.anthropic,
    baseUrl: 'https://api.anthropic.com',
  ),
  AiServiceTemplate(
    name: '硅基流动 (SiliconFlow)',
    apiType: AiServiceApiType.openAiChatCompletions,
    baseUrl: 'https://api.siliconflow.cn/v1',
  ),
  AiServiceTemplate(
    name: '智谱开放平台 (Zhipu)',
    apiType: AiServiceApiType.openAiChatCompletions,
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
  ),
  AiServiceTemplate(
    name: 'DeepSeek（深度求索）',
    apiType: AiServiceApiType.openAiChatCompletions,
    baseUrl: 'https://api.deepseek.com/v1',
  ),
  AiServiceTemplate(
    name: 'New API',
    apiType: AiServiceApiType.openAiChatCompletions,
    baseUrl: '',
  ),
  AiServiceTemplate(
    name: 'OpenRouter',
    apiType: AiServiceApiType.openAiChatCompletions,
    baseUrl: 'https://openrouter.ai/api/v1',
  ),
  AiServiceTemplate(
    name: 'ModelScope 魔搭',
    apiType: AiServiceApiType.openAiChatCompletions,
    baseUrl: '',
  ),
];

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
