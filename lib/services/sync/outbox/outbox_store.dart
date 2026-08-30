import 'dart:async';
import 'dart:io';

import '../../../utils/path_manager.dart';
import '../../logging/app_logger.dart';
import '../../persistence/durable_json_store.dart';

class OutboxReadException implements IOException {
  const OutboxReadException(this.message);

  final String message;

  @override
  String toString() => 'OutboxReadException: $message';
}

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
    String? remoteEntryKey,
    this.value,
    this.feedUrl,
    this.categoryTitle,
    String? streamId,
  }) : remoteEntryKey =
           _normalizeRemoteEntryKey(remoteEntryKey) ??
           remoteEntryId?.toString(),
       streamId = _normalizeStreamId(streamId);

  final OutboxActionType type;

  /// For entry-level actions (markRead/bookmark).
  ///
  /// Kept for legacy Miniflux/Fever outbox payloads. New remote backends should
  /// use [remoteEntryKey] because Google Reader compatible APIs use string IDs.
  final int? remoteEntryId;

  /// Provider/account-scoped remote item identity.
  ///
  /// Numeric backends store their ID here as a decimal string too, so action
  /// dedupe and replay can be string-first while preserving old integer JSON.
  final String? remoteEntryKey;

  final bool? value;

  /// For bulk actions (markAllRead).
  final String? feedUrl;
  final String? categoryTitle;
  final String? streamId;

  final DateTime createdAt;

  static OutboxAction fromJson(Map<String, Object?> json) {
    final remoteEntryId = _readLegacyRemoteEntryId(json['remoteEntryId']);
    return OutboxAction(
      type: OutboxActionTypeX.fromWire(json['type'] as String),
      remoteEntryId: remoteEntryId,
      remoteEntryKey:
          _readRemoteEntryKey(json['remoteEntryKey']) ??
          _readRemoteEntryKey(json['remoteEntryId']) ??
          remoteEntryId?.toString(),
      value: json['value'] as bool?,
      feedUrl: json['feedUrl'] as String?,
      categoryTitle: json['categoryTitle'] as String?,
      streamId: json['streamId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.wire,
    'remoteEntryKey': remoteEntryKey,
    'remoteEntryId': remoteEntryId,
    'value': value,
    'feedUrl': feedUrl,
    'categoryTitle': categoryTitle,
    'streamId': streamId,
    'createdAt': createdAt.toIso8601String(),
  };

  static int? _readLegacyRemoteEntryId(Object? value) {
    if (value is int) return value;
    if (value is num) return value.isFinite ? value.toInt() : null;
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String? _readRemoteEntryKey(Object? value) {
    if (value is! String) return null;
    return _normalizeRemoteEntryKey(value);
  }

  static String? _normalizeRemoteEntryKey(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _normalizeStreamId(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class OutboxStore {
  OutboxStore({DurableFileSystem fileSystem = const IoDurableFileSystem()})
    : _fileSystem = fileSystem;

  static final StreamController<String> _changes =
      StreamController<String>.broadcast();

  final DurableFileSystem _fileSystem;

  static Stream<String> get changes => _changes.stream;

  static void _emitChange(String accountId) {
    try {
      if (_changes.hasListener) _changes.add(accountId);
    } catch (_) {
      // Notifications are best effort and never change durable queue state.
    }
  }

  Future<List<OutboxAction>> load(String accountId) async {
    final store = await _store(accountId);
    final result = await store.runExclusive(() async {
      final snapshot = await _read(store, accountId);
      if (snapshot == null) {
        return (actions: <OutboxAction>[], compacted: false);
      }

      if (snapshot.wasRecovered) {
        _logOutboxWarning(
          'Outbox recovered',
          accountId: accountId,
          operation: 'recover',
          recoveredFrom: snapshot.source.name,
          actionCount: snapshot.value.length,
        );
      }

      final compacted = _compact(snapshot.value);
      final didCompact = compacted.length != snapshot.value.length;
      if (didCompact) {
        await _write(
          store,
          accountId,
          compacted,
          operation: 'compact',
          originalActionCount: snapshot.value.length,
        );
      }
      return (actions: compacted, compacted: didCompact);
    });
    if (result.compacted) _emitChange(accountId);
    return result.actions;
  }

  Future<void> save(String accountId, List<OutboxAction> actions) async {
    final store = await _store(accountId);
    await _write(store, accountId, actions, operation: 'save');
    _emitChange(accountId);
  }

  Future<void> enqueue(String accountId, OutboxAction action) async {
    final store = await _store(accountId);
    await store.runExclusive(() async {
      final current = (await _read(store, accountId))?.value ?? const [];
      await _write(store, accountId, <OutboxAction>[
        ...current,
        action,
      ], operation: 'enqueue');
    });
    _emitChange(accountId);
  }

  Future<void> remove(String accountId, OutboxAction action) async {
    await acknowledge(accountId, <OutboxAction>[action]);
  }

  /// Removes all durable queue snapshots for an account under the same path
  /// lock used by reads and writes.
  Future<void> clear(String accountId) async {
    final store = await _store(accountId);
    await store.deleteSnapshots();
    _emitChange(accountId);
  }

  /// Removes only the delivered actions from the latest persisted queue.
  ///
  /// Unlike replacing a previously loaded snapshot, acknowledging against the
  /// current queue preserves actions enqueued while remote delivery was in
  /// progress.
  Future<void> acknowledge(
    String accountId,
    Iterable<OutboxAction> actions,
  ) async {
    final delivered = actions.toList(growable: false);
    if (delivered.isEmpty) return;

    final store = await _store(accountId);
    final changed = await store.runExclusive(() async {
      final current = (await _read(store, accountId))?.value ?? const [];
      final next = [...current];
      for (final action in delivered) {
        final index = next.indexWhere(
          (candidate) => _sameAction(candidate, action),
        );
        if (index >= 0) next.removeAt(index);
      }
      if (next.length == current.length) return false;
      await _write(store, accountId, next, operation: 'acknowledge');
      return true;
    });
    if (changed) _emitChange(accountId);
  }

  Future<List<Map<String, Object?>>> loadQuarantined(String accountId) async {
    final file = await _quarantineFile(accountId);
    final store = DurableJsonStore<List<Map<String, Object?>>>(
      file: file,
      decode: (value) => value is List
          ? value
                .whereType<Map>()
                .map((e) => e.cast<String, Object?>())
                .toList()
          : <Map<String, Object?>>[],
      encode: (value) => value,
      fileSystem: _fileSystem,
    );
    final snapshot = await store.read();
    final now = DateTime.now();
    final kept = (snapshot?.value ?? const <Map<String, Object?>>[])
        .where((item) {
          final raw = item['quarantinedAt'];
          final date = raw is String ? DateTime.tryParse(raw) : null;
          return date != null && now.difference(date).inDays < 7;
        })
        .toList(growable: false);
    if (kept.length != (snapshot?.value.length ?? 0)) await store.write(kept);
    return kept;
  }

  Future<void> quarantine(
    String accountId,
    Iterable<OutboxAction> actions, {
    required String reason,
  }) async {
    final existing = await loadQuarantined(accountId);
    final now = DateTime.now().toIso8601String();
    final next = [
      ...existing,
      for (final action in actions)
        <String, Object?>{
          'action': action.toJson(),
          'reason': reason,
          'quarantinedAt': now,
        },
    ];
    final file = await _quarantineFile(accountId);
    final store = DurableJsonStore<List<Map<String, Object?>>>(
      file: file,
      decode: (value) => value is List
          ? value
                .whereType<Map>()
                .map((e) => e.cast<String, Object?>())
                .toList()
          : <Map<String, Object?>>[],
      encode: (value) => value,
      fileSystem: _fileSystem,
    );
    await store.write(next);
    _emitChange(accountId);
  }

  Future<void> clearQuarantined(String accountId) async {
    final file = await _quarantineFile(accountId);
    final store = DurableJsonStore<List<Map<String, Object?>>>(
      file: file,
      decode: (value) => <Map<String, Object?>>[],
      encode: (value) => value,
      fileSystem: _fileSystem,
    );
    await store.write(const []);
    _emitChange(accountId);
  }

  Future<File> _file(String accountId) async {
    final dir = await PathManager.getStateDir();
    return File('${dir.path}${Platform.pathSeparator}outbox_$accountId.json');
  }

  Future<File> _quarantineFile(String accountId) async {
    final dir = await PathManager.getStateDir();
    return File(
      '${dir.path}${Platform.pathSeparator}outbox_quarantine_$accountId.json',
    );
  }

  Future<DurableJsonStore<List<OutboxAction>>> _store(String accountId) async {
    final file = await _file(accountId);
    return DurableJsonStore<List<OutboxAction>>(
      file: file,
      decode: (decoded) => _decodeActions(accountId, decoded),
      encode: (actions) =>
          actions.map((action) => action.toJson()).toList(growable: false),
      fileSystem: _fileSystem,
    );
  }

  List<OutboxAction> _decodeActions(String accountId, Object? decoded) {
    if (decoded is! List) {
      throw const FormatException('Outbox JSON root is not a list');
    }

    final actions = <OutboxAction>[];
    var malformedEntryCount = 0;
    for (final item in decoded) {
      if (item is! Map) {
        malformedEntryCount += 1;
        continue;
      }
      try {
        actions.add(OutboxAction.fromJson(item.cast<String, Object?>()));
      } catch (_) {
        malformedEntryCount += 1;
      }
    }
    if (malformedEntryCount > 0) {
      _logOutboxWarning(
        'Outbox malformed entries detected',
        accountId: accountId,
        operation: 'load',
        actionCount: decoded.length,
        malformedEntryCount: malformedEntryCount,
      );
      throw const FormatException('Outbox contains malformed action entries');
    }
    return actions;
  }

  Future<DurableJsonSnapshot<List<OutboxAction>>?> _read(
    DurableJsonStore<List<OutboxAction>> store,
    String accountId,
  ) async {
    try {
      return await store.read();
    } on DurableJsonReadException catch (error, stackTrace) {
      _logOutboxWarning(
        'Outbox recovery failed',
        accountId: accountId,
        operation: 'recover',
        error: error,
        stackTrace: stackTrace,
        primaryExists: error.primaryExists,
        temporaryExists: error.temporaryExists,
        backupExists: error.backupExists,
      );
      Error.throwWithStackTrace(
        const OutboxReadException('no valid queue snapshot is available'),
        stackTrace,
      );
    }
  }

  Future<void> _write(
    DurableJsonStore<List<OutboxAction>> store,
    String accountId,
    List<OutboxAction> actions, {
    required String operation,
    int? originalActionCount,
  }) async {
    final compacted = _compact(actions);
    try {
      await store.write(compacted);
    } catch (error, stackTrace) {
      _logOutboxWarning(
        'Outbox write failed',
        accountId: accountId,
        operation: operation,
        actionCount: originalActionCount ?? actions.length,
        compactedCount: compacted.length,
        error: error,
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static bool _sameAction(OutboxAction a, OutboxAction b) {
    return a.type == b.type &&
        a.remoteEntryKey == b.remoteEntryKey &&
        a.remoteEntryId == b.remoteEntryId &&
        a.value == b.value &&
        a.feedUrl == b.feedUrl &&
        a.categoryTitle == b.categoryTitle &&
        a.streamId == b.streamId &&
        a.createdAt.toIso8601String() == b.createdAt.toIso8601String();
  }

  static List<OutboxAction> _compact(List<OutboxAction> actions) {
    if (actions.length <= 1) return actions;

    // Keep the last intent per scope; makes toggle-like operations safe to replay.
    final keptKeys = <String>{};
    final keptReversed = <OutboxAction>[];
    for (var i = actions.length - 1; i >= 0; i--) {
      final action = actions[i];
      final key = _dedupeKey(action);
      if (key == null) {
        keptReversed.add(action);
        continue;
      }
      if (keptKeys.add(key)) keptReversed.add(action);
    }
    return keptReversed.reversed.toList(growable: false);
  }

  static String? _dedupeKey(OutboxAction action) {
    switch (action.type) {
      case OutboxActionType.markRead:
        final id = action.remoteEntryKey ?? action.remoteEntryId?.toString();
        if (id == null) return null;
        return 'markRead:$id';
      case OutboxActionType.bookmark:
        final id = action.remoteEntryKey ?? action.remoteEntryId?.toString();
        if (id == null) return null;
        return 'bookmark:$id';
      case OutboxActionType.markAllRead:
        final streamId = (action.streamId ?? '').trim();
        final feedUrl = (action.feedUrl ?? '').trim();
        final categoryTitle = (action.categoryTitle ?? '').trim();
        return 'markAllRead:stream=$streamId:feed=$feedUrl:cat=$categoryTitle';
    }
  }

  static void _logOutboxWarning(
    String message, {
    required String accountId,
    required String operation,
    Object? error,
    StackTrace? stackTrace,
    int? actionCount,
    int? compactedCount,
    int? malformedEntryCount,
    String? recoveredFrom,
    bool? primaryExists,
    bool? temporaryExists,
    bool? backupExists,
  }) {
    AppLogger.w(
      message,
      tag: 'outbox',
      error: _safeOutboxError(error),
      stackTrace: stackTrace,
      context: <String, Object?>{
        'operation': operation,
        'accountId': accountId,
        'actionCount': actionCount,
        'compactedCount': compactedCount,
        'malformedEntryCount': malformedEntryCount,
        'recoveredFrom': recoveredFrom,
        'primaryExists': primaryExists,
        'tmpExists': temporaryExists,
        'bakExists': backupExists,
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
    if (error is DurableJsonWriteException) {
      return 'DurableJsonWriteException(stage=${error.stage.name})';
    }
    if (error is DurableJsonReadException) return 'DurableJsonReadException';
    if (error is FormatException) return 'FormatException';
    return error.runtimeType.toString();
  }
}
