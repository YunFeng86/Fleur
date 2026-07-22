import 'package:pool/pool.dart';

import 'package:fleur/services/extract/article_extractor_core.dart';
import 'package:fleur/services/opml/opml_service.dart';
import 'package:fleur/services/rss/feed_parser.dart';
import 'package:fleur/services/rss/parsed_feed.dart';

typedef ArticleExtractionAuditFetcher =
    Future<ArticleExtractionAuditFetchResult> Function(
      Uri uri, {
      required Duration timeout,
      required String? userAgent,
    });

class ArticleExtractionAuditOptions {
  const ArticleExtractionAuditOptions({
    this.feedLimit,
    this.entriesPerFeed = 1,
    this.concurrency = 4,
    this.timeout = const Duration(seconds: 12),
    this.userAgent,
    this.topExamplesPerReason = 5,
    this.fixtureCandidatesPerReason = 3,
    this.successFixtureCandidates = 5,
  });

  final int? feedLimit;
  final int entriesPerFeed;
  final int concurrency;
  final Duration timeout;
  final String? userAgent;
  final int topExamplesPerReason;
  final int fixtureCandidatesPerReason;
  final int successFixtureCandidates;
}

class ArticleExtractionAuditFetchResult {
  const ArticleExtractionAuditFetchResult({
    required this.body,
    required this.statusCode,
  });

  final String body;
  final int? statusCode;
}

class ArticleExtractionAuditor {
  ArticleExtractionAuditor({
    required ArticleExtractionAuditFetcher fetcher,
    OpmlService? opmlService,
    FeedParser? feedParser,
  }) : _fetcher = fetcher,
       _opmlService = opmlService ?? OpmlService(),
       _feedParser = feedParser ?? FeedParser();

  final ArticleExtractionAuditFetcher _fetcher;
  final OpmlService _opmlService;
  final FeedParser _feedParser;

  Future<ArticleExtractionAuditReport> auditOpml(
    String opmlXml, {
    ArticleExtractionAuditOptions options =
        const ArticleExtractionAuditOptions(),
  }) async {
    final watch = Stopwatch()..start();
    final entries = _opmlService.parseEntries(opmlXml);
    final selectedEntries = _limitEntries(entries, options.feedLimit);
    final pool = Pool(_positive(options.concurrency, fallback: 1));
    final futures = <Future<ArticleExtractionFeedAuditResult>>[];

    for (final entry in selectedEntries) {
      futures.add(
        pool.withResource(() async {
          return _auditFeed(entry, options: options);
        }),
      );
    }

    try {
      final feedResults = await Future.wait(futures);
      watch.stop();
      return ArticleExtractionAuditReport(
        opmlEntryCount: entries.length,
        feedResults: feedResults,
        elapsed: watch.elapsed,
        options: options,
      );
    } finally {
      await pool.close();
    }
  }

  List<OpmlEntry> _limitEntries(List<OpmlEntry> entries, int? limit) {
    if (limit == null) return entries;
    if (limit <= 0) return const [];
    return entries.take(limit).toList(growable: false);
  }

  Future<ArticleExtractionFeedAuditResult> _auditFeed(
    OpmlEntry entry, {
    required ArticleExtractionAuditOptions options,
  }) async {
    final feedUri = Uri.tryParse(entry.url);
    if (feedUri == null || !feedUri.hasScheme) {
      return ArticleExtractionFeedAuditResult(
        category: entry.category,
        feedUrl: entry.url,
        feedTitle: null,
        statusCode: null,
        parsedItemCount: 0,
        articles: const [],
        error: 'Invalid feed URL',
      );
    }

    ArticleExtractionAuditFetchResult fetchResult;
    try {
      fetchResult = await _fetcher(
        feedUri,
        timeout: options.timeout,
        userAgent: options.userAgent,
      );
    } catch (e) {
      return ArticleExtractionFeedAuditResult(
        category: entry.category,
        feedUrl: entry.url,
        feedTitle: null,
        statusCode: null,
        parsedItemCount: 0,
        articles: const [],
        error: 'Feed fetch failed: $e',
      );
    }

    if (!_isSuccessStatus(fetchResult.statusCode)) {
      return ArticleExtractionFeedAuditResult(
        category: entry.category,
        feedUrl: entry.url,
        feedTitle: null,
        statusCode: fetchResult.statusCode,
        parsedItemCount: 0,
        articles: const [],
        error: 'Feed HTTP ${fetchResult.statusCode ?? 'unknown'}',
      );
    }

    ParsedFeed parsed;
    try {
      parsed = _feedParser.parse(fetchResult.body);
    } catch (e) {
      return ArticleExtractionFeedAuditResult(
        category: entry.category,
        feedUrl: entry.url,
        feedTitle: null,
        statusCode: fetchResult.statusCode,
        parsedItemCount: 0,
        articles: const [],
        error: 'Feed parse failed: $e',
      );
    }

    final selectedItems = _selectItems(
      parsed.items,
      _positive(options.entriesPerFeed, fallback: 1),
    );
    final articles = <ArticleExtractionArticleAuditResult>[];
    for (final item in selectedItems) {
      articles.add(await _auditArticle(item, entry: entry, options: options));
    }

    return ArticleExtractionFeedAuditResult(
      category: entry.category,
      feedUrl: entry.url,
      feedTitle: parsed.title,
      statusCode: fetchResult.statusCode,
      parsedItemCount: parsed.items.length,
      articles: articles,
      error: null,
    );
  }

