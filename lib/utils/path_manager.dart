import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Centralized, semantic paths for app storage on desktop/mobile.
///
/// Storage strategy:
/// - Support (Application Support): DB, settings, user state (should be backed up by OS).
/// - Cache (Application Cache): derived data (can be safely cleared by OS/user).
///
/// Migration strategy (v2):
/// - Copy -> Verify (size + MD5) -> Delete
/// - Deletion is best-effort and retried on next startup using a pending-delete list.
class PathManager {
  static const String _appFolderName = 'fleur';

  // Legacy names used by older builds of this app (and the old Flutter Reader branding).
  static const String _legacyAppFolderName = 'flutter_reader';
  static const String _legacyIsarName = 'flutter_reader';
  static const String _isarName = 'fleur';

  static const String _migrationStateFileName = '.migration_v2_state.json';
  static const String _flattenStateFileName =
      '.migration_v3_flatten_state.json';
  static const int _md5VerifyMaxBytes = 50 * 1024 * 1024; // 50 MB

  static Future<void>? _initFuture;
  static late Directory _supportDir;
  static late Directory _cacheDir;
  static bool _migrationComplete = false;

  static Directory _dbDir() => Directory(p.join(_supportDir.path, 'db'));
  static Directory _settingsDir() =>
      Directory(p.join(_supportDir.path, 'settings'));
  static Directory _stateDir() => Directory(p.join(_supportDir.path, 'state'));

  @visibleForTesting
  static void resetForTests() {
    // Allows tests to swap PathProviderPlatform.instance between cases.
    _initFuture = null;
    _migrationComplete = false;
  }

  static bool get isMigrationComplete => _migrationComplete;

  static Future<void> _ensureInitialized() {
    return _initFuture ??= _init();
  }

  static Future<void> _init() async {
    final supportRoot = await getApplicationSupportDirectory();
    final cacheRoot = await getApplicationCacheDirectory();

    // PathProvider already returns an app-specific directory on all supported
    // platforms, so avoid creating an extra nested "<app>/<app>" folder.
    _supportDir = Directory(supportRoot.path);
    _cacheDir = Directory(cacheRoot.path);

    await _supportDir.create(recursive: true);
    await _cacheDir.create(recursive: true);

    try {
      await _ensureFlattenedFromNestedV2Dirs();
      await _ensureMigration();
    } catch (e) {
      // Migration failures should never block app startup.
      if (kDebugMode) {
        debugPrint('warning: migration v2 failed: $e');
      }
    }
  }

