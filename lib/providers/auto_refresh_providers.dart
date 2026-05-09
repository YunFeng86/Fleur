import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_providers.dart';
import 'app_settings_providers.dart';
import 'refresh_all_providers.dart';
import '../services/accounts/account.dart';
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
    final account = ref.watch(activeAccountProvider);

    _timer?.cancel();
    _timer = null;
    _sourceElapsedMinutes = 0;
    ref.onDispose(() => _timer?.cancel());

    if (settings?.syncEnabled == false) return;

    final shouldSyncAccount = account.type != AccountType.local;
    final shouldRefreshSources =
        sourceRefreshMinutes != null &&
        sourceRefreshMinutes > 0 &&
        account.type != AccountType.fever;
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
      final account = ref.read(activeAccountProvider);
      final sourceRefreshMinutes = settings?.sourceRefreshMinutes;
      final shouldRefreshSources =
          sourceRefreshMinutes != null &&
          sourceRefreshMinutes > 0 &&
          account.type != AccountType.fever;

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

      if (account.type == AccountType.local) return;

      await ref
          .read(accountSyncCoordinatorProvider)
          .syncAccount(
            trigger: AccountSyncTrigger.foregroundAuto,
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
