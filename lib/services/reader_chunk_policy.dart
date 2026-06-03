import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

final class ReaderContentComplexity {
  const ReaderContentComplexity({
    required this.htmlLength,
    required this.blockCount,
    required this.imageCount,
    required this.codeBlockCount,
  });

  final int htmlLength;
  final int blockCount;
  final int imageCount;
  final int codeBlockCount;
}

final class ReaderChunkPolicy {
  const ReaderChunkPolicy({
    this.lengthThreshold = 50000,
    this.blockThreshold = 120,
    this.imageThreshold = 20,
    this.codeBlockThreshold = 12,
  });

  static const defaultPolicy = ReaderChunkPolicy();

  final int lengthThreshold;
  final int blockThreshold;
  final int imageThreshold;
  final int codeBlockThreshold;

  bool shouldUseChunkedLayout(String html) {
    if (html.isEmpty) return false;
    if (html.length >= lengthThreshold) return true;
    return shouldUseChunkedLayoutForComplexity(analyze(html));
  }

  bool shouldUseChunkedLayoutForComplexity(ReaderContentComplexity complexity) {
    return complexity.htmlLength >= lengthThreshold ||
        complexity.blockCount > blockThreshold ||
        complexity.imageCount > imageThreshold ||
        complexity.codeBlockCount > codeBlockThreshold;
  }

  ReaderContentComplexity analyze(String html) {
    if (html.isEmpty) {
      return const ReaderContentComplexity(
        htmlLength: 0,
        blockCount: 0,
        imageCount: 0,
        codeBlockCount: 0,
      );
    }

    final fragment = html_parser.parseFragment(html);
    final preElements = fragment.querySelectorAll('pre');
    final blockCount = fragment.querySelectorAll(_blockSelector).length;
    final imageCount = fragment.querySelectorAll('img').length;
    final codeBlockCount =
        preElements.length +
        fragment.querySelectorAll('code').where(_isStandaloneCodeBlock).length;

    return ReaderContentComplexity(
      htmlLength: html.length,
      blockCount: blockCount,
      imageCount: imageCount,
      codeBlockCount: codeBlockCount,
    );
  }

  static bool _isStandaloneCodeBlock(dom.Element code) {
    if (_hasAncestorNamed(code, 'pre')) return false;
    final text = code.text.trim();
    return text.contains('\n') || text.length > 120;
  }

  static bool _hasAncestorNamed(dom.Element element, String localName) {
    dom.Node? parent = element.parent;
    while (parent != null) {
      if (parent is dom.Element && parent.localName == localName) {
        return true;
      }
      parent = parent.parent;
    }
    return false;
  }
}

final _blockSelector = [
  'address',
  'article',
  'aside',
  'blockquote',
  'details',
  'div',
  'dl',
  'figure',
  'footer',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'header',
  'hr',
  'li',
  'main',
  'nav',
  'ol',
  'p',
  'pre',
  'section',
  'table',
  'ul',
].join(', ');
