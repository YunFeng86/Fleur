import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import '../models/article.dart';
import '../models/category.dart';
import '../models/feed.dart';
import '../models/tag.dart';
import '../services/logging/app_logger.dart';
import '../utils/path_manager.dart';
import 'migrations.dart';

const String kPrimaryAccountId = 'local';

enum DbOpenFailureKind { transient, environmental }

class DbOpenFailure implements Exception {
  const DbOpenFailure({
    required this.kind,
    required this.directory,
    required this.name,
    required this.error,
  });

  final DbOpenFailureKind kind;
  final String directory;
  final String name;
  final Object error;

  @override
  String toString() {
    return 'DbOpenFailure(kind: $kind, directory: $directory, name: $name, error: $error)';
  }
}

class AccountDbTarget {
  const AccountDbTarget({
    required this.accountId,
    required this.directory,
    required this.name,
    required this.isPrimary,
  });

  final String accountId;
  final String directory;
  final String name;
  final bool isPrimary;
}

abstract interface class IsarLease {
  Isar get isar;

  Future<void> release();
}

typedef AccountDbTargetResolver =
    Future<AccountDbTarget> Function({
      required String accountId,
      String? dbName,
      required bool isPrimary,
    });

typedef AccountDbTargetOpener = Future<Isar> Function(AccountDbTarget target);
typedef PendingMigrationsRunner = Future<void> Function(Isar isar);

PendingMigrationsRunner _pendingMigrationsRunner = runPendingMigrations;

void debugSetPendingMigrationsRunnerForTests(PendingMigrationsRunner runner) {
  _pendingMigrationsRunner = runner;
}

void debugResetPendingMigrationsRunnerForTests() {
  _pendingMigrationsRunner = runPendingMigrations;
}

Future<AccountDbTarget> resolveAccountDbTarget({
  required String accountId,
  String? dbName,
  required bool isPrimary,
}) async {
  if (isPrimary) {
    final loc = await PathManager.getIsarLocation();
    return AccountDbTarget(
      accountId: accountId,
      directory: loc.directory.path,
      name: loc.name,
      isPrimary: true,
    );
  }

  final dir = await PathManager.getDbDir();
  final name = (dbName == null || dbName.trim().isEmpty)
      ? _dbNameForAccount(accountId)
      : dbName.trim();
  return AccountDbTarget(
    accountId: accountId,
    directory: dir.path,
    name: name,
    isPrimary: false,
  );
}

class AccountDbLease implements IsarLease {
  AccountDbLease._({
    required AccountDbSessionManager manager,
    required String name,
    required this.isar,
  }) : _manager = manager,
       _name = name;

  final AccountDbSessionManager _manager;
  final String _name;
  bool _released = false;

  @override
  final Isar isar;

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _manager._release(_name);
  }
}

class AccountDbSessionManager {
  AccountDbSessionManager({
    AccountDbTargetResolver? resolveTarget,
    AccountDbTargetOpener? openTarget,
  }) : _resolveTarget = resolveTarget ?? resolveAccountDbTarget,
       _openTarget = openTarget ?? _openIsarForTarget;

  static final AccountDbSessionManager instance = AccountDbSessionManager();

  final AccountDbTargetResolver _resolveTarget;
  final AccountDbTargetOpener _openTarget;
  final Map<String, _AccountDbSession> _sessions = {};

  Future<AccountDbLease> acquireForAccount({
    required String accountId,
    String? dbName,
    required bool isPrimary,
  }) async {
    final target = await _resolveTarget(
      accountId: accountId,
      dbName: dbName,
      isPrimary: isPrimary,
    );
    return _acquire(target);
  }

