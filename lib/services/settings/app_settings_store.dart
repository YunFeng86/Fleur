import 'dart:convert';
import 'dart:io';

import 'app_settings.dart';
import '../../utils/path_utils.dart';

class AppSettingsStore {
  Future<AppSettings> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const AppSettings();
      final raw = await f.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const AppSettings();
      return AppSettings.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(settings.toJson()));
  }

  Future<File> _file() async {
    final dir = await PathUtils.getAppDataDirectory();

    return File('${dir.path}${Platform.pathSeparator}app_settings.json');
  }
}
