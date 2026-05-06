import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;

import 'package:fleur/services/extract/article_extraction_audit.dart';
import 'package:fleur/services/extract/article_extraction_fixture_freezer.dart';
import 'package:fleur/services/extract/article_extractor.dart';

void main() {
  group('Article extraction frozen fixtures', () {
    test('fixture_manifest_is_valid', () {
      final samples = _loadSamples();

      expect(samples, isNotEmpty);
      expect(
        samples.map((sample) => sample.id).toSet(),
        hasLength(samples.length),
      );
      for (final sample in samples) {
        expect(sample.id, isNotEmpty, reason: sample.id);
        expect(sample.url, matches(RegExp(r'^https?://')), reason: sample.id);
        expect(sample.title, isNotEmpty, reason: sample.id);
        expect(sample.title, startsWith('Fixture '), reason: sample.id);
        expect(
          sample.sourceTitleHash,
          matches(RegExp(r'^[0-9a-f]{40}$')),
          reason: sample.id,
        );
        expect(sample.htmlPath, endsWith('.html'), reason: sample.id);
        expect(sample.htmlMode, ArticleExtractionFixtureHtmlMode.minimal);
        expect(
          sample.contentMode,
          ArticleExtractionFixtureContentMode.redacted,
          reason: sample.id,
        );
        expect(sample.sourceSizeBytes, greaterThan(0), reason: sample.id);
        expect(sample.fixtureSizeBytes, greaterThan(0), reason: sample.id);
        expect(
          sample.fixtureSizeBytes,
          lessThanOrEqualTo(sample.sourceSizeBytes),
          reason: sample.id,
        );
        expect(sample.htmlFile.existsSync(), true, reason: sample.id);
      }
    });

    test('fixture_html_is_redacted', () {
      final failures = <String>[];
      for (final sample in _loadSamples()) {
        final html = sample.htmlFile.readAsStringSync();
        final disallowedUrls = RegExp(r'''https?://[^\s"'<>]+''')
            .allMatches(html)
            .map((match) => match.group(0)!)
            .where((url) => !url.startsWith('https://fixture.local/'));
        if (disallowedUrls.isNotEmpty) {
          failures.add('${sample.id}: external URL ${disallowedUrls.first}');
        }
        if (RegExp(r'[一-龥ぁ-んァ-ン]').hasMatch(html)) {
          failures.add('${sample.id}: contains source locale text');
        }
        if (RegExp(r'%[eE][0-9A-Fa-f]').hasMatch(html)) {
          failures.add('${sample.id}: contains percent-encoded source text');
        }

        for (final host in [sample.urlHost, sample.feedHost]) {
          if (host.isNotEmpty && html.contains(host)) {
            failures.add('${sample.id}: contains original host $host');
          }
        }
      }

      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('diagnoses_frozen_fixtures', () {
      final failures = <String>[];
      for (final sample in _loadSamples()) {
        final diagnostics = _diagnose(sample);
        if (diagnostics.reason != sample.expectedReason) {
          failures.add(
            '${sample.id}: expected ${sample.expectedReason.name}, '
            'got ${diagnostics.reason.name}',
          );
        }
      }

      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('normal_fixtures_have_body', () {
      final normalSamples = _loadSamples()
          .where(
            (sample) =>
                sample.expectedReason == ArticleExtractionFailureReason.none,
          )
          .toList(growable: false);

      expect(normalSamples, isNotEmpty);
      for (final sample in normalSamples) {
        final diagnostics = _diagnose(sample);
        expect(
          _textFromHtml(diagnostics.sanitizedHtml).length,
          greaterThanOrEqualTo(120),
          reason: sample.id,
        );
      }
    });

    test('failure_fixtures_are_classified', () {
      final failureSamples = _loadSamples()
          .where(
            (sample) =>
                sample.expectedReason != ArticleExtractionFailureReason.none,
          )
          .toList(growable: false);

      expect(failureSamples, isNotEmpty);
      for (final sample in failureSamples) {
        final diagnostics = _diagnose(sample);
        expect(
          diagnostics.reason,
          isNot(ArticleExtractionFailureReason.none),
          reason: sample.id,
        );
      }
    });

    test('fixture_size_stays_small', () {
      final samples = _loadSamples();
      final totalSize = samples.fold<int>(
        0,
        (sum, sample) => sum + sample.htmlFile.lengthSync(),
      );

      expect(totalSize, lessThanOrEqualTo(300 * 1024));
      for (final sample in samples) {
        expect(
          sample.htmlFile.lengthSync(),
          lessThanOrEqualTo(50 * 1024),
          reason: sample.id,
        );
      }
    });
  });

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
    'minimal freeze skips snapshots when redaction changes reason',
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

        expect(result.frozen, isEmpty);
        expect(result.skipped, hasLength(1));
        expect(result.skipped.single.message, contains('changed reason'));
        expect(
          File(
            p.join(outputDirectory.path, 'manifest.json'),
          ).readAsStringSync(),
          contains('"samples": []'),
        );
      } finally {
        outputDirectory.deleteSync(recursive: true);
      }
    },
  );

  test('duplicateTitle redaction keeps equivalent synthetic titles', () async {
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
          reason: 'duplicateTitle',
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
      expect(diagnostics.reason, ArticleExtractionFailureReason.duplicateTitle);
    } finally {
      outputDirectory.deleteSync(recursive: true);
    }
  });

  test(
    'lazyImageMissing redaction keeps missing lazy source semantics',
    () async {
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
            reason: 'lazyImageMissing',
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

        expect(html, contains('src="/img/b_ld.png"'));
        expect(html, contains('data-lazyload="https://fixture.local/images/'));
        expect(html, isNot(contains('https://cdn.private.example')));
        expect(
          diagnostics.reason,
          ArticleExtractionFailureReason.lazyImageMissing,
        );
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

ArticleExtractionDiagnostics _diagnose(_FixtureSample sample) {
  return ArticleExtractor.diagnoseFromHtml(
    html: sample.htmlFile.readAsStringSync(),
    url: sample.url,
    statusCode: sample.statusCode,
  );
}

String _textFromHtml(String html) {
  return (html_parser.parseFragment(html).text ?? '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<_FixtureSample> _loadSamples() {
  final manifestFile = File(_manifestPath);
  expect(manifestFile.existsSync(), true);

  final decoded =
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
  final samplesValue = decoded['samples'];
  if (samplesValue is! List<Object?>) {
    fail('manifest samples must be a list');
  }
  return samplesValue.map(_FixtureSample.fromJson).toList(growable: false);
}

class _FixtureSample {
  _FixtureSample({
    required this.id,
    required this.feedUrl,
    required this.url,
    required this.title,
    required this.sourceTitleHash,
    required this.expectedReason,
    required this.htmlPath,
    required this.statusCode,
    required this.sourceSizeBytes,
    required this.fixtureSizeBytes,
    required this.htmlMode,
    required this.contentMode,
  });

  factory _FixtureSample.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      fail('manifest sample must be an object');
    }
    return _FixtureSample(
      id: _requiredString(value, 'id'),
      feedUrl: _requiredString(value, 'feedUrl'),
      url: _requiredString(value, 'url'),
      title: _requiredString(value, 'title'),
      sourceTitleHash: _requiredString(value, 'sourceTitleHash'),
      expectedReason: _requiredReason(value, 'expectedReason'),
      htmlPath: _requiredString(value, 'htmlPath'),
      statusCode: _optionalInt(value, 'statusCode'),
      sourceSizeBytes: _requiredInt(value, 'sourceSizeBytes'),
      fixtureSizeBytes: _requiredInt(value, 'fixtureSizeBytes'),
      htmlMode: _requiredHtmlMode(value, 'htmlMode'),
      contentMode: _requiredContentMode(value, 'contentMode'),
    );
  }

  final String id;
  final String feedUrl;
  final String url;
  final String title;
  final String sourceTitleHash;
  final ArticleExtractionFailureReason expectedReason;
  final String htmlPath;
  final int? statusCode;
  final int sourceSizeBytes;
  final int fixtureSizeBytes;
  final ArticleExtractionFixtureHtmlMode htmlMode;
  final ArticleExtractionFixtureContentMode contentMode;

  File get htmlFile => File(p.joinAll([_fixtureRoot, ...htmlPath.split('/')]));

  String get urlHost => Uri.tryParse(url)?.host ?? '';

  String get feedHost => Uri.tryParse(feedUrl)?.host ?? '';
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    fail('manifest sample field "$key" must be a non-empty string');
  }
  return value;
}

ArticleExtractionFailureReason _requiredReason(
  Map<String, Object?> json,
  String key,
) {
  final value = _requiredString(json, key);
  for (final reason in ArticleExtractionFailureReason.values) {
    if (reason.name == value) return reason;
  }
  fail('unknown ArticleExtractionFailureReason: $value');
}

int? _optionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  fail('manifest sample field "$key" must be an int or null');
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int && value > 0) return value;
  fail('manifest sample field "$key" must be a positive int');
}

ArticleExtractionFixtureHtmlMode _requiredHtmlMode(
  Map<String, Object?> json,
  String key,
) {
  final value = _requiredString(json, key);
  for (final mode in ArticleExtractionFixtureHtmlMode.values) {
    if (mode.name == value) return mode;
  }
  fail('unknown ArticleExtractionFixtureHtmlMode: $value');
}

ArticleExtractionFixtureContentMode _requiredContentMode(
  Map<String, Object?> json,
  String key,
) {
  final value = _requiredString(json, key);
  for (final mode in ArticleExtractionFixtureContentMode.values) {
    if (mode.name == value) return mode;
  }
  fail('unknown ArticleExtractionFixtureContentMode: $value');
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

const _fixtureRoot = 'test/fixtures/article_extraction';
const _manifestPath = '$_fixtureRoot/manifest.json';

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
