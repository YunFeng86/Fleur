import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../html_sanitizer.dart';

class ExtractedArticle {
  const ExtractedArticle({required this.title, required this.contentHtml});

  final String title;
  final String contentHtml;
}

class ArticleExtractionDiagnostics {
  const ArticleExtractionDiagnostics({
    required this.article,
    required this.reason,
    required this.sanitizedHtml,
  });

  final ExtractedArticle article;
  final ArticleExtractionFailureReason reason;
  final String sanitizedHtml;
}

enum ArticleExtractionFailureReason {
  none,
  emptyContent,
  titleOnly,
  loadingState,
  rssGarbled,
  lazyImageMissing,
  accessBlocked,
  duplicateTitle,
  noiseAsBody,
  sanitizerLoss,
}

class ArticleExtractorCore {
  ArticleExtractorCore._();

  static ExtractedArticle extractFromHtml({
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
        _pickCommonCandidate(body) ??
        _pickRuleBasedCandidate(doc, body) ??
        _pickBestCandidate(body) ??
        body;
    _stripNoise(candidate);
    _stripBoilerplateByClass(candidate);
    _deduplicateTitleBlocks(candidate, title);
    _absolutizeUrls(candidate, base);

    final shouldInjectTitle =
        title.isNotEmpty && !_candidateContainsTitleBlock(candidate, title);
    final titleHtml = shouldInjectTitle
        ? '  <h1>${_escapeHtml(title)}</h1>\n'
        : '';
    final contentHtml =
        '''
<article>
$titleHtml
  ${candidate.innerHtml}
</article>
''';

    return ExtractedArticle(title: title, contentHtml: contentHtml);
  }

  static ArticleExtractionDiagnostics diagnoseFromHtml({
    required String html,
    required String url,
    int? statusCode,
  }) {
    final article = extractFromHtml(html: html, url: url);
    final sanitizedHtml = HtmlSanitizer.sanitize(article.contentHtml);
    final reason = _classifyExtraction(
      html: html,
      url: url,
      statusCode: statusCode,
      article: article,
      sanitizedHtml: sanitizedHtml,
    );
    return ArticleExtractionDiagnostics(
      article: article,
      reason: reason,
      sanitizedHtml: sanitizedHtml,
    );
  }

  static ArticleExtractionFailureReason _classifyExtraction({
    required String html,
    required String url,
    required int? statusCode,
    required ExtractedArticle article,
    required String sanitizedHtml,
  }) {
    final pageText = _textFromHtml(html);
    final extractedText = _textFromHtml(article.contentHtml);
    final sanitizedText = _textFromHtml(sanitizedHtml);

    if (_isAccessBlocked(statusCode, pageText)) {
      return ArticleExtractionFailureReason.accessBlocked;
    }
    if (article.contentHtml.trim().isEmpty || sanitizedText.isEmpty) {
      return ArticleExtractionFailureReason.emptyContent;
    }
    if (_isLoadingState(pageText, sanitizedText)) {
      return ArticleExtractionFailureReason.loadingState;
    }
    if (_isGarbledText(extractedText) || _isGarbledText(sanitizedText)) {
      return ArticleExtractionFailureReason.rssGarbled;
    }
    if (_hasSanitizerLoss(extractedText, sanitizedText)) {
      return ArticleExtractionFailureReason.sanitizerLoss;
    }
    if (_isTitleOnly(article.title, sanitizedText)) {
      return ArticleExtractionFailureReason.titleOnly;
    }
    if (_hasDuplicateTitle(article.title, sanitizedHtml)) {
      return ArticleExtractionFailureReason.duplicateTitle;
    }
    if (_hasMissingLazyImage(
      article.contentHtml,
      sanitizedHtml,
      Uri.tryParse(url),
    )) {
      return ArticleExtractionFailureReason.lazyImageMissing;
    }
    if (_looksLikeNoiseBody(sanitizedText)) {
      return ArticleExtractionFailureReason.noiseAsBody;
    }
    return ArticleExtractionFailureReason.none;
  }

  static String _textFromHtml(String html) {
    if (html.trim().isEmpty) return '';
    return _collapseWhitespace(html_parser.parseFragment(html).text ?? '');
  }

  static bool _isAccessBlocked(int? statusCode, String pageText) {
    if (statusCode == 401 || statusCode == 403 || statusCode == 451) {
      return true;
    }
    final text = pageText.toLowerCase();
    const patterns = [
      '403 forbidden',
      'access denied',
      'access forbidden',
      'request blocked',
      'not authorized',
      'unauthorized',
      'verify you are human',
      'captcha',
    ];
    return patterns.any(text.contains);
  }

  static bool _isLoadingState(String pageText, String sanitizedText) {
    final text = '$pageText $sanitizedText'.toLowerCase();
    const strongSignals = [
      'please enable javascript',
      'enable javascript to continue',
      'checking your browser',
      'just a moment',
      'please wait while',
      '\u52a0\u8f7d\u4e2d',
    ];
    if (strongSignals.any(text.contains)) return true;

    const weakSignals = ['loading', 'please wait', 'redirecting'];
    final hits = weakSignals.where(text.contains).length;
    return hits >= 2 || (hits == 1 && sanitizedText.length < 120);
  }

  static bool _isGarbledText(String text) {
    if (text.runes.contains(0xfffd)) return true;
    for (final codeUnit in text.runes) {
      if (codeUnit == 0x00c2 || codeUnit == 0x00c3 || codeUnit == 0x00e2) {
        return true;
      }
    }
    return false;
  }

  static bool _hasSanitizerLoss(String extractedText, String sanitizedText) {
    if (sanitizedText.isEmpty) return false;
    final extractedLength = extractedText.length;
    final sanitizedLength = sanitizedText.length;
    if (extractedLength < 120) return false;
    return sanitizedLength < extractedLength * 0.35 &&
        extractedLength - sanitizedLength >= 80;
  }

  static bool _isTitleOnly(String title, String sanitizedText) {
    final normalizedTitle = _normalizeText(title);
    if (normalizedTitle.isEmpty) return false;
    return _normalizeText(sanitizedText) == normalizedTitle;
  }

  static bool _hasDuplicateTitle(String title, String sanitizedHtml) {
    if (title.trim().isEmpty || sanitizedHtml.trim().isEmpty) return false;
    final doc = html_parser.parse(sanitizedHtml);
    final body = doc.body;
    if (body == null) return false;
    return _titleEquivalentBlocks(body, title).length > 1;
  }

  static bool _hasMissingLazyImage(
    String html,
    String sanitizedHtml,
    Uri? base,
  ) {
    final expected = _lazyImageSources(html, base);
    if (expected.isEmpty) return false;
    final actual = _imageSources(sanitizedHtml);
    return expected.any((src) => !actual.contains(src));
  }

  static Set<String> _lazyImageSources(String html, Uri? base) {
    if (html.trim().isEmpty) return const {};
    final doc = html_parser.parse(html);
    final sources = <String>{};
    for (final img in doc.querySelectorAll('img')) {
      final src = img.attributes['src']?.trim();
      if (_isUsableImageSrc(src)) continue;

      for (final attr in const [
        'data-lazy-src',
        'data-src',
        'data-original',
        'data-lazyload',
      ]) {
        final value = img.attributes[attr]?.trim();
        if (_isUsableImageSrc(value)) {
          sources.add(_resolveUrl(value!, base));
        }
      }

      final srcset =
          img.attributes['srcset']?.trim() ??
          img.attributes['data-srcset']?.trim();
      final srcsetSource = _firstSrcFromSrcset(srcset);
      if (_isUsableImageSrc(srcsetSource)) {
        sources.add(_resolveUrl(srcsetSource!, base));
      }
    }
    return sources;
  }

  static Set<String> _imageSources(String html) {
    if (html.trim().isEmpty) return const {};
    final doc = html_parser.parse(html);
    return {
      for (final img in doc.querySelectorAll('img'))
        if ((img.attributes['src'] ?? '').trim().isNotEmpty)
          img.attributes['src']!.trim(),
    };
  }

  static String _resolveUrl(String url, Uri? base) {
    if (base == null) return url;
    return _resolveUrlOrNull(url, base) ?? url;
  }

  static String? _resolveUrlOrNull(String url, Uri base) {
    try {
      return base.resolve(url).toString();
    } on FormatException {
      return null;
    }
  }

  static bool _looksLikeNoiseBody(String sanitizedText) {
    final text = _normalizeText(sanitizedText);
    if (text.length < 80) return false;
    const signals = [
      'previous article',
      'next article',
      'related posts',
      'share',
      'comments',
      '\u4e0a\u4e00\u7bc7',
      '\u4e0b\u4e00\u7bc7',
      '\u76f8\u5173\u6587\u7ae0',
      '\u8bc4\u8bba',
      '\u5206\u4eab',
    ];
    final hits = signals.where(text.contains).length;
    return hits >= 3;
  }

  static String _collapseWhitespace(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
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

  static dom.Element? _pickCommonCandidate(dom.Element body) {
    const selectors = [
      '#articleContent',
      '.article-content.keep-markdown-body',
      '.article-content',
      '.markdown-body',
      '.post_detail .mdl-card__supporting-text',
    ];

    for (final sel in selectors) {
      final el = body.querySelector(sel);
      if (el == null) continue;
      if (_textLen(el) >= 80) return el;
    }
    return null;
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
      r'(^|[\s_-])(comments|comment-list|comments-area|comment-area|comment-form|respond|share|social|related|breadcrumb|nav|footer|header|subscribe|newsletter|sidebar|pagination|prev-next|post-copyright|post-tools|reward|toc|post-toc)([\s_-]|$)',
      caseSensitive: false,
    );
    for (final el in root.querySelectorAll('*')) {
      if (_isBoilerplateElement(el, re)) {
        el.remove();
      }
    }
  }

  static bool _isBoilerplateElement(dom.Element el, RegExp re) {
    return _isBoilerplateValue(el.className, re) ||
        _isBoilerplateValue(el.id, re);
  }

  static bool _isBoilerplateValue(String value, RegExp re) {
    final normalized = value.toLowerCase().trim();
    if (normalized.isEmpty) return false;
    if (normalized.contains('comment-block')) return false;
    if (normalized == 'comment') return true;
    return re.hasMatch(normalized);
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
      final src = _bestImageSource(img);
      if (src == null) continue;
      final resolved = _resolveUrlOrNull(src, base);
      if (resolved == null) continue;
      img.attributes['src'] = resolved;
    }
    for (final a in root.querySelectorAll('a')) {
      final href = a.attributes['href'];
      if (href == null || href.trim().isEmpty) continue;
      final resolved = _resolveUrlOrNull(href, base);
      if (resolved == null) continue;
      a.attributes['href'] = resolved;
    }
  }

