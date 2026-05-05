import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fleur/services/extract/article_extraction_audit.dart';

Future<void> main(List<String> args) async {
  final cli = _CliOptions.parse(args);
  if (cli.showHelp) {
    stdout.write(_usage);
    return;
  }
  if (cli.error != null) {
    stderr.writeln(cli.error);
    stderr.write(_usage);
    exitCode = 64;
    return;
  }

  final dio = Dio(
    BaseOptions(
      connectTimeout: cli.timeout,
      receiveTimeout: cli.timeout,
      sendTimeout: cli.timeout,
      followRedirects: true,
      maxRedirects: 5,
    ),
  );
  final auditor = ArticleExtractionAuditor(
    fetcher: (uri, {required timeout, required userAgent}) {
      return _fetch(dio, uri, timeout: timeout, userAgent: userAgent);
    },
  );

  try {
    final opmlXml = await File(cli.opmlPath!).readAsString();
    final report = await auditor.auditOpml(
      opmlXml,
      options: ArticleExtractionAuditOptions(
        feedLimit: cli.feedLimit,
        entriesPerFeed: cli.entriesPerFeed,
        concurrency: cli.concurrency,
        timeout: cli.timeout,
        userAgent: cli.userAgent,
      ),
    );
    final markdown = report.toMarkdown();

    final outputPath = cli.outputPath;
    if (outputPath == null) {
      stdout.write(markdown);
      return;
    }

    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(markdown);
    stdout.writeln('Wrote article extraction audit report to $outputPath');
  } finally {
    dio.close(force: true);
  }
}

Future<ArticleExtractionAuditFetchResult> _fetch(
  Dio dio,
  Uri uri, {
  required Duration timeout,
  required String? userAgent,
}) async {
  final response = await dio.getUri<String>(
    uri,
    options: Options(
      responseType: ResponseType.plain,
      sendTimeout: timeout,
      receiveTimeout: timeout,
      validateStatus: (int? _) => true,
      headers: <String, String>{
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        if (userAgent != null && userAgent.trim().isNotEmpty)
          'User-Agent': userAgent.trim(),
      },
    ),
  );
  return ArticleExtractionAuditFetchResult(
    body: response.data ?? '',
    statusCode: response.statusCode,
  );
}

class _CliOptions {
  const _CliOptions({
    required this.opmlPath,
    required this.outputPath,
    required this.feedLimit,
    required this.entriesPerFeed,
    required this.concurrency,
    required this.timeout,
    required this.userAgent,
    required this.showHelp,
    required this.error,
  });

  final String? opmlPath;
  final String? outputPath;
  final int? feedLimit;
  final int entriesPerFeed;
  final int concurrency;
  final Duration timeout;
  final String userAgent;
  final bool showHelp;
  final String? error;

  static _CliOptions parse(List<String> args) {
    String? opmlPath;
    String? outputPath;
    int? feedLimit;
    var entriesPerFeed = 1;
    var concurrency = 4;
    var timeoutSeconds = 12;
    var userAgent = _defaultUserAgent;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--help' || arg == '-h') {
        return _CliOptions._help();
      }

      String? nextValue() {
        if (i + 1 >= args.length) return null;
        i += 1;
        return args[i];
      }

      switch (arg) {
        case '--opml':
          opmlPath = nextValue();
          break;
        case '--output':
          outputPath = nextValue();
          break;
        case '--feed-limit':
          final value = nextValue();
          feedLimit = _parseOptionalPositiveInt(value);
          if (feedLimit == null && value != null && value.trim() != '0') {
            return _CliOptions._error('Invalid --feed-limit: $value');
          }
          break;
        case '--entries-per-feed':
          final value = nextValue();
          final parsed = _parsePositiveInt(value);
          if (parsed == null) {
            return _CliOptions._error('Invalid --entries-per-feed: $value');
          }
          entriesPerFeed = parsed;
          break;
        case '--concurrency':
          final value = nextValue();
          final parsed = _parsePositiveInt(value);
          if (parsed == null) {
            return _CliOptions._error('Invalid --concurrency: $value');
          }
          concurrency = parsed;
          break;
        case '--timeout-seconds':
          final value = nextValue();
          final parsed = _parsePositiveInt(value);
          if (parsed == null) {
            return _CliOptions._error('Invalid --timeout-seconds: $value');
          }
          timeoutSeconds = parsed;
          break;
        case '--user-agent':
          final value = nextValue();
          if (value == null || value.trim().isEmpty) {
            return _CliOptions._error('Invalid --user-agent: $value');
          }
          userAgent = value.trim();
          break;
        default:
          return _CliOptions._error('Unknown argument: $arg');
      }
    }

    if (opmlPath == null || opmlPath.trim().isEmpty) {
      return _CliOptions._error('Missing required --opml <path>.');
    }

    return _CliOptions(
      opmlPath: opmlPath,
      outputPath: outputPath,
      feedLimit: feedLimit,
      entriesPerFeed: entriesPerFeed,
      concurrency: concurrency,
      timeout: Duration(seconds: timeoutSeconds),
      userAgent: userAgent,
      showHelp: false,
      error: null,
    );
  }

  static _CliOptions _help() {
    return _CliOptions(
      opmlPath: null,
      outputPath: null,
      feedLimit: null,
      entriesPerFeed: 1,
      concurrency: 4,
      timeout: const Duration(seconds: 12),
      userAgent: _defaultUserAgent,
      showHelp: true,
      error: null,
    );
  }

  static _CliOptions _error(String message) {
    return _CliOptions(
      opmlPath: null,
      outputPath: null,
      feedLimit: null,
      entriesPerFeed: 1,
      concurrency: 4,
      timeout: const Duration(seconds: 12),
      userAgent: _defaultUserAgent,
      showHelp: false,
      error: message,
    );
  }

  static int? _parsePositiveInt(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static int? _parseOptionalPositiveInt(String? value) {
    if (value == null) return null;
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 0) return null;
    if (parsed == 0) return null;
    return parsed;
  }
}

const _usage = '''
Usage:
  flutter pub run tool/article_extraction_audit.dart --opml <path> [options]

Options:
  --output <path>            Write Markdown report to a file instead of stdout.
  --feed-limit <n>           Limit feeds audited. Defaults to all feeds.
  --entries-per-feed <n>     Articles per parsed feed. Defaults to 1.
  --concurrency <n>          Concurrent feed audits. Defaults to 4.
  --timeout-seconds <n>      Per-request timeout. Defaults to 12.
  --user-agent <ua>          Override the default desktop browser user agent.
  --help                     Show this help.
''';

const _defaultUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
