import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings_providers.dart';
import 'backend_capabilities_provider.dart';
import 'refresh_all_providers.dart';
import '../services/logging/app_logger.dart';
import '../services/sync/backend_capabilities.dart';
import '../services/sync/refresh_all_coordinator.dart';

class AutoRefreshController extends AutoDisposeNotifier<void> {
  static const accountSyncIntervalMinutes = 5;

  Timer? _timer;
  var _sourceElapsedMinutes = 0;
  var _running = false;

  @override
  void build() {
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final sourceRefreshMinutes = settings?.sourceRefreshMinutes;
    final capabilities = ref.watch(backendCapabilitiesProvider);

    _timer?.cancel();
    _timer = null;
    _sourceElapsedMinutes = 0;
    ref.onDispose(() => _timer?.cancel());

    if (settings?.syncEnabled == false) return;

    final shouldSyncAccount = capabilities.isRemoteBacked;
    final shouldRefreshSources =
        sourceRefreshMinutes != null &&
        sourceRefreshMinutes > 0 &&
        capabilities.isVisible(BackendFeature.refreshAllSources);
    if (!shouldSyncAccount && !shouldRefreshSources) return;

    final tickMinutes = shouldSyncAccount
        ? accountSyncIntervalMinutes
        : sourceRefreshMinutes!;
    _timer = Timer.periodic(Duration(minutes: tickMinutes), (_) {
      unawaited(_tick(tickMinutes));
    });
  }

  Future<void> _tick(int tickMinutes) async {
    if (_running) return;
    _running = true;
    try {
      final settings = ref.read(appSettingsProvider).valueOrNull;
      if (settings?.syncEnabled == false) return;
      final concurrency = settings?.autoRefreshConcurrency ?? 2;
      final capabilities = ref.read(backendCapabilitiesProvider);
      final sourceRefreshMinutes = settings?.sourceRefreshMinutes;
      final shouldRefreshSources =
          sourceRefreshMinutes != null &&
          sourceRefreshMinutes > 0 &&
          capabilities.isVisible(BackendFeature.refreshAllSources);

      if (shouldRefreshSources) {
        _sourceElapsedMinutes += tickMinutes;
        if (_sourceElapsedMinutes >= sourceRefreshMinutes) {
          _sourceElapsedMinutes = 0;
          await ref
              .read(refreshSourcesCoordinatorProvider)
              .refreshSources(
                trigger: RefreshSourcesTrigger.foregroundAuto,
                maxConcurrent: concurrency,
              );
          return;
        }
      }

      if (!capabilities.isRemoteBacked) return;

      await ref
          .read(accountSyncCoordinatorProvider)
          .syncAccount(
            trigger: AccountSyncTrigger.foregroundAuto,
            maxConcurrent: concurrency,
          );
    } catch (error, stackTrace) {
      AppLogger.w(
        'Foreground auto refresh failed',
        tag: 'sync',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _running = false;
    }
  }
}

final autoRefreshControllerProvider =
    AutoDisposeNotifierProvider<AutoRefreshController, void>(
      AutoRefreshController.new,
      dependencies: [
        appSettingsProvider,
        backendCapabilitiesProvider,
        refreshSourcesCoordinatorProvider,
        accountSyncCoordinatorProvider,
      ],
    );
