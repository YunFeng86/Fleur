import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data_integrity_service.dart';
import 'logging/app_logger.dart';

class DataIntegrityStartupService {
  const DataIntegrityStartupService();

  static const Duration _minInterval = Duration(days: 7);

  Future<void> runIfNeeded(Isar isar) async {
    final prefs = await SharedPreferences.getInstance();
    final name = isar.name.trim().isEmpty ? 'default' : isar.name.trim();
    final key = 'integrity:last_run:$name';

    final now = DateTime.now();
    final lastMs = prefs.getInt(key);
    if (lastMs != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      if (now.difference(last) < _minInterval) return;
    }

    try {
      final svc = DataIntegrityService(isar);
      final fixed = await svc.repairCategoryIdMismatch();
      if (fixed > 0) {
        AppLogger.i(
          'Data integrity: fixed $fixed categoryId mismatches',
          tag: 'integrity',
        );
      }

      final report = await svc.check();
      if (report.hasIssues) {
        AppLogger.w('Data integrity issues: $report', tag: 'integrity');
      } else {
        AppLogger.i('Data integrity check OK', tag: 'integrity');
      }
      await prefs.setInt(key, now.millisecondsSinceEpoch);
    } on IsarError catch (e) {
      // Account switching can close Isar while tasks are still running.
      if (e.message.toLowerCase().contains('already been closed')) return;
      AppLogger.w('Data integrity failed', tag: 'integrity', error: e);
    } catch (e) {
      AppLogger.w('Data integrity failed', tag: 'integrity', error: e);
    }
  }
}
