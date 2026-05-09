import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings_providers.dart';
import 'refresh_all_providers.dart';
import '../services/sync/refresh_all_coordinator.dart';

class AutoRefreshController extends AutoDisposeNotifier<void> {
  Timer? _timer;
  var _running = false;

  @override
  void build() {
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final minutes = settings?.autoRefreshMinutes;

    _timer?.cancel();
    _timer = null;
    ref.onDispose(() => _timer?.cancel());

    if (minutes == null || minutes <= 0) return;
    if (settings?.syncEnabled == false) return;

    _timer = Timer.periodic(Duration(minutes: minutes), (_) {
      unawaited(_tick());
    });
  }

  Future<void> _tick() async {
    if (_running) return;
    _running = true;
    try {
      final settings = ref.read(appSettingsProvider).valueOrNull;
      if (settings?.syncEnabled == false) return;
      final concurrency = settings?.autoRefreshConcurrency ?? 2;

      await ref
          .read(refreshAllCoordinatorProvider)
          .refreshAll(
            trigger: RefreshAllTrigger.foregroundAuto,
            maxConcurrent: concurrency,
          );
    } finally {
      _running = false;
    }
  }
}

final autoRefreshControllerProvider =
    AutoDisposeNotifierProvider<AutoRefreshController, void>(
      AutoRefreshController.new,
    );
