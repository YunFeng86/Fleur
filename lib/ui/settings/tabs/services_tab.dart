import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/account_providers.dart';
import '../../../providers/app_settings_providers.dart';
import '../../../providers/backend_capabilities_provider.dart';
import '../../../providers/backend_content_capabilities_provider.dart';
import '../../../providers/backend_sync_semantics_provider.dart';
import '../../../providers/refresh_all_providers.dart';
import '../../../services/accounts/account.dart';
import '../../../services/settings/app_settings.dart';
import '../../../services/sync/backend_capabilities.dart';
import '../../../services/sync/backend_sync_semantics.dart';
import '../../../services/sync/refresh_all_coordinator.dart';
import '../../../utils/context_extensions.dart';
import '../../../widgets/account_avatar.dart';
import '../../dialogs/add_account_dialogs.dart';
import '../../dialogs/text_input_dialog.dart';
import '../widgets/section_header.dart';

class ServicesTab extends ConsumerWidget {
  const ServicesTab({super.key, this.showPageTitle = true});

  final bool showPageTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final appSettings =
        ref.watch(appSettingsProvider).valueOrNull ?? AppSettings.defaults();
    final accountsAsync = ref.watch(accountsControllerProvider);
    final activeAccount = ref.watch(activeAccountProvider);
    final capabilities = ref.watch(backendCapabilitiesProvider);
    final contentCapabilities = ref.watch(backendContentCapabilitiesProvider);
    final syncSemantics = ref.watch(backendSyncSemanticsProvider);

    final interval = appSettings.sourceRefreshMinutes;
    final showSourceRefresh = capabilities.isVisible(
      BackendFeature.refreshAllSources,
    );
    final refreshSectionTitle = l10n.refreshAll;
    final refreshSectionDescription = l10n.autoRefreshSubtitle;
    final refreshActionLabel = l10n.refreshAll;
    final refreshSuccessLabel = l10n.refreshedAll;
    final remoteStrategySubtitle = switch (syncSemantics.historyCoverage) {
      BackendHistoryCoverage.remotePaginatedEntries =>
        l10n.remoteSyncStrategyMinifluxSubtitle,
      BackendHistoryCoverage.remoteUnreadAndSavedItems =>
        l10n.remoteSyncStrategyFeverSubtitle,
      BackendHistoryCoverage.localFeedContent =>
        l10n.remoteSyncStrategySubtitle,
    };
    final showRemoteSyncStrategy =
        syncSemantics.supportsEntrySyncLimit ||
        syncSemantics.supportsRemoteFetchConcurrency ||
        contentCapabilities.canChooseServerArticleContentFetchMode;
    final showRefreshConcurrency = syncSemantics.isFeedScopedRefresh;

    String refreshProgressLabel(int current, int total) {
      return l10n.refreshingProgress(current, total);
    }

