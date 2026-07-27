import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef DurableJsonDecoder<T extends Object> = T Function(Object? json);
typedef DurableJsonEncoder<T extends Object> = Object? Function(T value);

enum DurableJsonSource { primary, temporary, backup }

enum DurableJsonWriteStage {
  encode,
  prepare,
  temporaryWrite,
  temporaryVerify,
  inspectPrimary,
  backup,
  discardPreviousSnapshots,
  removeCorruptPrimary,
  replace,
  replaceVerify,
}

class DurableJsonSnapshot<T extends Object> {
  const DurableJsonSnapshot({required this.value, required this.source});

  final T value;
  final DurableJsonSource source;

  bool get wasRecovered => source != DurableJsonSource.primary;
}

class DurableJsonReadException implements IOException {
  const DurableJsonReadException({
    this.primaryError,
    this.temporaryError,
    this.backupError,
    this.primaryExists = false,
    this.temporaryExists = false,
    this.backupExists = false,
    this.recoveryError,
    this.recoverySource,
  });

  final Object? primaryError;
  final Object? temporaryError;
  final Object? backupError;
  final bool primaryExists;
  final bool temporaryExists;
  final bool backupExists;
  final Object? recoveryError;
  final DurableJsonSource? recoverySource;

  @override
  String toString() {
    final source = recoverySource;
    if (source != null) {
      return 'DurableJsonReadException: failed to restore a valid '
          '${source.name} snapshot';
    }
    return 'DurableJsonReadException: no valid JSON snapshot is available';
  }
}

class DurableJsonWriteException implements IOException {
  const DurableJsonWriteException({
    required this.stage,
    required this.cause,
    this.rollbackError,
  });

  final DurableJsonWriteStage stage;
  final Object cause;
  final Object? rollbackError;

  @override
  String toString() =>
      'DurableJsonWriteException: write failed during ${stage.name}';
}

/// Filesystem seam used by [DurableJsonStore].
///
/// Keeping this interface small makes storage failures deterministic in tests
/// while the production adapter continues to use `dart:io` directly.
abstract interface class DurableFileSystem {
  Future<void> createParentDirectory(String filePath);

  Future<bool> exists(String path);

  Future<String> readAsString(String path);

  Future<void> writeAsString(String path, String contents);

  Future<void> delete(String path);

  Future<void> move(String sourcePath, String destinationPath);
}

class IoDurableFileSystem implements DurableFileSystem {
  const IoDurableFileSystem();

  @override
  Future<void> createParentDirectory(String filePath) async {
    await File(filePath).parent.create(recursive: true);
  }

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<String> readAsString(String path) {
    return File(path).readAsString(encoding: utf8);
  }

  @override
  Future<void> writeAsString(String path, String contents) async {
    await File(path).writeAsString(contents, encoding: utf8, flush: true);
  }

  @override
  Future<void> delete(String path) async {
    await File(path).delete();
  }

  @override
  Future<void> move(String sourcePath, String destinationPath) async {
    await File(sourcePath).rename(destinationPath);
  }
}

/// Stores a typed JSON document with crash recovery.
///
/// Writes are staged in `<file>.tmp`, the last valid primary is retained as
/// `<file>.bak`, and replacement uses a filesystem rename. Reads prefer a valid
/// primary, then recover from the staged payload, then the backup. If files are
/// present but none decode successfully, the read fails instead of treating
/// corruption as an absent document.
class DurableJsonStore<T extends Object> {
  DurableJsonStore({
    required File file,
    required DurableJsonDecoder<T> decode,
    required DurableJsonEncoder<T> encode,
    DurableFileSystem fileSystem = const IoDurableFileSystem(),
  }) : _primaryPath = file.path,
       _decode = decode,
       _encode = encode,
       _fileSystem = fileSystem;

  final String _primaryPath;
  final DurableJsonDecoder<T> _decode;
  final DurableJsonEncoder<T> _encode;
  final DurableFileSystem _fileSystem;

  String get _temporaryPath => '$_primaryPath.tmp';
  String get _backupPath => '$_primaryPath.bak';

  /// Runs a compound operation while holding this document's path lock.
  ///
  /// Calls to [read] and [write] inside [operation] are re-entrant, which lets
  /// callers keep read-modify-write workflows atomic across store instances
  /// and isolates.
  Future<R> runExclusive<R>(Future<R> Function() operation) {
    return _DurablePathMutex.run(_primaryPath, operation);
  }

  Future<DurableJsonSnapshot<T>?> read() {
    return runExclusive(_readUnlocked);
  }

