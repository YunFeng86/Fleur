import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'db/isar_db.dart';
import 'providers/core_providers.dart';
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
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final isar = await openIsar();

  runApp(
    ProviderScope(
      overrides: [isarProvider.overrideWithValue(isar)],
      child: const App(),
    ),
  );
}