  static Future<void> _ensureFlattenedFromNestedV2Dirs() async {
    // This migration flattens the previous v2 layout where we created an extra
    // "fleur/" directory inside the app-specific support/cache directories.
    //
    // Before (v2):
    //   Support: <supportRoot>/fleur/{db,settings,state,...}
    //   Cache:   <cacheRoot>/fleur/{favicons.json,image_meta.json}
    // After (v3):
    //   Support: <supportRoot>/{db,settings,state,...}
    //   Cache:   <cacheRoot>/{favicons.json,image_meta.json}
    final stateFile = File(p.join(_supportDir.path, _flattenStateFileName));
    if (await stateFile.exists()) return;

    final nestedSupport = Directory(p.join(_supportDir.path, _appFolderName));
    final nestedCache = Directory(p.join(_cacheDir.path, _appFolderName));

    if (await nestedSupport.exists()) {
      await _moveDirIfAbsent(
        src: Directory(p.join(nestedSupport.path, 'db')),
        dst: Directory(p.join(_supportDir.path, 'db')),
      );
      await _moveDirIfAbsent(
        src: Directory(p.join(nestedSupport.path, 'settings')),
        dst: Directory(p.join(_supportDir.path, 'settings')),
      );
      await _moveDirIfAbsent(
        src: Directory(p.join(nestedSupport.path, 'state')),
        dst: Directory(p.join(_supportDir.path, 'state')),
      );
      // Preserve v2 migration state (pending deletes, etc.) if present.
      await _moveFileIfAbsent(
        src: File(p.join(nestedSupport.path, _migrationStateFileName)),
        dst: File(p.join(_supportDir.path, _migrationStateFileName)),
      );

      await _tryDeleteDirIfEmpty(nestedSupport);
    }

    if (await nestedCache.exists()) {
      await _moveFileIfAbsent(
        src: File(p.join(nestedCache.path, 'favicons.json')),
        dst: File(p.join(_cacheDir.path, 'favicons.json')),
      );
      await _moveFileIfAbsent(
        src: File(p.join(nestedCache.path, 'image_meta.json')),
        dst: File(p.join(_cacheDir.path, 'image_meta.json')),
      );
      await _tryDeleteDirIfEmpty(nestedCache);
    }

    // Mark flatten migration as complete (best-effort).
    try {
      final encoded = <String, Object?>{
        'version': 3,
        'flattened': true,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await stateFile.writeAsString(jsonEncode(encoded), encoding: utf8);
    } catch (_) {
      // best-effort
    }
  }

  static Future<void> _moveDirIfAbsent({
    required Directory src,
    required Directory dst,
  }) async {
    try {
      if (!await src.exists()) return;
      if (await dst.exists()) return;
      await dst.parent.create(recursive: true);
      try {
        await src.rename(dst.path);
        return;
      } catch (_) {
        // Fall through to copy+delete.
      }
      await _copyDirectory(src: src, dst: dst);
      try {
        await src.delete(recursive: true);
      } catch (_) {
        // best-effort
      }
    } catch (_) {
      // best-effort
    }
  }

  static Future<void> _moveFileIfAbsent({
    required File src,
    required File dst,
  }) async {
    try {
      if (!await src.exists()) return;
      if (await dst.exists()) return;
      await dst.parent.create(recursive: true);
      try {
        await src.rename(dst.path);
        return;
      } catch (_) {
        // Fall through to copy+delete.
      }
      await src.copy(dst.path);
      try {
        await src.delete();
      } catch (_) {
        // best-effort
      }
    } catch (_) {
      // best-effort
    }
  }

  static Future<void> _copyDirectory({
    required Directory src,
    required Directory dst,
  }) async {
    await dst.create(recursive: true);
    await for (final entity in src.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (entity is File) {
        final out = File(p.join(dst.path, name));
        if (await out.exists()) continue;
        await entity.copy(out.path);
      } else if (entity is Directory) {
        await _copyDirectory(
          src: entity,
          dst: Directory(p.join(dst.path, name)),
        );
      }
    }
  }

  static Future<void> _tryDeleteDirIfEmpty(Directory dir) async {
    try {
      if (!await dir.exists()) return;
      final items = await dir.list(followLinks: false).toList();
      if (items.isNotEmpty) return;
      await dir.delete();
    } catch (_) {
      // best-effort
    }
  }

  static Future<Directory> getSupportDir() async {
    await _ensureInitialized();
    // Support dir may be deleted by user/system cleanup tools; re-create best-effort.
    try {
      await _supportDir.create(recursive: true);
    } catch (_) {
      // best-effort
    }
    return _supportDir;
  }

  static Future<Directory> getCacheDir() async {
    await _ensureInitialized();
    // Cache dir may be deleted by user/system cleanup tools; re-create best-effort.
    try {
      await _cacheDir.create(recursive: true);
    } catch (_) {
      // best-effort
    }
    return _cacheDir;
  }

  static Future<Directory> getDbDir() async {
    await _ensureInitialized();
    final dir = _dbDir();
    await dir.create(recursive: true);
    return dir;
  }

  /// Returns the best Isar location to open without risking silent data loss.
  ///
  /// Preference order:
  /// 1) New location in Application Support (after successful migration)
  /// 2) Legacy location in Documents (fallback when migration/copy fails)
  static Future<({Directory directory, String name})> getIsarLocation() async {
    await _ensureInitialized();

    final dbDir = await getDbDir();
    final newDb = File(p.join(dbDir.path, '$_isarName.isar'));
    if (await newDb.exists()) {
      return (directory: dbDir, name: _isarName);
    }

    final legacy = await _findLegacyIsar();
    if (legacy != null) return legacy;

    return (directory: dbDir, name: _isarName);
  }

  static Future<Directory> getSettingsDir() async {
    await _ensureInitialized();
    final dir = _settingsDir();
    await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> getStateDir() async {
    await _ensureInitialized();
    final dir = _stateDir();
    await dir.create(recursive: true);
    return dir;
  }

  static Future<String> getSupportPath() async => (await getSupportDir()).path;
  static Future<String> getCachePath() async => (await getCacheDir()).path;

  static Future<File> appSettingsFile() async {
    final dir = await getSettingsDir();
    return File(p.join(dir.path, 'app_settings.json'));
  }

  static Future<File> readerSettingsFile() async {
    final dir = await getSettingsDir();
    return File(p.join(dir.path, 'reader_settings.json'));
  }

  static Future<File> readerProgressFile() async {
    final dir = await getStateDir();
    return File(p.join(dir.path, 'reader_progress.json'));
  }

  static Future<File> faviconCacheFile() async {
    final dir = await getCacheDir();
    return File(p.join(dir.path, 'favicons.json'));
  }

  static Future<File> imageMetaFile() async {
    final dir = await getCacheDir();
    return File(p.join(dir.path, 'image_meta.json'));
  }

  static Future<File?> legacyAppSettingsFile() async =>
      _findLegacyFile('app_settings.json');
  static Future<File?> legacyReaderSettingsFile() async =>
      _findLegacyFile('reader_settings.json');
  static Future<File?> legacyReaderProgressFile() async =>
      _findLegacyFile('reader_progress.json');

  static Future<File?> _findLegacyFile(String fileName) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final docPath = documentsDir.path;

      final candidates = <String>[
        p.join(docPath, _appFolderName, fileName),
        p.join(docPath, _legacyAppFolderName, fileName),
        p.join(docPath, fileName),
      ];

      for (final c in candidates) {
        final f = File(c);
        if (await f.exists()) return f;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _ensureMigration() async {
    final stateFile = File(p.join(_supportDir.path, _migrationStateFileName));
    final state = await _readMigrationState(stateFile);

    // Retry pending deletions first.
    final remainingDeletes = <_PendingDelete>[];
    for (final item in state.pendingDeletes) {
      final remaining = await _tryDeletePending(item);
      if (remaining != null) remainingDeletes.add(remaining);
    }

    // Ensure subdirectories exist before migration.
    final dbDir = _dbDir();
    final settingsDir = _settingsDir();
    final stateDir = _stateDir();
    await dbDir.create(recursive: true);
    await settingsDir.create(recursive: true);
    await stateDir.create(recursive: true);

    final dbReady = await File(p.join(dbDir.path, '$_isarName.isar')).exists();

    // Copy/verify steps are done until we have a usable DB in Support.
    // This avoids creating a "fresh" empty DB in the new location if migration fails.
    final shouldCopy = (!state.migrated) || (!dbReady);
    if (shouldCopy) {
      final migrationResult = await _migrateFromDocuments(
        dbDir: dbDir,
        settingsDir: settingsDir,
        stateDir: stateDir,
        cacheDir: _cacheDir,
      );
      final nextState = _MigrationState(
        migrated: migrationResult.migrated,
        pendingDeletes: <_PendingDelete>[
          ...remainingDeletes,
          ...migrationResult.pendingDeletes,
        ],
      );
      await _writeMigrationState(stateFile, nextState);
      _migrationComplete = nextState.migrated;
      if (_needsBackgroundFinalize(nextState.pendingDeletes)) {
        unawaited(_finalizeLargeDeletesInBackground(stateFile));
      }
      return;
    }

    // Persist the pending-delete list after retries.
    if (remainingDeletes.length != state.pendingDeletes.length) {
      final nextState = _MigrationState(
        migrated: true,
        pendingDeletes: remainingDeletes,
      );
      await _writeMigrationState(stateFile, nextState);
    }

    _migrationComplete = true;
    if (_needsBackgroundFinalize(remainingDeletes)) {
      unawaited(_finalizeLargeDeletesInBackground(stateFile));
    }
  }

  static Future<_MigrationResult> _migrateFromDocuments({
    required Directory dbDir,
    required Directory settingsDir,
    required Directory stateDir,
    required Directory cacheDir,
  }) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final oldAppDir = Directory(p.join(documentsDir.path, _appFolderName));
    final legacyDir = Directory(
      p.join(documentsDir.path, _legacyAppFolderName),
    );

    // Prefer app-specific subdirectories over the Documents root.
    final sources = <Directory>[oldAppDir, legacyDir, documentsDir];

    final migratedPending = <_PendingDelete>[];
    var needsRetryCopy = false;

    Future<void> migrateOne({
      required Directory srcDir,
      required String from,
      required File dst,
    }) async {
      final src = File(p.join(srcDir.path, from));
      if (!await src.exists()) return;
      final dstExistedBefore = await dst.exists();
      final result = await _copyVerifyDelete(src: src, dst: dst);
      if (result.pendingDelete != null) {
        migratedPending.add(result.pendingDelete!);
      }
      if (!dstExistedBefore && !await dst.exists()) {
        needsRetryCopy = true;
      }
    }

    for (final srcDir in sources) {
      if (!await srcDir.exists()) continue;

      // Isar DB: support/db/fleur.isar (migrate both old and new filenames).
      await migrateOne(
        srcDir: srcDir,
        from: '$_legacyIsarName.isar',
        dst: File(p.join(dbDir.path, '$_isarName.isar')),
      );
      await migrateOne(
        srcDir: srcDir,
        from: '$_isarName.isar',
        dst: File(p.join(dbDir.path, '$_isarName.isar')),
      );

      // Settings: support/settings/*.json
      await migrateOne(
        srcDir: srcDir,
        from: 'app_settings.json',
        dst: File(p.join(settingsDir.path, 'app_settings.json')),
      );
      await migrateOne(
        srcDir: srcDir,
        from: 'reader_settings.json',
        dst: File(p.join(settingsDir.path, 'reader_settings.json')),
      );

      // Reader progress: support/state/reader_progress.json
      await migrateOne(
        srcDir: srcDir,
        from: 'reader_progress.json',
        dst: File(p.join(stateDir.path, 'reader_progress.json')),
      );

      // Cache: cache/*.json
      await migrateOne(
        srcDir: srcDir,
        from: 'favicons.json',
        dst: File(p.join(cacheDir.path, 'favicons.json')),
      );
      await migrateOne(
        srcDir: srcDir,
        from: 'image_meta.json',
        dst: File(p.join(cacheDir.path, 'image_meta.json')),
      );

      // Best-effort cleanup for legacy lock files (do not migrate them).
      await _tryDeleteLockFile(p.join(srcDir.path, '$_legacyIsarName.lock'));
      await _tryDeleteLockFile(p.join(srcDir.path, '$_isarName.lock'));
    }

    return _MigrationResult(
      migrated: !needsRetryCopy,
      pendingDeletes: migratedPending,
    );
  }

  static Future<void> _tryDeleteLockFile(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return;
      await f.delete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('warning: failed to delete legacy lock file: $path ($e)');
      }
    }
  }

