import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sync/sync_status_reporter.dart';

enum SyncStatusKind { hidden, running, completed }

@immutable
class SyncStatusState {
  const SyncStatusState({
    required this.kind,
    required this.label,
    required this.revision,
    this.detail,
    this.current,
    this.total,
  });

  const SyncStatusState.hidden()
    : kind = SyncStatusKind.hidden,
      label = SyncStatusLabel.syncing,
      detail = null,
      current = null,
      total = null,
      revision = 0;

  final SyncStatusKind kind;
  final SyncStatusLabel label;
  final String? detail;
  final int? current;
  final int? total;

  /// Bumps only when the stage text (label/detail) changes, so UI can animate
  /// stage switches without reacting to every progress tick.
  final int revision;

  bool get visible => kind != SyncStatusKind.hidden;
  bool get running => kind == SyncStatusKind.running;
  bool get completed => kind == SyncStatusKind.completed;
}

class SyncStatusController extends Notifier<SyncStatusState> {
  final Map<int, _TaskData> _tasks = <int, _TaskData>{};
  final List<int> _order = <int>[];
  Timer? _hideTimer;
  int _nextId = 1;

  @override
  SyncStatusState build() {
    ref.onDispose(() {
      _hideTimer?.cancel();
    });
    return const SyncStatusState.hidden();
  }

  int _createTask(_TaskData data) {
    _hideTimer?.cancel();
    _hideTimer = null;

    final id = _nextId++;
    _tasks[id] = data;
    _order.add(id);

    _emitActive(bumpRevision: true);
    return id;
  }

  void _updateTask(int id, _TaskData next) {
    final prev = _tasks[id];
    if (prev == null) return;
    _tasks[id] = next;
    final isActive = _order.isNotEmpty && _order.last == id;
    if (!isActive) return;

    final bump =
        next.label != state.label ||
        next.detail != state.detail ||
        state.kind != SyncStatusKind.running;
    _emitFrom(next, bumpRevision: bump);
  }

  void _completeTask(int id, {required bool success}) {
    _tasks.remove(id);
    _order.remove(id);

    if (_order.isNotEmpty) {
      _emitActive(bumpRevision: true);
      return;
    }

    // No more tasks: show a terminal message for a short time, then hide.
    final nextLabel = success
        ? SyncStatusLabel.completed
        : SyncStatusLabel.failed;
    final bump =
        state.label != nextLabel || state.kind != SyncStatusKind.completed;
    state = SyncStatusState(
      kind: SyncStatusKind.completed,
      label: nextLabel,
      detail: null,
      current: null,
      total: null,
      revision: bump ? state.revision + 1 : state.revision,
    );

    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      // Guard: if a new task started, do not hide.
      if (_order.isNotEmpty) return;
      state = const SyncStatusState.hidden();
    });
  }

  void _emitActive({required bool bumpRevision}) {
    if (_order.isEmpty) return;
    final active = _tasks[_order.last];
    if (active == null) return;
    _emitFrom(active, bumpRevision: bumpRevision);
  }

  void _emitFrom(_TaskData data, {required bool bumpRevision}) {
    state = SyncStatusState(
      kind: SyncStatusKind.running,
      label: data.label,
      detail: data.detail,
      current: data.current,
      total: data.total,
      revision: bumpRevision ? state.revision + 1 : state.revision,
    );
  }
}

class _TaskData {
  const _TaskData({required this.label, this.detail, this.current, this.total});

  final SyncStatusLabel label;
  final String? detail;
  final int? current;
  final int? total;

  _TaskData copyWith({
    SyncStatusLabel? label,
    Object? detail = syncStatusUnchanged,
    Object? current = syncStatusUnchanged,
    Object? total = syncStatusUnchanged,
  }) {
    return _TaskData(
      label: label ?? this.label,
      detail: _resolveNullableField<String>(detail, this.detail),
      current: _resolveNullableField<int>(current, this.current),
      total: _resolveNullableField<int>(total, this.total),
    );
  }
}

T? _resolveNullableField<T>(Object? value, T? previous) {
  if (identical(value, syncStatusUnchanged)) return previous;
  return value as T?;
}

final syncStatusControllerProvider =
    NotifierProvider<SyncStatusController, SyncStatusState>(
      SyncStatusController.new,
    );

final syncStatusReporterProvider = Provider<SyncStatusReporter>((ref) {
  final controller = ref.watch(syncStatusControllerProvider.notifier);
  return _RiverpodSyncStatusReporter(controller);
});

class _RiverpodSyncStatusReporter extends SyncStatusReporter {
  const _RiverpodSyncStatusReporter(this._controller);

  final SyncStatusController _controller;

  @override
  SyncStatusTask startTask({
    required SyncStatusLabel label,
    String? detail,
    int? current,
    int? total,
  }) {
    final id = _controller._createTask(
      _TaskData(label: label, detail: detail, current: current, total: total),
    );
    return _RiverpodSyncStatusTask(_controller, id);
  }
}

class _RiverpodSyncStatusTask extends SyncStatusTask {
  const _RiverpodSyncStatusTask(this._controller, this._id);

  final SyncStatusController _controller;
  final int _id;

  @override
  void update({
    SyncStatusLabel? label,
    Object? detail = syncStatusUnchanged,
    Object? current = syncStatusUnchanged,
    Object? total = syncStatusUnchanged,
  }) {
    final prev = _controller._tasks[_id];
    if (prev == null) return;
    _controller._updateTask(
      _id,
      prev.copyWith(
        label: label,
        detail: detail,
        current: current,
        total: total,
      ),
    );
  }

  @override
  void complete({bool success = true}) {
    _controller._completeTask(_id, success: success);
  }
}
