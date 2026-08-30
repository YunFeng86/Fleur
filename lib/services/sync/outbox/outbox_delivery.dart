import '../../logging/app_logger.dart';
import '../remote_article_action_executor.dart';
import '../sync_mutex.dart';
import 'outbox_store.dart';

typedef OutboxActionApplier =
    Future<RemoteActionDisposition> Function(OutboxAction action);
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
  final Future<RemoteActionDisposition> Function(List<OutboxAction> actions)
  apply;
}

/// Delivers a stable outbox snapshot and acknowledges settled actions
/// against the latest persisted queue.
///
/// Remote calls intentionally run without the store lock, so UI actions can be
/// enqueued while a slow flush is in progress. [OutboxStore.acknowledge] merges
/// successful delivery into the latest queue instead of saving the old
/// snapshot over newly queued intents.
///
/// Actions the executor reports as [RemoteActionDisposition.rejected] can
/// never be delivered (e.g. missing remote identifiers or a deleted remote
/// scope); they are acknowledged off the queue with a warning so the pending
/// count can settle at zero instead of retrying forever. Thrown errors and
/// [RemoteActionDisposition.transient] results keep the action queued.
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

      final acknowledged = <OutboxAction>[];
      final rejected = <OutboxAction>[];
      var index = 0;
      while (index < pending.length) {
        final action = pending[index];
        final batch = _compatibleBatch(pending, index, batching);
        if (batch != null) {
          if (await _tryApplyBatch(batch, batching!)) {
            acknowledged.addAll(batch);
          } else {
            for (final item in batch) {
              await _tryApply(
                item,
                apply,
                acknowledged,
                rejected,
                onActionError,
              );
            }
          }
          index += batch.length;
          continue;
        }

        await _tryApply(action, apply, acknowledged, rejected, onActionError);
        index += 1;
      }

      if (rejected.isNotEmpty) {
        await _store.quarantine(
          accountId,
          rejected,
          reason: 'permanentlyUndeliverable',
        );
        AppLogger.w(
          'Outbox actions quarantined as permanently undeliverable',
          tag: 'sync',
          context: <String, Object?>{
            'operation': 'outboxFlush',
            'accountId': accountId,
            'rejected': rejected.length,
            'actions': [
              for (final action in rejected)
                {
                  'type': action.type.name,
                  'hasRemoteEntryId': action.remoteEntryId != null,
                  'hasRemoteEntryKey': action.remoteEntryKey != null,
                  'hasFeedUrl': action.feedUrl != null,
                  'hasCategoryTitle': action.categoryTitle != null,
                },
            ],
          },
        );
      }

      await _store.acknowledge(accountId, acknowledged);
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
      return await batching.apply(batch) == RemoteActionDisposition.delivered;
    } catch (_) {
      // Fall back to individual delivery so one bad item cannot block a batch.
      return false;
    }
  }

  static Future<void> _tryApply(
    OutboxAction action,
    OutboxActionApplier apply,
    List<OutboxAction> acknowledged,
    List<OutboxAction> rejected,
    OutboxActionErrorHandler? onActionError,
  ) async {
    try {
      final disposition = await apply(action);
      switch (disposition) {
        case RemoteActionDisposition.delivered:
          acknowledged.add(action);
        case RemoteActionDisposition.rejected:
          acknowledged.add(action);
          rejected.add(action);
        case RemoteActionDisposition.transient:
          break;
      }
    } catch (error, stackTrace) {
      onActionError?.call(action, error, stackTrace);
    }
  }
}
