import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/features/accounts/accounts.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/backend_capabilities_provider.dart';
import '../../providers/outbox_status_providers.dart';
import '../../providers/service_providers.dart';
import '../../services/sync/backend_capabilities.dart';
import '../../services/sync/sync_service.dart';
import '../../theme/fleur_icons.dart';
import '../design_system/design_system.dart';

class OutboxStatusAction extends ConsumerWidget {
  const OutboxStatusAction({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final account = ref.watch(activeAccountProvider);
    final capabilities = ref.watch(backendCapabilitiesProvider);
    if (!capabilities.isVisible(BackendFeature.outboxFlush)) {
      return const SizedBox.shrink();
    }

    final pending = ref.watch(outboxPendingCountProvider).valueOrNull ?? 0;
    final quarantined =
        ref.watch(outboxQuarantinedCountProvider).valueOrNull ?? 0;
    if (pending <= 0 && quarantined <= 0) return const SizedBox.shrink();

    final stalls = ref.watch(outboxFlushStallCountProvider);
    final isWarning = stalls >= 2;
    final scheme = Theme.of(context).colorScheme;
    final badgeColor = isWarning ? scheme.error : scheme.primary;
    final total = pending + quarantined;
    final label = total > 99 ? '99+' : total.toString();

    Future<void> flushNow() async {
      final before = pending;
      final svc = ref.read(syncServiceProvider);
      final ok = switch (svc) {
        OutboxFlushCapable s => await s.flushOutboxSafe(),
        _ => false,
      };

      final after = await ref.read(outboxStoreProvider).load(account.id);
      final afterCount = after.length;

      final stallNotifier = ref.read(outboxFlushStallCountProvider.notifier);
      if (afterCount == 0 || afterCount < before) {
        stallNotifier.state = 0;
      } else {
        stallNotifier.state = stallNotifier.state + 1;
      }

      if (!context.mounted) return;
      final success = ok && afterCount < before;
      final msg = (success || afterCount == 0)
          ? l10n.done
          : l10n.syncStatusFailed;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }

    return IconButton(
      tooltip: quarantined > 0
          ? l10n.syncStatusFailed
          : isWarning
          ? l10n.syncStatusFailed
          : l10n.syncStatusUploadingChanges,
      onPressed: () => unawaited(flushNow()),
      iconSize: compact ? 18 : null,
      style: compact
          ? FleurCapsuleIconButton.styleFor(context, selected: isWarning)
          : null,
      icon: Badge(
        backgroundColor: badgeColor,
        label: Text(label, style: const TextStyle(fontSize: 10)),
        child: Icon(isWarning ? FleurIcons.syncWarning : FleurIcons.syncUpload),
      ),
    );
  }
}
