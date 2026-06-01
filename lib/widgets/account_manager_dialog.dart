import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fleur/l10n/app_localizations.dart';

import '../providers/account_providers.dart';
import '../services/accounts/account.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../ui/dialogs/add_account_dialogs.dart';
import '../ui/dialogs/text_input_dialog.dart';
import '../utils/context_extensions.dart';
import 'app_scrollbar.dart';
import 'account_avatar.dart';

class AccountManagerDialog extends ConsumerWidget {
  const AccountManagerDialog({super.key});

  Future<void> _addAccount(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showDialog<AccountType>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.add),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AccountTypeCard(
                  icon: FleurIcons.localAccount,
                  title: l10n.addLocal,
                  subtitle: l10n.local,
                  onTap: () =>
                      Navigator.of(dialogContext).pop(AccountType.local),
                ),
                _AccountTypeCard(
                  icon: FleurIcons.minifluxAccount,
                  title: l10n.addMiniflux,
                  subtitle: l10n.miniflux,
                  onTap: () =>
                      Navigator.of(dialogContext).pop(AccountType.miniflux),
                ),
                _AccountTypeCard(
                  icon: FleurIcons.feverAccount,
                  title: l10n.addFever,
                  subtitle: l10n.fever,
                  onTap: () =>
                      Navigator.of(dialogContext).pop(AccountType.fever),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );

    if (picked == null || !context.mounted) return;
    switch (picked) {
      case AccountType.local:
        await showAddLocalAccountDialog(context, ref);
        return;
      case AccountType.miniflux:
        await showAddMinifluxAccountDialog(context, ref);
        return;
      case AccountType.fever:
        await showAddFeverAccountDialog(context, ref);
        return;
    }
  }

  Future<void> _renameAccount(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final next = await showTextInputDialog(
      context,
      title: l10n.rename,
      labelText: l10n.fieldName,
      initialText: account.name,
      confirmText: l10n.done,
    );
    final trimmed = (next ?? '').trim();
    if (trimmed.isEmpty || trimmed == account.name) return;
    await ref
        .read(accountsControllerProvider.notifier)
        .renameAccount(account.id, trimmed);
    if (!context.mounted) return;
    context.showSnack(l10n.done);
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (account.isPrimary) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.delete),
          content: Text('${l10n.delete} "${account.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    await ref
        .read(accountsControllerProvider.notifier)
        .deleteAccount(account.id);
    if (!context.mounted) return;
    context.showSnack(l10n.done);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final accountsAsync = ref.watch(accountsControllerProvider);
    final active = ref.watch(activeAccountProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaces = theme.fleurSurface;
    final states = theme.fleurState;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: accountsAsync.when(
            loading: () => const SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SizedBox(
              height: 240,
              child: Center(child: Text(l10n.errorMessage(e.toString()))),
            ),
            data: (state) {
              final accounts = state.accounts;
              final listHeight = max(
                260.0,
                min(MediaQuery.of(context).size.height * 0.5, 520.0),
              );

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.account,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            active.name,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(FleurIcons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const Key('account_manager_add_button'),
                        onPressed: () => unawaited(_addAccount(context, ref)),
                        icon: const Icon(FleurIcons.add),
                        label: Text(l10n.add),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(FleurIcons.activeAccount),
                          const SizedBox(width: 4),
                          Text(active.name),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DecoratedBox(
                    key: const Key('account_manager_list_surface'),
                    decoration: BoxDecoration(
                      color: surfaces.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: surfaces.subtleDivider),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: SizedBox(
                        height: listHeight,
                        child: AppScrollbar(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 4,
                            ),
                            itemCount: accounts.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final a = accounts[index];
                              final isActive = a.id == active.id;
                              final subtitle = switch (a.type) {
                                AccountType.local => l10n.local,
                                AccountType.miniflux =>
                                  (a.baseUrl ?? '').trim().isEmpty
                                      ? l10n.miniflux
                                      : a.baseUrl!.trim(),
                                AccountType.fever =>
                                  (a.baseUrl ?? '').trim().isEmpty
                                      ? l10n.fever
                                      : a.baseUrl!.trim(),
                              };

                              return AnimatedContainer(
                                key: Key('account_manager_account_${a.id}'),
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? surfaces.cardSelected
                                      : surfaces.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isActive
                                        ? states.focusRing
                                        : surfaces.subtleDivider,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  leading: AccountAvatar(
                                    account: a,
                                    radius: 18,
                                    showTypeBadge: true,
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          a.name,
                                          style: TextStyle(
                                            fontWeight: isActive
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isActive)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8.0,
                                          ),
                                          child: Icon(
                                            FleurIcons.activeAccount,
                                            size: 18,
                                            color: scheme.primary,
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: l10n.rename,
                                        onPressed: () =>
                                            _renameAccount(context, ref, a),
                                        icon: const Icon(FleurIcons.rename),
                                      ),
                                      IconButton(
                                        tooltip: l10n.delete,
                                        onPressed: a.isPrimary
                                            ? null
                                            : () => _deleteAccount(
                                                context,
                                                ref,
                                                a,
                                              ),
                                        icon: const Icon(FleurIcons.delete),
                                      ),
                                    ],
                                  ),
                                  onTap: () async {
                                    if (isActive) return;
                                    await ref
                                        .read(
                                          accountsControllerProvider.notifier,
                                        )
                                        .setActive(a.id);
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaces = theme.fleurSurface;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: surfaces.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: surfaces.subtleDivider),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(FleurIcons.chevronRight, size: 14),
        onTap: onTap,
      ),
    );
  }
}
