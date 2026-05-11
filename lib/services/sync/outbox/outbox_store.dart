import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../logging/app_logger.dart';
import '../../../utils/path_manager.dart';
import '../sync_mutex.dart';

typedef _OutboxJsonRead = ({
  List<Object?>? decoded,
  bool existed,
  Object? error,
  StackTrace? stackTrace,
});

enum OutboxActionType { markRead, bookmark, markAllRead }

extension OutboxActionTypeX on OutboxActionType {
  String get wire => switch (this) {
    OutboxActionType.markRead => 'markRead',
    OutboxActionType.bookmark => 'bookmark',
    OutboxActionType.markAllRead => 'markAllRead',
  };

  static OutboxActionType fromWire(String wire) {
    switch (wire) {
      case 'markRead':
        return OutboxActionType.markRead;
      case 'bookmark':
        return OutboxActionType.bookmark;
      case 'markAllRead':
        return OutboxActionType.markAllRead;
      default:
        throw ArgumentError('Unknown outbox action: $wire');
    }
  }
}

class OutboxAction {
  OutboxAction({
    required this.type,
    required this.createdAt,
    this.remoteEntryId,
    this.value,
    this.feedUrl,
    this.categoryTitle,
  });

  final OutboxActionType type;

  /// For entry-level actions (markRead/bookmark).
  final int? remoteEntryId;
  final bool? value;

  /// For bulk actions (markAllRead).
  final String? feedUrl;
  final String? categoryTitle;

  final DateTime createdAt;

