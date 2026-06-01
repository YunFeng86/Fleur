import 'package:flutter/material.dart';

import 'reader_code_html_renderer.dart';
import 'reader_code_language.dart';
import 'reader_code_models.dart';
import 'reader_code_token_overlay.dart';
import 'reader_code_syntax_adapter.dart';
import 'reader_code_tokenizer.dart';

final class ReaderCodeRenderer {
  const ReaderCodeRenderer({
    ReaderCodeHtmlRenderer htmlRenderer = const ReaderCodeHtmlRenderer(),
    ReaderCodeLanguageResolver languageResolver =
        const ReaderCodeLanguageResolver(),
    ReaderCodeSyntaxAdapter syntaxAdapter = const ReaderCodeSyntaxAdapter(),
    ReaderCodeTokenizer tokenizer = const ReaderCodeTokenizer(),
  }) : _htmlRenderer = htmlRenderer,
       _languageResolver = languageResolver,
       _syntaxAdapter = syntaxAdapter,
       _tokenizer = tokenizer;

  final ReaderCodeHtmlRenderer _htmlRenderer;
  final ReaderCodeLanguageResolver _languageResolver;
  final ReaderCodeSyntaxAdapter _syntaxAdapter;
  final ReaderCodeTokenizer _tokenizer;

  Future<ReaderCodeRenderResult> render(ReaderCodeRenderInput input) async {
    final extraction = _htmlRenderer.extract(input.source);
    final language = _languageResolver.resolveForElements(
      input.source,
      input.pre,
    );
    final baseTokens = _applySearchOverlay(
      extraction.tokens,
      searchRanges: extraction.searchRanges,
      currentAnchorId: input.currentAnchorId,
    );
    final ReaderCodeSourceKind sourceKind;

    if (extraction.hasTokenStyles) {
      sourceKind = ReaderCodeSourceKind.htmlTokens;
    } else if (language?.id == 'diff') {
      final diffTokens = _applySearchOverlay(
        _highlightDiffTokens(extraction.text),
        searchRanges: extraction.searchRanges,
        currentAnchorId: input.currentAnchorId,
      );
      sourceKind = ReaderCodeSourceKind.internalTokenizer;
      return ReaderCodeRenderResult(
        document: ReaderCodeDocument.fromTokens(
          text: extraction.text,
          language: language,
          sourceKind: sourceKind,
          tokens: diffTokens,
          searchRanges: extraction.searchRanges,
        ),
      );
    } else if (extraction.text.length <= input.maxHighlightedCodeLength) {
      final tokenized = _tokenizer.tokenize(extraction.text, language?.id);
      if (tokenized != null) {
        final overlayTokens = _applySearchOverlay(
          tokenized,
          searchRanges: extraction.searchRanges,
          currentAnchorId: input.currentAnchorId,
        );
        return ReaderCodeRenderResult(
          document: ReaderCodeDocument.fromTokens(
            text: extraction.text,
            language: language,
            sourceKind: ReaderCodeSourceKind.internalTokenizer,
            tokens: overlayTokens,
            searchRanges: extraction.searchRanges,
          ),
        );
      }
      final highlighted = await _trySyntaxHighlight(
        extraction.text,
        language?.id,
        input,
      );
      if (highlighted != null) {
        final highlightedTokens = _tokensFromSpan(highlighted, extraction.text);
        final overlayTokens = _applySearchOverlay(
          highlightedTokens,
          searchRanges: extraction.searchRanges,
          currentAnchorId: input.currentAnchorId,
        );
        return ReaderCodeRenderResult(
          document: ReaderCodeDocument.fromTokens(
            text: extraction.text,
            language: language,
            sourceKind: ReaderCodeSourceKind.syntaxHighlightFallback,
            tokens: overlayTokens,
            searchRanges: extraction.searchRanges,
          ),
        );
      }
      sourceKind = ReaderCodeSourceKind.plainText;
    } else {
      sourceKind = ReaderCodeSourceKind.plainText;
    }

    return ReaderCodeRenderResult(
      document: ReaderCodeDocument.fromTokens(
        text: extraction.text,
        language: language,
        sourceKind: sourceKind,
        tokens: baseTokens,
        searchRanges: extraction.searchRanges,
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

  static List<ReaderCodeToken> _highlightDiffTokens(String code) {
    final tokens = <ReaderCodeToken>[];

    var start = 0;
    while (start < code.length) {
      final newline = code.indexOf('\n', start);
      final end = newline < 0 ? code.length : newline + 1;
      final line = code.substring(start, end);
      final marker = line.isEmpty ? 0 : line.codeUnitAt(0);
      final token = switch (marker) {
        43 => ReaderCodeToken(
          text: line,
          role: ReaderCodeTokenRole.diffInserted,
          start: start,
          end: end,
        ),
        45 => ReaderCodeToken(
          text: line,
          role: ReaderCodeTokenRole.diffDeleted,
          start: start,
          end: end,
        ),
        _ => ReaderCodeToken(
          text: line,
          role: ReaderCodeTokenRole.plain,
          start: start,
          end: end,
        ),
      };
      tokens.add(token);
      start = end;
    }

    return tokens;
  }

  static List<ReaderCodeToken> _applySearchOverlay(
    List<ReaderCodeToken> tokens, {
    required List<ReaderCodeSearchRange> searchRanges,
    required String? currentAnchorId,
  }) {
    return applyReaderCodeSearchTokenOverlay(
      tokens,
      searchRanges: searchRanges,
      currentAnchorId: currentAnchorId,
    );
  }

  static List<ReaderCodeToken> _tokensFromSpan(TextSpan span, String text) {
    final tokens = <ReaderCodeToken>[];
    var offset = 0;

    void visit(TextSpan node) {
      final value = node.text;
      if (value != null && value.isNotEmpty) {
        tokens.add(
          ReaderCodeToken(
            text: value,
            role: ReaderCodeTokenRole.plain,
            start: offset,
            end: offset + value.length,
            colorOverride: node.style?.color,
          ),
        );
        offset += value.length;
      }
      for (final child in node.children ?? const <InlineSpan>[]) {
        if (child is TextSpan) visit(child);
      }
    }

    visit(span);
    return tokens;
  }
}