  Future<void> deleteIdleForAccount({
    required String accountId,
    String? dbName,
    required bool isPrimary,
  }) async {
    final target = await _resolveTarget(
      accountId: accountId,
      dbName: dbName,
      isPrimary: isPrimary,
    );
    final existing = _sessions[target.name];
    if (existing != null) {
      _ensureSameTarget(existing.target, target);
      if (existing.leases > 0 ||
          existing.opening != null ||
          existing.closing != null) {
        throw DbOpenFailure(
          kind: DbOpenFailureKind.transient,
          directory: target.directory,
          name: target.name,
          error: StateError('Database is currently in use.'),
        );
      }
      _sessions.remove(target.name);
    }

    final isar = await _openTarget(target);
    await isar.close(deleteFromDisk: true);
  }

  Future<AccountDbLease> _acquire(AccountDbTarget target) async {
    final key = target.name;
    var session = _sessions[key];
    if (session != null) {
      _ensureSameTarget(session.target, target);
      final closing = session.closing;
      if (closing != null) {
        await closing;
        return _acquire(target);
      }
      final isar = session.isar;
      if (isar != null && _isIsarOpen(isar)) {
        session.leases++;
        return AccountDbLease._(manager: this, name: key, isar: isar);
      }
      final opening = session.opening;
      if (opening != null) {
        session.leases++;
        try {
          final opened = await opening;
          return AccountDbLease._(manager: this, name: key, isar: opened);
        } catch (_) {
          session.leases--;
          if (session.leases <= 0 && identical(_sessions[key], session)) {
            _sessions.remove(key);
          }
          rethrow;
        }
      }
      _sessions.remove(key);
    }

    session = _AccountDbSession(target: target)..leases = 1;
    _sessions[key] = session;
    final opening = _openTarget(target);
    session.opening = opening;

    try {
      final isar = await opening;
      session.isar = isar;
      return AccountDbLease._(manager: this, name: key, isar: isar);
    } catch (_) {
      session.leases--;
      if (session.leases <= 0 && identical(_sessions[key], session)) {
        _sessions.remove(key);
      }
      rethrow;
    } finally {
      if (identical(session.opening, opening)) {
        session.opening = null;
      }
    }
  }

  Future<void> _release(String name) async {
    final session = _sessions[name];
    if (session == null) return;
    if (session.leases > 0) {
      session.leases--;
    }
    if (session.leases > 0) return;
    if (session.opening != null) return;
    final closing = session.closing;
    if (closing != null) {
      await closing;
      return;
    }

    final isar = session.isar;
    session.isar = null;
    if (isar == null || !_isIsarOpen(isar)) {
      if (identical(_sessions[name], session)) {
        _sessions.remove(name);
      }
      return;
    }

    late final Future<void> closeFuture;
    closeFuture = isar.close().whenComplete(() {
      if (identical(_sessions[name], session) &&
          identical(session.closing, closeFuture)) {
        session.closing = null;
        _sessions.remove(name);
      }
    });
    session.closing = closeFuture;
    await closeFuture;
  }

  void _ensureSameTarget(AccountDbTarget current, AccountDbTarget requested) {
    if (p.equals(current.directory, requested.directory)) return;
    throw DbOpenFailure(
      kind: DbOpenFailureKind.environmental,
      directory: requested.directory,
      name: requested.name,
      error: StateError(
        'Isar instance name "${requested.name}" is already held for '
        '"${current.directory}", not "${requested.directory}".',
      ),
    );
  }

  bool _isIsarOpen(Isar isar) {
    try {
      return isar.isOpen;
    } catch (_) {
      return true;
    }
  }
}

class _AccountDbSession {
  _AccountDbSession({required this.target});

  final AccountDbTarget target;
  Isar? isar;
  Future<Isar>? opening;
  Future<void>? closing;
  int leases = 0;
}

/// Open the Isar database for a given account.
///
/// - Primary account uses [PathManager.getIsarLocation] to avoid silent data
///   loss during migrations/legacy fallback.
/// - Other accounts always live under the new Support/db directory with a
///   stable per-account db name.
Future<Isar> openIsarForAccount({
  required String accountId,
  String? dbName,
  required bool isPrimary,
}) async {
  final target = await resolveAccountDbTarget(
    accountId: accountId,
    dbName: dbName,
    isPrimary: isPrimary,
  );
  return _openIsarForTarget(target);
}

