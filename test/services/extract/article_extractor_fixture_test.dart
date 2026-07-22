import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
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
        expect(sample.htmlMode, 'minimal');
        expect(sample.contentMode, 'redacted', reason: sample.id);
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
      htmlMode: _requiredString(value, 'htmlMode'),
      contentMode: _requiredString(value, 'contentMode'),
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
  final String htmlMode;
  final String contentMode;

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

const _fixtureRoot = 'test/fixtures/article_extraction';
const _manifestPath = '$_fixtureRoot/manifest.json';
