import 'dart:convert';
import 'dart:io';

import 'reader_settings.dart';
import '../../utils/path_utils.dart';

class ReaderSettingsStore {
  Future<ReaderSettings> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const ReaderSettings();
      final raw = await f.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const ReaderSettings();
      return ReaderSettings.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return const ReaderSettings();
    }
  }

  Future<void> save(ReaderSettings settings) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(settings.toJson()));
  }

  Future<File> _file() async {
    final dir = await PathUtils.getAppDataDirectory();

    return File('${dir.path}${Platform.pathSeparator}reader_settings.json');
  }
}