Future<Isar> _openIsarForTarget(AccountDbTarget target) async {
  final schemas = [FeedSchema, ArticleSchema, CategorySchema, TagSchema];

  final isar = await _openWithBackupAndRecovery(
    schemas: schemas,
    directory: target.directory,
    name: target.name,
    accountId: target.accountId,
    isPrimary: target.isPrimary,
  );
  try {
    await _pendingMigrationsRunner(isar);
    return isar;
  } catch (e, s) {
    try {
      await isar.close();
    } catch (closeError, closeStack) {
      AppLogger.e(
        'Failed to close Isar after open finalization failure',
        tag: 'db',
        error: closeError,
        stackTrace: closeStack,
      );
    }
    Error.throwWithStackTrace(e, s);
  }
}

String _dbNameForAccount(String accountId) {
  final sanitized = accountId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  return 'fleur_$sanitized';
}

class _DbRecoveryNotice {
  const _DbRecoveryNotice({
    required this.createdAtIso,
    required this.accountId,
    required this.dbDirectory,
    required this.dbName,
    required this.originalPath,
    required this.backupPath,
    required this.movedPath,
    required this.error,
    required this.fallbackDbName,
  });

  final String createdAtIso;
  final String accountId;
  final String dbDirectory;
  final String dbName;
  final String originalPath;
  final String? backupPath;
  final String? movedPath;
  final String error;
  final String fallbackDbName;

  Map<String, Object?> toJson() => <String, Object?>{
    'createdAtIso': createdAtIso,
    'accountId': accountId,
    'dbDirectory': dbDirectory,
    'dbName': dbName,
    'originalPath': originalPath,
    'backupPath': backupPath,
    'movedPath': movedPath,
    'error': error,
    'fallbackDbName': fallbackDbName,
  };
}

String _tsForFileName(DateTime dt) {
  String two(int v) => v.toString().padLeft(2, '0');
  final y = dt.year.toString().padLeft(4, '0');
  final m = two(dt.month);
  final d = two(dt.day);
  final hh = two(dt.hour);
  final mm = two(dt.minute);
  final ss = two(dt.second);
  return '$y$m$d-$hh$mm$ss';
}

Future<File> _recoveryNoticeFile(String directory) async {
  final backupDir = Directory(p.join(directory, 'backups'));
  await backupDir.create(recursive: true);
  return File(p.join(backupDir.path, 'recovery_last.json'));
}

Future<void> _writeRecoveryNotice(
  String directory,
  _DbRecoveryNotice notice,
) async {
  try {
    final f = await _recoveryNoticeFile(directory);
    await f.writeAsString(jsonEncode(notice.toJson()));
  } catch (e, s) {
    AppLogger.e(
      'Failed to write recovery notice',
      tag: 'db',
      error: e,
      stackTrace: s,
    );
  }
}

Future<String?> _maybeBackupDbFile({
  required String directory,
  required String name,
  required bool force,
}) async {
  final src = File(p.join(directory, '$name.isar'));
  if (!await src.exists()) return null;

  final backupDir = Directory(p.join(directory, 'backups'));
  await backupDir.create(recursive: true);

  if (!force) {
    try {
      final candidates = await backupDir
          .list()
          .where((e) => e is File)
          .cast<File>()
          .where((f) => p.basename(f.path).startsWith('$name.isar.bak-'))
          .toList();
      candidates.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
      if (candidates.isNotEmpty) {
        final latest = candidates.first.statSync().modified;
        if (DateTime.now().difference(latest) < const Duration(days: 7)) {
          return null;
        }
      }
    } catch (_) {
      // ignore: best-effort backup throttling
    }
  }

  final ts = _tsForFileName(DateTime.now());
  final dest = File(p.join(backupDir.path, '$name.isar.bak-$ts'));
  try {
    await src.copy(dest.path);
    return dest.path;
  } catch (e, s) {
    AppLogger.e('DB backup failed', tag: 'db', error: e, stackTrace: s);
    return null;
  }
}

