import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../network/user_agents.dart';

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
    // Use compute to parse HTML in a separate isolate to avoid blocking the UI thread.
    return compute(_extractInIsolate, _ExtractParams(html: html, url: url));
  }

  Future<String> _fetchHtml(String url) async {
    final res = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: const {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'User-Agent': UserAgents.web,
        },
      ),
    );
    return res.data ?? '';
  }

  static ExtractedArticle _extractInIsolate(_ExtractParams params) {
    return _extractFromHtmlStatic(html: params.html, url: params.url);
  }

  static ExtractedArticle _extractFromHtmlStatic({
    required String html,
    required String url,
  }) {
    final base = Uri.tryParse(url);
    final doc = html_parser.parse(html);

    final title = _pickTitle(doc);

    final body = doc.body;
    if (body == null) {
      return ExtractedArticle(title: title, contentHtml: '');
    }

    _stripNoise(body);

    final candidate =
        _pickRuleBasedCandidate(doc, body) ?? _pickBestCandidate(body) ?? body;
    _stripNoise(candidate);
    _stripBoilerplateByClass(candidate);
    _absolutizeUrls(candidate, base);

    final contentHtml =
        '''
<article>
  <h1>${_escapeHtml(title)}</h1>
  ${candidate.innerHtml}
</article>
''';

    return ExtractedArticle(title: title, contentHtml: contentHtml);
  }

  static String _pickTitle(dom.Document doc) {
    final og = doc
        .querySelector('meta[property="og:title"]')
        ?.attributes['content'];
    if (og != null && og.trim().isNotEmpty) return og.trim();
    final t = doc.querySelector('title')?.text;
    if (t != null && t.trim().isNotEmpty) return t.trim();
    // Keep extracted content locale-agnostic; UI can decide how to display missing titles.
    return '';
  }

  static void _stripNoise(dom.Element root) {
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

  static dom.Element? _pickRuleBasedCandidate(
    dom.Document doc,
    dom.Element body,
  ) {
    final detector = _detectCms(doc, body);
    final selectors = switch (detector) {
      _Cms.wordpress => const [
        'article .entry-content',
        'article .post-content',
        '.entry-content',
        '.post-content',
        'article',
      ],
      _Cms.hexo => const ['.post-content', '.article-entry', 'article'],
      _Cms.hugo => const [
        '.post-content',
        '.content',
        'main article',
        'article',
      ],
      _Cms.halo => const ['.post-content', '.post-body', '.content', 'article'],
      _Cms.unknown => const ['article', 'main article', 'main'],
    };

    for (final sel in selectors) {
      final el = body.querySelector(sel);
      if (el == null) continue;
      if (_textLen(el) >= 200) return el;
    }
    return null;
  }

  static _Cms _detectCms(dom.Document doc, dom.Element body) {
    final gen =
        (doc.querySelector('meta[name="generator"]')?.attributes['content'] ??
                '')
            .toLowerCase();
    if (gen.contains('wordpress')) return _Cms.wordpress;
    if (gen.contains('hexo')) return _Cms.hexo;
    if (gen.contains('hugo')) return _Cms.hugo;
    if (gen.contains('halo')) return _Cms.halo;

    final cls = body.className.toLowerCase();
    if (cls.contains('wordpress')) return _Cms.wordpress;
    if (cls.contains('hexo')) return _Cms.hexo;
    return _Cms.unknown;
  }

  static void _stripBoilerplateByClass(dom.Element root) {
    final re = RegExp(
      r'(comment|comments|respond|share|social|related|breadcrumb|nav|footer|header|subscribe|newsletter|sidebar)',
      caseSensitive: false,
    );
    for (final el in root.querySelectorAll('*')) {
      final cls = el.className;
      final id = el.id;
      if ((cls.isNotEmpty && re.hasMatch(cls)) ||
          (id.isNotEmpty && re.hasMatch(id))) {
        el.remove();
      }
    }
  }

  static dom.Element? _pickBestCandidate(dom.Element body) {
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

  static dom.Element? _maxByScore(List<dom.Element> nodes) {
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

  static int _textLen(dom.Element e) => e.text.trim().length;

  static int _linkTextLen(dom.Element e) {
    var sum = 0;
    for (final a in e.querySelectorAll('a')) {
      sum += a.text.trim().length;
    }
    return sum;
  }

  static void _absolutizeUrls(dom.Element root, Uri? base) {
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

  static String _escapeHtml(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}

class _ExtractParams {
  final String html;
  final String url;
  _ExtractParams({required this.html, required this.url});
}

enum _Cms { unknown, wordpress, hexo, hugo, halo }
