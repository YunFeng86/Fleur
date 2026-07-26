part of '../reader_view.dart';

class _ReaderMathNode extends StatelessWidget {
  const _ReaderMathNode({required this.expression, required this.display});

  final String expression;
  final bool display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.fleurReader.mathStyle.copyWith(
      color: theme.colorScheme.onSurface,
    );
    final math = flutter_math.Math.tex(
      expression,
      key: const Key('reader_math_node'),
      mathStyle: display
          ? flutter_math.MathStyle.display
          : flutter_math.MathStyle.text,
      textStyle: textStyle,
      onErrorFallback: (_) => Text(
        expression,
        key: const Key('reader_math_fallback'),
        style: theme.fleurReader.mathFallbackStyle.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );

    if (!display) {
      return math;
    }

    return Container(
      key: const Key('reader_math_block'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.fleurReader.codeBlockSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.fleurSurface.subtleDivider),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: math,
      ),
    );
  }
}