  Future<DurableJsonSnapshot<T>?> _readUnlocked() async {
    final primary = await _tryRead(_primaryPath);
    final primaryValue = primary.value;
    if (primaryValue != null) {
      await _deleteBestEffort(_temporaryPath);
      return DurableJsonSnapshot<T>(
        value: primaryValue,
        source: DurableJsonSource.primary,
      );
    }

    final temporary = await _tryRead(_temporaryPath);
    final backup = await _tryRead(_backupPath);
    final recovery = temporary.value != null
        ? (attempt: temporary, source: DurableJsonSource.temporary)
        : backup.value != null
        ? (attempt: backup, source: DurableJsonSource.backup)
        : null;

    if (recovery != null) {
      try {
        await _restorePrimary(recovery.attempt.raw!);
      } catch (error) {
        throw DurableJsonReadException(
          primaryError: primary.error,
          temporaryError: temporary.error,
          backupError: backup.error,
          primaryExists: primary.existed,
          temporaryExists: temporary.existed,
          backupExists: backup.existed,
          recoveryError: error,
          recoverySource: recovery.source,
        );
      }
      return DurableJsonSnapshot<T>(
        value: recovery.attempt.value!,
        source: recovery.source,
      );
    }

    final anySnapshotExists =
        primary.existed || temporary.existed || backup.existed;
    if (!anySnapshotExists) return null;

    throw DurableJsonReadException(
      primaryError: primary.error,
      temporaryError: temporary.error,
      backupError: backup.error,
      primaryExists: primary.existed,
      temporaryExists: temporary.existed,
      backupExists: backup.existed,
    );
  }

  Future<void> write(T value) {
    return runExclusive(() => _writeUnlocked(value));
  }

  /// Commits a monotonic state transition without retaining an older value as
  /// a recovery candidate.
  ///
  /// The verified temporary snapshot remains recoverable if replacement is
  /// interrupted after the previous snapshots have been discarded.
  Future<void> writeReplacingPreviousSnapshots(T value) {
    return runExclusive(
      () => _writeUnlocked(value, discardPreviousSnapshots: true),
    );
  }

  /// Deletes the document snapshots while retaining the adjacent lock file.
  ///
  /// Lock files must remain stable: unlinking one while another process is
  /// waiting on its inode can let a later caller acquire a different inode and
  /// enter the critical section concurrently.
  Future<void> deleteSnapshots() {
    return runExclusive(() async {
      Object? firstError;
      StackTrace? firstStackTrace;
      for (final path in <String>[_primaryPath, _temporaryPath, _backupPath]) {
        try {
          if (await _fileSystem.exists(path)) {
            await _fileSystem.delete(path);
          }
        } catch (error, stackTrace) {
          firstError ??= error;
          firstStackTrace ??= stackTrace;
        }
      }
      if (firstError != null) {
        Error.throwWithStackTrace(firstError, firstStackTrace!);
      }
    });
  }

  Future<void> _writeUnlocked(
    T value, {
    bool discardPreviousSnapshots = false,
  }) async {
    late final String contents;
    try {
      contents = jsonEncode(_encode(value));
    } catch (error) {
      throw DurableJsonWriteException(
        stage: DurableJsonWriteStage.encode,
        cause: error,
      );
    }

    try {
      await _fileSystem.createParentDirectory(_primaryPath);
    } catch (error) {
      throw DurableJsonWriteException(
        stage: DurableJsonWriteStage.prepare,
        cause: error,
      );
    }

    try {
      await _fileSystem.writeAsString(_temporaryPath, contents);
    } catch (error) {
      throw DurableJsonWriteException(
        stage: DurableJsonWriteStage.temporaryWrite,
        cause: error,
      );
    }

    final temporary = await _tryRead(_temporaryPath);
    if (temporary.value == null) {
      throw DurableJsonWriteException(
        stage: DurableJsonWriteStage.temporaryVerify,
        cause:
            temporary.error ?? StateError('Temporary JSON snapshot is absent'),
      );
    }

    final primary = await _tryRead(_primaryPath);
    if (primary.existed && primary.raw == null) {
      await _discardTemporaryBestEffort();
      throw DurableJsonWriteException(
        stage: DurableJsonWriteStage.inspectPrimary,
        cause:
            primary.error ?? StateError('Primary JSON snapshot is unreadable'),
      );
    }

    if (discardPreviousSnapshots) {
      try {
        if (await _fileSystem.exists(_backupPath)) {
          await _fileSystem.delete(_backupPath);
        }
        if (primary.existed) {
          await _fileSystem.delete(_primaryPath);
        }
      } catch (error) {
        final rollbackError = await _rollbackFailedWrite();
        throw DurableJsonWriteException(
          stage: DurableJsonWriteStage.discardPreviousSnapshots,
          cause: error,
          rollbackError: rollbackError,
        );
      }
    } else if (primary.value != null) {
      try {
        if (await _fileSystem.exists(_backupPath)) {
          await _fileSystem.delete(_backupPath);
        }
        await _fileSystem.move(_primaryPath, _backupPath);
      } catch (error) {
        final rollbackError = await _rollbackFailedWrite();
        throw DurableJsonWriteException(
          stage: DurableJsonWriteStage.backup,
          cause: error,
          rollbackError: rollbackError,
        );
      }
    } else if (primary.existed) {
      // Never rotate a corrupt primary over the last known-good backup.
      try {
        await _fileSystem.delete(_primaryPath);
      } catch (error) {
        await _discardTemporaryBestEffort();
        throw DurableJsonWriteException(
          stage: DurableJsonWriteStage.removeCorruptPrimary,
          cause: error,
        );
      }
    }

    try {
      await _fileSystem.move(_temporaryPath, _primaryPath);
    } catch (error) {
      final rollbackError = await _rollbackFailedWrite();
      throw DurableJsonWriteException(
        stage: DurableJsonWriteStage.replace,
        cause: error,
        rollbackError: rollbackError,
      );
    }

    final committed = await _tryRead(_primaryPath);
    if (committed.value == null) {
      final rollbackError = await _rollbackFailedWrite();
      throw DurableJsonWriteException(
        stage: DurableJsonWriteStage.replaceVerify,
        cause:
            committed.error ?? StateError('Committed JSON snapshot is absent'),
        rollbackError: rollbackError,
      );
    }
  }

