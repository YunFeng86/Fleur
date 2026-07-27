import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fleur/services/persistence/durable_json_store.dart';

void main() {
  late Directory tempDir;
  late File primary;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fleur_durable_json_');
    primary = File('${tempDir.path}${Platform.pathSeparator}state.json');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'write atomically replaces primary and retains previous backup',
    () async {
      final store = _store(primary);

      await store.write(<String, Object?>{'value': 1});
      await store.write(<String, Object?>{'value': 2});

      final snapshot = await store.read();
      final backup = File('${primary.path}.bak');
      final backupJson = jsonDecode(await backup.readAsString());

      expect(snapshot?.value['value'], 2);
      expect(snapshot?.source, DurableJsonSource.primary);
      expect(backupJson, <String, Object?>{'value': 1});
    },
  );

  test('monotonic write does not retain the previous recovery value', () async {
    final store = _store(primary);
    await store.write(<String, Object?>{'initialized': false});

    await store.writeReplacingPreviousSnapshots(<String, Object?>{
      'initialized': true,
    });

    expect(jsonDecode(await primary.readAsString()), <String, Object?>{
      'initialized': true,
    });
    expect(await File('${primary.path}.bak').exists(), isFalse);
    expect(await File('${primary.path}.tmp').exists(), isFalse);
  });

  test(
    'monotonic write keeps the new snapshot when replacement fails',
    () async {
      await _store(primary).write(<String, Object?>{'initialized': false});
      final store = _store(primary, fileSystem: _ReplaceFailingFileSystem());

      await expectLater(
        store.writeReplacingPreviousSnapshots(<String, Object?>{
          'initialized': true,
        }),
        throwsA(
          isA<DurableJsonWriteException>().having(
            (error) => error.stage,
            'stage',
            DurableJsonWriteStage.replace,
          ),
        ),
      );

      expect(await primary.exists(), isFalse);
      expect(await File('${primary.path}.bak').exists(), isFalse);
      expect(await File('${primary.path}.tmp').exists(), isTrue);

      final recovered = await _store(primary).read();
      expect(recovered?.source, DurableJsonSource.temporary);
      expect(recovered?.value, <String, Object?>{'initialized': true});
    },
  );

  test(
    'read repairs a corrupt primary from backup without consuming it',
    () async {
      final store = _store(primary);
      await store.write(<String, Object?>{'value': 1});
      await store.write(<String, Object?>{'value': 2});
      await primary.writeAsString('{');

      final snapshot = await store.read();

      expect(snapshot?.value['value'], 1);
      expect(snapshot?.source, DurableJsonSource.backup);
      expect(jsonDecode(await primary.readAsString()), <String, Object?>{
        'value': 1,
      });
      expect(
        jsonDecode(await File('${primary.path}.bak').readAsString()),
        <String, Object?>{'value': 1},
      );
    },
  );

  test('read prefers and commits a valid temporary snapshot', () async {
    final store = _store(primary);
    await store.write(<String, Object?>{'value': 1});
    await primary.writeAsString('{');
    final temporary = File('${primary.path}.tmp');
    await temporary.writeAsString(jsonEncode(<String, Object?>{'value': 3}));

    final snapshot = await store.read();

    expect(snapshot?.value['value'], 3);
    expect(snapshot?.source, DurableJsonSource.temporary);
    expect(jsonDecode(await primary.readAsString()), <String, Object?>{
      'value': 3,
    });
    expect(await temporary.exists(), isFalse);
  });

  test('read reports corruption without overwriting any snapshot', () async {
    final store = _store(primary);
    final temporary = File('${primary.path}.tmp');
    final backup = File('${primary.path}.bak');
    await primary.writeAsString('{');
    await temporary.writeAsString('[');
    await backup.writeAsString('"wrong shape"');

    await expectLater(store.read(), throwsA(isA<DurableJsonReadException>()));

    expect(await primary.readAsString(), '{');
    expect(await temporary.readAsString(), '[');
    expect(await backup.readAsString(), '"wrong shape"');
  });

  test(
    'replace failure is explicit and restores the previous primary',
    () async {
      await _store(primary).write(<String, Object?>{'value': 1});
      final fileSystem = _ReplaceFailingFileSystem();
      final store = _store(primary, fileSystem: fileSystem);

      await expectLater(
        store.write(<String, Object?>{'value': 2}),
        throwsA(
          isA<DurableJsonWriteException>().having(
            (error) => error.stage,
            'stage',
            DurableJsonWriteStage.replace,
          ),
        ),
      );

      expect(jsonDecode(await primary.readAsString()), <String, Object?>{
        'value': 1,
      });
      expect(await File('${primary.path}.tmp').exists(), isFalse);
    },
  );

  test('read waits for an in-progress replacement on the same path', () async {
    await _store(primary).write(<String, Object?>{'value': 1});
    final fileSystem = _BlockingReplaceFileSystem();
    final writer = _store(primary, fileSystem: fileSystem);

    final write = writer.write(<String, Object?>{'value': 2});
    await fileSystem.replaceStarted.future;

    var readCompleted = false;
    final read = _store(primary).read().then((snapshot) {
      readCompleted = true;
      return snapshot;
    });
    await Future<void>.delayed(Duration.zero);
    expect(readCompleted, isFalse);

    fileSystem.allowReplace.complete();
    await write;
    final snapshot = await read;

    expect(snapshot?.value['value'], 2);
    expect(jsonDecode(await primary.readAsString()), <String, Object?>{
      'value': 2,
    });
  });
}

