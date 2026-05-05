import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/extract/article_extractor.dart';
import 'package:fleur/services/html_sanitizer.dart';

void main() {
  group('ArticleExtractor.extractFromHtml', () {
    test('sanitizer_loss keeps text through unknown structural wrappers', () {
      final html = _page('''
<main>
  <custom-wrapper>
    <p>${_longText('Sanitizer loss body stays readable after extraction.')}</p>
  </custom-wrapper>
</main>
''');

      final sanitized = _extractAndSanitize(html);

      expect(sanitized, contains('Sanitizer loss body stays readable'));
    });

    test('phodal_like_container prefers post detail body over page layout', () {
      final html = _page('''
<div class="mdl-layout mdl-js-layout mdl-layout--fixed-header">
  <nav>Site nav noise should not be selected.</nav>
  <section class="section--center post_detail">
    <div class="mdl-card__supporting-text">
      <p>${_longText('Phodal body paragraph from the card support area.')}</p>
    </div>
  </section>
  <section class="recent-post">
    <p>${_longText('Recent post noise must stay out of extraction.')}</p>
  </section>
</div>
''');

      final sanitized = _extractAndSanitize(html);

      expect(sanitized, contains('Phodal body paragraph'));
      expect(sanitized, isNot(contains('Recent post noise')));
      expect(sanitized, isNot(contains('Site nav noise')));
    });

    test('innei_comment_block does not remove body comment-block class', () {
      final html = _page('''
<article>
  <div class="group/comment-block relative">
    <p>${_longText('Innei article body lives inside a comment-block host.')}</p>
  </div>
  <section class="comments">
    <p>${_longText('Reader comment noise should be removed.')}</p>
  </section>
</article>
''');

      final sanitized = _extractAndSanitize(html);

      expect(sanitized, contains('Innei article body'));
      expect(sanitized, isNot(contains('Reader comment noise')));
    });

    test(
      'blinkfox_article_content prefers articleContent over prev-next cards',
      () {
        final html = _page('''
<main class="post-container content">
  <article id="prenext-posts" class="prev-next articles">
    <p>${_longText('Previous and next article card noise.')}</p>
  </article>
  <div id="articleContent">
    <p>${_longText('Blinkfox primary article content should be selected.')}</p>
  </div>
</main>
''');

        final sanitized = _extractAndSanitize(html);

        expect(sanitized, contains('Blinkfox primary article content'));
        expect(sanitized, isNot(contains('Previous and next article card')));
      },
    );

    test('zero_sky_article_content prefers markdown body over toc/footer', () {
      final html = _page('''
<main class="page-container">
  <div class="toc-content-container">
    <p>${_longText('Table of contents noise must not be selected.')}</p>
  </div>
  <div class="article-content keep-markdown-body">
    <p>${_longText('Zero Sky markdown body should be selected cleanly.')}</p>
  </div>
  <footer>${_longText('Footer noise should be removed.')}</footer>
</main>
''');

      final sanitized = _extractAndSanitize(html);

      expect(sanitized, contains('Zero Sky markdown body'));
      expect(sanitized, isNot(contains('Table of contents noise')));
      expect(sanitized, isNot(contains('Footer noise')));
    });

    test('zhheo_lazy_image promotes data-lazy-src over placeholder src', () {
      final html = _page('''
<article class="post-content">
  <p>
    <img src="/img/b_ld.png"
      data-lazy-src="https://p.zhheo.com/asset.webp!blogimg"
      alt="CompressO screenshot">
  </p>
  <p>${_longText('Zhheo lazy image article body should keep the real image.')}</p>
</article>
''');

      final sanitized = _extractAndSanitize(html);

      expect(
        sanitized,
        contains('src="https://p.zhheo.com/asset.webp!blogimg"'),
      );
      expect(sanitized, contains('alt="CompressO screenshot"'));
      expect(sanitized, isNot(contains('/img/b_ld.png')));
    });

    test('duplicate_title_h1 does not inject a second identical title', () {
      final html = _page('''
<article>
  <h1>Duplicate Title</h1>
  <p>${_longText('Duplicate title body should appear after one heading.')}</p>
</article>
''', title: 'Duplicate Title');

      final extracted = ArticleExtractor.extractFromHtml(
        html: html,
        url: _baseUrl,
      );

      expect(_occurrences(extracted.contentHtml, 'Duplicate Title'), 1);
      expect(extracted.contentHtml, contains('Duplicate title body'));
    });

    test('normal_wordpress_entry_content still extracts entry content', () {
      final html = _page('''
<meta name="generator" content="WordPress 6.9">
<article>
  <div class="entry-content">
    <p>${_longText('WordPress entry content remains the preferred body.')}</p>
  </div>
  <aside>${_longText('Sidebar noise should not leak.')}</aside>
</article>
''');

      final sanitized = _extractAndSanitize(html);

      expect(sanitized, contains('WordPress entry content'));
      expect(sanitized, isNot(contains('Sidebar noise')));
    });

    test('normal_hexo_post_content still extracts post content', () {
      final html = _page('''
<meta name="generator" content="Hexo 6.3.0">
<article class="post-content">
  <p>${_longText('Hexo post content remains the preferred body.')}</p>
</article>
<article class="prev-next articles">
  <p>${_longText('Hexo prev next card should be ignored.')}</p>
</article>
''');

      final sanitized = _extractAndSanitize(html);

      expect(sanitized, contains('Hexo post content'));
      expect(sanitized, isNot(contains('Hexo prev next card')));
    });

    test(
      'noise_container_removed drops explicit related share comments noise',
      () {
        final html = _page('''
<article>
  <p>${_longText('Primary body paragraph survives noise stripping.')}</p>
  <div class="related-posts">${_longText('Related article noise')}</div>
  <div id="comments">${_longText('Comment area noise')}</div>
  <div class="social-share">${_longText('Share toolbar noise')}</div>
</article>
''');

        final sanitized = _extractAndSanitize(html);

        expect(sanitized, contains('Primary body paragraph'));
        expect(sanitized, isNot(contains('Related article noise')));
        expect(sanitized, isNot(contains('Comment area noise')));
        expect(sanitized, isNot(contains('Share toolbar noise')));
      },
    );
  });

  group('ArticleExtractor.diagnoseFromHtml', () {
    test('classifies clean extraction as none', () {
      final html = _page('''
<article>
  <p>${_longText('Clean article body should not be diagnosed as failed.')}</p>
</article>
''');

      final diagnostics = _diagnose(html);

      expect(diagnostics.reason, ArticleExtractionFailureReason.none);
      expect(diagnostics.sanitizedHtml, contains('Clean article body'));
    });

    test('classifies blocked status before page content', () {
      final html = _page('''
<main>
  <p>Loading...</p>
  <p>Please enable JavaScript to continue.</p>
</main>
''', title: '');

      final diagnostics = _diagnose(html, statusCode: 403);

      expect(diagnostics.reason, ArticleExtractionFailureReason.accessBlocked);
    });

    test('classifies empty extraction', () {
      final diagnostics = _diagnose('');

      expect(diagnostics.reason, ArticleExtractionFailureReason.emptyContent);
    });

    test('classifies loading state pages', () {
      final html = _page('''
<main>
  <p>Loading...</p>
  <p>Please enable JavaScript to continue.</p>
</main>
''', title: '');

      final diagnostics = _diagnose(html);

      expect(diagnostics.reason, ArticleExtractionFailureReason.loadingState);
    });

    test('classifies garbled RSS/body text', () {
      final html = _page('''
<article>
  <p>${_longText('This body contains replacement text &#65533; from decoding.')}</p>
</article>
''');

      final diagnostics = _diagnose(html);

      expect(diagnostics.reason, ArticleExtractionFailureReason.rssGarbled);
    });

    test('classifies sanitizer loss without treating it as empty', () {
      final html = _page('''
<article>
  <p>Small visible survivor.</p>
  <object>${_longText('Important article text disappears during sanitizing.')}</object>
</article>
''', title: '');

      final diagnostics = _diagnose(html);

      expect(diagnostics.reason, ArticleExtractionFailureReason.sanitizerLoss);
      expect(diagnostics.sanitizedHtml, contains('Small visible survivor'));
    });

    test('classifies title-only output', () {
      final html = _page('', title: 'Only Title');

      final diagnostics = _diagnose(html);

      expect(diagnostics.reason, ArticleExtractionFailureReason.titleOnly);
    });

    test('classifies duplicate title output', () {
      final html = _page('''
<article>
  <h2>Repeated Title</h2>
  <p>Repeated Title</p>
  <p>${_longText('Actual article body remains after repeated titles.')}</p>
</article>
''', title: 'Repeated Title');

      final diagnostics = _diagnose(html);

      expect(diagnostics.reason, ArticleExtractionFailureReason.duplicateTitle);
    });

    test('classifies missing lazy image promotion', () {
      final html = _page('''
<article>
  <p>
    <img src="/img/b_ld.png"
      data-lazyload="https://cdn.example.com/real.webp"
      alt="Real image">
  </p>
  <p>${_longText('Lazy image body keeps enough text to avoid title-only.')}</p>
</article>
''');

      final diagnostics = _diagnose(html);

      expect(
        diagnostics.reason,
        ArticleExtractionFailureReason.lazyImageMissing,
      );
    });

    test('classifies noise selected as body', () {
      final html = _page('''
<article>
  <p>${_longText('Previous article next article related posts share comments.')}</p>
</article>
''', title: 'Noise Page');

      final diagnostics = _diagnose(html);

      expect(diagnostics.reason, ArticleExtractionFailureReason.noiseAsBody);
    });
  });
}

const _baseUrl = 'https://example.com/posts/demo/';

String _page(String body, {String title = 'Example Article'}) {
  return '''
<!doctype html>
<html>
<head>
  <title>$title</title>
</head>
<body>
$body
</body>
</html>
''';
}

String _longText(String seed) {
  return List<String>.filled(8, seed).join(' ');
}

String _extractAndSanitize(String html) {
  final extracted = ArticleExtractor.extractFromHtml(html: html, url: _baseUrl);
  return HtmlSanitizer.sanitize(extracted.contentHtml);
}

ArticleExtractionDiagnostics _diagnose(String html, {int? statusCode}) {
  return ArticleExtractor.diagnoseFromHtml(
    html: html,
    url: _baseUrl,
    statusCode: statusCode,
  );
}

int _occurrences(String text, String needle) {
  var count = 0;
  var index = 0;
  while (true) {
    index = text.indexOf(needle, index);
    if (index == -1) return count;
    count += 1;
    index += needle.length;
  }
}
