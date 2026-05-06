import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sync/sync_service.dart';
import '../utils/platform.dart';
import 'account_providers.dart';
import 'backend_capabilities_provider.dart';
import 'outbox_status_providers.dart';
import 'service_providers.dart';

abstract class OutboxFlushTimerHandle {
  void cancel();
}

typedef OutboxFlushTimerFactory =
    OutboxFlushTimerHandle Function(Duration delay, void Function() callback);

class _OutboxFlushTimerHandle implements OutboxFlushTimerHandle {
  _OutboxFlushTimerHandle(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

final outboxFlushTimerFactoryProvider = Provider<OutboxFlushTimerFactory>((
  ref,
) {
  return (delay, callback) => _OutboxFlushTimerHandle(Timer(delay, callback));
});

class OutboxFlushCycleResult {
  const OutboxFlushCycleResult({required this.delay, required this.stallCount});

  final Duration delay;
  final int stallCount;
}

OutboxFlushCycleResult resolveOutboxFlushCycleResult({
  required bool flushOk,
  required int beforeCount,
  required int afterCount,
  required Duration currentDelay,
  required int currentStallCount,
}) {
  if (!flushOk) {
    return OutboxFlushCycleResult(
      delay: OutboxFlushController.nextBackoff(currentDelay),
      stallCount: currentStallCount + 1,
    );
  }

  if (afterCount == 0) {
    return const OutboxFlushCycleResult(
      delay: Duration(seconds: 30),
      stallCount: 0,
    );
  }

  if (afterCount < beforeCount) {
    return const OutboxFlushCycleResult(
      delay: Duration(seconds: 5),
      stallCount: 0,
    );
  }

  return OutboxFlushCycleResult(
    delay: OutboxFlushController.nextBackoff(currentDelay),
    stallCount: currentStallCount + 1,
  );
}

class OutboxFlushController extends AutoDisposeNotifier<void> {
  OutboxFlushTimerHandle? _timer;
  Duration _delay = const Duration(seconds: 3);
  bool _running = false;
  var _disposed = false;
  var _stallCount = 0;

  @override
  void build() {
    // Desktop-first: keep it lightweight and foreground-only.
    // Mobile background flush should use platform-specific scheduling.
    if (!isDesktop) {
      // Still allow foreground flushing; just be less aggressive.
      _delay = const Duration(seconds: 10);
    }

    final capabilities = ref.watch(backendCapabilitiesProvider);

    _timer?.cancel();
    _timer = null;
    _disposed = false;
    _stallCount = 0;
    ref.read(outboxFlushStallCountProvider.notifier).state = 0;
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
    });

    if (!capabilities.isOutboxCapable) {
      return;
    }

    _schedule();
  }

  void _schedule() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = ref.read(outboxFlushTimerFactoryProvider)(_delay, () {
      unawaited(_tick());
    });
  }

  @visibleForTesting
  Future<void> runSingleCycleForTest() => _tick();

  Future<void> _tick() async {
    if (_running) return;
    _running = true;
    var shouldReschedule = true;
    try {
      final account = ref.read(activeAccountProvider);
      final capabilities = ref.read(backendCapabilitiesProvider);
      if (!capabilities.isOutboxCapable) {
        _delay = const Duration(seconds: 30);
        shouldReschedule = false;
        return;
      }

      final pending = await ref.read(outboxStoreProvider).load(account.id);
      if (pending.isEmpty) {
        // Idle: poll slowly.
        _delay = const Duration(seconds: 30);
        _stallCount = 0;
        ref.read(outboxFlushStallCountProvider.notifier).state = 0;
        // Keep polling while the account can flush deferred remote actions.
        return;
      }

      final beforeCount = pending.length;
      final svc = ref.read(syncServiceProvider);
      final ok = switch (svc) {
        OutboxFlushCapable s => await s.flushOutboxSafe(),
        _ => false,
      };

      if (!ok) {
        final result = resolveOutboxFlushCycleResult(
          flushOk: false,
          beforeCount: beforeCount,
          afterCount: beforeCount,
          currentDelay: _delay,
          currentStallCount: _stallCount,
        );
        _delay = result.delay;
        _stallCount = result.stallCount;
        ref.read(outboxFlushStallCountProvider.notifier).state = _stallCount;
        return;
      }

      // `flushOutboxSafe()` may succeed but make no progress (e.g. permanent
      // server errors, bad credentials, or unsupported actions). Detect this to
      // avoid a fast-poll loop that burns battery/network.
      final after = await ref.read(outboxStoreProvider).load(account.id);
      final result = resolveOutboxFlushCycleResult(
        flushOk: true,
        beforeCount: beforeCount,
        afterCount: after.length,
        currentDelay: _delay,
        currentStallCount: _stallCount,
      );
      _delay = result.delay;
      _stallCount = result.stallCount;
      ref.read(outboxFlushStallCountProvider.notifier).state = _stallCount;
    } finally {
      _running = false;
      var doReschedule = shouldReschedule && !_disposed;
      if (doReschedule) {
        try {
          doReschedule = ref.read(backendCapabilitiesProvider).isOutboxCapable;
        } catch (_) {
          doReschedule = false;
        }
      }
      if (doReschedule) {
        _schedule();
      }
    }
  }

  static Duration nextBackoff(Duration cur) {
    final secs = cur.inSeconds <= 0 ? 3 : cur.inSeconds;
    final next = secs * 2;
    // Cap to avoid infinite hammering on flaky networks or bad credentials.
    final capped = next > 300 ? 300 : next;
    // Keep a floor to avoid busy looping.
    final floored = capped < 5 ? 5 : capped;
    return Duration(seconds: floored);
  }
}

final outboxFlushControllerProvider =
    AutoDisposeNotifierProvider<OutboxFlushController, void>(
      OutboxFlushController.new,
    );