DurableJsonStore<Map<String, Object?>> _store(
  File file, {
  DurableFileSystem fileSystem = const IoDurableFileSystem(),
}) {
  return DurableJsonStore<Map<String, Object?>>(
    file: file,
    decode: (decoded) {
      if (decoded is! Map) throw const FormatException('Expected an object');
      return decoded.cast<String, Object?>();
    },
    encode: (value) => value,
    fileSystem: fileSystem,
  );
}

class _ReplaceFailingFileSystem implements DurableFileSystem {
  final IoDurableFileSystem _delegate = const IoDurableFileSystem();
  var _failed = false;

  @override
  Future<void> createParentDirectory(String filePath) {
    return _delegate.createParentDirectory(filePath);
  }

  @override
  Future<void> delete(String path) => _delegate.delete(path);

  @override
  Future<bool> exists(String path) => _delegate.exists(path);

  @override
  Future<void> move(String sourcePath, String destinationPath) {
    if (!_failed && sourcePath.endsWith('.tmp')) {
      _failed = true;
      throw FileSystemException('Injected replace failure');
    }
    return _delegate.move(sourcePath, destinationPath);
  }

  @override
  Future<String> readAsString(String path) => _delegate.readAsString(path);

  @override
  Future<void> writeAsString(String path, String contents) {
    return _delegate.writeAsString(path, contents);
  }
}

class _BlockingReplaceFileSystem implements DurableFileSystem {
  final IoDurableFileSystem _delegate = const IoDurableFileSystem();
  final Completer<void> replaceStarted = Completer<void>();
  final Completer<void> allowReplace = Completer<void>();

  @override
  Future<void> createParentDirectory(String filePath) {
    return _delegate.createParentDirectory(filePath);
  }

  @override
  Future<void> delete(String path) => _delegate.delete(path);

  @override
  Future<bool> exists(String path) => _delegate.exists(path);

  @override
  Future<void> move(String sourcePath, String destinationPath) async {
    if (sourcePath.endsWith('.tmp')) {
      if (!replaceStarted.isCompleted) replaceStarted.complete();
      await allowReplace.future;
    }
    await _delegate.move(sourcePath, destinationPath);
  }

  @override
  Future<String> readAsString(String path) => _delegate.readAsString(path);

  @override
  Future<void> writeAsString(String path, String contents) {
    return _delegate.writeAsString(path, contents);
  }
}