  static OutboxAction fromJson(Map<String, Object?> json) {
    return OutboxAction(
      type: OutboxActionTypeX.fromWire(json['type'] as String),
      remoteEntryId: json['remoteEntryId'] as int?,
      value: json['value'] as bool?,
      feedUrl: json['feedUrl'] as String?,
      categoryTitle: json['categoryTitle'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.wire,
    'remoteEntryId': remoteEntryId,
    'value': value,
    'feedUrl': feedUrl,
    'categoryTitle': categoryTitle,
    'createdAt': createdAt.toIso8601String(),
  };
}

class OutboxStore {
  static final StreamController<String> _changes =
      StreamController<String>.broadcast();

  static Stream<String> get changes => _changes.stream;

  static void _emitChange(String accountId) {
    try {
      if (_changes.hasListener) _changes.add(accountId);
    } catch (_) {
      // ignore: best-effort notify
    }
  }

  Future<List<OutboxAction>> load(String accountId) async {
    return SyncMutex.instance.run('outbox:$accountId', () async {
      final f = await _file(accountId);
      final tmp = _tmpFile(f);
      final bak = _bakFile(f);

      try {
        final decoded = await _readJsonListOrRecover(
          accountId: accountId,
          primary: f,
          tmp: tmp,
          bak: bak,
        );
        if (decoded == null) return const [];
        final out = <OutboxAction>[];
        var malformedEntryCount = 0;
        for (final item in decoded) {
          if (item is! Map) {
            malformedEntryCount += 1;
            continue;
          }
          try {
            out.add(OutboxAction.fromJson(item.cast<String, Object?>()));
          } catch (_) {
            malformedEntryCount += 1;
            // Skip malformed entries; keep the rest of the queue.
          }
        }
        if (malformedEntryCount > 0) {
          _logOutboxWarning(
            'Outbox malformed entries skipped',
            accountId: accountId,
            operation: 'load',
            actionCount: decoded.length,
            malformedEntryCount: malformedEntryCount,
          );
        }
        // Auto-compact legacy/duplicated actions.
        final compacted = _compact(out);
        if (compacted.length != out.length || await tmp.exists()) {
          try {
            await save(accountId, compacted);
          } catch (e, st) {
            _logOutboxWarning(
              'Outbox compact save failed',
              accountId: accountId,
              operation: 'compact',
              actionCount: out.length,
              compactedCount: compacted.length,
              error: e,
              stackTrace: st,
            );
            // ignore: best-effort cleanup
          }
        }
        try {
          if (await tmp.exists()) await tmp.delete();
        } catch (_) {
          // ignore: best-effort cleanup
        }
        return compacted;
      } catch (e, st) {
        _logOutboxWarning(
          'Outbox load failed',
          accountId: accountId,
          operation: 'load',
          error: e,
          stackTrace: st,
        );
        return const [];
      }
    });
  }

  Future<void> save(String accountId, List<OutboxAction> actions) async {
    await SyncMutex.instance.run('outbox:$accountId', () async {
      final f = await _file(accountId);
      final compacted = _compact(actions);
      final payload = compacted.map((a) => a.toJson()).toList(growable: false);
      await _writeJsonAtomically(
        f,
        jsonEncode(payload),
        accountId: accountId,
        actionCount: actions.length,
        compactedCount: compacted.length,
      );
    });
    _emitChange(accountId);
  }

  Future<void> enqueue(String accountId, OutboxAction action) async {
    await SyncMutex.instance.run('outbox:$accountId', () async {
      final cur = await load(accountId);
      final next = [...cur, action];
      await save(accountId, next);
    });
  }

  Future<void> remove(String accountId, OutboxAction action) async {
    await SyncMutex.instance.run('outbox:$accountId', () async {
      final cur = await load(accountId);
      final next = [...cur];
      final idx = next.indexWhere((a) => _sameAction(a, action));
      if (idx < 0) return;
      next.removeAt(idx);
      await save(accountId, next);
    });
  }

  Future<File> _file(String accountId) async {
    final dir = await PathManager.getStateDir();
    return File('${dir.path}${Platform.pathSeparator}outbox_$accountId.json');
  }

  File _tmpFile(File primary) => File('${primary.path}.tmp');
  File _bakFile(File primary) => File('${primary.path}.bak');

  Future<List<Object?>?> _readJsonListOrRecover({
    required String accountId,
    required File primary,
    required File tmp,
    required File bak,
  }) async {
    // Prefer the primary file when it's valid.
    final primaryRead = await _tryReadJsonList(primary);
    if (primaryRead.decoded != null) return primaryRead.decoded;

    // Crash safety: if an atomic write was interrupted, `.tmp` may contain the
    // new full payload; `.bak` may contain the previous valid payload.
    final tmpRead = await _tryReadJsonList(tmp);
    final tmpRecovery = await _recoverDecodedJson(
      accountId: accountId,
      primary: primary,
      sourceRead: tmpRead,
      recoveredFrom: 'tmp',
      primaryExists: primaryRead.existed,
      tmpExists: tmpRead.existed,
      bakExists: await bak.exists(),
    );
    if (tmpRecovery != null) return tmpRecovery;

    final bakRead = await _tryReadJsonList(bak);
    final bakRecovery = await _recoverDecodedJson(
      accountId: accountId,
      primary: primary,
      sourceRead: bakRead,
      recoveredFrom: 'bak',
      primaryExists: primaryRead.existed,
      tmpExists: tmpRead.existed,
      bakExists: bakRead.existed,
    );
    if (bakRecovery != null) return bakRecovery;

    final anyFileExists =
        primaryRead.existed || tmpRead.existed || bakRead.existed;
    if (anyFileExists) {
      final error = primaryRead.error ?? tmpRead.error ?? bakRead.error;
      final stackTrace =
          primaryRead.stackTrace ?? tmpRead.stackTrace ?? bakRead.stackTrace;
      _logOutboxWarning(
        'Outbox recovery failed',
        accountId: accountId,
        operation: 'recover',
        primaryExists: primaryRead.existed,
        tmpExists: tmpRead.existed,
        bakExists: bakRead.existed,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return null;
  }

  Future<_OutboxJsonRead> _tryReadJsonList(File file) async {
    try {
      if (!await file.exists()) {
        return (decoded: null, existed: false, error: null, stackTrace: null);
      }
      final raw = await file.readAsString(encoding: utf8);
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return (
          decoded: null,
          existed: true,
          error: StateError('Outbox JSON root is not a list'),
          stackTrace: null,
        );
      }
      return (
        decoded: decoded.cast<Object?>(),
        existed: true,
        error: null,
        stackTrace: null,
      );
    } catch (e, st) {
      return (decoded: null, existed: true, error: e, stackTrace: st);
    }
  }

  Future<List<Object?>?> _recoverDecodedJson({
    required String accountId,
    required File primary,
    required _OutboxJsonRead sourceRead,
    required String recoveredFrom,
    required bool primaryExists,
    required bool tmpExists,
    required bool bakExists,
  }) async {
    final decoded = sourceRead.decoded;
    if (decoded == null) return null;

    try {
      await _writeJsonAtomically(
        primary,
        jsonEncode(decoded),
        accountId: accountId,
        actionCount: decoded.length,
        compactedCount: decoded.length,
        operation: 'recover',
      );
    } catch (e, st) {
      _logOutboxWarning(
        'Outbox recovery write failed',
        accountId: accountId,
        operation: 'recover',
        recoveredFrom: recoveredFrom,
        primaryExists: primaryExists,
        tmpExists: tmpExists,
        bakExists: bakExists,
        error: e,
        stackTrace: st,
      );
      // ignore: best-effort recovery
    }
    return decoded;
  }

  Future<void> _writeJsonAtomically(
    File primary,
    String contents, {
    required String accountId,
    int? actionCount,
    int? compactedCount,
    String operation = 'write',
  }) async {
    final tmp = _tmpFile(primary);
    final bak = _bakFile(primary);

    try {
      await tmp.writeAsString(contents, encoding: utf8);
    } catch (e, st) {
      _logOutboxWarning(
        'Outbox temp write failed',
        accountId: accountId,
        operation: operation,
        pathKind: 'tmp',
        actionCount: actionCount,
        compactedCount: compactedCount,
        error: e,
        stackTrace: st,
      );
      // If we can't write a temp file, fall back to a best-effort direct write.
      try {
        await primary.writeAsString(contents, encoding: utf8);
      } catch (e, st) {
        _logOutboxWarning(
          'Outbox direct write failed',
          accountId: accountId,
          operation: 'directWrite',
          pathKind: 'primary',
          actionCount: actionCount,
          compactedCount: compactedCount,
          error: e,
          stackTrace: st,
        );
        // ignore: best-effort write
      }
      return;
    }

    // Rotate the previous file to `.bak` so a crash during replace can recover.
    // Keep `.bak` as the last known-good payload (rotated on each successful write).
    var backedUp = false;
    try {
      if (await primary.exists()) {
        try {
          if (await bak.exists()) await bak.delete();
        } catch (e, st) {
          _logOutboxWarning(
            'Outbox backup cleanup failed',
            accountId: accountId,
            operation: 'deleteBackup',
            pathKind: 'bak',
            actionCount: actionCount,
            compactedCount: compactedCount,
            error: e,
            stackTrace: st,
          );
          // ignore: best-effort cleanup
        }

        try {
          await primary.rename(bak.path);
          backedUp = true;
        } catch (renameError, renameStackTrace) {
          // Best-effort fallback when rename is not possible (e.g. file lock).
          try {
            await primary.copy(bak.path);
            backedUp = true;
          } catch (copyError, copyStackTrace) {
            _logOutboxWarning(
              'Outbox backup failed',
              accountId: accountId,
              operation: 'backup',
              pathKind: 'bak',
              actionCount: actionCount,
              compactedCount: compactedCount,
              error: copyError,
              stackTrace: copyStackTrace,
            );
            _logOutboxWarning(
              'Outbox backup rename failed',
              accountId: accountId,
              operation: 'backupRename',
              pathKind: 'primary',
              actionCount: actionCount,
              compactedCount: compactedCount,
              error: renameError,
              stackTrace: renameStackTrace,
            );
            // ignore: best-effort backup
          }
        }
      }
    } catch (e, st) {
      _logOutboxWarning(
        'Outbox backup phase failed',
        accountId: accountId,
        operation: 'backup',
        actionCount: actionCount,
        compactedCount: compactedCount,
        error: e,
        stackTrace: st,
      );
      // ignore: best-effort backup
    }

    var replaced = false;
    try {
      await tmp.rename(primary.path);
      replaced = true;
    } catch (e, st) {
      _logOutboxWarning(
        'Outbox replace failed',
        accountId: accountId,
        operation: 'replace',
        pathKind: 'tmp',
        actionCount: actionCount,
        compactedCount: compactedCount,
        error: e,
        stackTrace: st,
      );
      // If the primary still exists (e.g. couldn't be renamed to `.bak`), only
      // delete it if we have a backup already.
      if (await primary.exists() && backedUp) {
        try {
          await primary.delete();
        } catch (e, st) {
          _logOutboxWarning(
            'Outbox primary delete failed',
            accountId: accountId,
            operation: 'deletePrimary',
            pathKind: 'primary',
            actionCount: actionCount,
            compactedCount: compactedCount,
            error: e,
            stackTrace: st,
          );
          // ignore: best-effort delete
        }
        try {
          await tmp.rename(primary.path);
          replaced = true;
        } catch (e, st) {
          _logOutboxWarning(
            'Outbox replace after delete failed',
            accountId: accountId,
            operation: 'replace',
            pathKind: 'tmp',
            actionCount: actionCount,
            compactedCount: compactedCount,
            error: e,
            stackTrace: st,
          );
          // fall through
        }
      }

      // Fall back to a direct write; leave `.tmp` for recovery on next load if that fails.
      if (!replaced) {
        try {
          await primary.writeAsString(contents, encoding: utf8);
          replaced = true;
        } catch (e, st) {
          _logOutboxWarning(
            'Outbox direct write failed',
            accountId: accountId,
            operation: 'directWrite',
            pathKind: 'primary',
            actionCount: actionCount,
            compactedCount: compactedCount,
            error: e,
            stackTrace: st,
          );
          // ignore: best-effort write
        }
      }
      if (replaced) {
        try {
          await tmp.delete();
        } catch (_) {
          // ignore: best-effort cleanup
        }
      }
    }

    // Keep `.bak` to allow recovery from a corrupted primary.
  }

  static bool _sameAction(OutboxAction a, OutboxAction b) {
    return a.type == b.type &&
        a.remoteEntryId == b.remoteEntryId &&
        a.value == b.value &&
        a.feedUrl == b.feedUrl &&
        a.categoryTitle == b.categoryTitle &&
        a.createdAt.toIso8601String() == b.createdAt.toIso8601String();
  }

  static List<OutboxAction> _compact(List<OutboxAction> actions) {
    if (actions.length <= 1) return actions;

    // Keep the last intent per scope; makes toggle-like operations safe to replay.
    final keptKeys = <String>{};
    final keptReversed = <OutboxAction>[];
    for (var i = actions.length - 1; i >= 0; i--) {
      final a = actions[i];
      final key = _dedupeKey(a);
      if (key == null) {
        keptReversed.add(a);
        continue;
      }
      if (keptKeys.add(key)) {
        keptReversed.add(a);
      }
    }
    return keptReversed.reversed.toList(growable: false);
  }

  static String? _dedupeKey(OutboxAction a) {
    switch (a.type) {
      case OutboxActionType.markRead:
        final id = a.remoteEntryId;
        if (id == null) return null;
        return 'markRead:$id';
      case OutboxActionType.bookmark:
        final id = a.remoteEntryId;
        if (id == null) return null;
        return 'bookmark:$id';
      case OutboxActionType.markAllRead:
        final feedUrl = (a.feedUrl ?? '').trim();
        final categoryTitle = (a.categoryTitle ?? '').trim();
        // Empty values represent "all feeds" scope.
        return 'markAllRead:feed=$feedUrl:cat=$categoryTitle';
    }
  }

  static void _logOutboxWarning(
    String message, {
    required String accountId,
    required String operation,
    Object? error,
    StackTrace? stackTrace,
    String? pathKind,
    int? actionCount,
    int? compactedCount,
    int? malformedEntryCount,
    bool? primaryExists,
    bool? tmpExists,
    bool? bakExists,
    String? recoveredFrom,
  }) {
    AppLogger.w(
      message,
      tag: 'outbox',
      error: _safeOutboxError(error),
      stackTrace: stackTrace,
      context: <String, Object?>{
        'operation': operation,
        'accountId': accountId,
        'pathKind': pathKind,
        'actionCount': actionCount,
        'compactedCount': compactedCount,
        'malformedEntryCount': malformedEntryCount,
        'primaryExists': primaryExists,
        'tmpExists': tmpExists,
        'bakExists': bakExists,
        'recoveredFrom': recoveredFrom,
      },
    );
  }

  static String? _safeOutboxError(Object? error) {
    if (error == null) return null;
    if (error is FileSystemException) {
      final code = error.osError?.errorCode;
      if (code != null) return 'FileSystemException(osErrorCode=$code)';
      return 'FileSystemException';
    }
    if (error is FormatException) return 'FormatException';
    return error.runtimeType.toString();
  }
}
