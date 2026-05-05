import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/extract/article_extraction_audit.dart';
import 'package:fleur/services/extract/article_extractor.dart';

void main() {
  test('audits OPML feeds and aggregates extraction diagnostics', () async {
    final fetcher = _FakeFetcher({
      'https://example.com/clean.xml': _ok(
        _rss('Clean feed', [
          _item(
            title: 'Clean article',
            link: 'https://example.com/clean-article',
            pubDate: 'Tue, 05 May 2026 10:00:00 GMT',
          ),
        ]),
      ),
      'https://example.com/clean-article': _ok(
        _article('''
<article>
  <p>${_longText('Clean article body should pass extraction diagnostics.')}</p>
</article>
'''),
      ),
      'https://example.com/blocked.xml': _ok(
        _rss('Blocked feed', [
          _item(
            title: 'Blocked article',
            link: 'https://example.com/blocked-article',
            pubDate: 'Tue, 05 May 2026 09:00:00 GMT',
          ),
        ]),
      ),
      'https://example.com/blocked-article':
          const ArticleExtractionAuditFetchResult(
            body: '<html><body>403 Forbidden access denied</body></html>',
            statusCode: 403,
          ),
      'https://example.com/article-http-fail.xml': _ok(
        _rss('HTTP fail feed', [
          _item(
            title: 'HTTP failed article',
            link: 'https://example.com/article-http-fail',
            pubDate: 'Tue, 05 May 2026 08:00:00 GMT',
          ),
        ]),
      ),
      'https://example.com/article-http-fail':
          const ArticleExtractionAuditFetchResult(
            body: 'server error',
            statusCode: 500,
          ),
      'https://example.com/empty.xml': _ok(_rss('Empty feed', const [])),
      'https://example.com/bad.xml': const ArticleExtractionAuditFetchResult(
        body: '<html>not a feed</html>',
        statusCode: 200,
      ),
      'https://example.com/feed-fetch-fail.xml': TimeoutException('offline'),
    });
    final auditor = ArticleExtractionAuditor(fetcher: fetcher.call);

    final report = await auditor.auditOpml(
      _opml([
        ('Tech', 'https://example.com/clean.xml'),
        ('Tech', 'https://example.com/blocked.xml'),
        ('Tech', 'https://example.com/article-http-fail.xml'),
        ('Misc', 'https://example.com/empty.xml'),
        ('Misc', 'https://example.com/bad.xml'),
        ('Misc', 'https://example.com/feed-fetch-fail.xml'),
      ]),
    );

    expect(report.opmlEntryCount, 6);
    expect(report.feedAttempted, 6);
    expect(report.feedOkCount, 4);
    expect(report.feedFailedCount, 2);
    expect(report.emptyFeedCount, 1);
    expect(report.articleAttempted, 3);
    expect(report.articleOkCount, 2);
    expect(report.articleFailedCount, 1);
    expect(report.reasonCounts[ArticleExtractionFailureReason.none], 1);
    expect(
      report.reasonCounts[ArticleExtractionFailureReason.accessBlocked],
      1,
    );
    expect(fetcher.calls, contains('https://example.com/clean.xml'));
    expect(fetcher.calls, contains('https://example.com/clean-article'));
  });

  test(
    'markdown report includes summary, examples, candidates, and failures',
    () async {
      final fetcher = _FakeFetcher({
        'https://example.com/clean.xml': _ok(
          _rss('Clean feed', [
            _item(
              title: 'Clean article',
              link: 'https://example.com/clean-article',
              pubDate: 'Tue, 05 May 2026 10:00:00 GMT',
            ),
          ]),
        ),
        'https://example.com/clean-article': _ok(
          _article('''
<article>
  <p>${_longText('Clean article body should appear in markdown report.')}</p>
</article>
'''),
        ),
        'https://example.com/blocked.xml': _ok(
          _rss('Blocked feed', [
            _item(
              title: 'Blocked article',
              link: 'https://example.com/blocked-article',
              pubDate: 'Tue, 05 May 2026 09:00:00 GMT',
            ),
          ]),
        ),
        'https://example.com/blocked-article':
            const ArticleExtractionAuditFetchResult(
              body: '<html><body>403 Forbidden access denied</body></html>',
              statusCode: 403,
            ),
        'https://example.com/bad.xml': const ArticleExtractionAuditFetchResult(
          body: '<html>not a feed</html>',
          statusCode: 200,
        ),
      });
      final auditor = ArticleExtractionAuditor(fetcher: fetcher.call);

      final report = await auditor.auditOpml(
        _opml([
          ('Tech', 'https://example.com/clean.xml'),
          ('Tech', 'https://example.com/blocked.xml'),
          ('Misc', 'https://example.com/bad.xml'),
        ]),
      );
      final markdown = report.toMarkdown();

      expect(markdown, contains('# Fleur Article Extraction Audit'));
      expect(markdown, contains('## Summary'));
      expect(markdown, contains('## Reason Breakdown'));
      expect(markdown, contains('| none | 1 |'));
      expect(markdown, contains('| accessBlocked | 1 |'));
      expect(markdown, contains('## Top Examples'));
      expect(markdown, contains('### none'));
      expect(markdown, contains('### accessBlocked'));
      expect(markdown, contains('## Fixture Candidates'));
      expect(markdown, contains('Clean article'));
      expect(markdown, contains('Blocked article'));
      expect(markdown, contains('## Fetch Failures'));
      expect(markdown, contains('Feed parse failed'));
    },
  );

  test('respects feed limit and picks newest parsed item per feed', () async {
    final fetcher = _FakeFetcher({
      'https://example.com/limited.xml': _ok(
        _rss('Limited feed', [
          _item(
            title: 'Old article',
            link: 'https://example.com/old',
            pubDate: 'Tue, 05 May 2026 08:00:00 GMT',
          ),
          _item(
            title: 'New article',
            link: '/new',
            pubDate: 'Tue, 05 May 2026 11:00:00 GMT',
          ),
        ]),
      ),
      'https://example.com/new': _ok(
        _article('''
<article>
  <p>${_longText('Newest article should be selected for auditing.')}</p>
</article>
'''),
      ),
      'https://example.com/skipped.xml': _ok(_rss('Skipped feed', const [])),
    });
    final auditor = ArticleExtractionAuditor(fetcher: fetcher.call);

    final report = await auditor.auditOpml(
      _opml([
        ('Tech', 'https://example.com/limited.xml'),
        ('Tech', 'https://example.com/skipped.xml'),
      ]),
      options: const ArticleExtractionAuditOptions(feedLimit: 1),
    );

    expect(report.opmlEntryCount, 2);
    expect(report.feedAttempted, 1);
    expect(report.articleAttempted, 1);
    expect(fetcher.calls, contains('https://example.com/new'));
    expect(fetcher.calls, isNot(contains('https://example.com/old')));
    expect(fetcher.calls, isNot(contains('https://example.com/skipped.xml')));
  });
}

