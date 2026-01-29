import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'db/isar_db.dart';
import 'providers/core_providers.dart';
import 'services/data_integrity_service.dart';
import 'utils/platform.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable localized relative time strings in the article list.
  timeago.setLocaleMessages('zh', timeago.ZhMessages());
  timeago.setLocaleMessages('zh_CN', timeago.ZhCnMessages());

  if (isDesktop) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1200, 800),
      center: true,
      minimumSize: Size(360, 520),
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final isar = await openIsar();

  // [BUGFIX] Run data integrity check in background to avoid blocking UI
  // This prevents categoryId mismatches caused by race conditions
  Future.microtask(() async {
    final integrityService = DataIntegrityService(isar);
    try {
      final fixed = await integrityService.repairCategoryIdMismatch();
      if (fixed > 0) {
        debugPrint('✅ Data integrity check: Fixed $fixed articles with mismatched categoryId');
      }
    } catch (e) {
      debugPrint('⚠️ Data integrity check failed: $e');
    }
  });

  runApp(
    ProviderScope(
      overrides: [isarProvider.overrideWithValue(isar)],
      child: const App(),
    ),
  );
}
