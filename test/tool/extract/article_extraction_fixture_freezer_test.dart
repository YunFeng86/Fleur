import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:fleur/services/extract/article_extractor.dart';

import '../../../tool/src/extract/article_extraction_audit.dart';
import '../../../tool/src/extract/article_extraction_fixture_freezer.dart';

void main() {
  test(
    'freeze_tool_dry_run parses candidates without fetching or writing',
    () async {
      final fetcher = _FakeFetcher();
      final freezer = ArticleExtractionFixtureFreezer(fetcher: fetcher.call);
      final outputDirectory = Directory(
        p.join(
          Directory.systemTemp.path,
          'fleur-article-fixture-dry-run-unused',
        ),
      );

      final result = await freezer.freezeFromAuditReport(
        auditMarkdown: _dryRunAuditMarkdown,
        outputDirectory: outputDirectory,
        options: const ArticleExtractionFixtureFreezeOptions(
          dryRun: true,
          limit: 2,
        ),
      );

      expect(result.dryRun, true);
      expect(result.planned, hasLength(2));
      expect(result.frozen, isEmpty);
      expect(result.skipped, isEmpty);
      expect(fetcher.calls, isEmpty);
      expect(outputDirectory.existsSync(), false);
    },
  );

  test('freeze_tool_dry_run can target titleOnly candidates', () async {
    final fetcher = _FakeFetcher();
    final freezer = ArticleExtractionFixtureFreezer(fetcher: fetcher.call);
    final outputDirectory = Directory(
      p.join(
        Directory.systemTemp.path,
        'fleur-article-fixture-targeted-dry-run-unused',
      ),
    );

    final result = await freezer.freezeFromAuditReport(
      auditMarkdown: _dryRunAuditMarkdown,
      outputDirectory: outputDirectory,
      options: const ArticleExtractionFixtureFreezeOptions(
        dryRun: true,
        targetReasons: [ArticleExtractionFailureReason.titleOnly],
      ),
    );

    expect(result.dryRun, true);
    expect(result.planned, hasLength(1));
    expect(
      result.planned.single.expectedReason,
      ArticleExtractionFailureReason.titleOnly,
    );
    expect(result.planned.single.url, 'https://example.com/title-only');
    expect(fetcher.calls, isEmpty);
    expect(outputDirectory.existsSync(), false);
  });

  test('minimal freeze redacts page content while preserving reason', () async {
    final fetcher = _FakeFetcher({
      'https://example.com/clean': ArticleExtractionAuditFetchResult(
        body: _minimalFreezeHtml(
          title: 'Private clean title',
          reasonText: 'Private clean article fixture body.',
          imageUrl: 'https://cdn.private.example/images/secret.webp',
          imageAlt: 'Private image description',
        ),
        statusCode: 200,
      ),
    });
    final freezer = ArticleExtractionFixtureFreezer(fetcher: fetcher.call);
    final outputDirectory = Directory.systemTemp.createTempSync(
      'fleur-article-fixture-minimal-',
    );

    try {
      final result = await freezer.freezeFromAuditReport(
        auditMarkdown: _singleCandidateMarkdown(
          reason: 'none',
          url: 'https://example.com/clean',
          title: 'Private clean title',
        ),
        outputDirectory: outputDirectory,
      );

      expect(result.frozen, hasLength(1));
      final fixture = result.frozen.single;
      expect(fixture.htmlMode, ArticleExtractionFixtureHtmlMode.minimal);
      expect(fixture.contentMode, ArticleExtractionFixtureContentMode.redacted);
      expect(fixture.title, startsWith('Fixture None '));
      expect(fixture.sourceTitleHash, matches(RegExp(r'^[0-9a-f]{40}$')));
      expect(fixture.fixtureSizeBytes, lessThan(fixture.sourceSizeBytes));
      final html = File(
        p.joinAll([outputDirectory.path, ...fixture.htmlPath.split('/')]),
      ).readAsStringSync();
      expect(html, isNot(contains('x-script-noise')));
      expect(html, isNot(contains('data-large')));
      expect(html, isNot(contains('Private clean title')));
      expect(html, isNot(contains('Private clean article fixture body')));
      expect(html, isNot(contains('https://cdn.private.example')));
      expect(html, isNot(contains('Private image description')));
      expect(html, contains('Fixture article body paragraph'));
      expect(html, contains('https://fixture.local/images/'));
    } finally {
      outputDirectory.deleteSync(recursive: true);
    }
  });

  test(
    'minimal freeze preserves empty content without title injection',
    () async {
      final fetcher = _FakeFetcher({
        'https://example.com/empty': const ArticleExtractionAuditFetchResult(
          body: '',
          statusCode: 200,
        ),
      });
      final freezer = ArticleExtractionFixtureFreezer(fetcher: fetcher.call);
      final outputDirectory = Directory.systemTemp.createTempSync(
        'fleur-article-fixture-skip-',
      );

      try {
        final result = await freezer.freezeFromAuditReport(
          auditMarkdown: _singleCandidateMarkdown(
            reason: 'emptyContent',
            url: 'https://example.com/empty',
            title: 'Empty sample',
          ),
          outputDirectory: outputDirectory,
          options: const ArticleExtractionFixtureFreezeOptions(
            failureReasons: [ArticleExtractionFailureReason.emptyContent],
          ),
        );

        expect(result.frozen, hasLength(1));
        expect(result.skipped, isEmpty);
        expect(
          File(
            p.join(outputDirectory.path, 'manifest.json'),
          ).readAsStringSync(),
          contains('"expectedReason": "emptyContent"'),
        );
      } finally {
        outputDirectory.deleteSync(recursive: true);
      }
    },
  );

  test(
    'minimal redaction keeps fixed duplicate-like sources synthetic',
    () async {
      final fetcher = _FakeFetcher({
        'https://example.com/duplicate': ArticleExtractionAuditFetchResult(
          body: _duplicateTitleHtml(title: 'Private duplicate title'),
          statusCode: 200,
        ),
      });
      final freezer = ArticleExtractionFixtureFreezer(fetcher: fetcher.call);
      final outputDirectory = Directory.systemTemp.createTempSync(
        'fleur-article-fixture-duplicate-redacted-',
      );

      try {
        final result = await freezer.freezeFromAuditReport(
          auditMarkdown: _singleCandidateMarkdown(
            reason: 'none',
            url: 'https://example.com/duplicate',
            title: 'Private duplicate title',
          ),
          outputDirectory: outputDirectory,
        );

        expect(result.frozen, hasLength(1));
        final fixture = result.frozen.single;
        final html = File(
          p.joinAll([outputDirectory.path, ...fixture.htmlPath.split('/')]),
        ).readAsStringSync();
        final diagnostics = ArticleExtractor.diagnoseFromHtml(
          html: html,
          url: fixture.url,
          statusCode: fixture.statusCode,
        );

        expect(html, isNot(contains('Private duplicate title')));
        expect(html, contains(fixture.title));
        expect(diagnostics.reason, ArticleExtractionFailureReason.none);
      } finally {
        outputDirectory.deleteSync(recursive: true);
      }
    },
  );

  test('minimal redaction keeps fixed lazy image sources synthetic', () async {
    final fetcher = _FakeFetcher({
      'https://example.com/lazy': ArticleExtractionAuditFetchResult(
        body: _lazyImageMissingHtml(),
        statusCode: 200,
      ),
    });
    final freezer = ArticleExtractionFixtureFreezer(fetcher: fetcher.call);
    final outputDirectory = Directory.systemTemp.createTempSync(
      'fleur-article-fixture-lazy-redacted-',
    );

    try {
      final result = await freezer.freezeFromAuditReport(
        auditMarkdown: _singleCandidateMarkdown(
          reason: 'none',
          url: 'https://example.com/lazy',
          title: 'Private lazy title',
        ),
        outputDirectory: outputDirectory,
      );

      expect(result.frozen, hasLength(1));
      final fixture = result.frozen.single;
      final html = File(
        p.joinAll([outputDirectory.path, ...fixture.htmlPath.split('/')]),
      ).readAsStringSync();
      final diagnostics = ArticleExtractor.diagnoseFromHtml(
        html: html,
        url: fixture.url,
        statusCode: fixture.statusCode,
      );

      expect(html, isNot(contains('src="/img/b_ld.png"')));
      expect(html, contains('https://fixture.local/images/'));
      expect(html, isNot(contains('https://cdn.private.example')));
      expect(diagnostics.reason, ArticleExtractionFailureReason.none);
    } finally {
      outputDirectory.deleteSync(recursive: true);
    }
  });

  test(
    'minimal redaction accepts fixed titleOnly snapshots as normal',
    () async {
      final fetcher = _FakeFetcher({
        'https://example.com/title-recoverable':
            ArticleExtractionAuditFetchResult(
              body: _recoverableTitleOnlyHtml(),
              statusCode: 200,
            ),
      });
      final freezer = ArticleExtractionFixtureFreezer(fetcher: fetcher.call);
      final outputDirectory = Directory.systemTemp.createTempSync(
        'fleur-article-fixture-titleonly-redacted-',
      );

      try {
        final result = await freezer.freezeFromAuditReport(
          auditMarkdown: _singleCandidateMarkdown(
            reason: 'titleOnly',
            url: 'https://example.com/title-recoverable',
            title: _longPrivateTitle,
          ),
          outputDirectory: outputDirectory,
          options: const ArticleExtractionFixtureFreezeOptions(
            targetReasons: [ArticleExtractionFailureReason.titleOnly],
          ),
        );

        expect(result.frozen, hasLength(1));
        final fixture = result.frozen.single;
        expect(fixture.expectedReason, ArticleExtractionFailureReason.none);
        final html = File(
          p.joinAll([outputDirectory.path, ...fixture.htmlPath.split('/')]),
        ).readAsStringSync();
        final diagnostics = ArticleExtractor.diagnoseFromHtml(
          html: html,
          url: fixture.url,
          statusCode: fixture.statusCode,
        );

        expect(html, isNot(contains(_longPrivateTitle)));
        expect(html, isNot(contains('Private static body text')));
        expect(html, contains('post-content-content'));
        expect(html, contains('Fixture body paragraph'));
        expect(diagnostics.reason, ArticleExtractionFailureReason.none);
      } finally {
        outputDirectory.deleteSync(recursive: true);
      }
    },
  );

  test('raw freeze keeps the fetched HTML for local debugging', () async {
    final fetcher = _FakeFetcher({
      'https://example.com/raw': ArticleExtractionAuditFetchResult(
        body: _minimalFreezeHtml(reasonText: 'Raw article fixture body.'),
        statusCode: 200,
      ),
    });
    final freezer = ArticleExtractionFixtureFreezer(fetcher: fetcher.call);
    final outputDirectory = Directory.systemTemp.createTempSync(
      'fleur-article-fixture-raw-',
    );

    try {
      final result = await freezer.freezeFromAuditReport(
        auditMarkdown: _singleCandidateMarkdown(
          reason: 'none',
          url: 'https://example.com/raw',
          title: 'Raw sample',
        ),
        outputDirectory: outputDirectory,
        options: const ArticleExtractionFixtureFreezeOptions(
          htmlMode: ArticleExtractionFixtureHtmlMode.raw,
        ),
      );

      expect(result.frozen, hasLength(1));
      final fixture = result.frozen.single;
      expect(fixture.htmlMode, ArticleExtractionFixtureHtmlMode.raw);
      expect(fixture.contentMode, ArticleExtractionFixtureContentMode.raw);
      expect(fixture.fixtureSizeBytes, fixture.sourceSizeBytes);
      final html = File(
        p.joinAll([outputDirectory.path, ...fixture.htmlPath.split('/')]),
      ).readAsStringSync();
      expect(html, contains('x-script-noise'));
      expect(html, contains('data-large'));
    } finally {
      outputDirectory.deleteSync(recursive: true);
    }
  });
}

