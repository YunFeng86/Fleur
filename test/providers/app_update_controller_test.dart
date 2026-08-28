import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fleur/providers/app_update_providers.dart';
import 'package:fleur/services/update/app_update_manifest.dart';
import 'package:fleur/services/update/app_update_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enters updateAvailable when a newer manifest is returned', () async {
    final container = _buildContainer(
      _FakeAppUpdateService(
        result: AppUpdateCheckResult(
          manifest: _manifest(version: '0.1.5'),
          isUpdateAvailable: true,
          currentVersion: '0.1.2',
        ),
      ),
    );
    addTearDown(container.dispose);

    await container.read(appUpdateControllerProvider.notifier).check();

    final state = container.read(appUpdateControllerProvider);
    expect(state.status, AppUpdateStatus.updateAvailable);
    expect(state.hasUpdate, isTrue);
    expect(state.manifest?.version, '0.1.5');
    expect(state.currentVersion, '0.1.2');
  });

  test('enters upToDate when latest manifest is not newer', () async {
    final container = _buildContainer(
      _FakeAppUpdateService(
        result: AppUpdateCheckResult(
          manifest: _manifest(version: '0.1.5'),
          isUpdateAvailable: false,
          currentVersion: '0.1.5',
        ),
      ),
    );
    addTearDown(container.dispose);

    await container.read(appUpdateControllerProvider.notifier).check();

    final state = container.read(appUpdateControllerProvider);
    expect(state.status, AppUpdateStatus.upToDate);
    expect(state.hasUpdate, isFalse);
  });

  test('manual failure enters error state', () async {
    final container = _buildContainer(
      _FakeAppUpdateService(error: StateError('network failed')),
    );
    addTearDown(container.dispose);

    await container.read(appUpdateControllerProvider.notifier).check();

    final state = container.read(appUpdateControllerProvider);
    expect(state.status, AppUpdateStatus.error);
    expect(state.error, isA<StateError>());
  });

  test('silent startup failure keeps previous state', () async {
    final container = _buildContainer(
      _FakeAppUpdateService(error: StateError('network failed')),
    );
    addTearDown(container.dispose);

    await container
        .read(appUpdateControllerProvider.notifier)
        .check(silent: true);

    final state = container.read(appUpdateControllerProvider);
    expect(state.status, AppUpdateStatus.idle);
    expect(state.error, isNull);
  });

  test(
    'manual result survives a late-failing silent check started earlier',
    () async {
      final service = _GatedAppUpdateService();
      final container = _buildContainer(service);
      addTearDown(container.dispose);
      final notifier = container.read(appUpdateControllerProvider.notifier);

      final silent = notifier.check(silent: true);
      final manual = notifier.check();
      expect(
        container.read(appUpdateControllerProvider).status,
        AppUpdateStatus.checking,
      );

      service.calls[1].complete(
        AppUpdateCheckResult(
          manifest: _manifest(version: '0.2.0'),
          isUpdateAvailable: true,
          currentVersion: '0.1.2',
        ),
      );
      await manual;
      expect(
        container.read(appUpdateControllerProvider).status,
        AppUpdateStatus.updateAvailable,
      );

      service.calls[0].completeError(StateError('network failed'));
      await silent;

      final state = container.read(appUpdateControllerProvider);
      expect(state.status, AppUpdateStatus.updateAvailable);
      expect(state.manifest?.version, '0.2.0');
    },
  );

  test(
    'late-completing silent check does not overwrite a newer manual result',
    () async {
      final service = _GatedAppUpdateService();
      final container = _buildContainer(service);
      addTearDown(container.dispose);
      final notifier = container.read(appUpdateControllerProvider.notifier);

      final silent = notifier.check(silent: true);
      final manual = notifier.check();

      service.calls[1].complete(
        AppUpdateCheckResult(
          manifest: _manifest(version: '0.1.5'),
          isUpdateAvailable: false,
          currentVersion: '0.1.5',
        ),
      );
      await manual;

      service.calls[0].complete(
        AppUpdateCheckResult(
          manifest: _manifest(version: '0.9.9'),
          isUpdateAvailable: true,
          currentVersion: '0.1.5',
        ),
      );
      await silent;

      final state = container.read(appUpdateControllerProvider);
      expect(state.status, AppUpdateStatus.upToDate);
      expect(state.manifest?.version, '0.1.5');
    },
  );
}

ProviderContainer _buildContainer(AppUpdateService service) {
  return ProviderContainer(
    overrides: [appUpdateServiceProvider.overrideWithValue(service)],
  );
}

AppUpdateManifest _manifest({required String version}) {
  return AppUpdateManifest.fromJson({
    'schemaVersion': 1,
    'channel': 'stable',
    'version': version,
    'tag': 'v$version',
    'releaseUrl': 'https://github.com/ZeyrMe/Fleur/releases/tag/v$version',
    'notes': {'en': '- Fixed', 'zh': '- 修复'},
  });
}

class _FakeAppUpdateService extends AppUpdateService {
  _FakeAppUpdateService({AppUpdateCheckResult? result, Object? error})
    : _result = result,
      _error = error,
      super(
        dio: Dio(),
        manifestUri: Uri.parse('https://updates.example.com/latest.json'),
      );

  final AppUpdateCheckResult? _result;
  final Object? _error;

  @override
  Future<AppUpdateCheckResult> checkLatest({String? currentVersion}) async {
    final error = _error;
    if (error != null) throw error;
    return _result!;
  }
}

/// Each [AppUpdateService.checkLatest] call parks on its own completer so
/// tests can resolve overlapping requests in any order. Callers of
/// [AppUpdateController.check] trigger [checkLatest] synchronously, so the
/// Nth check maps to `calls[N - 1]`.
class _GatedAppUpdateService extends AppUpdateService {
  _GatedAppUpdateService()
    : super(
        dio: Dio(),
        manifestUri: Uri.parse('https://updates.example.com/latest.json'),
      );

  final calls = <Completer<AppUpdateCheckResult>>[];

  @override
  Future<AppUpdateCheckResult> checkLatest({String? currentVersion}) {
    final completer = Completer<AppUpdateCheckResult>();
    calls.add(completer);
    return completer.future;
  }
}
