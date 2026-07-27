import 'dart:async';
import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import 'isar_account_database_driver.dart';

class AccountDbLease {
  AccountDbLease._({
    required AccountDbSessionManager manager,
    required String name,
    required this.isar,
  }) : _manager = manager,
       _name = name;

  final AccountDbSessionManager _manager;
  final String _name;
  bool _released = false;
  Future<void>? _releaseFuture;

  final Isar isar;

  Future<void> release() {
    if (_released) return Future<void>.value();
    final inFlight = _releaseFuture;
    if (inFlight != null) return inFlight;

    final release = _releaseAndMarkReleased();
    _releaseFuture = release;
    return release;
  }

  Future<void> _releaseAndMarkReleased() async {
    try {
      await _manager._release(_name);
      _released = true;
    } finally {
      _releaseFuture = null;
    }
  }
}

class AccountDbSessionManager {
  AccountDbSessionManager({
    AccountDbTargetResolver? resolveTarget,
    AccountDbTargetOpener? openTarget,
    Duration deletionWaitTimeout = const Duration(seconds: 10),
  }) : _resolveTarget = resolveTarget ?? resolveAccountDbTarget,
       _openTarget = openTarget ?? openAccountDbTarget,
       _deletionWaitTimeout = deletionWaitTimeout;

  static final AccountDbSessionManager instance = AccountDbSessionManager();

  final AccountDbTargetResolver _resolveTarget;
  final AccountDbTargetOpener _openTarget;
  final Duration _deletionWaitTimeout;
  final Map<String, _AccountDbSession> _sessions = {};
  final Map<String, AccountDbTarget> _deletionReservations = {};
  final Map<String, Completer<void>> _stateChanges = {};

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
    final key = _sessionKey(target.name);
    final existingReservation = _deletionReservations[key];
    if (existingReservation != null) {
      _ensureSameTarget(existingReservation, target);
      throw _transientFailure(
        target,
        'Database deletion is already in progress.',
      );
    }
    _deletionReservations[key] = target;

    try {
      await _waitUntilIdle(target, key);

      final dbFile = File(p.join(target.directory, '${target.name}.isar'));
      if (!await dbFile.exists()) return false;

      final isar = await _openTarget(target, AccountDbOpenMode.existing);
      await isar.close(deleteFromDisk: true);
      return true;
    } finally {
      if (identical(_deletionReservations[key], target)) {
        _deletionReservations.remove(key);
      }
    }
  }

  Future<AccountDbLease> _acquire(
    AccountDbTarget target,
    AccountDbOpenMode mode,
  ) async {
    final key = _sessionKey(target.name);
    final deletion = _deletionReservations[key];
    if (deletion != null) {
      _ensureSameTarget(deletion, target);
      throw _transientFailure(target, 'Database deletion is in progress.');
    }
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
            _notifyStateChanged(key);
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
        _notifyStateChanged(key);
      }
      rethrow;
    } finally {
      if (identical(session.opening, opening)) {
        session.opening = null;
      }
    }
  }

  Future<void> _release(String name) async {
    final key = _sessionKey(name);
    final session = _sessions[key];
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
      if (identical(_sessions[key], session)) {
        _sessions.remove(key);
        _notifyStateChanged(key);
      }
      return;
    }

    late final Future<void> closeFuture;
    closeFuture = () async {
      try {
        await isar.close();
      } catch (error, stackTrace) {
        if (identical(_sessions[key], session) &&
            identical(session.closing, closeFuture)) {
          session.closing = null;
          session.isar = isar;
          session.leases++;
        }
        Error.throwWithStackTrace(error, stackTrace);
      }

      if (identical(_sessions[key], session) &&
          identical(session.closing, closeFuture)) {
        session.closing = null;
        _sessions.remove(key);
        _notifyStateChanged(key);
      }
    }();
    session.closing = closeFuture;
    await closeFuture;
  }

  Future<void> _waitUntilIdle(AccountDbTarget target, String key) async {
    final deadline = DateTime.now().add(_deletionWaitTimeout);
    while (true) {
      final session = _sessions[key];
      if (session == null) return;
      _ensureSameTarget(session.target, target);

      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw _transientFailure(
          target,
          'Timed out waiting for database leases to release.',
        );
      }

      final changed = _stateChanges.putIfAbsent(key, Completer<void>.new);
      try {
        await changed.future.timeout(remaining);
      } on TimeoutException {
        if (identical(_stateChanges[key], changed)) {
          _stateChanges.remove(key);
        }
        throw _transientFailure(
          target,
          'Timed out waiting for database leases to release.',
        );
      }
    }
  }

  void _notifyStateChanged(String key) {
    final changed = _stateChanges.remove(key);
    if (changed != null && !changed.isCompleted) changed.complete();
  }

  DbOpenFailure _transientFailure(AccountDbTarget target, String message) {
    return DbOpenFailure(
      kind: DbOpenFailureKind.transient,
      directory: target.directory,
      name: target.name,
      error: StateError(message),
    );
  }

  String _sessionKey(String name) => name.trim();

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
