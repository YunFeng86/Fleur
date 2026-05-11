import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fleur/utils/path_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../test_utils/fake_path_provider_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform originalPlatform;
  Directory? tempDir;

  setUpAll(() {
    originalPlatform = PathProviderPlatform.instance;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fleur_path_manager_');
    final docs = await Directory(
      '${tempDir!.path}/documents',
    ).create(recursive: true);
    final support = await Directory(
      '${tempDir!.path}/support',
    ).create(recursive: true);
    final cache = await Directory(
      '${tempDir!.path}/cache',
    ).create(recursive: true);
    final temporary = await Directory(
      '${tempDir!.path}/temporary',
    ).create(recursive: true);
    PathProviderPlatform.instance = FakePathProviderPlatform(
      documentsPath: docs.path,
      supportPath: support.path,
      cachePath: cache.path,
      temporaryPath: temporary.path,
    );
    PathManager.resetForTests();
  });

  tearDown(() async {
    PathManager.resetForTests();
    PathProviderPlatform.instance = originalPlatform;
    final dir = tempDir;
    tempDir = null;
    if (dir != null && await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });

  test(
    'ignores non-finite pending deletes without dropping valid ones',
    () async {
      final support = Directory('${tempDir!.path}/support');
      await Directory('${support.path}/db').create(recursive: true);
      await File('${support.path}/db/fleur.isar').writeAsString('db');
      final validSource = File('${tempDir!.path}/valid-source');
      final validDestination = File('${tempDir!.path}/valid-destination');
      await validSource.writeAsString('source');
      await validDestination.writeAsString('target');
      await File('${support.path}/.migration_v2_state.json').writeAsString('''
{
  "version": 2,
  "migrated": true,
  "pendingDeletes": [
    {
      "srcPath": "/tmp/source",
      "dstPath": "/tmp/destination",
      "length": 1e9999
    },
    {
      "srcPath": "${validSource.path}",
      "dstPath": "${validDestination.path}",
      "length": 5
    }
  ]
}
''');

      await PathManager.getStateDir();

      expect(PathManager.isMigrationComplete, isTrue);
      final state = await File(
        '${support.path}/.migration_v2_state.json',
      ).readAsString();
      expect(state, contains(validSource.path));
    },
  );
}