ArticleExtractionAuditFetchResult _ok(String body) {
  return ArticleExtractionAuditFetchResult(body: body, statusCode: 200);
}

String _opml(List<(String, String)> entries) {
  final outlines = entries
      .map(
        (entry) =>
            '<outline text="${entry.$1}"><outline type="rss" xmlUrl="${entry.$2}"/></outline>',
      )
      .join('\n');
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<opml version="1.0">
  <body>
    $outlines
  </body>
</opml>
''';
}

String _rss(String title, List<String> items) {
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>$title</title>
    <link>https://example.com/</link>
    ${items.join('\n')}
  </channel>
</rss>
''';
}

String _item({
  required String title,
  required String link,
  required String pubDate,
}) {
  return '''
<item>
  <title>$title</title>
  <link>$link</link>
  <pubDate>$pubDate</pubDate>
</item>
''';
}

String _article(String body) {
  return '''
<!doctype html>
<html>
<head><title>Audit Article</title></head>
<body>$body</body>
</html>
''';
}

String _longText(String seed) {
  return List<String>.filled(8, seed).join(' ');
}

class _FakeFetcher {
  _FakeFetcher(this._responses);

  final Map<String, Object> _responses;
  final calls = <String>[];

  Future<ArticleExtractionAuditFetchResult> call(
    Uri uri, {
    required Duration timeout,
    required String? userAgent,
  }) async {
    calls.add(uri.toString());
    final response = _responses[uri.toString()];
    if (response == null) {
      throw StateError('Unexpected fetch: $uri');
    }
    if (response is Exception) {
      throw response;
    }
    if (response is ArticleExtractionAuditFetchResult) {
      return response;
    }
    throw StateError('Unsupported fake response for $uri');
  }
}
