import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

/// Minimal "shell integration" helpers for revealing/opening paths in the OS.
///
/// Notes:
/// - Windows/macOS can reveal a file in the file manager.
/// - Linux typically cannot reliably "select" a file across file managers, so
///   it falls back to opening the parent directory.
class ShellService {
  static Future<void> openPath(String path) async {
    // Accept paths wrapped in quotes (common when copied from terminals/scripts).
    final normalized = _normalizeInputPath(path);
    if (normalized.isEmpty) return;

    final entityType = await FileSystemEntity.type(normalized);
    if (entityType == FileSystemEntityType.notFound) {
      throw FileSystemException('Path does not exist', normalized);
    }

    final isFile = entityType == FileSystemEntityType.file;
    if (isFile) {
      await revealFile(normalized);
      return;
    }
    await openDirectory(normalized);
  }

  static Future<void> revealFile(String filePath) async {
    final normalized = _normalizeInputPath(filePath);
    final abs = p.absolute(normalized);

    if (Platform.isWindows) {
      final targetPath = abs.replaceAll('/', r'\');
      // Explorer needs the path quoted when it contains spaces/special chars.
      // Note: No space after `/select,`.
      final args = ['/select,"$targetPath"'];
      // Explorer may return a non-zero exit code even when the window opens
      // successfully. Detach to avoid false error toasts.
      await Process.start(
        'explorer.exe',
        args,
        mode: ProcessStartMode.detached,
      );
      return;
    }

    if (Platform.isMacOS) {
      final result = await Process.run('open', ['-R', abs]);
      if (result.exitCode != 0) {
        final stderrText = result.stderr is String
            ? result.stderr as String
            : '${result.stderr}';
        throw ProcessException(
          'open',
          ['-R', abs],
          stderrText,
          result.exitCode,
        );
      }
      return;
    }

    // Linux and other platforms: no reliable "reveal" support -> open parent dir.
    await openDirectory(p.dirname(abs));
  }

  static Future<void> openDirectory(String dirPath) async {
    final normalized = _normalizeInputPath(dirPath);
    final abs = p.absolute(normalized);

    if (Platform.isWindows) {
      final targetPath = abs.replaceAll('/', r'\');
      await Process.start('explorer.exe', [
        targetPath,
      ], mode: ProcessStartMode.detached);
      return;
    }

    final uri = Uri.file(abs);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched) return;

    if (Platform.isMacOS) {
      final result = await Process.run('open', [abs]);
      if (result.exitCode != 0) {
        final stderrText = result.stderr is String
            ? result.stderr as String
            : '${result.stderr}';
        throw ProcessException('open', [abs], stderrText, result.exitCode);
      }
      return;
    }

    if (Platform.isLinux) {
      final result = await Process.run('xdg-open', [abs]);
      if (result.exitCode != 0) {
        final stderrText = result.stderr is String
            ? result.stderr as String
            : '${result.stderr}';
        throw ProcessException('xdg-open', [abs], stderrText, result.exitCode);
      }
      return;
    }

    throw StateError('launchUrl failed for $abs');
  }

  static String _normalizeInputPath(String input) {
    var normalized = input.trim();
    if (normalized.length > 1 &&
        normalized.startsWith('"') &&
        normalized.endsWith('"')) {
      normalized = normalized.substring(1, normalized.length - 1);
    }
    return normalized;
  }
}