class _FakeFetcher {
  _FakeFetcher([Map<String, ArticleExtractionAuditFetchResult>? responses])
    : _responses = responses ?? const {};

  final Map<String, ArticleExtractionAuditFetchResult> _responses;
  final calls = <Uri>[];

  Future<ArticleExtractionAuditFetchResult> call(
    Uri uri, {
    required Duration timeout,
    required String? userAgent,
  }) async {
    calls.add(uri);
    final response = _responses[uri.toString()];
    if (response == null) {
      throw StateError('Unexpected fetch: $uri');
    }
    return response;
  }
}

String _minimalFreezeHtml({
  String title = 'Clean sample',
  required String reasonText,
  String? imageUrl,
  String imageAlt = 'Fixture image',
  String removedSignal = '',
}) {
  final longAttribute = List<String>.filled(5000, 'x').join();
  final body = List<String>.filled(12, reasonText).join(' ');
  final imageHtml = imageUrl == null
      ? ''
      : '<img src="$imageUrl" alt="$imageAlt" title="$imageAlt">';
  return '''
<!doctype html>
<html>
<head>
  <title>$title</title>
  <meta property="og:title" content="$title">
  <meta name="description" content="$longAttribute">
  <script>window.__noise = "x-script-noise $removedSignal";</script>
  <style>.x-style-noise { color: red; } $removedSignal</style>
</head>
<body>
  <article data-large="$longAttribute">
    $imageHtml
    <p>$body</p>
  </article>
</body>
</html>
''';
}

