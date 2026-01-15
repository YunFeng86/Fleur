import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class ExtractedArticle {
  const ExtractedArticle({required this.title, required this.contentHtml});

  final String title;
  final String contentHtml;
}

class ArticleExtractor {
  ArticleExtractor(this._dio);

  final Dio _dio;

  Future<ExtractedArticle> extract(String url) async {
    final html = await _fetchHtml(url);
    return _extractFromHtml(html: html, url: url);
  }

  Future<String> _fetchHtml(String url) async {
    final res = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: const {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ),
    );
    return res.data ?? '';
  }

  ExtractedArticle _extractFromHtml({required String html, required String url}) {
    final base = Uri.tryParse(url);
    final doc = html_parser.parse(html);

    final title = _pickTitle(doc);

    final body = doc.body;
    if (body == null) {
      return ExtractedArticle(title: title, contentHtml: '');
    }

    _stripNoise(body);

    final candidate = _pickBestCandidate(body) ?? body;
    _stripNoise(candidate);
    _absolutizeUrls(candidate, base);

    final contentHtml = '''
<article>
  <h1>${_escapeHtml(title)}</h1>
  ${candidate.innerHtml}
</article>
''';

    return ExtractedArticle(title: title, contentHtml: contentHtml);
  }

  String _pickTitle(dom.Document doc) {
    final og = doc.querySelector('meta[property="og:title"]')?.attributes['content'];
    if (og != null && og.trim().isNotEmpty) return og.trim();
    final t = doc.querySelector('title')?.text;
    if (t != null && t.trim().isNotEmpty) return t.trim();
    return 'Untitled';
  }

  void _stripNoise(dom.Element root) {
    const removeTags = {
      'script',
      'style',
      'noscript',
      'iframe',
      'canvas',
      'svg',
      'footer',
      'header',
      'nav',
      'aside',
      'form',
      'button',
      'input',
      'select',
      'textarea',
    };
    for (final e in root.querySelectorAll(removeTags.join(','))) {
      e.remove();
    }
  }

  dom.Element? _pickBestCandidate(dom.Element body) {
    final articles = body.querySelectorAll('article');
    if (articles.isNotEmpty) {
      return _maxByScore(articles);
    }
    final mains = body.querySelectorAll('main');
    if (mains.isNotEmpty) {
      return _maxByScore(mains);
    }
    final blocks = body.querySelectorAll('section,div');
    if (blocks.isNotEmpty) {
      final best = _maxByScore(blocks);
      if (best != null && _textLen(best) >= 200) return best;
    }
    return null;
  }

  dom.Element? _maxByScore(List<dom.Element> nodes) {
    dom.Element? best;
    var bestScore = double.negativeInfinity;
    for (final n in nodes) {
      final textLen = _textLen(n);
      if (textLen < 80) continue;
      final linkLen = _linkTextLen(n);
      final density = linkLen / (textLen + 1);
      final score = textLen * (1.0 - density);
      if (score > bestScore) {
        bestScore = score;
        best = n;
      }
    }
    return best;
  }

  int _textLen(dom.Element e) => e.text.trim().length;

  int _linkTextLen(dom.Element e) {
    var sum = 0;
    for (final a in e.querySelectorAll('a')) {
      sum += a.text.trim().length;
    }
    return sum;
  }

  void _absolutizeUrls(dom.Element root, Uri? base) {
    if (base == null) return;
    for (final img in root.querySelectorAll('img')) {
      final src = img.attributes['src'];
      if (src == null || src.trim().isEmpty) continue;
      img.attributes['src'] = base.resolve(src).toString();
    }
    for (final a in root.querySelectorAll('a')) {
      final href = a.attributes['href'];
      if (href == null || href.trim().isEmpty) continue;
      a.attributes['href'] = base.resolve(href).toString();
    }
  }

  String _escapeHtml(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}