  static Future<_PendingDelete?> _tryDeletePending(_PendingDelete item) async {
    try {
      final src = File(item.srcPath);
      if (!await src.exists()) return null;

      final dst = File(item.dstPath);
      if (!await dst.exists()) return item;

      final srcLen = await src.length();
      if (srcLen != item.length) return item;

      final dstLen = await dst.length();
      if (dstLen != item.length) return item;

      final srcMtimeMs = (await src.lastModified()).millisecondsSinceEpoch;
      final dstMtimeMs = (await dst.lastModified()).millisecondsSinceEpoch;
      final canReuseHashes =
          item.srcMd5 != null &&
          item.dstMd5 != null &&
          item.srcMtimeMs == srcMtimeMs &&
          item.dstMtimeMs == dstMtimeMs;

      final srcMd5 = canReuseHashes
          ? item.srcMd5!
          : await _md5HexPossiblyInBackground(src);
      final dstMd5 = canReuseHashes
          ? item.dstMd5!
          : await _md5HexPossiblyInBackground(dst);

      final next = item.copyWith(
        srcMd5: srcMd5,
        dstMd5: dstMd5,
        srcMtimeMs: srcMtimeMs,
        dstMtimeMs: dstMtimeMs,
      );

      if (srcMd5 != dstMd5) return next;

      try {
        await src.delete();
        return null;
      } catch (_) {
        return next;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('warning: pending delete failed: ${item.srcPath} ($e)');
      }
      return item;
    }
  }

