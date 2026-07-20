import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../feed_html_normalizer.dart';
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
        _pickCommonCandidate(body, title) ??
        _pickRuleBasedCandidate(doc, body, title) ??
        _pickBestCandidate(body, title) ??
        body;
    _stripNoise(candidate);
    _stripBoilerplateByClass(candidate);
    _stripStandaloneNoiseBlocks(candidate);
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
    final normalizedHtml = FeedHtmlNormalizer.normalize(
      article.contentHtml,
      baseUrl: Uri.tryParse(url),
    );
    final sanitizedHtml = HtmlSanitizer.sanitize(normalizedHtml);
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
    final hits = _noiseSignalHitCount(text);
    if (hits < 3) return false;
    final density = _noiseSignalDensity(text);
    if (!_hasSubstantiveNonNoiseText(text)) return density >= 0.30;
    return density >= 0.70;
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

  static dom.Element? _pickCommonCandidate(dom.Element body, String title) {
    const selectors = [
      '#articleContent',
      '.article-content.keep-markdown-body',
      '.article-content',
      '.article_content',
      '.markdown-body',
      '.entry-content',
      '.post-content',
      '.post-body',
      '.article-body',
      '.post-content-content',
      '.post_detail .mdl-card__supporting-text',
    ];

    return _firstViableCandidate(body, selectors, title, minTextLength: 80);
  }

  static dom.Element? _pickRuleBasedCandidate(
    dom.Document doc,
    dom.Element body,
    String title,
  ) {
    final detector = _detectCms(doc, body);
    final selectors = switch (detector) {
      _Cms.wordpress => const [
        'article .entry-content',
        'article .post-content',
        'article .post-body',
        'article .article-body',
        'article .article_content',
        'article .post-content-content',
        '.entry-content',
        '.post-content',
        '.post-body',
        '.article-body',
        '.article_content',
        '.post-content-content',
        'article',
      ],
      _Cms.hexo => const [
        '.post-content',
        '.article-entry',
        '.article_content',
        '.post-content-content',
        'article',
      ],
      _Cms.hugo => const [
        '.post-content',
        '.post-body',
        '.article-body',
        '.content',
        'main article',
        'article',
      ],
      _Cms.halo => const [
        '.post-content',
        '.post-body',
        '.article-body',
        '.content',
        'article',
      ],
      _Cms.unknown => const [
        '.entry-content',
        '.post-content',
        '.post-body',
        '.article-body',
        '.article_content',
        '.post-content-content',
        'article',
        'main article',
        'main',
      ],
    };

    return _firstViableCandidate(body, selectors, title, minTextLength: 200);
  }

  static dom.Element? _firstViableCandidate(
    dom.Element body,
    List<String> selectors,
    String title, {
    required int minTextLength,
  }) {
    dom.Element? firstTitleOnly;
    for (final sel in selectors) {
      final el = body.querySelector(sel);
      if (el == null) continue;
      if (_textLen(el) < minTextLength) continue;
      if (_isTitleOnlyCandidate(el, title)) {
        firstTitleOnly ??= el;
        continue;
      }
      return el;
    }
    return firstTitleOnly;
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
    for (final el in root.querySelectorAll('*')) {
      if (_isBoilerplateElement(el)) {
        el.remove();
      }
    }
  }

  static final RegExp _boilerplateClassOrIdPattern = RegExp(
    r'(^|[\s_-])(comments|comment-list|comments-area|comment-area|comment-form|comment-count|respond|share|social|related|breadcrumb|nav|footer|header|subscribe|newsletter|sidebar|pagination|prev-next|prev-article|next-article|post-info|post-meta|article-meta|post-tags|post-category|entry-date|post-copyright|post-tools|post-end-tools|post-nav|reward|toc|post-toc)([\s_-]|$)',
    caseSensitive: false,
  );

  static bool _isBoilerplateElement(dom.Element el) {
    return _isBoilerplateValue(el.className) || _isBoilerplateValue(el.id);
  }

  static bool _isBoilerplateValue(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized.isEmpty) return false;
    if (normalized.contains('comment-block')) return false;
    if (normalized == 'comment') return true;
    return _boilerplateClassOrIdPattern.hasMatch(normalized);
  }

  static void _stripStandaloneNoiseBlocks(dom.Element root) {
    if (!_hasSubstantiveNonNoiseText(root.text)) return;

    final blocks = root
        .querySelectorAll('p,div,section,ul,ol,li,span,blockquote')
        .toList(growable: false)
        .reversed;
    for (final block in blocks) {
      if (_looksLikeStandaloneNoiseBlock(block)) {
        block.remove();
      }
    }
  }

  static bool _looksLikeStandaloneNoiseBlock(dom.Element element) {
    final text = _normalizeText(element.text);
    if (text.length < 20) return false;
    if (_hasSubstantiveNonNoiseText(text)) return false;
    if (_noiseSignalHitCount(text) < 2) return false;
    return _noiseSignalDensity(text) >= 0.45;
  }

  static dom.Element? _pickBestCandidate(dom.Element body, String title) {
    dom.Element? titleOnlyFallback;
    final articles = body.querySelectorAll('article');
    if (articles.isNotEmpty) {
      final best = _maxByScore(articles, title);
      if (best != null && !_isTitleOnlyCandidate(best, title)) return best;
      titleOnlyFallback ??= best;
    }
    final mains = body.querySelectorAll('main');
    if (mains.isNotEmpty) {
      final best = _maxByScore(mains, title);
      if (best != null && !_isTitleOnlyCandidate(best, title)) return best;
      titleOnlyFallback ??= best;
    }
    final blocks = body.querySelectorAll('section,div');
    if (blocks.isNotEmpty) {
      final best = _maxByScore(blocks, title);
      if (best != null && _textLen(best) >= 200) {
        if (!_isTitleOnlyCandidate(best, title)) return best;
        titleOnlyFallback ??= best;
      }
    }
    return titleOnlyFallback;
  }

  static dom.Element? _maxByScore(List<dom.Element> nodes, String title) {
    dom.Element? best;
    var bestScore = double.negativeInfinity;
    for (final n in nodes) {
      final text = _collapseWhitespace(n.text);
      final textLen = text.length;
      if (textLen < 80) continue;
      final linkLen = _linkTextLen(n);
      final density = linkLen / (textLen + 1);
      final score =
          textLen *
          (1.0 - density) *
          _candidateNoisePenalty(text) *
          _candidateTitleOnlyPenalty(n, title);
      if (score > bestScore) {
        bestScore = score;
        best = n;
      }
    }
    return best;
  }

  static int _textLen(dom.Element e) => e.text.trim().length;

  static bool _isTitleOnlyCandidate(dom.Element element, String title) {
    final normalizedTitle = _normalizeText(title);
    if (normalizedTitle.isEmpty) return false;
    return _normalizeText(element.text) == normalizedTitle;
  }

  static double _candidateTitleOnlyPenalty(dom.Element element, String title) {
    return _isTitleOnlyCandidate(element, title) ? 0.05 : 1.0;
  }

  static double _candidateNoisePenalty(String text) {
    final normalized = _normalizeText(text);
    if (_noiseSignalHitCount(normalized) < 3) return 1.0;
    if (!_hasSubstantiveNonNoiseText(normalized)) return 0.08;
    final density = _noiseSignalDensity(normalized);
    return (1.0 - density * 0.75).clamp(0.15, 1.0).toDouble();
  }

  static final List<RegExp> _noiseSignalPatterns = [
    RegExp(r'\bprevious article\b', caseSensitive: false),
    RegExp(r'\bnext article\b', caseSensitive: false),
    RegExp(r'\brelated posts?\b', caseSensitive: false),
    RegExp(r'\bshare\b', caseSensitive: false),
    RegExp(r'\bcomments?\b', caseSensitive: false),
    RegExp('\u4e0a\u4e00\u7bc7'),
    RegExp('\u4e0b\u4e00\u7bc7'),
    RegExp('\u76f8\u5173\u6587\u7ae0'),
    RegExp('\u8bc4\u8bba'),
    RegExp('\u5206\u4eab'),
  ];

  static int _noiseSignalHitCount(String normalizedText) {
    return _noiseSignalPatterns
        .where((pattern) => pattern.hasMatch(normalizedText))
        .length;
  }

  static int _noiseSignalCount(String normalizedText) {
    var count = 0;
    for (final pattern in _noiseSignalPatterns) {
      count += pattern.allMatches(normalizedText).length;
    }
    return count;
  }

  static double _noiseSignalDensity(String text) {
    final normalized = _normalizeText(text);
    if (normalized.isEmpty) return 0;

    final count = _noiseSignalCount(normalized);
    if (count == 0) return 0;

    final tokenCount = normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .length;
    final denominator = tokenCount <= 1
        ? (normalized.length / 8).clamp(1.0, double.infinity)
        : (tokenCount / 6).clamp(1.0, double.infinity);
    return (count / denominator).clamp(0.0, 1.0).toDouble();
  }

  static bool _hasSubstantiveNonNoiseText(String text) {
    final stripped = _stripNoiseSignals(
      _normalizeText(text),
    ).replaceAll(RegExp(r'[\s.,;:!?，。；：！？、]+'), '');
    return stripped.length >= 80;
  }

  static String _stripNoiseSignals(String text) {
    var stripped = text;
    for (final pattern in _noiseSignalPatterns) {
      stripped = stripped.replaceAll(pattern, ' ');
    }
    return _collapseWhitespace(stripped);
  }

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
