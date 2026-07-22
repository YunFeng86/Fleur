import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../providers/core_providers.dart';
import '../widgets/app_scrollbar.dart';

class DbRecoveryNoticeOverlay extends ConsumerStatefulWidget {
  const DbRecoveryNoticeOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DbRecoveryNoticeOverlay> createState() =>
      _DbRecoveryNoticeOverlayState();
}

class _DbRecoveryNoticeOverlayState
    extends ConsumerState<DbRecoveryNoticeOverlay> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_checkAndShow());
    });
  }

  Future<void> _checkAndShow() async {
    // Best-effort overlay: in widget tests or non-DB environments, `isarProvider`
    // may not be overridden.
    //
    // Do not fail the whole app tree in that case.
    Isar isar;
    try {
      isar = ref.read(isarProvider);
    } on UnimplementedError {
      return;
    }
    final directory = isar.directory?.trim();
    if (directory == null || directory.isEmpty) return;

    final noticeFile = File(p.join(directory, 'backups', 'recovery_last.json'));
    if (!await noticeFile.exists()) return;

    Map<String, Object?>? payload;
    try {
      final raw = await noticeFile.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        payload = decoded.cast<String, Object?>();
      }
    } catch (_) {
      // ignore: best-effort notice parsing
    }

    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    final createdAt = (payload?['createdAtIso'] as String?)?.trim();
    final accountId = (payload?['accountId'] as String?)?.trim();
    final dbName = (payload?['dbName'] as String?)?.trim();
    final backupPath = (payload?['backupPath'] as String?)?.trim();
    final movedPath = (payload?['movedPath'] as String?)?.trim();
    final fallbackDbName = (payload?['fallbackDbName'] as String?)?.trim();
    final error = (payload?['error'] as String?)?.trim();

    Future<void> copyToClipboard(String text) async {
      final trimmed = text.trim();
      if (trimmed.isEmpty) return;
      await Clipboard.setData(ClipboardData(text: trimmed));
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.copiedToClipboard)));
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        Widget row({
          required String label,
          required String value,
          bool allowCopy = true,
        }) {
          final v = value.trim();
          if (v.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SelectableText(v)),
                    if (allowCopy)
                      IconButton(
                        tooltip: materialL10n.copyButtonLabel,
                        onPressed: () => unawaited(copyToClipboard(v)),
                        icon: const Icon(Icons.copy),
                      ),
                  ],
                ),
              ],
            ),
          );
        }

        return AlertDialog(
          title: Text(l10n.dbRecoveryTitle),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AppScrollbar(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.dbRecoveryDescription),
                    const SizedBox(height: 16),
                    row(
                      label: l10n.dbRecoveryTimeLabel,
                      value: createdAt ?? '',
                    ),
                    row(label: l10n.account, value: accountId ?? ''),
                    row(label: l10n.dbRecoveryDbNameLabel, value: dbName ?? ''),
                    row(
                      label: l10n.dbRecoveryOpenedAsLabel,
                      value: fallbackDbName ?? '',
                    ),
                    row(
                      label: l10n.dbRecoveryBackupPathLabel,
                      value: backupPath ?? '',
                    ),
                    row(
                      label: l10n.dbRecoveryMovedOriginalPathLabel,
                      value: movedPath ?? '',
                    ),
                    row(label: l10n.dbRecoveryErrorLabel, value: error ?? ''),
                    const SizedBox(height: 4),
                    Text(
                      l10n.dbRecoveryDataPreservedHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(materialL10n.okButtonLabel),
            ),
          ],
        );
      },
    );

    // Clear notice once shown.
    try {
      await noticeFile.delete();
    } catch (_) {
      // ignore: best-effort cleanup
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
