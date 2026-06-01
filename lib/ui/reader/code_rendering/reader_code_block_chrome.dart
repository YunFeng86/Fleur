import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/fleur_icons.dart';
import '../reader_selectable_rich_text.dart';
import 'reader_code_models.dart';
import 'reader_code_theme.dart';
import 'reader_code_token_theme.dart';

final class ReaderCodeBlockPresentation {
  const ReaderCodeBlockPresentation._({
    required this.copyText,
    required this.displayLanguage,
    required this.lineCount,
  });

  factory ReaderCodeBlockPresentation.fromDocument(
    ReaderCodeDocument document,
  ) {
    return ReaderCodeBlockPresentation._(
      copyText: document.text,
      displayLanguage: _displayLanguage(document.language?.id),
      lineCount: document.lines.length,
    );
  }

  final String copyText;
  final String? displayLanguage;
  final int lineCount;

  static String? _displayLanguage(String? language) {
    final value = language?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    if (value == 'plain' ||
        value == 'plaintext' ||
        value == 'text' ||
        value == 'none' ||
        value == 'unknown') {
      return null;
    }
    return value;
  }
}

final class ReaderCodeLayoutMetrics {
  ReaderCodeLayoutMetrics._({
    required this.strutStyle,
    required this.textHeightBehavior,
    required this.gutterWidth,
    required this.lineHeight,
  });

  factory ReaderCodeLayoutMetrics.resolve({
    required TextStyle codeStyle,
    required int lineCount,
    required TextDirection textDirection,
  }) {
    final strutStyle = StrutStyle.fromTextStyle(
      codeStyle,
      forceStrutHeight: true,
    );
    const textHeightBehavior = TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false,
    );
    final maxLineNumber = lineCount < 1 ? '1' : lineCount.toString();
    final painter = TextPainter(
      text: TextSpan(text: maxLineNumber, style: codeStyle),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();
    final linePainter = TextPainter(
      text: TextSpan(text: '0', style: codeStyle),
      textDirection: textDirection,
      strutStyle: strutStyle,
      textHeightBehavior: textHeightBehavior,
      maxLines: 1,
    )..layout();
    final lineMetrics = linePainter.computeLineMetrics();

    return ReaderCodeLayoutMetrics._(
      strutStyle: strutStyle,
      textHeightBehavior: textHeightBehavior,
      gutterWidth: painter.width + _ReaderCodeLineGutter.horizontalPadding,
      lineHeight: lineMetrics.isEmpty
          ? linePainter.preferredLineHeight
          : lineMetrics.first.height,
    );
  }

  final StrutStyle strutStyle;
  final TextHeightBehavior textHeightBehavior;
  final double gutterWidth;
  final double lineHeight;
}

class ReaderCodeBlockChrome extends StatelessWidget {
  const ReaderCodeBlockChrome({
    super.key,
    required this.document,
    required this.codeStyle,
  });

  static const copyFeedbackDuration = Duration(milliseconds: 1200);

  final ReaderCodeDocument document;
  final TextStyle codeStyle;

  @override
  Widget build(BuildContext context) {
    final codeTheme = ReaderCodeTheme.resolve(context);
    final presentation = ReaderCodeBlockPresentation.fromDocument(document);

    return Container(
      key: const Key('reader_code_block'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: codeTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: codeTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReaderCodeHeader(
            language: presentation.displayLanguage,
            copyText: presentation.copyText,
            codeTheme: codeTheme,
          ),
          _ReaderCodeBody(
            document: document,
            codeStyle: codeStyle,
            codeTheme: codeTheme,
          ),
        ],
      ),
    );
  }
}

class _ReaderCodeHeader extends StatelessWidget {
  const _ReaderCodeHeader({
    required this.language,
    required this.copyText,
    required this.codeTheme,
  });

  final String? language;
  final String copyText;
  final ReaderCodeTheme codeTheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('reader_code_header'),
      height: 38,
      padding: const EdgeInsetsDirectional.only(start: 12, end: 6),
      decoration: BoxDecoration(
        color: codeTheme.headerSurface,
        border: Border(bottom: BorderSide(color: codeTheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: language == null
                ? const SizedBox.shrink()
                : Text(
                    language!,
                    key: const Key('reader_code_language_label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          _ReaderCodeCopyButton(copyText: copyText),
        ],
      ),
    );
  }
}

class _ReaderCodeBody extends StatelessWidget {
  const _ReaderCodeBody({
    required this.document,
    required this.codeStyle,
    required this.codeTheme,
  });

