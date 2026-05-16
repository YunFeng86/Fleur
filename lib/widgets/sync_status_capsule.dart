import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fleur/l10n/app_localizations.dart';

import '../providers/sync_status_providers.dart';
import '../services/sync/sync_status_reporter.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../ui/motion.dart';

const double kSyncStatusCapsuleMaxWidth = 360;

class SyncStatusCapsuleHost extends ConsumerWidget {
  const SyncStatusCapsuleHost({
    super.key,
    required this.child,
    this.enabled = true,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
    this.maxWidth = kSyncStatusCapsuleMaxWidth,
  });

  final Widget child;
  final bool enabled;
  final EdgeInsets padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) return child;

    final state = ref.watch(syncStatusControllerProvider);
    final visible = state.visible;
    final reduceMotion = AppMotion.reduceMotion(context);
    final duration = reduceMotion ? Duration.zero : AppMotion.short;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: padding,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: AnimatedSlide(
                  offset: visible ? Offset.zero : const Offset(0, 1),
                  duration: duration,
                  curve: AppMotion.standardCurve,
                  child: AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: duration,
                    curve: AppMotion.standardCurve,
                    child: IgnorePointer(
                      ignoring: !visible,
                      child: _SyncStatusCapsule(state: state),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SyncStatusCapsule extends StatelessWidget {
  const _SyncStatusCapsule({required this.state});

  final SyncStatusState state;

  String _labelText(AppLocalizations l10n, SyncStatusLabel label) {
    // Keep this in one place so UI can stay consistent across panes.
    switch (label) {
      case SyncStatusLabel.syncing:
        return l10n.syncStatusSyncing;
      case SyncStatusLabel.syncingFeeds:
        return l10n.syncStatusSyncingFeeds;
      case SyncStatusLabel.syncingSubscriptions:
        return l10n.syncStatusSyncingSubscriptions;
      case SyncStatusLabel.syncingUnreadArticles:
        return l10n.syncStatusSyncingUnreadArticles;
      case SyncStatusLabel.uploadingChanges:
        return l10n.syncStatusUploadingChanges;
      case SyncStatusLabel.completed:
        return l10n.syncStatusCompleted;
      case SyncStatusLabel.failed:
        return l10n.syncStatusFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;
    final tokens = theme.fleurState;
    final scheme = theme.colorScheme;
    final reduceMotion = AppMotion.reduceMotion(context);
    final duration = reduceMotion ? Duration.zero : AppMotion.medium;

    final label = _labelText(l10n, state.label);
    final detail = (state.detail ?? '').trim();
    final title = detail.isEmpty ? label : '$label · $detail';

    final current = state.current;
    final total = state.total;
    final hasProgress = current != null && (total != null && total > 0);
    final text = hasProgress ? '$title（$current/$total）' : title;

    final key = ValueKey<int>(state.revision);

    final indicator = state.running
        ? SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tokens.syncAccent,
            ),
          )
        : Icon(
            state.label == SyncStatusLabel.failed
                ? FleurIcons.statusError
                : FleurIcons.statusOk,
            size: 16,
            color: state.label == SyncStatusLabel.failed
                ? tokens.errorAccent
                : tokens.syncAccent,
          );

    return Material(
      key: const Key('sync_status_capsule'),
      elevation: 6,
      color: surfaces.floating,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            indicator,
            const SizedBox(width: 10),
            Expanded(
              child: DefaultTextStyle(
                style:
                    theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface,
                    ) ??
                    TextStyle(color: scheme.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: AppMotion.standardCurve,
                  switchOutCurve: AppMotion.emphasizedAccelerate,
                  transitionBuilder: (child, animation) {
                    // Stage switches: new label scrolls in from top, old exits down.
                    final isIncoming = child.key == key;
                    final begin = isIncoming
                        ? const Offset(0, -0.6)
                        : const Offset(0, 0.6);
                    return ClipRect(
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: begin,
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(text, key: key),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