    Future<void> refreshNow() async {
      final concurrency = appSettings.autoRefreshConcurrency;

      if (!context.mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);

      // Show progress dialog.
      final progressNotifier = ValueNotifier<String>(
        refreshProgressLabel(0, 0),
      );
      try {
        unawaited(
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return PopScope(
                canPop: false,
                child: AlertDialog(
                  content: Row(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(width: 24),
                      ValueListenableBuilder<String>(
                        valueListenable: progressNotifier,
                        builder: (context, value, _) {
                          return Text(value);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ).then((_) {}),
        );

        final result = await ref
            .read(refreshSourcesCoordinatorProvider)
            .refreshSources(
              trigger: RefreshSourcesTrigger.manual,
              maxConcurrent: concurrency,
              onProgress: (current, total) {
                progressNotifier.value = refreshProgressLabel(current, total);
              },
            );

        final err = result.firstError;
        if (!context.mounted) return;
        context.showSnack(
          err == null ? refreshSuccessLabel : l10n.errorMessage(err.toString()),
        );
      } finally {
        // Close progress dialog even if the settings page was popped.
        try {
          if (navigator.mounted && navigator.canPop()) {
            navigator.pop();
          }
        } catch (_) {
          // ignore: best-effort cleanup
        }
        progressNotifier.dispose();
      }
    }

    Future<void> addAccount() async {
      final picked = await showDialog<AccountType>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(l10n.add),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.rss_feed),
                  title: Text(l10n.addLocal),
                  subtitle: Text(l10n.local),
                  onTap: () =>
                      Navigator.of(dialogContext).pop(AccountType.local),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(l10n.addMiniflux),
                  subtitle: Text(l10n.miniflux),
                  onTap: () =>
                      Navigator.of(dialogContext).pop(AccountType.miniflux),
                ),
                ListTile(
                  leading: const Icon(Icons.local_fire_department_outlined),
                  title: Text(l10n.addFever),
                  subtitle: Text(l10n.fever),
                  onTap: () =>
                      Navigator.of(dialogContext).pop(AccountType.fever),
                ),
              ],
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

    String accountSubtitle(Account account) {
      return switch (account.type) {
        AccountType.local => l10n.local,
        AccountType.miniflux =>
          (account.baseUrl ?? '').trim().isEmpty
              ? l10n.miniflux
              : account.baseUrl!.trim(),
        AccountType.fever =>
          (account.baseUrl ?? '').trim().isEmpty
              ? l10n.fever
              : account.baseUrl!.trim(),
      };
    }

    List<Account> accountsWithActiveFirst(List<Account> accounts) {
      final activeId = activeAccount.id;
      final active = accounts.where((a) => a.id == activeId).toList();
      final rest = accounts.where((a) => a.id != activeId).toList();
      return [...active, ...rest];
    }

    Future<void> renameAccount(Account account) async {
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

    Future<void> deleteAccount(Account account) async {
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

    return SettingsPageBody(
      children: [
        if (showPageTitle) ...[
          SectionHeader(title: l10n.services),
          const SizedBox(height: 8),
        ],
        SettingsSection(
          title: l10n.account,
          child: SettingsCard(
            padding: EdgeInsets.zero,
            child: accountsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.errorMessage(e.toString())),
              ),
              data: (state) {
                final accounts = accountsWithActiveFirst(state.accounts);
                return SettingsTileGroup(
                  children: [
                    for (final account in accounts)
                      _AccountSettingsTile(
                        key: Key('services_account_tile_${account.id}'),
                        account: account,
                        subtitle: accountSubtitle(account),
                        isActive: account.id == activeAccount.id,
                        onTap: account.id == activeAccount.id
                            ? null
                            : () {
                                unawaited(
                                  ref
                                      .read(accountsControllerProvider.notifier)
                                      .setActive(account.id),
                                );
                              },
                        onRename: () => unawaited(renameAccount(account)),
                        onDelete: account.isPrimary
                            ? null
                            : () => unawaited(deleteAccount(account)),
                      ),
                    SettingsTile(
                      key: const Key('services_add_account'),
                      leading: const CircleAvatar(
                        radius: 18,
                        child: Icon(Icons.add),
                      ),
                      title: Text(l10n.addOrRegisterAccount),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => unawaited(addAccount()),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        if (showSourceRefresh)
          SettingsSection(
            title: refreshSectionTitle,
            description: refreshSectionDescription,
            child: SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: interval,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(l10n.off),
                        ),
                        for (final m in const [15, 30, 60])
                          DropdownMenuItem<int?>(
                            value: m,
                            child: Text(l10n.everyMinutes(m)),
                          ),
                      ],
                      onChanged: (v) => ref
                          .read(appSettingsProvider.notifier)
                          .setSourceRefreshMinutes(v),
                    ),
                  ),
                  if (showRefreshConcurrency) ...[
                    const SizedBox(height: 16),
                    Text(
                      l10n.refreshConcurrency,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: appSettings.autoRefreshConcurrency,
                        isExpanded: true,
                        items: [
                          for (final c in [1, 2, 4, 6])
                            DropdownMenuItem(
                              value: c,
                              child: Text(c.toString()),
                            ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setAutoRefreshConcurrency(v),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: refreshNow,
                    icon: const Icon(Icons.refresh),
                    label: Text(refreshActionLabel),
                  ),
                ],
              ),
            ),
          ),
        if (showRemoteSyncStrategy)
          SettingsSection(
            title: l10n.remoteSyncStrategy,
            description: remoteStrategySubtitle,
            bottomSpacing: 0,
            child: SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (syncSemantics.supportsEntrySyncLimit) ...[
                    Text(
                      l10n.remoteEntriesLimit,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: appSettings.remoteEntriesLimit,
                        isExpanded: true,
                        items: [
                          for (final v in const [100, 200, 400, 800, 1200])
                            DropdownMenuItem(value: v, child: Text('$v')),
                          DropdownMenuItem(
                            value: 0,
                            child: Text(l10n.unlimited),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setRemoteEntriesLimit(v),
                          );
                        },
                      ),
                    ),
                  ],
                  if (syncSemantics.supportsRemoteFetchConcurrency) ...[
                    const SizedBox(height: 16),
                    Text(
                      l10n.remoteFetchConcurrency,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.remoteFetchConcurrencySubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: appSettings.remoteFetchConcurrency,
                        isExpanded: true,
                        items: [
                          for (final c in const [1, 2, 3, 4])
                            DropdownMenuItem(
                              value: c,
                              child: Text(c.toString()),
                            ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setRemoteFetchConcurrency(v),
                          );
                        },
                      ),
                    ),
                  ],
                  if (contentCapabilities
                      .canChooseServerArticleContentFetchMode) ...[
                    const SizedBox(height: 16),
                    Text(
                      l10n.minifluxWebFetchMode,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.minifluxWebFetchModeSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<MinifluxWebFetchMode>(
                        value: appSettings.minifluxWebFetchMode,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: MinifluxWebFetchMode.clientReadability,
                            child: Text(l10n.minifluxWebFetchModeClient),
                          ),
                          DropdownMenuItem(
                            value: MinifluxWebFetchMode.serverFetchContent,
                            child: Text(l10n.minifluxWebFetchModeServer),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setMinifluxWebFetchMode(v),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

enum _AccountAction { rename, delete }

class _AccountSettingsTile extends StatelessWidget {
  const _AccountSettingsTile({
    super.key,
    required this.account,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final Account account;
  final String subtitle;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return SettingsTile(
      selected: isActive,
      leading: AccountAvatar(account: account, radius: 18, showTypeBadge: true),
      title: Text(
        account.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            Icon(
              Icons.check_circle,
              key: Key('services_account_selected_${account.id}'),
              color: scheme.primary,
              size: 20,
            ),
          PopupMenuButton<_AccountAction>(
            key: Key('services_account_menu_${account.id}'),
            tooltip: l10n.more,
            onSelected: (action) {
              switch (action) {
                case _AccountAction.rename:
                  onRename();
                  return;
                case _AccountAction.delete:
                  onDelete?.call();
                  return;
              }
            },
            itemBuilder: (context) {
              return [
                PopupMenuItem<_AccountAction>(
                  key: Key('services_account_rename_${account.id}'),
                  value: _AccountAction.rename,
                  child: _AccountMenuItem(
                    icon: Icons.edit_outlined,
                    label: l10n.rename,
                  ),
                ),
                PopupMenuItem<_AccountAction>(
                  key: Key('services_account_delete_${account.id}'),
                  value: _AccountAction.delete,
                  enabled: onDelete != null,
                  child: _AccountMenuItem(
                    icon: Icons.delete_outline,
                    label: l10n.delete,
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _AccountMenuItem extends StatelessWidget {
  const _AccountMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
    );
  }
}
