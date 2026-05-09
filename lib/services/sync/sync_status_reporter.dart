// Lightweight, UI-agnostic sync status reporting.
//
// Sync implementations can optionally report their progress without depending
// on Flutter widgets or Riverpod directly. UI layers can provide a concrete
// reporter that drives an overlay/capsule, and localize [SyncStatusLabel]
// values as needed.

enum SyncStatusLabel {
  syncing,
  syncingFeeds,
  syncingSubscriptions,
  syncingUnreadArticles,
  uploadingChanges,
  completed,
  failed,
}

extension SyncStatusLabelX on SyncStatusLabel {
  bool get isTerminal =>
      this == SyncStatusLabel.completed || this == SyncStatusLabel.failed;
}

/// Sentinel used by [SyncStatusTask.update] to distinguish an omitted nullable
/// field from an explicit request to clear that field with `null`.
const Object syncStatusUnchanged = Object();

abstract class SyncStatusReporter {
  const SyncStatusReporter();

  SyncStatusTask startTask({
    required SyncStatusLabel label,
    String? detail,
    int? current,
    int? total,
  });
}

abstract class SyncStatusTask {
  const SyncStatusTask();

  void update({
    SyncStatusLabel? label,
    Object? detail = syncStatusUnchanged,
    Object? current = syncStatusUnchanged,
    Object? total = syncStatusUnchanged,
  });

  void complete({bool success = true});
}

class NoopSyncStatusReporter extends SyncStatusReporter {
  const NoopSyncStatusReporter();

  @override
  SyncStatusTask startTask({
    required SyncStatusLabel label,
    String? detail,
    int? current,
    int? total,
  }) {
    return const _NoopSyncStatusTask();
  }
}

class _NoopSyncStatusTask extends SyncStatusTask {
  const _NoopSyncStatusTask();

  @override
  void update({
    SyncStatusLabel? label,
    Object? detail = syncStatusUnchanged,
    Object? current = syncStatusUnchanged,
    Object? total = syncStatusUnchanged,
  }) {}

  @override
  void complete({bool success = true}) {}
}
