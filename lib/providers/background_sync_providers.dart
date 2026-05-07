import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/background/background_sync_service.dart';
import 'app_settings_providers.dart';
import 'backend_capabilities_provider.dart';
import 'outbox_status_providers.dart';
import '../utils/platform.dart';

abstract class BackgroundSyncScheduler {
  Future<void> schedulePeriodic({required Duration frequency});
  Future<void> cancelPeriodic();
}

class WorkmanagerBackgroundSyncScheduler implements BackgroundSyncScheduler {
  const WorkmanagerBackgroundSyncScheduler();

  @override
  Future<void> schedulePeriodic({required Duration frequency}) {
    return BackgroundSyncService.schedulePeriodic(frequency: frequency);
  }

  @override
  Future<void> cancelPeriodic() {
    return BackgroundSyncService.cancelPeriodic();
  }
}

final backgroundSyncSchedulerProvider = Provider<BackgroundSyncScheduler>(
  (ref) => const WorkmanagerBackgroundSyncScheduler(),
);

class BackgroundSyncScheduleDecision {
  const BackgroundSyncScheduleDecision({
    required this.enabled,
    required this.frequency,
  });

  final bool enabled;
  final Duration? frequency;
}

BackgroundSyncScheduleDecision resolveBackgroundSyncScheduleDecision({
  required bool refreshEnabled,
  required bool outboxCapable,
  required AsyncValue<int> pendingAsync,
  required bool? lastEnabled,
  required int stallCount,
}) {
  final pending = pendingAsync.valueOrNull;
  final hasPendingOutbox = (pending ?? 0) > 0;

  var enabled = refreshEnabled;
  if (!enabled && outboxCapable) {
    if (pending != null) {
      enabled = hasPendingOutbox;
    } else if (pendingAsync.hasError) {
      enabled = lastEnabled ?? false;
    } else {
      enabled = lastEnabled ?? false;
    }
  }

  if (!enabled) {
    return const BackgroundSyncScheduleDecision(
      enabled: false,
      frequency: null,
    );
  }

  return BackgroundSyncScheduleDecision(
    enabled: true,
    frequency: refreshEnabled
        ? null
        : BackgroundSyncController.outboxBackoffFrequencyForStalls(stallCount),
  );
}

class BackgroundSyncController extends AutoDisposeNotifier<void> {
  Duration? _lastFrequency;
  bool? _lastEnabled;

  @override
  void build() {
    if (!supportsBackgroundSyncPlatform) return;

    final appSettings = ref.watch(appSettingsProvider).valueOrNull;
    final scheduler = ref.watch(backgroundSyncSchedulerProvider);
    final capabilities = ref.watch(backendCapabilitiesProvider);

    final refreshMinutes = appSettings?.autoRefreshMinutes ?? 0;
    final syncEnabled = appSettings?.syncEnabled ?? true;
    final refreshEnabled = refreshMinutes > 0 && syncEnabled;

    final pendingAsync = ref.watch(outboxPendingCountProvider);
    final decision = resolveBackgroundSyncScheduleDecision(
      refreshEnabled: refreshEnabled,
      outboxCapable: capabilities.isOutboxCapable,
      pendingAsync: pendingAsync,
      lastEnabled: _lastEnabled,
      stallCount: ref.watch(outboxFlushStallCountProvider),
    );
    final enabled = decision.enabled;

    if (!enabled) {
      if (_lastEnabled == false) return;
      _lastEnabled = false;
      _lastFrequency = null;
      unawaited(scheduler.cancelPeriodic());
      return;
    }

    final frequency = refreshEnabled
        ? Duration(minutes: refreshMinutes)
        : decision.frequency!;

    if (_lastEnabled == true && _lastFrequency == frequency) return;
    _lastEnabled = true;
    _lastFrequency = frequency;

    unawaited(scheduler.schedulePeriodic(frequency: frequency));
  }

  static Duration outboxBackoffFrequencyForStalls(int stalls) {
    const baseMinutes = 15;
    final step = stalls < 0 ? 0 : (stalls > 4 ? 4 : stalls);
    final minutes = baseMinutes * (1 << step);
    return Duration(minutes: minutes);
  }
}

final backgroundSyncControllerProvider =
    AutoDisposeNotifierProvider<BackgroundSyncController, void>(
      BackgroundSyncController.new,
    );