  static String? _bestImageSource(dom.Element img) {
    final src = img.attributes['src']?.trim();
    if (_isUsableImageSrc(src)) return src;

    for (final attr in const [
      'data-lazy-src',
      'data-src',
      'data-original',
      'data-lazyload',
    ]) {
      final value = img.attributes[attr]?.trim();
      if (_isUsableImageSrc(value)) return value;
    }

    final srcset =
        img.attributes['srcset']?.trim() ??
        img.attributes['data-srcset']?.trim();
    final srcsetSource = _firstSrcFromSrcset(srcset);
    if (_isUsableImageSrc(srcsetSource)) return srcsetSource;

    return src == null || src.isEmpty ? null : src;
  }

  static String? _firstSrcFromSrcset(String? srcset) {
    if (srcset == null || srcset.isEmpty) return null;
    final first = srcset.split(',').first.trim();
    if (first.isEmpty) return null;
    return first.split(RegExp(r'\s+')).first.trim();
  }

  static bool _isUsableImageSrc(String? src) {
    if (src == null || src.isEmpty) return false;
    final lower = src.toLowerCase();
    if (lower.startsWith('data:')) return false;
    if (lower == 'about:blank') return false;
    return !RegExp(
      r'(b_ld\.|loading|placeholder|blank|transparent|spacer|pixel)',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  static void _deduplicateTitleBlocks(dom.Element candidate, String title) {
    final titleBlocks = _titleEquivalentBlocks(candidate, title);
    if (titleBlocks.length <= 1) return;

    for (final block in titleBlocks.skip(1)) {
      block.remove();
    }
  }

  static bool _candidateContainsTitleBlock(
    dom.Element candidate,
    String title,
  ) {
    return _titleEquivalentBlocks(candidate, title).isNotEmpty;
  }

  static List<dom.Element> _titleEquivalentBlocks(
    dom.Element candidate,
    String title,
  ) {
    final normalizedTitle = _normalizeText(title);
    if (normalizedTitle.isEmpty) return const [];

    final blocks = <dom.Element>[];
    for (final element in candidate.querySelectorAll('*')) {
      if (!_isTitleEquivalentBlock(element, normalizedTitle)) continue;
      if (_hasTitleEquivalentAncestor(element, candidate, normalizedTitle)) {
        continue;
      }
      blocks.add(element);
    }
    return blocks;
  }

  static bool _hasTitleEquivalentAncestor(
    dom.Element element,
    dom.Element candidate,
    String normalizedTitle,
  ) {
    dom.Node? current = element.parent;
    while (current is dom.Element && current != candidate) {
      if (_isTitleEquivalentBlock(current, normalizedTitle)) return true;
      current = current.parent;
    }
    return false;
  }

  static bool _isTitleEquivalentBlock(
    dom.Element element,
    String normalizedTitle,
  ) {
    final tag = element.localName?.toLowerCase();
    if (tag == null) return false;
    if (!_canBeStandaloneTitleBlock(tag)) return false;
    if (_normalizeText(element.text) != normalizedTitle) return false;
    if (_isHeadingTag(tag)) return true;
    return !element.children.any((child) {
      final childTag = child.localName?.toLowerCase();
      return childTag != null && _isHeadingTag(childTag);
    });
  }

  static bool _canBeStandaloneTitleBlock(String tag) {
    return _isHeadingTag(tag) ||
        const {'p', 'div', 'span', 'strong', 'b', 'a', 'li'}.contains(tag);
  }

  static bool _isHeadingTag(String tag) {
    return const {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'}.contains(tag);
  }

  static String _normalizeText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
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

enum _Cms { unknown, wordpress, hexo, hugo, halo }