  final ReaderCodeDocument document;
  final TextStyle codeStyle;
  final ReaderCodeTheme codeTheme;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final tokenTheme = ReaderCodeTokenTheme(theme: codeTheme);
    final metrics = ReaderCodeLayoutMetrics.resolve(
      codeStyle: codeStyle,
      lineCount: document.lines.length,
      textDirection: direction,
    );
    return Row(
      key: const Key('reader_code_body'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReaderCodeLineGutter(
          lineCount: document.lines.length,
          codeStyle: codeStyle,
          metrics: metrics,
          codeTheme: codeTheme,
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                key: const Key('reader_code_line_column'),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final line in document.lines)
                    _ReaderCodeLineText(
                      line: line,
                      metrics: metrics,
                      tokenTheme: tokenTheme,
                      baseStyle: codeStyle,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReaderCodeLineText extends StatelessWidget {
  const _ReaderCodeLineText({
    required this.line,
    required this.metrics,
    required this.tokenTheme,
    required this.baseStyle,
  });

  final ReaderCodeLine line;
  final ReaderCodeLayoutMetrics metrics;
  final ReaderCodeTokenTheme tokenTheme;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final registrar = SelectionContainer.maybeOf(context);
    final selectionColor = registrar == null
        ? null
        : DefaultSelectionStyle.of(context).selectionColor ??
              DefaultSelectionStyle.defaultColor;
    final text = ReaderSelectableRichText(
      key: const Key('reader_code_line_code'),
      overflow: TextOverflow.visible,
      selectionColor: selectionColor,
      selectionRegistrar: registrar,
      softWrap: false,
      strutStyle: metrics.strutStyle,
      text: TextSpan(
        style: baseStyle,
        children: [
          for (final token in line.tokens)
            TextSpan(text: token.text, style: tokenTheme.styleFor(token)),
        ],
      ),
      textHeightBehavior: metrics.textHeightBehavior,
      textWidthBasis: TextWidthBasis.longestLine,
    );

    return SizedBox(
      height: metrics.lineHeight,
      child: MouseRegion(cursor: SystemMouseCursors.text, child: text),
    );
  }
}

class _ReaderCodeLineGutter extends StatelessWidget {
  const _ReaderCodeLineGutter({
    required this.lineCount,
    required this.codeStyle,
    required this.metrics,
    required this.codeTheme,
  });

  static const double leadingPadding = 10;
  static const double trailingPadding = 12;
  static const double horizontalPadding = leadingPadding + trailingPadding;

  final int lineCount;
  final TextStyle codeStyle;
  final ReaderCodeLayoutMetrics metrics;
  final ReaderCodeTheme codeTheme;

  @override
  Widget build(BuildContext context) {
    return SelectionContainer.disabled(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Container(
            key: const Key('reader_code_line_gutter'),
            width: metrics.gutterWidth,
            padding: const EdgeInsetsDirectional.fromSTEB(
              leadingPadding,
              14,
              trailingPadding,
              14,
            ),
            decoration: BoxDecoration(
              border: BorderDirectional(
                end: BorderSide(color: codeTheme.gutterDivider),
              ),
            ),
            child: Column(
              key: const Key('reader_code_line_numbers'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < lineCount; index++)
                  SizedBox(
                    height: metrics.lineHeight,
                    child: Text(
                      '${index + 1}',
                      key: const Key('reader_code_line_number'),
                      softWrap: false,
                      textAlign: TextAlign.end,
                      strutStyle: metrics.strutStyle,
                      textHeightBehavior: metrics.textHeightBehavior,
                      style: codeStyle.copyWith(color: codeTheme.gutterText),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderCodeCopyButton extends StatefulWidget {
  const _ReaderCodeCopyButton({required this.copyText});

  final String copyText;

  @override
  State<_ReaderCodeCopyButton> createState() => _ReaderCodeCopyButtonState();
}

class _ReaderCodeCopyButtonState extends State<_ReaderCodeCopyButton> {
  Timer? _resetTimer;
  bool _copied = false;

  @override
  void didUpdateWidget(covariant _ReaderCodeCopyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.copyText != widget.copyText && _copied) {
      _resetTimer?.cancel();
      _copied = false;
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.copyText));
    if (!mounted) return;
    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(ReaderCodeBlockChrome.copyFeedbackDuration, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copiedLabel =
        AppLocalizations.of(context)?.copiedToClipboard ??
        'Copied to clipboard';
    return IconButton(
      key: const Key('reader_code_copy_button'),
      tooltip: _copied
          ? copiedLabel
          : MaterialLocalizations.of(context).copyButtonLabel,
      onPressed: _copy,
      visualDensity: VisualDensity.compact,
      iconSize: 16,
      color: _copied
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant,
      icon: Icon(
        _copied ? FleurIcons.check : FleurIcons.copy,
        key: Key(
          _copied ? 'reader_code_copy_success_icon' : 'reader_code_copy_icon',
        ),
      ),
    );
  }
}
