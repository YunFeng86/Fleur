import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/providers/account_providers.dart';
import 'package:fleur/providers/app_settings_providers.dart';
import 'package:fleur/providers/background_sync_providers.dart';
import 'package:fleur/providers/outbox_flush_providers.dart';
import 'package:fleur/providers/outbox_status_providers.dart';
import 'package:fleur/providers/service_providers.dart';
import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/settings/app_settings.dart';
import 'package:fleur/services/sync/outbox/outbox_store.dart';
import 'package:fleur/utils/platform.dart';

import '../test_utils/critical_workflow_test_support.dart';

void main() {
  Future<void> flushAsync() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test(
    'resolveOutboxFlushCycleResult resets delay after successful progress',
    () {
      final result = resolveOutboxFlushCycleResult(
        flushOk: true,
        beforeCount: 3,
        afterCount: 1,
        currentDelay: const Duration(seconds: 3),
        currentStallCount: 2,
      );

      expect(result.delay, const Duration(seconds: 5));
      expect(result.stallCount, 0);
    },
  );

  test(
    'resolveOutboxFlushCycleResult backs off after success without progress',
    () {
      final result = resolveOutboxFlushCycleResult(
        flushOk: true,
        beforeCount: 3,
        afterCount: 3,
        currentDelay: const Duration(seconds: 3),
        currentStallCount: 1,
      );

      expect(result.delay, const Duration(seconds: 6));
      expect(result.stallCount, 2);
    },
  );

  test('resolveOutboxFlushCycleResult backs off after failure', () {
    final result = resolveOutboxFlushCycleResult(
      flushOk: false,
      beforeCount: 2,
      afterCount: 2,
      currentDelay: const Duration(seconds: 6),
      currentStallCount: 0,
    );

    expect(result.delay, const Duration(seconds: 12));
    expect(result.stallCount, 1);
  });

  test('resolveBackgroundSyncScheduleDecision enables refresh scheduling', () {
    final decision = resolveBackgroundSyncScheduleDecision(
      refreshEnabled: true,
      outboxCapable: true,
      pendingAsync: const AsyncData<int>(0),
      lastEnabled: false,
      stallCount: 0,
    );

    expect(decision.enabled, isTrue);
    expect(decision.frequency, isNull);
  });

  test(
    'resolveBackgroundSyncScheduleDecision enables outbox backoff scheduling',
    () {
      final decision = resolveBackgroundSyncScheduleDecision(
        refreshEnabled: false,
        outboxCapable: true,
        pendingAsync: const AsyncData<int>(2),
        lastEnabled: false,
        stallCount: 2,
      );

      expect(decision.enabled, isTrue);
      expect(
        decision.frequency,
        BackgroundSyncController.outboxBackoffFrequencyForStalls(2),
      );
    },
  );

  test(
    'resolveBackgroundSyncScheduleDecision disables scheduling with no work',
    () {
      final decision = resolveBackgroundSyncScheduleDecision(
        refreshEnabled: false,
        outboxCapable: true,
        pendingAsync: const AsyncData<int>(0),
        lastEnabled: false,
        stallCount: 0,
      );

      expect(decision.enabled, isFalse);
      expect(decision.frequency, isNull);
    },
  );

  test(
    'OutboxFlushController wiring triggers flush via scheduled timer',
    () async {
      debugFleurTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugFleurTargetPlatformOverride = null);

      final timerFactory = FakeOutboxFlushTimerFactory();
      final syncService = FakeSyncService();
      final outbox = FakeOutboxStore();
      final account = buildTestAccount(
        id: 'outbox-account',
        type: AccountType.miniflux,
      );
      await outbox.save(account.id, [
        OutboxAction(
          type: OutboxActionType.markRead,
          remoteEntryId: 1,
          value: true,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ]);

      final container = ProviderContainer(
        overrides: [
          activeAccountProvider.overrideWithValue(account),
          outboxStoreProvider.overrideWithValue(outbox),
          syncServiceProvider.overrideWithValue(syncService),
          outboxFlushTimerFactoryProvider.overrideWithValue(timerFactory.call),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen<void>(
        outboxFlushControllerProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      expect(timerFactory.handles, hasLength(1));
      expect(timerFactory.lastHandle.delay, const Duration(seconds: 3));

      timerFactory.lastHandle.fire();
      await flushAsync();

      expect(syncService.flushCalls, 1);
      expect(container.read(outboxFlushStallCountProvider), 1);
    },
  );

  test('OutboxFlushController stays idle for local accounts', () async {
    debugFleurTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugFleurTargetPlatformOverride = null);

    final timerFactory = FakeOutboxFlushTimerFactory();
    final syncService = FakeSyncService();
    final outbox = FakeOutboxStore();

    final container = ProviderContainer(
      overrides: [
        activeAccountProvider.overrideWithValue(buildTestAccount()),
        outboxStoreProvider.overrideWithValue(outbox),
        syncServiceProvider.overrideWithValue(syncService),
        outboxFlushTimerFactoryProvider.overrideWithValue(timerFactory.call),
      ],
    );
    addTearDown(container.dispose);

    final sub = container.listen<void>(
      outboxFlushControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    expect(timerFactory.handles, isEmpty);
    expect(syncService.flushCalls, 0);
  });

  test(
    'BackgroundSyncController wiring schedules and cancels background work',
    () async {
      final scheduler = FakeBackgroundSyncScheduler();
      final appStore = FakeAppSettingsStore(
        AppSettings.defaults().copyWith(
          autoRefreshMinutes: 30,
          syncEnabled: true,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          activeAccountProvider.overrideWithValue(
            buildTestAccount(type: AccountType.miniflux),
          ),
          appSettingsStoreProvider.overrideWithValue(appStore),
          outboxPendingCountProvider.overrideWith((ref) async => 0),
          backgroundSyncSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appSettingsProvider.future);
      final sub = container.listen<void>(
        backgroundSyncControllerProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      await flushAsync();

      expect(scheduler.scheduledFrequencies, [const Duration(minutes: 30)]);

      await container
          .read(appSettingsProvider.notifier)
          .setAutoRefreshMinutes(null);
      await flushAsync();

      expect(scheduler.cancelCalls, 1);
    },
  );

  test(
    'BackgroundSyncController stays idle for local accounts without refresh work',
    () async {
      final scheduler = FakeBackgroundSyncScheduler();
      final appStore = FakeAppSettingsStore(
        AppSettings.defaults().copyWith(
          autoRefreshMinutes: null,
          syncEnabled: false,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          activeAccountProvider.overrideWithValue(buildTestAccount()),
          appSettingsStoreProvider.overrideWithValue(appStore),
          outboxPendingCountProvider.overrideWith((ref) async => 0),
          backgroundSyncSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appSettingsProvider.future);
      final sub = container.listen<void>(
        backgroundSyncControllerProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      await flushAsync();

      expect(scheduler.scheduledFrequencies, isEmpty);
      expect(scheduler.cancelCalls, 1);
    },
  );
}