  List<ParsedItem> _selectItems(List<ParsedItem> items, int limit) {
    if (limit <= 0 || items.isEmpty) return const [];
    final sorted = items.toList();
    sorted.sort(_compareItemsByPublishedAtDesc);
    return sorted.take(limit).toList(growable: false);
  }

  int _compareItemsByPublishedAtDesc(ParsedItem a, ParsedItem b) {
    final aDate = a.publishedAt;
    final bDate = b.publishedAt;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  }

  Future<ArticleExtractionArticleAuditResult> _auditArticle(
    ParsedItem item, {
    required OpmlEntry entry,
    required ArticleExtractionAuditOptions options,
  }) async {
    final articleUri = _resolveArticleUri(item.link, entry.url);
    if (articleUri == null) {
      return ArticleExtractionArticleAuditResult(
        category: entry.category,
        feedUrl: entry.url,
        articleUrl: item.link,
        articleTitle: item.title,
        statusCode: null,
        reason: null,
        extractedTitle: null,
        sanitizedLength: 0,
        error: 'Invalid article URL',
      );
    }

    ArticleExtractionAuditFetchResult fetchResult;
    try {
      fetchResult = await _fetcher(
        articleUri,
        timeout: options.timeout,
        userAgent: options.userAgent,
      );
    } catch (e) {
      return ArticleExtractionArticleAuditResult(
        category: entry.category,
        feedUrl: entry.url,
        articleUrl: articleUri.toString(),
        articleTitle: item.title,
        statusCode: null,
        reason: null,
        extractedTitle: null,
        sanitizedLength: 0,
        error: 'Article fetch failed: $e',
      );
    }

    if (!_isSuccessStatus(fetchResult.statusCode) &&
        !_isDiagnosticStatus(fetchResult.statusCode)) {
      return ArticleExtractionArticleAuditResult(
        category: entry.category,
        feedUrl: entry.url,
        articleUrl: articleUri.toString(),
        articleTitle: item.title,
        statusCode: fetchResult.statusCode,
        reason: null,
        extractedTitle: null,
        sanitizedLength: 0,
        error: 'Article HTTP ${fetchResult.statusCode ?? 'unknown'}',
      );
    }

    ArticleExtractionDiagnostics diagnostics;
    try {
      diagnostics = ArticleExtractorCore.diagnoseFromHtml(
        html: fetchResult.body,
        url: articleUri.toString(),
        statusCode: fetchResult.statusCode,
      );
    } catch (e) {
      return ArticleExtractionArticleAuditResult(
        category: entry.category,
        feedUrl: entry.url,
        articleUrl: articleUri.toString(),
        articleTitle: item.title,
        statusCode: fetchResult.statusCode,
        reason: null,
        extractedTitle: null,
        sanitizedLength: 0,
        error: 'Article diagnose failed: $e',
      );
    }
    return ArticleExtractionArticleAuditResult(
      category: entry.category,
      feedUrl: entry.url,
      articleUrl: articleUri.toString(),
      articleTitle: item.title,
      statusCode: fetchResult.statusCode,
      reason: diagnostics.reason,
      extractedTitle: diagnostics.article.title,
      sanitizedLength: diagnostics.sanitizedHtml.length,
      error: null,
    );
  }

