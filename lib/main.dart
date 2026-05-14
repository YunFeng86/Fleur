import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:window_manager/window_manager.dart';

import 'app/account_gate.dart';
import 'app/app.dart';
import 'services/background/background_sync_service.dart';
import 'services/logging/app_logger.dart';
import 'services/logging/app_provider_observer.dart';
import 'utils/macos_window_chrome_bridge.dart';
import 'utils/platform.dart';

Future<void> _configureMacOSTitlebarChrome() async {
  if (!isMacOS) return;

  try {
    await MacOSWindowChromeBridge.configureTitlebarChrome();
  } catch (error, stackTrace) {
    AppLogger.w(
      'Failed to configure macOS titlebar chrome',
      tag: 'platform',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await AppLogger.ensureInitialized();
      unawaited(BackgroundSyncService.ensureInitialized());

      FlutterError.onError = (details) {
        if (kDebugMode) {
          FlutterError.presentError(details);
        }
        AppLogger.e(
          details.exceptionAsString(),
          tag: 'flutter',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (error, stackTrace) {
        AppLogger.e(
          'Uncaught platform error',
          tag: 'platform',
          error: error,
          stackTrace: stackTrace,
        );
        return false;
      };

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
        await _configureMacOSTitlebarChrome();
      }

      runApp(
        const ProviderScope(
          observers: [AppProviderObserver()],
          child: AppRuntimeHost(child: AccountGate()),
        ),
      );
    },
    (error, stackTrace) {
      AppLogger.e(
        'Uncaught zone error',
        tag: 'zone',
        error: error,
        stackTrace: stackTrace,
      );
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        parent.print(zone, line);
        if (line.trim().isEmpty) return;
        AppLogger.i(line, tag: 'print');
      },
    ),
  );
}
