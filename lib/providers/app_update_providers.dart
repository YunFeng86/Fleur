import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/logging/app_logger.dart';
import '../services/update/app_update_manifest.dart';
import '../services/update/app_update_service.dart';
import 'service_providers.dart';

const kStableUpdateManifestUrl =
    'https://zeyrme.github.io/Fleur/updates/stable/latest.json';

final appUpdateManifestUriProvider = Provider<Uri>(
  (ref) => Uri.parse(kStableUpdateManifestUrl),
);

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService(
    dio: ref.watch(dioProvider),
    manifestUri: ref.watch(appUpdateManifestUriProvider),
  );
}, dependencies: [dioProvider, appUpdateManifestUriProvider]);

enum AppUpdateStatus { idle, checking, upToDate, updateAvailable, error }

class AppUpdateState {
  const AppUpdateState({
    required this.status,
    this.manifest,
    this.currentVersion,
    this.checkedAt,
    this.error,
  });

  const AppUpdateState.idle() : this(status: AppUpdateStatus.idle);

  final AppUpdateStatus status;
  final AppUpdateManifest? manifest;
  final String? currentVersion;
  final DateTime? checkedAt;
  final Object? error;

  bool get hasUpdate =>
      status == AppUpdateStatus.updateAvailable && manifest != null;
}

class AppUpdateController extends Notifier<AppUpdateState> {
  Timer? _startupTimer;
  bool _startupCheckScheduled = false;
  int _requestSeq = 0;

  @override
  AppUpdateState build() {
    ref.onDispose(() => _startupTimer?.cancel());
    return const AppUpdateState.idle();
  }

  void scheduleStartupCheck({Duration delay = const Duration(seconds: 45)}) {
    if (_startupCheckScheduled) return;
    _startupCheckScheduled = true;
    _startupTimer = Timer(delay, () {
      unawaited(check(silent: true));
    });
  }

  void cancelStartupCheck() {
    _startupTimer?.cancel();
    _startupTimer = null;
  }

  Future<void> check({bool silent = false}) async {
    final previous = state;
    if (previous.status == AppUpdateStatus.checking) return;
    // Silent checks never enter `checking`, so a manual check may start while
    // one is in flight; only the latest request may write state afterwards.
    final request = ++_requestSeq;
    if (!silent) {
      state = AppUpdateState(
        status: AppUpdateStatus.checking,
        manifest: previous.manifest,
        currentVersion: previous.currentVersion,
        checkedAt: previous.checkedAt,
      );
    }

    try {
      final result = await ref.read(appUpdateServiceProvider).checkLatest();
      if (request != _requestSeq) return;
      state = AppUpdateState(
        status: result.isUpdateAvailable
            ? AppUpdateStatus.updateAvailable
            : AppUpdateStatus.upToDate,
        manifest: result.manifest,
        currentVersion: result.currentVersion,
        checkedAt: DateTime.now(),
      );
    } catch (e, s) {
      AppLogger.w(
        'Update check failed',
        tag: 'update',
        error: e,
        stackTrace: s,
      );
      if (request != _requestSeq) return;
      if (silent) {
        state = previous;
        return;
      }
      state = AppUpdateState(
        status: AppUpdateStatus.error,
        manifest: previous.manifest,
        currentVersion: previous.currentVersion,
        checkedAt: DateTime.now(),
        error: e,
      );
    }
  }
}

final appUpdateControllerProvider =
    NotifierProvider<AppUpdateController, AppUpdateState>(
      AppUpdateController.new,
    );