  Uri? _resolveArticleUri(String link, String feedUrl) {
    final trimmed = link.trim();
    if (trimmed.isEmpty) return null;
    final direct = Uri.tryParse(trimmed);
    if (direct != null && direct.hasScheme) return direct;

    final base = Uri.tryParse(feedUrl);
    if (base == null || !base.hasScheme) return null;
    try {
      final resolved = base.resolve(trimmed);
      return resolved.hasScheme ? resolved : null;
    } on FormatException {
      return null;
    }
  }

  bool _isSuccessStatus(int? statusCode) {
    return statusCode != null && statusCode >= 200 && statusCode < 300;
  }

  bool _isDiagnosticStatus(int? statusCode) {
    return statusCode == 401 || statusCode == 403 || statusCode == 451;
  }

  int _positive(int value, {required int fallback}) {
    return value > 0 ? value : fallback;
  }
}

class ArticleExtractionAuditReport {
  const ArticleExtractionAuditReport({
    required this.opmlEntryCount,
    required this.feedResults,
    required this.elapsed,
    required this.options,
  });

  final int opmlEntryCount;
  final List<ArticleExtractionFeedAuditResult> feedResults;
  final Duration elapsed;
  final ArticleExtractionAuditOptions options;

  int get feedAttempted => feedResults.length;

  int get feedOkCount => feedResults.where((r) => r.error == null).length;

  int get feedFailedCount => feedResults.where((r) => r.error != null).length;

  int get emptyFeedCount => feedResults
      .where((r) => r.error == null && r.parsedItemCount == 0)
      .length;

  List<ArticleExtractionArticleAuditResult> get articleResults {
    return [for (final feed in feedResults) ...feed.articles];
  }

  int get articleAttempted => articleResults.length;

  int get articleOkCount => articleResults.where((r) => r.error == null).length;

  int get articleFailedCount =>
      articleResults.where((r) => r.error != null).length;

  Map<ArticleExtractionFailureReason, int> get reasonCounts {
    final counts = {
      for (final reason in ArticleExtractionFailureReason.values) reason: 0,
    };
    for (final article in articleResults) {
      final reason = article.reason;
      if (reason == null) continue;
      counts[reason] = (counts[reason] ?? 0) + 1;
    }
    return counts;
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Fleur Article Extraction Audit')
      ..writeln()
      ..writeln('## Summary')
      ..writeln()
      ..writeln('| Metric | Value |')
      ..writeln('| --- | ---: |')
      ..writeln('| OPML entries | $opmlEntryCount |')
      ..writeln('| Feeds attempted | $feedAttempted |')
      ..writeln('| Feeds ok | $feedOkCount |')
      ..writeln('| Feeds failed | $feedFailedCount |')
      ..writeln('| Empty feeds | $emptyFeedCount |')
      ..writeln('| Articles attempted | $articleAttempted |')
      ..writeln('| Articles ok | $articleOkCount |')
      ..writeln('| Articles failed | $articleFailedCount |')
      ..writeln('| Elapsed | ${elapsed.inMilliseconds} ms |')
      ..writeln()
      ..writeln('## Reason Breakdown')
      ..writeln()
      ..writeln('| Reason | Count |')
      ..writeln('| --- | ---: |');

    final counts = reasonCounts;
    for (final reason in ArticleExtractionFailureReason.values) {
      buffer.writeln('| ${reason.name} | ${counts[reason] ?? 0} |');
    }

    buffer
      ..writeln()
      ..writeln('## Top Examples');
    _writeExamples(
      buffer,
      perReasonLimit: options.topExamplesPerReason,
      includeNone: true,
    );

    buffer
      ..writeln()
      ..writeln('## Fixture Candidates');
    _writeFixtureCandidates(buffer);

    final fetchFailures = articleResults.where((r) => r.error != null).toList();
    if (feedFailedCount > 0 || fetchFailures.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Fetch Failures');
      _writeFetchFailures(buffer, fetchFailures);
    }

    return buffer.toString();
  }

  void _writeExamples(
    StringBuffer buffer, {
    required int perReasonLimit,
    required bool includeNone,
  }) {
    final limit = perReasonLimit <= 0 ? 1 : perReasonLimit;
    for (final reason in ArticleExtractionFailureReason.values) {
      if (!includeNone && reason == ArticleExtractionFailureReason.none) {
        continue;
      }
      final examples = articleResults
          .where((r) => r.reason == reason)
          .take(limit)
          .toList(growable: false);
      if (examples.isEmpty) continue;
      buffer
        ..writeln()
        ..writeln('### ${reason.name}')
        ..writeln()
        ..writeln(_exampleHeader())
        ..writeln(_exampleDivider());
      for (final example in examples) {
        buffer.writeln(_exampleRow(example));
      }
    }
  }

