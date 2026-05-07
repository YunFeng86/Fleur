import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/account_providers.dart';
import '../../../providers/app_settings_providers.dart';
import '../../../providers/backend_capabilities_provider.dart';
import '../../../providers/backend_content_capabilities_provider.dart';
import '../../../providers/backend_sync_semantics_provider.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../services/accounts/account.dart';
import '../../../services/settings/app_settings.dart';
import '../../../services/sync/backend_sync_semantics.dart';
import '../../../utils/context_extensions.dart';
import '../../dialogs/add_account_dialogs.dart';
import '../widgets/section_header.dart';
import '../../../widgets/account_manager_dialog.dart';

class ServicesTab extends ConsumerWidget {
  const ServicesTab({super.key, this.showPageTitle = true});

  final bool showPageTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final appSettings =
        ref.watch(appSettingsProvider).valueOrNull ?? AppSettings.defaults();
    final accounts = ref.watch(accountsControllerProvider).valueOrNull;
    final activeAccount = ref.watch(activeAccountProvider);
    final capabilities = ref.watch(backendCapabilitiesProvider);
    final contentCapabilities = ref.watch(backendContentCapabilitiesProvider);
    final syncSemantics = ref.watch(backendSyncSemanticsProvider);

    final interval = appSettings.autoRefreshMinutes;
    final isAccountWideSync = syncSemantics.isAccountWideRefresh;
    final refreshSectionTitle = isAccountWideSync
        ? l10n.accountSync
        : l10n.refreshAll;
    final refreshSectionDescription = isAccountWideSync
        ? l10n.accountSyncSubtitle
        : l10n.autoRefreshSubtitle;
    final refreshActionLabel = isAccountWideSync
        ? l10n.syncAccount
        : l10n.refreshAll;
    final refreshSuccessLabel = isAccountWideSync
        ? l10n.syncedAccount
        : l10n.refreshedAll;
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
        contentCapabilities.canChooseServerArticleContentFetchMode;

    String refreshProgressLabel(int current, int total) {
      if (isAccountWideSync) return l10n.syncingAccount;
      return l10n.refreshingProgress(current, total);
    }

    Future<void> refreshNow() async {
      final feeds = await ref.read(feedRepositoryProvider).getAll();
      // Remote-backed accounts can sync even when local DB is empty.
      if (feeds.isEmpty && !capabilities.isRemoteBacked) return;

      final concurrency = appSettings.autoRefreshConcurrency;

      if (!context.mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);

      // Show progress dialog.
      final progressNotifier = ValueNotifier<String>(
        refreshProgressLabel(0, feeds.length),
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

        final batch = await ref
            .read(syncServiceProvider)
            .refreshFeedsSafe(
              feeds.map((f) => f.id),
              maxConcurrent: concurrency,
              onProgress: (current, total) {
                progressNotifier.value = refreshProgressLabel(current, total);
              },
            );

        final err = batch.firstError?.error;
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

    return SettingsPageBody(
      children: [
        if (showPageTitle) ...[
          SectionHeader(title: l10n.services),
          const SizedBox(height: 8),
        ],
        SettingsSection(
          title: l10n.account,
          child: SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: activeAccount.id,
                    isExpanded: true,
                    items: (accounts?.accounts ?? const [])
                        .map(
                          (a) => DropdownMenuItem<String>(
                            value: a.id,
                            child: Text('${a.name} (${a.type.wire})'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (v) {
                      if (v == null) return;
                      unawaited(
                        ref
                            .read(accountsControllerProvider.notifier)
                            .setActive(v),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: addAccount,
                      icon: const Icon(Icons.add),
                      label: Text(l10n.add),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await showDialog<void>(
                          context: context,
                          useRootNavigator: true,
                          builder: (context) => const AccountManagerDialog(),
                        );
                      },
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: Text(l10n.more),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SettingsSection(
          title: refreshSectionTitle,
          description: refreshSectionDescription,
          child: SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  refreshSectionDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: interval,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(l10n.off),
                      ),
                      for (final m in const [5, 15, 30, 60])
                        DropdownMenuItem<int?>(
                          value: m,
                          child: Text(l10n.everyMinutes(m)),
                        ),
                    ],
                    onChanged: (v) => ref
                        .read(appSettingsProvider.notifier)
                        .setAutoRefreshMinutes(v),
                  ),
                ),
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
                        DropdownMenuItem(value: c, child: Text(c.toString())),
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
                  Text(
                    remoteStrategySubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (syncSemantics.supportsEntrySyncLimit) ...[
                    const SizedBox(height: 16),
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
