import 'package:flutter/material.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

final class ReaderCodeSyntaxAdapter {
  const ReaderCodeSyntaxAdapter();

  static const List<String> supportedLanguages = [
    'css',
    'dart',
    'go',
    'html',
    'java',
    'javascript',
    'json',
    'kotlin',
    'python',
    'rust',
    'sql',
    'swift',
    'typescript',
    'yaml',
  ];

  static Future<void>? _syntaxHighlightInit;

  Future<TextSpan?> highlight(
    String code, {
    required String? language,
    required Brightness brightness,
    required TextStyle baseStyle,
  }) async {
    final normalized = syntaxLanguageFor(language);
    if (normalized == null) return null;
    _syntaxHighlightInit ??= Highlighter.initialize(supportedLanguages);
    await _syntaxHighlightInit;
    final highlighter = Highlighter(
      language: normalized,
      theme: await HighlighterTheme.loadForBrightness(brightness),
    );
    return colorOnlySpan(highlighter.highlight(code), baseStyle);
  }

  static String? syntaxLanguageFor(String? language) {
    final normalized = switch (language) {
      'jsx' => 'javascript',
      'tsx' => 'typescript',
      'shell' => null,
      'markdown' => null,
      'plain' || 'plaintext' || 'text' => null,
      _ => language,
    };
    if (normalized == null) return null;
    return supportedLanguages.contains(normalized) ? normalized : null;
  }

  static TextSpan colorOnlySpan(TextSpan span, TextStyle baseStyle) {
    return TextSpan(
      text: span.text,
      style: baseStyle,
      children: _colorOnlyChildren(span.children),
    );
  }

  static List<InlineSpan>? _colorOnlyChildren(List<InlineSpan>? children) {
    if (children == null) return null;
    return [
      for (final child in children)
        if (child is TextSpan)
          TextSpan(
            text: child.text,
            style: _highlightColorOnly(child.style),
            children: _colorOnlyChildren(child.children),
          )
        else
          child,
    ];
  }

  static TextStyle? _highlightColorOnly(TextStyle? style) {
    final color = style?.color;
    return color == null ? null : TextStyle(color: color);
  }
}