  void _writeFixtureCandidates(StringBuffer buffer) {
    for (final reason in ArticleExtractionFailureReason.values) {
      final limit = reason == ArticleExtractionFailureReason.none
          ? options.successFixtureCandidates
          : options.fixtureCandidatesPerReason;
      final normalizedLimit = limit <= 0 ? 1 : limit;
      final examples = articleResults
          .where((r) => r.reason == reason)
          .take(normalizedLimit)
          .toList(growable: false);
      if (examples.isEmpty) continue;
      buffer
        ..writeln()
        ..writeln('### ${reason.name}')
        ..writeln()
        ..writeln(_exampleHeader())
        ..writeln(_exampleDivider());
      for (final example in examples) {
        buffer.writeln(_exampleRow(example));
      }
    }
  }

  void _writeFetchFailures(
    StringBuffer buffer,
    List<ArticleExtractionArticleAuditResult> articleFailures,
  ) {
    final feedFailures = feedResults.where((r) => r.error != null).toList();
    if (feedFailures.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('### Feeds')
        ..writeln()
        ..writeln('| Category | Feed | Status | Error |')
        ..writeln('| --- | --- | ---: | --- |');
      for (final feed in feedFailures.take(20)) {
        buffer.writeln(
          '| ${_cell(feed.category ?? '')} | ${_cell(feed.feedUrl)} | '
          '${feed.statusCode ?? ''} | ${_cell(feed.error ?? '')} |',
        );
      }
    }

    if (articleFailures.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('### Articles')
        ..writeln()
        ..writeln('| Category | Feed | Article | Status | Title | Error |')
        ..writeln('| --- | --- | --- | ---: | --- | --- |');
      for (final article in articleFailures.take(20)) {
        buffer.writeln(
          '| ${_cell(article.category ?? '')} | ${_cell(article.feedUrl)} | '
          '${_cell(article.articleUrl)} | ${article.statusCode ?? ''} | '
          '${_cell(article.displayTitle)} | ${_cell(article.error ?? '')} |',
        );
      }
    }
  }

  String _exampleHeader() {
    return '| Category | Feed | Article | Status | Title | Reason |';
  }

  String _exampleDivider() {
    return '| --- | --- | --- | ---: | --- | --- |';
  }

  String _exampleRow(ArticleExtractionArticleAuditResult article) {
    return '| ${_cell(article.category ?? '')} | ${_cell(article.feedUrl)} | '
        '${_cell(article.articleUrl)} | ${article.statusCode ?? ''} | '
        '${_cell(article.displayTitle)} | ${article.reason?.name ?? ''} |';
  }

  String _cell(String value) {
    return value
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('|', r'\|')
        .trim();
  }
}

class ArticleExtractionFeedAuditResult {
  const ArticleExtractionFeedAuditResult({
    required this.category,
    required this.feedUrl,
    required this.feedTitle,
    required this.statusCode,
    required this.parsedItemCount,
    required this.articles,
    required this.error,
  });

  final String? category;
  final String feedUrl;
  final String? feedTitle;
  final int? statusCode;
  final int parsedItemCount;
  final List<ArticleExtractionArticleAuditResult> articles;
  final String? error;
}

class ArticleExtractionArticleAuditResult {
  const ArticleExtractionArticleAuditResult({
    required this.category,
    required this.feedUrl,
    required this.articleUrl,
    required this.articleTitle,
    required this.statusCode,
    required this.reason,
    required this.extractedTitle,
    required this.sanitizedLength,
    required this.error,
  });

  final String? category;
  final String feedUrl;
  final String articleUrl;
  final String? articleTitle;
  final int? statusCode;
  final ArticleExtractionFailureReason? reason;
  final String? extractedTitle;
  final int sanitizedLength;
  final String? error;

  String get displayTitle {
    final article = articleTitle?.trim();
    if (article != null && article.isNotEmpty) return article;
    final extracted = extractedTitle?.trim();
    if (extracted != null && extracted.isNotEmpty) return extracted;
    return '';
  }
}
