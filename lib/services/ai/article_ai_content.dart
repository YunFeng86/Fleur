import 'package:html/parser.dart' as html_parser;

class ArticleAiContent {
  const ArticleAiContent._();

  static String extractPlainText(String html) {
    final trimmed = html.trim();
    if (trimmed.isEmpty) return '';
    final doc = html_parser.parse(trimmed);
    for (final e in doc.querySelectorAll('script,style,noscript')) {
      e.remove();
    }
    return (doc.body?.text ?? '')
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String sampleSummaryContent(String content) {
    const maxChars = 40000;
    const separator = '\n\n[...]\n\n';
    final normalized = content.trim();
    if (normalized.length <= maxChars) return normalized;

    final available = maxChars - separator.length;
    final headChars = (available * 0.6).round();
    final tailChars = available - headChars;
    final head = normalized.substring(0, headChars).trimRight();
    final tail = normalized.substring(normalized.length - tailChars).trimLeft();
    return '$head$separator$tail';
  }
}
