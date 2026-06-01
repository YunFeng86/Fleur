import 'package:flutter/material.dart';

import 'reader_code_html_renderer.dart';
import 'reader_code_language.dart';
import 'reader_code_models.dart';
import 'reader_code_search_overlay.dart';
import 'reader_code_syntax_adapter.dart';

final class ReaderCodeRenderer {
  const ReaderCodeRenderer({
    ReaderCodeHtmlRenderer htmlRenderer = const ReaderCodeHtmlRenderer(),
    ReaderCodeLanguageResolver languageResolver =
        const ReaderCodeLanguageResolver(),
    ReaderCodeSyntaxAdapter syntaxAdapter = const ReaderCodeSyntaxAdapter(),
  }) : _htmlRenderer = htmlRenderer,
       _languageResolver = languageResolver,
       _syntaxAdapter = syntaxAdapter;

  final ReaderCodeHtmlRenderer _htmlRenderer;
  final ReaderCodeLanguageResolver _languageResolver;
  final ReaderCodeSyntaxAdapter _syntaxAdapter;

  Future<ReaderCodeRenderResult> render(ReaderCodeRenderInput input) async {
    final extraction = _htmlRenderer.extract(input.source);
    final language = _languageResolver.resolveForElements(
      input.source,
      input.pre,
    );
    final plainSpan = TextSpan(text: extraction.text, style: input.baseStyle);
    final TextSpan baseSpan;
    final ReaderCodeSourceKind sourceKind;

    if (extraction.hasTokenStyles) {
      baseSpan = _htmlRenderer.spanFromExtraction(extraction, input.baseStyle);
      sourceKind = ReaderCodeSourceKind.htmlTokens;
    } else if (language?.id == 'diff') {
      baseSpan = _highlightDiffCode(
        extraction.text,
        input.baseStyle,
        brightness: input.brightness,
        errorColor: input.errorColor,
      );
      sourceKind = ReaderCodeSourceKind.syntaxHighlight;
    } else if (extraction.text.length <= input.maxHighlightedCodeLength) {
      final highlighted = await _trySyntaxHighlight(
        extraction.text,
        language?.id,
        input,
      );
      baseSpan = highlighted ?? plainSpan;
      sourceKind = highlighted == null
          ? ReaderCodeSourceKind.plainText
          : ReaderCodeSourceKind.syntaxHighlight;
    } else {
      baseSpan = plainSpan;
      sourceKind = ReaderCodeSourceKind.plainText;
    }

    return ReaderCodeRenderResult(
      text: extraction.text,
      language: language?.id,
      sourceKind: sourceKind,
      searchRanges: extraction.searchRanges,
      span: applyReaderCodeSearchRanges(
        baseSpan,
        searchRanges: extraction.searchRanges,
        currentAnchorId: input.currentAnchorId,
        activeBackground: input.activeSearchBackground,
        background: input.searchBackground,
      ),
    );
  }

  Future<TextSpan?> _trySyntaxHighlight(
    String code,
    String? language,
    ReaderCodeRenderInput input,
  ) async {
    try {
      return await _syntaxAdapter.highlight(
        code,
        language: language,
        brightness: input.brightness,
        baseStyle: input.baseStyle,
      );
    } catch (_) {
      return null;
    }
  }

  static TextSpan _highlightDiffCode(
    String code,
    TextStyle fallbackStyle, {
    required Brightness brightness,
    required Color errorColor,
  }) {
    final dark = brightness == Brightness.dark;
    final addedColor = dark ? const Color(0xFF7EE787) : const Color(0xFF116329);
    final removedColor = dark ? const Color(0xFFFF7B72) : errorColor;
    final addedBackground = addedColor.withAlpha(dark ? 44 : 30);
    final removedBackground = removedColor.withAlpha(dark ? 42 : 28);
    final spans = <TextSpan>[];

    var start = 0;
    while (start < code.length) {
      final newline = code.indexOf('\n', start);
      final end = newline < 0 ? code.length : newline + 1;
      final line = code.substring(start, end);
      final marker = line.isEmpty ? 0 : line.codeUnitAt(0);
      final style = switch (marker) {
        43 => TextStyle(color: addedColor, backgroundColor: addedBackground),
        45 => TextStyle(
          color: removedColor,
          backgroundColor: removedBackground,
        ),
        _ => null,
      };
      spans.add(TextSpan(text: line, style: style));
      start = end;
    }

    return TextSpan(style: fallbackStyle, children: spans);
  }
}
