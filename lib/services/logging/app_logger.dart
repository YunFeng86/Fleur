import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../utils/build_info.dart';
import '../../utils/path_manager.dart';

enum AppLogLevel { debug, info, warning, error }

class AppLogger {
  static const String _kName = 'fleur';
  static const int _kRetentionDays = 14;
  static const int _kMaxPendingLines = 200;
  static const int _kMaxExportFiles = 30;

  static Future<void>? _initFuture;
  static Future<void>? _pendingFlush;
  static IOSink? _sink;
  static File? _activeLogFile;
  static final List<String> _pending = <String>[];

  static Future<void> ensureInitialized() => _initFuture ??= _init();

  static Future<Directory> getLogsDir() => PathManager.getLogsDir();

  static Future<File?> getActiveLogFile() async {
    await ensureInitialized();
    return _activeLogFile;
  }

  static Future<File?> getLatestLogFile() async {
    final dir = await getLogsDir();
    final files = await _listLogFiles(dir);
    if (files.isEmpty) return null;
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files.first;
  }

  static void d(String message, {String? tag, Map<String, Object?>? context}) {
    _log(AppLogLevel.debug, message, tag: tag, context: context);
  }

  static void i(String message, {String? tag, Map<String, Object?>? context}) {
    _log(AppLogLevel.info, message, tag: tag, context: context);
  }