  static Future<_CopyResult> _copyVerifyDelete({
    required File src,
    required File dst,
  }) async {
    try {
      if (await dst.exists()) {
        // Destination already exists. Only delete the source when it's proven to
        // be identical to the destination.
        try {
          final srcLen = await src.length();
          final dstLen = await dst.length();
          if (srcLen != dstLen) {
            return const _CopyResult(copied: false, pendingDelete: null);
          }

          if (srcLen > _md5VerifyMaxBytes) {
            return _CopyResult(
              copied: false,
              pendingDelete: _PendingDelete(
                srcPath: src.path,
                dstPath: dst.path,
                length: srcLen,
              ),
            );
          }

          final srcMd5 = await _md5HexPossiblyInBackground(src);
          final dstMd5 = await _md5HexPossiblyInBackground(dst);
          if (srcMd5 != dstMd5) {
            return const _CopyResult(copied: false, pendingDelete: null);
          }

          try {
            await src.delete();
            return const _CopyResult(copied: false, pendingDelete: null);
          } catch (_) {
            return _CopyResult(
              copied: false,
              pendingDelete: _PendingDelete(
                srcPath: src.path,
                dstPath: dst.path,
                length: srcLen,
                srcMd5: srcMd5,
                dstMd5: dstMd5,
              ),
            );
          }
        } catch (_) {
          return const _CopyResult(copied: false, pendingDelete: null);
        }
      }

      await dst.parent.create(recursive: true);

      final tmp = File('${dst.path}.tmp');
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {
          // ignore
        }
      }

      await src.copy(tmp.path);

      final srcLen = await src.length();
      final tmpLen = await tmp.length();
      if (srcLen != tmpLen) {
        try {
          await tmp.delete();
        } catch (_) {
          // ignore
        }
        return const _CopyResult(copied: false, pendingDelete: null);
      }

      // For huge files, only check size on the critical path and finalize
      // cleanup later after background MD5 verification.
      String? verifiedSrcMd5;
      String? verifiedDstMd5;
      if (srcLen <= _md5VerifyMaxBytes) {
        verifiedSrcMd5 = await _md5HexPossiblyInBackground(src);
        final tmpMd5 = await _md5HexPossiblyInBackground(tmp);
        if (verifiedSrcMd5 != tmpMd5) {
          try {
            await tmp.delete();
          } catch (_) {
            // ignore
          }
          return const _CopyResult(copied: false, pendingDelete: null);
        }
        verifiedDstMd5 = tmpMd5;
      }

      await tmp.rename(dst.path);

      if (srcLen > _md5VerifyMaxBytes) {
        return _CopyResult(
          copied: true,
          pendingDelete: _PendingDelete(
            srcPath: src.path,
            dstPath: dst.path,
            length: srcLen,
          ),
        );
      }

      // Delete source (best-effort). If it fails, persist a pending-delete entry.
      try {
        await src.delete();
        return const _CopyResult(copied: true, pendingDelete: null);
      } catch (_) {
        return _CopyResult(
          copied: true,
          pendingDelete: _PendingDelete(
            srcPath: src.path,
            dstPath: dst.path,
            length: srcLen,
            srcMd5: verifiedSrcMd5,
            dstMd5: verifiedDstMd5,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'warning: migrate file failed: ${src.path} -> ${dst.path} ($e)',
        );
      }
      return const _CopyResult(copied: false, pendingDelete: null);
    }
  }