  Future<_JsonReadAttempt<T>> _tryRead(String path) async {
    bool existed;
    try {
      existed = await _fileSystem.exists(path);
    } catch (error) {
      return _JsonReadAttempt<T>(existed: true, error: error);
    }
    if (!existed) return _JsonReadAttempt<T>(existed: false);

    late final String raw;
    try {
      raw = await _fileSystem.readAsString(path);
    } catch (error) {
      return _JsonReadAttempt<T>(existed: true, error: error);
    }

    try {
      final decoded = jsonDecode(raw);
      return _JsonReadAttempt<T>(
        existed: true,
        raw: raw,
        value: _decode(decoded),
      );
    } catch (error) {
      return _JsonReadAttempt<T>(existed: true, raw: raw, error: error);
    }
  }

  Future<void> _restorePrimary(String contents) async {
    await _fileSystem.createParentDirectory(_primaryPath);
    if (await _fileSystem.exists(_primaryPath)) {
      await _fileSystem.delete(_primaryPath);
    }
    await _fileSystem.writeAsString(_primaryPath, contents);

    final restored = await _tryRead(_primaryPath);
    if (restored.value == null) {
      throw restored.error ?? StateError('Restored JSON snapshot is invalid');
    }
    await _deleteBestEffort(_temporaryPath);
  }

  Future<Object?> _rollbackFailedWrite() async {
    try {
      final primary = await _tryRead(_primaryPath);
      if (primary.value != null) {
        await _deleteBestEffort(_temporaryPath);
        return null;
      }

      final backup = await _tryRead(_backupPath);
      if (backup.value != null) {
        await _restorePrimary(backup.raw!);
        return null;
      }
      // With no previous valid state, keep the verified temporary snapshot so
      // startup recovery still has a complete document to work with.
      return null;
    } catch (error) {
      return error;
    }
  }

  Future<void> _discardTemporaryBestEffort() {
    return _deleteBestEffort(_temporaryPath);
  }

  Future<void> _deleteBestEffort(String path) async {
    try {
      if (await _fileSystem.exists(path)) await _fileSystem.delete(path);
    } catch (_) {
      // Cleanup must not hide the successful read or the original write error.
    }
  }
}

class _JsonReadAttempt<T extends Object> {
  const _JsonReadAttempt({
    required this.existed,
    this.raw,
    this.value,
    this.error,
  });

  final bool existed;
  final String? raw;
  final T? value;
  final Object? error;
}

class _DurablePathMutex {
  const _DurablePathMutex._();

  static final Object _heldPathsZoneKey = Object();
  static final Map<String, Future<void>> _queues = <String, Future<void>>{};

  static Future<R> run<R>(String path, Future<R> Function() operation) {
    final heldPaths =
        (Zone.current[_heldPathsZoneKey] as Set<String>?) ?? const <String>{};
    if (heldPaths.contains(path)) return operation();

    final previous = _queues[path] ?? Future<void>.value();
    final task = previous.then(
      (_) => _runWithFileLock(path, operation, heldPaths),
    );
    final tail = task.then<void>((_) {}).catchError((_) {});
    _queues[path] = tail;
    unawaited(
      tail.whenComplete(() {
        _queues.removeWhere(
          (queuedPath, queuedTail) =>
              queuedPath == path && identical(queuedTail, tail),
        );
      }),
    );
    return task;
  }

  static Future<R> _runWithFileLock<R>(
    String path,
    Future<R> Function() operation,
    Set<String> heldPaths,
  ) {
    return runZoned(
      () async {
        RandomAccessFile? lockHandle;
        try {
          try {
            final lockFile = File('$path.lock');
            await lockFile.parent.create(recursive: true);
            lockHandle = await lockFile.open(mode: FileMode.append);
            await lockHandle.lock(FileLock.exclusive);
          } catch (_) {
            // The in-isolate queue still protects callers on filesystems that do
            // not support advisory locks.
          }
          return await operation();
        } finally {
          final handle = lockHandle;
          if (handle != null) {
            try {
              await handle.unlock();
            } catch (_) {
              // Best-effort unlock; closing also releases the OS handle.
            }
            try {
              await handle.close();
            } catch (_) {
              // Best-effort close during failure propagation.
            }
          }
        }
      },
      zoneValues: <Object, Object?>{
        _heldPathsZoneKey: {...heldPaths, path},
      },
    );
  }
}