String _duplicateTitleHtml({required String title}) {
  return '''
<!doctype html>
<html>
<head>
  <title>$title</title>
</head>
<body>
  <article>
    <h2>$title</h2>
    <p>$title</p>
    <p>${List<String>.filled(8, 'Private duplicate body text.').join(' ')}</p>
  </article>
</body>
</html>
''';
}

String _lazyImageMissingHtml() {
  return '''
<!doctype html>
<html>
<head>
  <title>Private lazy title</title>
</head>
<body>
  <article>
    <img src="/img/b_ld.png"
      data-lazyload="https://cdn.private.example/images/secret.webp"
      alt="Private lazy image">
    <p>${List<String>.filled(8, 'Private lazy image body text.').join(' ')}</p>
  </article>
</body>
</html>
''';
}

String _recoverableTitleOnlyHtml() {
  final body = List<String>.filled(8, 'Private static body text.').join(' ');
  return '''
<!doctype html>
<html>
<head>
  <title>$_longPrivateTitle</title>
</head>
<body>
  <article>
    <h1>$_longPrivateTitle</h1>
  </article>
  <content-host>
    <p>$body</p>
  </content-host>
</body>
</html>
''';
}

const _longPrivateTitle =
    'Private title-only regression heading long enough to be selected as the '
    'initial article candidate by the legacy scorer';

String _singleCandidateMarkdown({
  required String reason,
  required String url,
  required String title,
}) {
  return '''
# Fleur Article Extraction Audit

## Fixture Candidates

### $reason

| Category | Feed | Article | Status | Title | Reason |
| --- | --- | --- | ---: | --- | --- |
| Blogs | https://example.com/feed.xml | $url | 200 | $title | $reason |
''';
}

const _dryRunAuditMarkdown = '''
# Fleur Article Extraction Audit

## Fixture Candidates

### none

| Category | Feed | Article | Status | Title | Reason |
| --- | --- | --- | ---: | --- | --- |
| Blogs | https://example.com/feed.xml | https://example.com/clean | 200 | Clean sample | none |

### titleOnly

| Category | Feed | Article | Status | Title | Reason |
| --- | --- | --- | ---: | --- | --- |
| Blogs | https://example.com/feed.xml | https://example.com/title-only | 200 | Title only sample | titleOnly |
''';
