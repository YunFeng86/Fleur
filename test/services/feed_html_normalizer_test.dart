import 'package:html/parser.dart' as html_parser;
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/feed_html_normalizer.dart';
import 'package:fleur/services/html_sanitizer.dart';

void main() {
  test('normalizes protocol-relative image urls with the article scheme', () {
    final normalized = FeedHtmlNormalizer.normalize(
      '<p><img src="//image.example/a.png"></p>',
      baseUrl: Uri.parse('https://site.example/post'),
    );

    expect(normalized, contains('src="https://image.example/a.png"'));
  });

  test(
    'uses https for protocol-relative images when base url is unavailable',
    () {
      final normalized = FeedHtmlNormalizer.normalize(
        '<p><img src="//image.example/a.png"></p>',
      );

      expect(normalized, contains('src="https://image.example/a.png"'));
    },
  );

  test('promotes lazy image attributes to src', () {
    final normalized = FeedHtmlNormalizer.normalize(
      '<p>'
      '<img src="" data-src="https://cdn.example/data.png">'
      '<img src="about:blank" data-lazy-src="/lazy.png">'
      '<img src="placeholder.gif" data-original="https://cdn.example/orig.png">'
      '<img data-srcset="/from-srcset.png 1x, /second.png 2x">'
      '</p>',
      baseUrl: Uri.parse('https://site.example/articles/one/'),
    );

    expect(normalized, contains('src="https://cdn.example/data.png"'));
    expect(normalized, contains('src="https://site.example/lazy.png"'));
    expect(normalized, contains('src="https://cdn.example/orig.png"'));
    expect(normalized, contains('src="https://site.example/from-srcset.png"'));
  });

  test('resolves relative image and link urls against article url', () {
    final normalized = FeedHtmlNormalizer.normalize(
      '<p><a href="../demo">Demo</a><img src="./img.png"></p>',
      baseUrl: Uri.parse('https://site.example/blog/post/'),
    );

    expect(normalized, contains('href="https://site.example/blog/demo"'));
    expect(
      normalized,
      contains('src="https://site.example/blog/post/img.png"'),
    );
  });

  test('removes unusable image sources from src', () {
    final normalized = FeedHtmlNormalizer.normalize(
      '<p>'
      '<img src="">'
      '<img src="data:image/png;base64,abc">'
      '<img src="about:blank">'
      '<img src="/placeholder.png">'
      '</p>',
      baseUrl: Uri.parse('https://site.example/post'),
    );

    expect(normalized, isNot(contains('src=""')));
    expect(normalized, isNot(contains('data:image')));
    expect(normalized, isNot(contains('about:blank')));
    expect(normalized, isNot(contains('placeholder.png')));
  });

  test('converts Hexo highlight tables into canonical code blocks', () {
    final normalized = FeedHtmlNormalizer.normalize('''
<figure class="highlight bash">
  <table><tbody><tr>
    <td class="gutter"><pre><span>1</span><br><span>2</span></pre></td>
    <td class="code"><pre><span class="meta">\$</span> echo <span class="string">hello</span><br>pwd</pre></td>
  </tr></tbody></table>
</figure>
''');
    final fragment = html_parser.parseFragment(normalized);
    final pre = fragment.querySelector('pre.language-bash');
    final code = pre?.querySelector('code.language-bash');

    expect(fragment.querySelector('figure'), isNull);
    expect(fragment.querySelector('table'), isNull);
    expect(pre?.attributes['data-language'], 'bash');
    expect(code?.attributes['data-language'], 'bash');
    expect(code?.querySelector('span.meta')?.text, r'$');
    expect(code?.querySelector('span.string')?.text, 'hello');
    expect(code?.innerHtml, contains('<br>pwd'));
    expect(code?.text, isNot(contains('1')));
    expect(code?.text, isNot(contains('2')));
  });

  test('repairs Hexo code tables sanitized before normalization', () {
    const html = '''
<figure class="highlight python">
  <table><tbody><tr>
    <td class="gutter"><pre><span class="line">1</span><br><span class="line">2</span></pre></td>
    <td class="code"><pre><span class="line"><span class="keyword">print</span>("one")</span><br><span class="line">print("two")</span></pre></td>
  </tr></tbody></table>
</figure>
''';
    final prematurelySanitized = HtmlSanitizer.sanitize(html);
    final normalized = FeedHtmlNormalizer.normalize(prematurelySanitized);
    final fragment = html_parser.parseFragment(normalized);
    final code = fragment.querySelector('pre > code');

    expect(prematurelySanitized, contains('<table>'));
    expect(fragment.querySelector('table'), isNull);
    expect(code?.text, contains('print("one")'));
    expect(code?.text, contains('print("two")'));
    expect(code?.text, isNot(contains('12')));
    expect(code?.querySelector('span.keyword')?.text, 'print');
  });

  test('does not rewrite ordinary article tables', () {
    const html = '''
<table><tbody><tr>
  <td><pre><span class="line">Version</span></pre></td>
  <td><pre>value</pre></td>
</tr></tbody></table>
''';

    final normalized = FeedHtmlNormalizer.normalize(html);
    final fragment = html_parser.parseFragment(normalized);

    expect(fragment.querySelector('table'), isNotNull);
    expect(fragment.querySelectorAll('td pre'), hasLength(2));
    expect(fragment.querySelector('pre > code'), isNull);
  });
}