Future<String?> _moveBrokenDbFiles({
  required String directory,
  required String name,
}) async {
  final src = File(p.join(directory, '$name.isar'));
  if (!await src.exists()) return null;

  final brokenDir = Directory(p.join(directory, 'broken'));
  await brokenDir.create(recursive: true);
  final ts = _tsForFileName(DateTime.now());
  final movedPath = p.join(brokenDir.path, '$name.broken-$ts.isar');

  try {
    await src.rename(movedPath);
  } catch (_) {
    try {
      await src.copy(movedPath);
      await src.delete();
    } catch (e, s) {
      AppLogger.e(
        'Failed to move broken db file',
        tag: 'db',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  // Best-effort: also move lock file if present.
  try {
    final lock = File(p.join(directory, '$name.isar.lock'));
    if (await lock.exists()) {
      final movedLock = p.join(brokenDir.path, '$name.broken-$ts.isar.lock');
      try {
        await lock.rename(movedLock);
      } catch (_) {
        await lock.copy(movedLock);
        await lock.delete();
      }
    }
  } catch (_) {
    // ignore: best-effort lock move
  }

  return movedPath;
}

bool _containsAny(String haystack, List<String> needles) {
  for (final n in needles) {
    if (haystack.contains(n)) return true;
  }
  return false;
}

String _openErrorText(Object error) {
  if (error is IsarError) {
    return error.message;
  }
  if (error is FileSystemException) {
    final parts = <String>[
      error.message,
      error.osError?.message ?? '',
      error.path ?? '',
    ];
    return parts.where((p) => p.trim().isNotEmpty).join(' | ');
  }
  return error.toString();
}

DbOpenFailureKind? _classifyNonRecoveryOpenFailure(Object error) {
  final text = _openErrorText(error).toLowerCase();

  // File locks / concurrent opens (common during fast account switching or when
  // the app is launched twice).
  if (_containsAny(text, <String>[
    'lock',
    'locked',
    'resource busy',
    'resource temporarily unavailable',
    'device or resource busy',
    'text file busy',
    'being used by another process',
    'in use',
    'already opened',
    'already been opened',
    'another instance',
    'mdbxerror (35)',
  ])) {
    return DbOpenFailureKind.transient;
  }

  // Environment issues: recovery (moving db / opening fresh) won't help.
  if (_containsAny(text, <String>[
    'permission denied',
    'access is denied',
    'operation not permitted',
    'read-only file system',
    'no such file or directory',
    'file system exception',
    'no space left on device',
  ])) {
    return DbOpenFailureKind.environmental;
  }

  // Destructive recovery is only allowed for explicit corruption signals.
  // Unknown Isar errors must preserve the original database and fail closed.
  if (_containsAny(text, <String>[
    'corrupt',
    'checksum mismatch',
    'invalid database',
    'malformed database',
    'mdbx_corrupted',
  ])) {
    return null;
  }

  // Default: preserve user data and avoid destructive recovery.
  return DbOpenFailureKind.environmental;
}

@visibleForTesting
DbOpenFailureKind? debugClassifyDbOpenFailure(Object error) {
  return _classifyNonRecoveryOpenFailure(error);
}

Future<Isar> _openWithBackupAndRecovery({
  required List<CollectionSchema<dynamic>> schemas,
  required String directory,
  required String name,
  required String accountId,
  required bool isPrimary,
}) async {
  // 1) Auto-backup (throttled) before opening to minimize data loss risk.
  await _maybeBackupDbFile(directory: directory, name: name, force: false);

  try {
    return await Isar.open(schemas, directory: directory, name: name);
  } catch (e, s) {
    Object recoveryError = e;
    StackTrace recoveryStack = s;
    final initialKind = _classifyNonRecoveryOpenFailure(e);

    // For non-corruption failures (locks, permission, etc.), do a short backoff
    // retry before we consider any destructive recovery.
    if (initialKind != null) {
      Object lastError = e;
      StackTrace lastStack = s;
      DbOpenFailureKind? kindOrNull = initialKind;

      const delays = <Duration>[
        Duration(milliseconds: 120),
        Duration(milliseconds: 240),
        Duration(milliseconds: 480),
        Duration(milliseconds: 960),
      ];

      for (var i = 0; i < delays.length; i++) {
        await Future<void>.delayed(delays[i]);
        try {
          final isar = await Isar.open(
            schemas,
            directory: directory,
            name: name,
          );
          AppLogger.i('Isar open succeeded after retry #${i + 1}', tag: 'db');
          return isar;
        } catch (e2, s2) {
          lastError = e2;
          lastStack = s2;
          kindOrNull = _classifyNonRecoveryOpenFailure(e2);
          if (kindOrNull == null) {
            // Escalate to recovery for a DB-level failure.
            recoveryError = e2;
            recoveryStack = s2;
            break;
          }
        }
      }

      if (kindOrNull != null) {
        AppLogger.e(
          'Failed to open Isar DB (non-recoverable)',
          tag: 'db',
          error: lastError,
          stackTrace: lastStack,
        );
        throw DbOpenFailure(
          kind: kindOrNull,
          directory: directory,
          name: name,
          error: lastError,
        );
      }
    }

    AppLogger.e(
      'Failed to open Isar DB; attempting recovery',
      tag: 'db',
      error: recoveryError,
      stackTrace: recoveryStack,
    );

    final originalPath = p.join(directory, '$name.isar');
    final backupPath = await _maybeBackupDbFile(
      directory: directory,
      name: name,
      force: true,
    );
    final movedPath = await _moveBrokenDbFiles(
      directory: directory,
      name: name,
    );

    var fallbackName = name;
    try {
      // If we successfully moved the broken file away, we can re-open using the
      // original stable name.
      if (movedPath != null) {
        final isar = await Isar.open(schemas, directory: directory, name: name);
        await _writeRecoveryNotice(
          directory,
          _DbRecoveryNotice(
            createdAtIso: DateTime.now().toIso8601String(),
            accountId: accountId,
            dbDirectory: directory,
            dbName: name,
            originalPath: originalPath,
            backupPath: backupPath,
            movedPath: movedPath,
            error: recoveryError.toString(),
            fallbackDbName: fallbackName,
          ),
        );
        return isar;
      }
    } catch (e2, s2) {
      AppLogger.e(
        'Recovery open (stable name) failed',
        tag: 'db',
        error: e2,
        stackTrace: s2,
      );
    }

    // Last-resort: open a fresh DB under a new name to avoid a boot loop.
    final ts = _tsForFileName(DateTime.now());
    fallbackName = '${name}_fresh_$ts';
    final isar = await Isar.open(
      schemas,
      directory: directory,
      name: fallbackName,
    );
    await _writeRecoveryNotice(
      directory,
      _DbRecoveryNotice(
        createdAtIso: DateTime.now().toIso8601String(),
        accountId: accountId,
        dbDirectory: directory,
        dbName: name,
        originalPath: originalPath,
        backupPath: backupPath,
        movedPath: movedPath,
        error: recoveryError.toString(),
        fallbackDbName: fallbackName,
      ),
    );

    // On primary DB, prefer failing loudly in logs; UI will also show the notice.
    if (isPrimary) {
      AppLogger.w(
        'Primary DB opened with fallback name: $fallbackName',
        tag: 'db',
      );
    }

    return isar;
  }
}
