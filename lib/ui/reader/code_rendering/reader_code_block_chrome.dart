import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/fleur_icons.dart';
import '../../../theme/fleur_theme_extensions.dart';
import 'reader_code_models.dart';

final class ReaderCodeBlockPresentation {
  const ReaderCodeBlockPresentation._({
    required this.copyText,
    required this.displayLanguage,
    required this.lineCount,
  });

  factory ReaderCodeBlockPresentation.fromResult(
    ReaderCodeRenderResult result,
  ) {
    return ReaderCodeBlockPresentation._(
      copyText: result.text,
      displayLanguage: _displayLanguage(result.language),
      lineCount: _lineCount(result.text),
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

  static int _lineCount(String text) {
    if (text.isEmpty) return 1;
    return '\n'.allMatches(text).length + 1;
  }
}

class ReaderCodeBlockChrome extends StatelessWidget {
  const ReaderCodeBlockChrome({
    super.key,
    required this.result,
    required this.codeStyle,
  });

  static const copyFeedbackDuration = Duration(milliseconds: 1200);

  final ReaderCodeRenderResult result;
  final TextStyle codeStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = theme.fleurReader;
    final presentation = ReaderCodeBlockPresentation.fromResult(result);
    final headerColor = Color.alphaBlend(
      theme.colorScheme.onSurface.withAlpha(
        theme.brightness == Brightness.dark ? 18 : 8,
      ),
      reader.codeBlockSurface,
    );

    return Container(
      key: const Key('reader_code_block'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: reader.codeBlockSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.fleurSurface.subtleDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReaderCodeHeader(
            language: presentation.displayLanguage,
            copyText: presentation.copyText,
            backgroundColor: headerColor,
          ),
          _ReaderCodeBody(
            result: result,
            codeStyle: codeStyle,
            lineCount: presentation.lineCount,
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
    required this.backgroundColor,
  });

  final String? language;
  final String copyText;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('reader_code_header'),
      height: 38,
      padding: const EdgeInsetsDirectional.only(start: 12, end: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(color: theme.fleurSurface.subtleDivider),
        ),
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
    required this.result,
    required this.codeStyle,
    required this.lineCount,
  });

  final ReaderCodeRenderResult result;
  final TextStyle codeStyle;
  final int lineCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      key: const Key('reader_code_body'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReaderCodeLineGutter(lineCount: lineCount, codeStyle: codeStyle),
        Container(
          width: 1,
          height: _estimatedBodyHeight(lineCount, codeStyle),
          margin: const EdgeInsets.symmetric(vertical: 14),
          color: theme.fleurSurface.subtleDivider,
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SelectableText.rich(result.span),
            ),
          ),
        ),
      ],
    );
  }

  double _estimatedBodyHeight(int lines, TextStyle style) {
    final fontSize = style.fontSize ?? 13;
    final height = style.height ?? 1.0;
    return math.max(1, lines) * fontSize * height;
  }
}

class _ReaderCodeLineGutter extends StatelessWidget {
  const _ReaderCodeLineGutter({
    required this.lineCount,
    required this.codeStyle,
  });

  final int lineCount;
  final TextStyle codeStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digits = math.max(2, lineCount.toString().length);
    final fontSize = codeStyle.fontSize ?? 13;
    final width = math.max(26.0, digits * fontSize * 0.68 + 12);
    final numbers = List<String>.generate(lineCount, (index) {
      return '${index + 1}';
    }).join('\n');

    return SelectionContainer.disabled(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Container(
            key: const Key('reader_code_line_gutter'),
            width: width,
            padding: const EdgeInsetsDirectional.fromSTEB(10, 14, 8, 14),
            child: Text(
              numbers,
              key: const Key('reader_code_line_numbers'),
              softWrap: false,
              textAlign: TextAlign.end,
              style: codeStyle.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
              ),
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