  static Future<_MigrationState> _readMigrationState(File stateFile) async {
    try {
      if (!await stateFile.exists()) {
        return const _MigrationState(
          migrated: false,
          pendingDeletes: <_PendingDelete>[],
        );
      }
      final raw = await stateFile.readAsString(encoding: utf8);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const _MigrationState(
          migrated: false,
          pendingDeletes: <_PendingDelete>[],
        );
      }
      final migrated = decoded['migrated'] == true;
      final pendingRaw = decoded['pendingDeletes'];
      final pending = <_PendingDelete>[];
      if (pendingRaw is List) {
        for (final item in pendingRaw) {
          final parsed = _PendingDelete.tryFromJson(item);
          if (parsed != null) pending.add(parsed);
        }
      }
      return _MigrationState(migrated: migrated, pendingDeletes: pending);
    } catch (_) {
      return const _MigrationState(
        migrated: false,
        pendingDeletes: <_PendingDelete>[],
      );
    }
  }

  static Future<void> _writeMigrationState(
    File stateFile,
    _MigrationState state,
  ) async {
    final encoded = <String, Object?>{
      'version': 2,
      'migrated': state.migrated,
      'pendingDeletes': [for (final p in state.pendingDeletes) p.toJson()],
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await stateFile.writeAsString(jsonEncode(encoded), encoding: utf8);
  }

  static Future<String> _md5Hex(File file) async {
    final digest = await md5.bind(file.openRead()).first;
    return digest.toString();
  }

  static Future<String> _md5HexForPath(String path) async {
    final digest = await md5.bind(File(path).openRead()).first;
    return digest.toString();
  }

  static Future<String> _md5HexPossiblyInBackground(File file) async {
    try {
      final len = await file.length();
      if (len <= _md5VerifyMaxBytes) return _md5Hex(file);
      // Offload hashing to a background isolate for huge files.
      return compute(_md5HexForPath, file.path);
    } catch (_) {
      return _md5Hex(file);
    }
  }

  static bool _needsBackgroundFinalize(List<_PendingDelete> pendingDeletes) {
    for (final p in pendingDeletes) {
      if (p.srcMd5 == null || p.dstMd5 == null) return true;
    }
    return false;
  }

  static Future<void> _finalizeLargeDeletesInBackground(File stateFile) async {
    try {
      final state = await _readMigrationState(stateFile);
      if (state.pendingDeletes.isEmpty) return;

      var changed = false;
      final remaining = <_PendingDelete>[];
      for (final item in state.pendingDeletes) {
        // Only re-check entries that are missing hashes.
        if (item.srcMd5 != null && item.dstMd5 != null) {
          remaining.add(item);
          continue;
        }

        final next = await _tryDeletePending(item);
        if (next != null) {
          if (next != item) changed = true;
          remaining.add(next);
        } else {
          changed = true;
        }
      }

      if (!changed) return;
      final nextState = _MigrationState(
        migrated: state.migrated,
        pendingDeletes: remaining,
      );
      await _writeMigrationState(stateFile, nextState);
    } catch (_) {
      // best-effort
    }
  }

  static Future<({Directory directory, String name})?> _findLegacyIsar() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final docPath = documentsDir.path;
      final oldAppDir = p.join(docPath, _appFolderName);
      final legacyDir = p.join(docPath, _legacyAppFolderName);

      final candidates = <({String path, String name})>[
        // Old app dir in Documents.
        (path: p.join(oldAppDir, '$_isarName.isar'), name: _isarName),
        (
          path: p.join(oldAppDir, '$_legacyIsarName.isar'),
          name: _legacyIsarName,
        ),
        // Legacy branding directory.
        (
          path: p.join(legacyDir, '$_legacyIsarName.isar'),
          name: _legacyIsarName,
        ),
        (path: p.join(legacyDir, '$_isarName.isar'), name: _isarName),
        // Documents root.
        (path: p.join(docPath, '$_isarName.isar'), name: _isarName),
        (path: p.join(docPath, '$_legacyIsarName.isar'), name: _legacyIsarName),
      ];

      for (final c in candidates) {
        final f = File(c.path);
        if (await f.exists()) {
          return (directory: Directory(p.dirname(c.path)), name: c.name);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

class _MigrationResult {
  const _MigrationResult({
    required this.migrated,
    required this.pendingDeletes,
  });

  final bool migrated;
  final List<_PendingDelete> pendingDeletes;
}

class _MigrationState {
  const _MigrationState({required this.migrated, required this.pendingDeletes});

  final bool migrated;
  final List<_PendingDelete> pendingDeletes;
}

class _PendingDelete {
  const _PendingDelete({
    required this.srcPath,
    required this.dstPath,
    required this.length,
    this.srcMd5,
    this.dstMd5,
    this.srcMtimeMs,
    this.dstMtimeMs,
  });

  final String srcPath;
  final String dstPath;
  final int length;
  final String? srcMd5;
  final String? dstMd5;
  final int? srcMtimeMs;
  final int? dstMtimeMs;

  _PendingDelete copyWith({
    String? srcPath,
    String? dstPath,
    int? length,
    String? srcMd5,
    String? dstMd5,
    int? srcMtimeMs,
    int? dstMtimeMs,
  }) {
    return _PendingDelete(
      srcPath: srcPath ?? this.srcPath,
      dstPath: dstPath ?? this.dstPath,
      length: length ?? this.length,
      srcMd5: srcMd5 ?? this.srcMd5,
      dstMd5: dstMd5 ?? this.dstMd5,
      srcMtimeMs: srcMtimeMs ?? this.srcMtimeMs,
      dstMtimeMs: dstMtimeMs ?? this.dstMtimeMs,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'srcPath': srcPath,
    'dstPath': dstPath,
    'length': length,
    if (srcMd5 != null) 'srcMd5': srcMd5,
    if (dstMd5 != null) 'dstMd5': dstMd5,
    if (srcMtimeMs != null) 'srcMtimeMs': srcMtimeMs,
    if (dstMtimeMs != null) 'dstMtimeMs': dstMtimeMs,
  };

  static _PendingDelete? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final srcPath = raw['srcPath'];
    final dstPath = raw['dstPath'];
    final length = raw['length'];
    if (srcPath is! String || srcPath.trim().isEmpty) return null;
    if (dstPath is! String || dstPath.trim().isEmpty) return null;
    if (length is! num) return null;
    final srcMd5 = raw['srcMd5'];
    final dstMd5 = raw['dstMd5'];
    final srcMtimeMs = raw['srcMtimeMs'];
    final dstMtimeMs = raw['dstMtimeMs'];
    return _PendingDelete(
      srcPath: srcPath,
      dstPath: dstPath,
      length: length.toInt(),
      srcMd5: srcMd5 is String && srcMd5.trim().isNotEmpty ? srcMd5 : null,
      dstMd5: dstMd5 is String && dstMd5.trim().isNotEmpty ? dstMd5 : null,
      srcMtimeMs: srcMtimeMs is num ? srcMtimeMs.toInt() : null,
      dstMtimeMs: dstMtimeMs is num ? dstMtimeMs.toInt() : null,
    );
  }
}

class _CopyResult {
  const _CopyResult({required this.copied, required this.pendingDelete});

  final bool copied;
  final _PendingDelete? pendingDelete;
}
