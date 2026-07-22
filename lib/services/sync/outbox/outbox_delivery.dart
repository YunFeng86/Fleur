import '../sync_mutex.dart';
import 'outbox_store.dart';

typedef OutboxActionApplier = Future<bool> Function(OutboxAction action);
typedef OutboxActionErrorHandler =
    void Function(OutboxAction action, Object error, StackTrace stackTrace);

class OutboxBatching {
  const OutboxBatching({
    required this.maxSize,
    required this.isBatchable,
    required this.isCompatible,
    required this.apply,
  }) : assert(maxSize > 0);

  final int maxSize;
  final bool Function(OutboxAction action) isBatchable;
  final bool Function(OutboxAction first, OutboxAction next) isCompatible;
  final Future<bool> Function(List<OutboxAction> actions) apply;
}

/// Delivers a stable outbox snapshot and acknowledges successful actions
/// against the latest persisted queue.
///
/// Remote calls intentionally run without the store lock, so UI actions can be
/// enqueued while a slow flush is in progress. [OutboxStore.acknowledge] merges
/// successful delivery into the latest queue instead of saving the old
/// snapshot over newly queued intents.
class OutboxDelivery {
  const OutboxDelivery(this._store);

  final OutboxStore _store;

  Future<void> flush({
    required String accountId,
    required OutboxActionApplier apply,
    OutboxActionErrorHandler? onActionError,
    OutboxBatching? batching,
  }) {
    return SyncMutex.instance.run('outbox-delivery:$accountId', () async {
      final pending = await _store.load(accountId);
      if (pending.isEmpty) return;

      final delivered = <OutboxAction>[];
      var index = 0;
      while (index < pending.length) {
        final action = pending[index];
        final batch = _compatibleBatch(pending, index, batching);
        if (batch != null) {
          if (await _tryApplyBatch(batch, batching!)) {
            delivered.addAll(batch);
          } else {
            for (final item in batch) {
              await _tryApply(item, apply, delivered, onActionError);
            }
          }
          index += batch.length;
          continue;
        }

        await _tryApply(action, apply, delivered, onActionError);
        index += 1;
      }

      await _store.acknowledge(accountId, delivered);
    });
  }

  static List<OutboxAction>? _compatibleBatch(
    List<OutboxAction> pending,
    int start,
    OutboxBatching? batching,
  ) {
    if (batching == null || !batching.isBatchable(pending[start])) return null;

    final first = pending[start];
    final batch = <OutboxAction>[first];
    var index = start + 1;
    while (index < pending.length &&
        batch.length < batching.maxSize &&
        batching.isCompatible(first, pending[index])) {
      batch.add(pending[index]);
      index += 1;
    }
    return batch;
  }

  static Future<bool> _tryApplyBatch(
    List<OutboxAction> batch,
    OutboxBatching batching,
  ) async {
    try {
      return await batching.apply(batch);
    } catch (_) {
      // Fall back to individual delivery so one bad item cannot block a batch.
      return false;
    }
  }

  static Future<void> _tryApply(
    OutboxAction action,
    OutboxActionApplier apply,
    List<OutboxAction> delivered,
    OutboxActionErrorHandler? onActionError,
  ) async {
    try {
      if (await apply(action)) delivered.add(action);
    } catch (error, stackTrace) {
      onActionError?.call(action, error, stackTrace);
    }
  }
}
