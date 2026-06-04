import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

String normalizeReaderHtmlForDisplay(String html) {
  if (html.trim().isEmpty) return '';
  final fragment = html_parser.parseFragment(html);

  void visit(dom.Node node) {
    if (node is dom.Element && _skipMathNormalizationInside(node)) {
      return;
    }

    final children = List<dom.Node>.from(node.nodes);
    for (final child in children) {
      if (child is dom.Text) {
        _replaceMathTextNode(child);
      } else {
        visit(child);
      }
    }
  }

  visit(fragment);
  return fragment.outerHtml;
}

bool _skipMathNormalizationInside(dom.Element element) {
  final tag = element.localName?.toLowerCase();
  return tag == 'pre' || tag == 'code' || tag == 'a' || tag == 'fleur-math';
}

void _replaceMathTextNode(dom.Text node) {
  final text = node.text;
  if (!_mayContainMathDelimiter(text)) return;
  final parent = node.parent;
  if (parent == null) return;
  final index = parent.nodes.indexOf(node);
  if (index < 0) return;

  final replacements = _parseMathText(text);
  if (replacements == null) return;
  parent.nodes.removeAt(index);
  parent.nodes.insertAll(index, replacements);
}

bool _mayContainMathDelimiter(String text) {
  return text.contains(r'$') || text.contains(r'\(') || text.contains(r'\[');
}

List<dom.Node>? _parseMathText(String text) {
  final nodes = <dom.Node>[];
  var cursor = 0;
  var found = false;

  while (cursor < text.length) {
    final match = _findNextMath(text, cursor);
    if (match == null) break;
    if (match.start > cursor) {
      nodes.add(dom.Text(text.substring(cursor, match.start)));
    }
    nodes.add(_buildMathElement(match.expression, display: match.display));
    found = true;
    cursor = match.end;
  }

  if (!found) return null;
  if (cursor < text.length) {
    nodes.add(dom.Text(text.substring(cursor)));
  }
  return nodes;
}

_MathMatch? _findNextMath(String text, int start) {
  _MathMatch? best;
  for (final opener in const [r'$$', r'\[', r'\(', r'$']) {
    final candidate = _findMathWithOpener(text, start, opener);
    if (candidate == null) continue;
    if (best == null || candidate.start < best.start) {
      best = candidate;
    }
  }
  return best;
}

_MathMatch? _findMathWithOpener(String text, int start, String opener) {
  final openIndex = _indexOfUnescaped(text, opener, start);
  if (openIndex < 0) return null;
  if (opener == r'$' && _isDoubleDollarAt(text, openIndex)) {
    return null;
  }

  final closer = switch (opener) {
    r'$$' => r'$$',
    r'\[' => r'\]',
    r'\(' => r'\)',
    _ => r'$',
  };
  final closeStart = openIndex + opener.length;
  final closeIndex = _indexOfUnescaped(text, closer, closeStart);
  if (closeIndex < 0) return null;
  if (closer == r'$' && _isDoubleDollarAt(text, closeIndex)) {
    return null;
  }

  final expression = text.substring(closeStart, closeIndex).trim();
  if (expression.isEmpty) return null;
  return _MathMatch(
    start: openIndex,
    end: closeIndex + closer.length,
    expression: expression,
    display: opener == r'$$' || opener == r'\[',
  );
}

int _indexOfUnescaped(String text, String pattern, int start) {
  var index = text.indexOf(pattern, start);
  while (index >= 0) {
    if (!_isEscaped(text, index)) return index;
    index = text.indexOf(pattern, index + pattern.length);
  }
  return -1;
}

bool _isEscaped(String text, int index) {
  var count = 0;
  for (var i = index - 1; i >= 0 && text.codeUnitAt(i) == 92; i--) {
    count++;
  }
  return count.isOdd;
}

bool _isDoubleDollarAt(String text, int index) {
  return index + 1 < text.length &&
      text.codeUnitAt(index) == 36 &&
      text.codeUnitAt(index + 1) == 36;
}

dom.Element _buildMathElement(String expression, {required bool display}) {
  return dom.Element.tag('fleur-math')
    ..attributes['data-fleur-math'] = expression
    ..attributes['data-fleur-math-display'] = display ? 'block' : 'inline'
    ..text = expression;
}

class _MathMatch {
  const _MathMatch({
    required this.start,
    required this.end,
    required this.expression,
    required this.display,
  });

  final int start;
  final int end;
  final String expression;
  final bool display;
}
