import '../../l10n/app_localizations.dart';
import '../../utils/prompt_template.dart';

class ArticleAiPromptPolicy {
  const ArticleAiPromptPolicy._();

  static const summaryContractVersion = 'summary-v2';
  static const translationContractVersion = 'translation-v2';

  static const summarySystemInstruction = '''
You are a careful article summarizer.
Use only the information provided by the user prompt.
Return only the final summary in plain text.
Keep the summary concise, factual, and easy to scan.
Follow the target language requested in the user prompt.
Do not add preambles like "Summary:" unless the article content itself requires it.
''';

  static const translationSystemInstruction = '''
You are translating a single article fragment, not an entire article.
Return only the translated fragment in plain text.
Do not add explanations, notes, or surrounding quotation marks.
Do not wrap the result in code fences or markup.
Preserve proper nouns, numbers, URLs, and the original formatting intent when possible.
Follow the target language requested in the user prompt.
''';

  static String summaryTemplate(AppLocalizations l10n, String? configured) {
    final trimmed = (configured ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    return l10n.defaultAiSummaryPromptTemplate(
      PromptTemplate.token(PromptTemplate.varLanguage),
      PromptTemplate.token(PromptTemplate.varTitle),
      PromptTemplate.token(PromptTemplate.varContent),
    );
  }

  static String translationTemplate(AppLocalizations l10n, String? configured) {
    final trimmed = (configured ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    return l10n.defaultAiTranslationPromptTemplate(
      PromptTemplate.token(PromptTemplate.varLanguage),
      PromptTemplate.token(PromptTemplate.varTitle),
      PromptTemplate.token(PromptTemplate.varContent),
    );
  }

  static String contractHash({
    required String version,
    required String systemInstruction,
    required String userTemplate,
  }) {
    return PromptTemplate.hash(
      [
        version.trim(),
        systemInstruction.trim(),
        userTemplate.trim(),
      ].join('\n\n'),
    );
  }
}
