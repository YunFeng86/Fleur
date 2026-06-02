import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:isar_community/isar.dart';

bool _isarCoreInitialized = false;

/// Ensures Isar Core native libraries are available for unit tests.
///
/// In `flutter test`, the working directory might not contain Isar Core binaries,
/// so we load them from `isar_community_flutter_libs` in pub cache to keep tests runnable
/// offline.
Future<void> ensureIsarCoreInitialized() async {
  if (_isarCoreInitialized) return;

  final coreLibName = switch (true) {
    _ when Platform.isWindows => 'isar.dll',
    _ when Platform.isMacOS => 'libisar.dylib',
    _ => 'libisar.so',
  };
  final platformDir = switch (true) {
    _ when Platform.isWindows => 'windows',
    _ when Platform.isMacOS => 'macos',
    _ => 'linux',
  };

  final isarFlutterLibsRoot = await _resolvePackageRoot(
    'isar_community_flutter_libs',
  );
  if (isarFlutterLibsRoot == null) {
    throw StateError(
      'Failed to locate isar_community_flutter_libs in the package config. '
      'Add isar_community_flutter_libs to your dependencies.',
    );
  }

  final isarCorePath =
      '${isarFlutterLibsRoot.path}${Platform.pathSeparator}$platformDir'
      '${Platform.pathSeparator}$coreLibName';
  await Isar.initializeIsarCore(libraries: {Abi.current(): isarCorePath});

  _isarCoreInitialized = true;
}

Future<Directory?> _resolvePackageRoot(String packageName) async {
  final configFile = File('.dart_tool/package_config.json');
  // ignore: avoid_slow_async_io
  if (!await configFile.exists()) return null;

  final configUri = configFile.uri;
  final raw =
      jsonDecode(await configFile.readAsString()) as Map<String, Object?>;
  final packages = (raw['packages'] as List<Object?>)
      .whereType<Map<String, Object?>>()
      .toList();

  Map<String, Object?>? pkg;
  for (final p in packages) {
    if (p['name'] == packageName) {
      pkg = p;
      break;
    }
  }
  if (pkg == null) return null;

  final rootUriStr = pkg['rootUri'] as String?;
  if (rootUriStr == null) return null;

  // `rootUri` can be relative to the config file, so resolve against it.
  final rootUri = configUri.resolve(rootUriStr);
  return Directory.fromUri(rootUri);
}