  static void w(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    _log(
      AppLogLevel.warning,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  static void e(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    _log(
      AppLogLevel.error,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  static Future<void> flush() async {
    try {
      await _pendingFlush;
      await _sink?.flush();
    } catch (_) {
      // best-effort
    }
  }

  @visibleForTesting
  static Future<void> resetForTests() async {
    final sink = _sink;
    final pendingFlush = _pendingFlush;
    _sink = null;
    _activeLogFile = null;
    _initFuture = null;
    _pendingFlush = null;
    _pending.clear();
    try {
      await pendingFlush;
      await sink?.flush();
      await sink?.close();
    } catch (_) {
      // best-effort
    }
  }

  /// Creates a zip archive containing log files + a short manifest.
  ///
  /// Returned file lives in the OS temp directory.
  static Future<File> createLogsArchive() async {
    await ensureInitialized();
    await flush();

    final logsDir = await getLogsDir();
    final logFiles = await _listLogFiles(logsDir);
    logFiles.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );

    final selected = logFiles.take(_kMaxExportFiles).toList();
    final manifest = await _buildExportManifest(
      logsDir: logsDir,
      files: selected,
    );

    final manifestBytes = utf8.encode(manifest);
    final archive = Archive()
      ..addFile(
        ArchiveFile('manifest.txt', manifestBytes.length, manifestBytes),
      );

    for (final file in selected) {
      List<int> bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (e) {
        // Keep exporting other files; include a stub entry.
        final err = 'Failed to read ${file.path}: $e\n';
        bytes = utf8.encode(err);
      }
      final name = p.basename(file.path);
      archive.addFile(ArchiveFile('logs/$name', bytes.length, bytes));
    }

    final zipped = ZipEncoder().encode(archive);

    final tmp = await getTemporaryDirectory();
    final outPath = p.join(
      tmp.path,
      'fleur_logs_${_compactTimestamp(DateTime.now())}.zip',
    );
    final outFile = File(outPath);
    await outFile.writeAsBytes(zipped, flush: true);
    return outFile;
  }

  static Future<void> _init() async {
    try {
      final dir = await getLogsDir();
      await _cleanupOldLogs(dir);

      final now = DateTime.now();
      final fileName = 'fleur_${_yyyyMmDd(now)}.log';
      final file = File(p.join(dir.path, fileName));
      await file.parent.create(recursive: true);
      _activeLogFile = file;

      _sink = file.openWrite(mode: FileMode.append, encoding: utf8);

      _writeLine(
        _formatLine(
          AppLogLevel.info,
          'Session start',
          tag: 'logger',
          time: now,
        ),
        flush: true,
      );

      final pending = List<String>.from(_pending);
      _pending.clear();
      for (final line in pending) {
        _writeLine(line);
      }
      await flush();

      _logBuildInfo();
    } catch (e, st) {
      // Never block app startup on logger failures.
      _sink = null;
      _activeLogFile = null;
      if (kDebugMode) {
        developer.log(
          'logger init failed: $e',
          name: _kName,
          error: e,
          stackTrace: st,
          level: 1000,
        );
      }
    }
  }

  static void _logBuildInfo() {
    final mode = kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug';

    i(
      'Build ${AppBuildInfo.buildNumber} '
      '(commit=${AppBuildInfo.commitHash}, time=${AppBuildInfo.buildTime}, mode=$mode)',
      tag: 'build',
    );
    try {
      i(
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        tag: 'platform',
      );
      i('dart ${Platform.version}', tag: 'platform');
    } catch (_) {
      // best-effort
    }
  }

  static void _log(
    AppLogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    if (level == AppLogLevel.debug && !kDebugMode) return;
    final line = _formatLine(
      level,
      message,
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
    _writeLine(line, flush: level.index >= AppLogLevel.warning.index);

    if (kDebugMode) {
      developer.log(
        _consoleMessage(level, message, tag: tag),
        name: _kName,
        level: _developerLevel(level),
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static String _formatLine(
    AppLogLevel level,
    String message, {
    DateTime? time,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    final ts = (time ?? DateTime.now()).toIso8601String();
    final lvl = switch (level) {
      AppLogLevel.debug => 'D',
      AppLogLevel.info => 'I',
      AppLogLevel.warning => 'W',
      AppLogLevel.error => 'E',
    };
    final t = (tag == null || tag.trim().isEmpty) ? '' : ' [$tag]';
    final buf = StringBuffer('$ts [$lvl]$t $message');
    if (error != null) buf.write('\n$ts [$lvl]$t error: $error');
    final contextLine = _formatContext(context);
    if (contextLine != null) buf.write('\n$ts [$lvl]$t context: $contextLine');
    if (stackTrace != null) buf.write('\n$stackTrace');
    return buf.toString();
  }

  static String? _formatContext(Map<String, Object?>? context) {
    if (context == null || context.isEmpty) return null;
    final keys =
        context.keys
            .where((key) => key.trim().isNotEmpty && context[key] != null)
            .toList()
          ..sort();
    if (keys.isEmpty) return null;
    return keys
        .map((key) {
          final value = _isSensitiveContextKey(key)
              ? '<redacted>'
              : _sanitizeContextValue(context[key]);
          return '$key=$value';
        })
        .join(' ');
  }

  static bool _isSensitiveContextKey(String key) {
    final lower = key.toLowerCase();
    if (lower == 'authmode') return false;
    return lower.contains('token') ||
        lower.contains('password') ||
        lower.contains('secret') ||
        lower.contains('auth') ||
        lower.contains('header') ||
        lower.contains('body') ||
        lower == 'key' ||
        lower.endsWith('key') ||
        lower.contains('_key');
  }

  static String _sanitizeContextValue(Object? value) {
    if (value is Map) {
      final entries = value.entries
          .where((entry) => entry.key != null && entry.value != null)
          .map((entry) {
            final childKey = entry.key.toString();
            final child = _isSensitiveContextKey(childKey)
                ? '<redacted>'
                : _sanitizeContextValue(entry.value);
            return '$childKey=$child';
          });
      return '{${entries.join(',')}}';
    }
    if (value is Iterable) {
      return '[${value.map(_sanitizeContextValue).join(',')}]';
    }
    final raw = value.toString();
    return raw.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
  }

  static String _consoleMessage(
    AppLogLevel level,
    String message, {
    String? tag,
  }) {
    final lvl = switch (level) {
      AppLogLevel.debug => 'DEBUG',
      AppLogLevel.info => 'INFO',
      AppLogLevel.warning => 'WARN',
      AppLogLevel.error => 'ERROR',
    };
    final t = (tag == null || tag.trim().isEmpty) ? '' : ' [$tag]';
    return '$lvl$t $message';
  }

  static int _developerLevel(AppLogLevel level) {
    return switch (level) {
      AppLogLevel.debug => 500,
      AppLogLevel.info => 800,
      AppLogLevel.warning => 900,
      AppLogLevel.error => 1000,
    };
  }

  static void _writeLine(String line, {bool flush = false}) {
    final sink = _sink;
    if (sink == null) {
      if (_pending.length < _kMaxPendingLines) _pending.add(line);
      return;
    }
    try {
      sink.writeln(line);
      if (flush) _scheduleFlush(sink);
    } catch (_) {
      // best-effort
    }
  }

  static void _scheduleFlush(IOSink sink) {
    _pendingFlush = (_pendingFlush ?? Future<void>.value())
        .then((_) => sink.flush())
        .catchError((_) {});
  }

  static Future<List<File>> _listLogFiles(Directory dir) async {
    final files = <File>[];
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        if (!entity.path.toLowerCase().endsWith('.log')) continue;
        files.add(entity);
      }
    } catch (_) {
      // best-effort
    }
    return files;
  }

  static Future<void> _cleanupOldLogs(Directory dir) async {
    final cutoff = DateTime.now().subtract(
      const Duration(days: _kRetentionDays),
    );
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith('fleur_') || !name.endsWith('.log')) continue;
        final dash = name.indexOf('_');
        final dot = name.lastIndexOf('.');
        if (dash == -1 || dot == -1 || dot <= dash + 1) continue;
        final datePart = name.substring(dash + 1, dot);
        final parsed = DateTime.tryParse(datePart);
        if (parsed == null) continue;
        if (parsed.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day))) {
          await entity.delete();
        }
      }
    } catch (_) {
      // best-effort
    }
  }

  static String _yyyyMmDd(DateTime dt) {
    String pad2(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad2(dt.month)}-${pad2(dt.day)}';
  }

  static String _compactTimestamp(DateTime dt) {
    String pad2(int n) => n.toString().padLeft(2, '0');
    String pad3(int n) => n.toString().padLeft(3, '0');
    return '${dt.year}${pad2(dt.month)}${pad2(dt.day)}_'
        '${pad2(dt.hour)}${pad2(dt.minute)}${pad2(dt.second)}'
        '${pad3(dt.millisecond)}';
  }

  static Future<String> _buildExportManifest({
    required Directory logsDir,
    required List<File> files,
  }) async {
    PackageInfo? info;
    try {
      info = await PackageInfo.fromPlatform();
    } catch (_) {
      // best-effort
    }

    final supportPath = await PathManager.getSupportPath();
    final logsPath = await PathManager.getLogsPath();

    final sb = StringBuffer()
      ..writeln('Fleur log export')
      ..writeln('exportedAt: ${DateTime.now().toIso8601String()}')
      ..writeln('appName: ${info?.appName ?? 'unknown'}')
      ..writeln('package: ${info?.packageName ?? 'unknown'}')
      ..writeln('version: ${info?.version ?? 'unknown'}')
      ..writeln('buildNumber: ${info?.buildNumber ?? 'unknown'}')
      ..writeln(
        'buildInfo: number=${AppBuildInfo.buildNumber}, '
        'commit=${AppBuildInfo.commitHash}, time=${AppBuildInfo.buildTime}',
      )
      ..writeln('supportDir: $supportPath')
      ..writeln('logsDir: $logsPath')
      ..writeln(
        'mode: ${kReleaseMode
            ? 'release'
            : kProfileMode
            ? 'profile'
            : 'debug'}',
      );

    try {
      sb
        ..writeln('os: ${Platform.operatingSystem}')
        ..writeln('osVersion: ${Platform.operatingSystemVersion}')
        ..writeln('dart: ${Platform.version}');
    } catch (_) {
      // best-effort
    }

    sb.writeln('\nfiles:');
    for (final f in files) {
      try {
        final stat = await f.stat();
        sb.writeln(
          '- ${p.basename(f.path)} (${stat.size} bytes, mtime=${stat.modified.toIso8601String()})',
        );
      } catch (_) {
        sb.writeln('- ${p.basename(f.path)}');
      }
    }

    return sb.toString();
  }
}
