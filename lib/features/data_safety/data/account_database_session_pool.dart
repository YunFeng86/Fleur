import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import 'isar_account_database_driver.dart';

abstract interface class IsarLease {
  Isar get isar;

  Future<void> release();
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
       _openTarget = openTarget ?? openAccountDbTarget;

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
