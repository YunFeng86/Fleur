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

enum DbOpenFailureKind {
  transient,
  environmental,
  recoveryRequired,
  dataMissing,
  ownershipMismatch,
}

enum AccountDbOpenMode { existing, initialize }

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

typedef AccountDbTargetOpener =
    Future<Isar> Function(AccountDbTarget target, AccountDbOpenMode mode);
typedef PendingMigrationsRunner = Future<void> Function(Isar isar);
typedef IsarOpenFn =
    Future<Isar> Function(
      List<CollectionSchema<dynamic>> schemas, {
      required String directory,
      required String name,
    });

PendingMigrationsRunner _pendingMigrationsRunner = runPendingMigrations;
IsarOpenFn _isarOpen = Isar.open;

void debugSetPendingMigrationsRunnerForTests(PendingMigrationsRunner runner) {
  _pendingMigrationsRunner = runner;
}

void debugResetPendingMigrationsRunnerForTests() {
  _pendingMigrationsRunner = runPendingMigrations;
}

@visibleForTesting
void debugSetIsarOpenForTests(IsarOpenFn opener) {
  _isarOpen = opener;
}

@visibleForTesting
void debugResetIsarOpenForTests() {
  _isarOpen = Isar.open;
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

  Future<AccountDbLease> acquireExistingForAccount({
    required String accountId,
    String? dbName,
    required bool isPrimary,
  }) async {
    final target = await _resolveTarget(
      accountId: accountId,
      dbName: dbName,
      isPrimary: isPrimary,
    );
    return _acquire(target, AccountDbOpenMode.existing);
  }

  Future<AccountDbLease> initializeForAccount({
    required String accountId,
    String? dbName,
    required bool isPrimary,
  }) async {
    final target = await _resolveTarget(
      accountId: accountId,
      dbName: dbName,
      isPrimary: isPrimary,
    );
    return _acquire(target, AccountDbOpenMode.initialize);
  }

  Future<bool> deleteIdleForAccount({
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

    final dbFile = File(p.join(target.directory, '${target.name}.isar'));
    if (!await dbFile.exists()) return false;

    final isar = await _openTarget(target, AccountDbOpenMode.existing);
    await isar.close(deleteFromDisk: true);
    return true;
  }

  Future<AccountDbLease> _acquire(
    AccountDbTarget target,
    AccountDbOpenMode mode,
  ) async {
    final key = target.name;
    var session = _sessions[key];
    if (session != null) {
      _ensureSameTarget(session.target, target);
      final closing = session.closing;
      if (closing != null) {
        await closing;
        return _acquire(target, mode);
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
    final opening = _openTarget(target, mode);
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
    if (current.accountId == requested.accountId &&
        current.name == requested.name &&
        current.isPrimary == requested.isPrimary &&
        p.equals(current.directory, requested.directory)) {
      return;
    }
    throw DbOpenFailure(
      kind: DbOpenFailureKind.ownershipMismatch,
      directory: requested.directory,
      name: requested.name,
      error: StateError(
        'Database target "${requested.name}" is already owned by account '
        '"${current.accountId}" at "${current.directory}".',
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
Future<Isar> openExistingIsarForAccount({
  required String accountId,
  String? dbName,
  required bool isPrimary,
}) async {
  final target = await resolveAccountDbTarget(
    accountId: accountId,
    dbName: dbName,
    isPrimary: isPrimary,
  );
  return _openIsarForTarget(target, AccountDbOpenMode.existing);
}

Future<Isar> initializeIsarForAccount({
  required String accountId,
  String? dbName,
  required bool isPrimary,
}) async {
  final target = await resolveAccountDbTarget(
    accountId: accountId,
    dbName: dbName,
    isPrimary: isPrimary,
  );
  return _openIsarForTarget(target, AccountDbOpenMode.initialize);
}

Future<Isar> _openIsarForTarget(
  AccountDbTarget target,
  AccountDbOpenMode mode,
) async {
  final schemas = [FeedSchema, ArticleSchema, CategorySchema, TagSchema];

  if (mode == AccountDbOpenMode.existing) {
    final dbFile = File(p.join(target.directory, '${target.name}.isar'));
    if (!await dbFile.exists()) {
      throw DbOpenFailure(
        kind: DbOpenFailureKind.dataMissing,
        directory: target.directory,
        name: target.name,
        error: StateError('Existing account database is missing.'),
      );
    }
  }

  final isar = await _openPreservingAccountData(
    schemas: schemas,
    directory: target.directory,
    name: target.name,
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

DbOpenFailureKind _classifyOpenFailure(Object error) {
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

  // Corruption requires an explicit recovery workflow. Opening never mutates
  // or replaces the original account data.
  if (_containsAny(text, <String>[
    'corrupt',
    'checksum mismatch',
    'invalid database',
    'malformed database',
    'mdbx_corrupted',
  ])) {
    return DbOpenFailureKind.recoveryRequired;
  }

  // Default: preserve user data and avoid destructive recovery.
  return DbOpenFailureKind.environmental;
}

@visibleForTesting
DbOpenFailureKind debugClassifyDbOpenFailure(Object error) {
  return _classifyOpenFailure(error);
}

Future<Isar> _openPreservingAccountData({
  required List<CollectionSchema<dynamic>> schemas,
  required String directory,
  required String name,
}) async {
  try {
    return await _isarOpen(schemas, directory: directory, name: name);
  } catch (e, s) {
    var lastError = e;
    var lastStack = s;
    var kind = _classifyOpenFailure(e);

    if (kind == DbOpenFailureKind.transient) {
      const delays = <Duration>[
        Duration(milliseconds: 120),
        Duration(milliseconds: 240),
        Duration(milliseconds: 480),
        Duration(milliseconds: 960),
      ];

      for (var i = 0; i < delays.length; i++) {
        await Future<void>.delayed(delays[i]);
        try {
          final isar = await _isarOpen(
            schemas,
            directory: directory,
            name: name,
          );
          AppLogger.i('Isar open succeeded after retry #${i + 1}', tag: 'db');
          return isar;
        } catch (retryError, retryStack) {
          lastError = retryError;
          lastStack = retryStack;
          kind = _classifyOpenFailure(retryError);
          if (kind != DbOpenFailureKind.transient) break;
        }
      }
    }

    AppLogger.e(
      'Failed to open Isar DB; preserving account data',
      tag: 'db',
      error: lastError,
      stackTrace: lastStack,
    );
    throw DbOpenFailure(
      kind: kind,
      directory: directory,
      name: name,
      error: lastError,
    );
  }
}
