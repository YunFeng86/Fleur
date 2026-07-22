import 'dart:io';

import 'package:dio/dio.dart';

import 'src/extract/article_extraction_tooling.dart';

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
  final freezer = ArticleExtractionFixtureFreezer(
    fetcher: (uri, {required timeout, required userAgent}) {
      return _fetch(dio, uri, timeout: timeout, userAgent: userAgent);
    },
  );

  try {
    final auditMarkdown = await File(cli.auditReportPath!).readAsString();
    final result = await freezer.freezeFromAuditReport(
      auditMarkdown: auditMarkdown,
      outputDirectory: Directory(cli.outputDir),
      options: ArticleExtractionFixtureFreezeOptions(
        dryRun: cli.dryRun,
        htmlMode: cli.htmlMode,
        limit: cli.limit,
        timeout: cli.timeout,
        userAgent: cli.userAgent,
        targetReasons: cli.targetReasons.isEmpty ? null : cli.targetReasons,
      ),
    );
    stdout.write(result.toSummary());
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
    required this.auditReportPath,
    required this.outputDir,
    required this.htmlMode,
    required this.limit,
    required this.timeout,
    required this.userAgent,
    required this.targetReasons,
    required this.dryRun,
    required this.showHelp,
    required this.error,
  });

  final String? auditReportPath;
  final String outputDir;
  final ArticleExtractionFixtureHtmlMode htmlMode;
  final int? limit;
  final Duration timeout;
  final String userAgent;
  final List<ArticleExtractionFailureReason> targetReasons;
  final bool dryRun;
  final bool showHelp;
  final String? error;

  static _CliOptions parse(List<String> args) {
    String? auditReportPath;
    var outputDir = 'test/fixtures/article_extraction';
    var htmlMode = ArticleExtractionFixtureHtmlMode.minimal;
    int? limit;
    var timeoutSeconds = 12;
    var userAgent = _defaultUserAgent;
    final targetReasons = <ArticleExtractionFailureReason>[];
    var dryRun = false;

    for (var i = 0; i < args.length; i += 1) {
      final arg = args[i];
      if (arg == '--help' || arg == '-h') {
        return _CliOptions._help();
      }
      if (arg == '--dry-run') {
        dryRun = true;
        continue;
      }

      String? nextValue() {
        if (i + 1 >= args.length) return null;
        i += 1;
        return args[i];
      }

      switch (arg) {
        case '--audit-report':
          auditReportPath = nextValue();
          break;
        case '--output-dir':
          final value = nextValue();
          if (value == null || value.trim().isEmpty) {
            return _CliOptions._error('Invalid --output-dir: $value');
          }
          outputDir = value.trim();
          break;
        case '--html-mode':
          final value = nextValue();
          final parsed = _parseHtmlMode(value);
          if (parsed == null) {
            return _CliOptions._error('Invalid --html-mode: $value');
          }
          htmlMode = parsed;
          break;
        case '--limit':
          final value = nextValue();
          final parsed = _parsePositiveInt(value);
          if (parsed == null) {
            return _CliOptions._error('Invalid --limit: $value');
          }
          limit = parsed;
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
        case '--reason':
          final value = nextValue();
          final parsed = _parseReason(value);
          if (parsed == null) {
            return _CliOptions._error('Invalid --reason: $value');
          }
          targetReasons.add(parsed);
          break;
        default:
          return _CliOptions._error('Unknown argument: $arg');
      }
    }

    if (auditReportPath == null || auditReportPath.trim().isEmpty) {
      return _CliOptions._error('Missing required --audit-report <path>.');
    }

    return _CliOptions(
      auditReportPath: auditReportPath,
      outputDir: outputDir,
      htmlMode: htmlMode,
      limit: limit,
      timeout: Duration(seconds: timeoutSeconds),
      userAgent: userAgent,
      targetReasons: targetReasons,
      dryRun: dryRun,
      showHelp: false,
      error: null,
    );
  }

  static _CliOptions _help() {
    return const _CliOptions(
      auditReportPath: null,
      outputDir: 'test/fixtures/article_extraction',
      htmlMode: ArticleExtractionFixtureHtmlMode.minimal,
      limit: null,
      timeout: Duration(seconds: 12),
      userAgent: _defaultUserAgent,
      targetReasons: [],
      dryRun: false,
      showHelp: true,
      error: null,
    );
  }

  static _CliOptions _error(String message) {
    return _CliOptions(
      auditReportPath: null,
      outputDir: 'test/fixtures/article_extraction',
      htmlMode: ArticleExtractionFixtureHtmlMode.minimal,
      limit: null,
      timeout: const Duration(seconds: 12),
      userAgent: _defaultUserAgent,
      targetReasons: const [],
      dryRun: false,
      showHelp: false,
      error: message,
    );
  }

  static int? _parsePositiveInt(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static ArticleExtractionFixtureHtmlMode? _parseHtmlMode(String? value) {
    if (value == null) return null;
    for (final mode in ArticleExtractionFixtureHtmlMode.values) {
      if (mode.name == value.trim()) return mode;
    }
    return null;
  }

  static ArticleExtractionFailureReason? _parseReason(String? value) {
    if (value == null) return null;
    for (final reason in ArticleExtractionFailureReason.values) {
      if (reason.name == value.trim()) return reason;
    }
    return null;
  }
}

const _usage = '''
Usage:
  flutter pub run tool/freeze_article_extraction_fixtures.dart --audit-report <path> [options]

Options:
  --output-dir <path>        Fixture directory. Defaults to test/fixtures/article_extraction.
  --html-mode minimal|raw    HTML snapshot mode. minimal writes redacted snapshots; raw keeps fetched HTML for /tmp debugging.
  --limit <n>                Limit total frozen or planned candidates.
  --reason <reason>          Only plan/freeze this reason. May be repeated.
  --dry-run                  Parse and print candidates without fetching or writing files.
  --timeout-seconds <n>      Per-request timeout. Defaults to 12.
  --user-agent <ua>          Override the default desktop browser user agent.
  --help                     Show this help.
''';

const _defaultUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
