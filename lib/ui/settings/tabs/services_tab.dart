import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/account_providers.dart';
import '../../../providers/app_settings_providers.dart';
import '../../../providers/backend_capabilities_provider.dart';
import '../../../providers/backend_content_capabilities_provider.dart';
import '../../../providers/backend_sync_semantics_provider.dart';
import '../../../services/accounts/account.dart';
import '../../../services/settings/app_settings.dart';
import '../../../services/sync/backend_capabilities.dart';
import '../../../services/sync/backend_sync_semantics.dart';
import '../../../theme/fleur_icons.dart';
import '../../../utils/context_extensions.dart';
import '../../../widgets/account_avatar.dart';
import '../../app_menu.dart';
import '../../actions/subscription_actions.dart';
import '../../dialogs/add_account_dialogs.dart';
import '../../dialogs/text_input_dialog.dart';
import '../widgets/section_header.dart';

class ServicesTab extends ConsumerStatefulWidget {
  const ServicesTab({super.key, this.showPageTitle = true});

  final bool showPageTitle;

  @override
  ConsumerState<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends ConsumerState<ServicesTab> {
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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

    Future<void> refreshNow() async {
      if (_isRefreshing) return;
      setState(() => _isRefreshing = true);
      try {
        await SubscriptionActions.refreshAll(context, ref);
      } finally {
        if (mounted) setState(() => _isRefreshing = false);
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
                  leading: const Icon(FleurIcons.localAccount),
                  title: Text(l10n.addLocal),
                  subtitle: Text(l10n.local),
                  onTap: () =>
                      Navigator.of(dialogContext).pop(AccountType.local),
                ),
                ListTile(
                  leading: const Icon(FleurIcons.minifluxAccount),
                  title: Text(l10n.addMiniflux),
                  subtitle: Text(l10n.miniflux),
                  onTap: () =>
                      Navigator.of(dialogContext).pop(AccountType.miniflux),
                ),
                ListTile(
                  leading: const Icon(FleurIcons.feverAccount),
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
        if (widget.showPageTitle) ...[
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
                        child: Icon(FleurIcons.add),
                      ),
                      title: Text(l10n.addOrRegisterAccount),
                      trailing: const Icon(FleurIcons.chevronRight, size: 20),
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
              padding: EdgeInsets.zero,
              child: SettingsTileGroup(
                children: [
                  SettingsControlRow(
                    title: Text(refreshSectionTitle),
                    control: SettingsSelectField<int?>(
                      key: const Key('services_source_refresh_interval_select'),
                      value: interval,
                      options: [
                        SettingsSelectOption<int?>(
                          value: null,
                          label: Text(l10n.off),
                        ),
                        for (final m in const [15, 30, 60])
                          SettingsSelectOption<int?>(
                            value: m,
                            label: Text(l10n.everyMinutes(m)),
                          ),
                      ],
                      onChanged: (v) => ref
                          .read(appSettingsProvider.notifier)
                          .setSourceRefreshMinutes(v),
                    ),
                  ),
                  if (showRefreshConcurrency)
                    SettingsControlRow(
                      title: Text(l10n.refreshConcurrency),
                      control: SettingsSelectField<int>(
                        key: const Key('services_refresh_concurrency_select'),
                        value: appSettings.autoRefreshConcurrency,
                        options: [
                          for (final c in [1, 2, 4, 6])
                            SettingsSelectOption(
                              value: c,
                              label: Text(c.toString()),
                            ),
                        ],
                        onChanged: (v) {
                          unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setAutoRefreshConcurrency(v),
                          );
                        },
                      ),
                    ),
                  SettingsControlRow(
                    title: Text(refreshActionLabel),
                    control: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: SettingsActionButton(
                        key: const Key('services_refresh_sources_button'),
                        onPressed: _isRefreshing
                            ? null
                            : () => unawaited(refreshNow()),
                        icon: _isRefreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(FleurIcons.refresh),
                        label: Text(refreshActionLabel),
                      ),
                    ),
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
              padding: EdgeInsets.zero,
              child: SettingsTileGroup(
                children: [
                  if (syncSemantics.supportsEntrySyncLimit)
                    SettingsControlRow(
                      title: Text(l10n.remoteEntriesLimit),
                      control: SettingsSelectField<int>(
                        key: const Key('services_remote_entries_limit_select'),
                        value: appSettings.remoteEntriesLimit,
                        options: [
                          for (final v in const [100, 200, 400, 800, 1200])
                            SettingsSelectOption(value: v, label: Text('$v')),
                          SettingsSelectOption(
                            value: 0,
                            label: Text(l10n.unlimited),
                          ),
                        ],
                        onChanged: (v) {
                          unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setRemoteEntriesLimit(v),
                          );
                        },
                      ),
                    ),
                  if (syncSemantics.supportsRemoteFetchConcurrency)
                    SettingsControlRow(
                      title: Text(l10n.remoteFetchConcurrency),
                      subtitle: Text(l10n.remoteFetchConcurrencySubtitle),
                      control: SettingsSelectField<int>(
                        key: const Key(
                          'services_remote_fetch_concurrency_select',
                        ),
                        value: appSettings.remoteFetchConcurrency,
                        options: [
                          for (final c in const [1, 2, 3, 4])
                            SettingsSelectOption(
                              value: c,
                              label: Text(c.toString()),
                            ),
                        ],
                        onChanged: (v) {
                          unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setRemoteFetchConcurrency(v),
                          );
                        },
                      ),
                    ),
                  if (contentCapabilities
                      .canChooseServerArticleContentFetchMode)
                    SettingsControlRow(
                      title: Text(l10n.minifluxWebFetchMode),
                      subtitle: Text(l10n.minifluxWebFetchModeSubtitle),
                      control: SettingsSelectField<MinifluxWebFetchMode>(
                        key: const Key(
                          'services_miniflux_web_fetch_mode_select',
                        ),
                        value: appSettings.minifluxWebFetchMode,
                        options: [
                          SettingsSelectOption(
                            value: MinifluxWebFetchMode.clientReadability,
                            label: Text(l10n.minifluxWebFetchModeClient),
                          ),
                          SettingsSelectOption(
                            value: MinifluxWebFetchMode.serverFetchContent,
                            label: Text(l10n.minifluxWebFetchModeServer),
                          ),
                        ],
                        onChanged: (v) {
                          unawaited(
                            ref
                                .read(appSettingsProvider.notifier)
                                .setMinifluxWebFetchMode(v),
                          );
                        },
                      ),
                    ),
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
              FleurIcons.activeAccount,
              key: Key('services_account_selected_${account.id}'),
              color: scheme.primary,
              size: 20,
            ),
          AppMenuButton<_AccountAction>(
            buttonKey: Key('services_account_menu_${account.id}'),
            tooltip: l10n.more,
            icon: FleurIcons.moreVertical,
            items: [
              AppMenuItem(
                key: Key('services_account_rename_${account.id}'),
                value: _AccountAction.rename,
                icon: FleurIcons.rename,
                label: l10n.rename,
              ),
              AppMenuItem(
                key: Key('services_account_delete_${account.id}'),
                value: _AccountAction.delete,
                icon: FleurIcons.delete,
                label: l10n.delete,
                enabled: onDelete != null,
              ),
            ],
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
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
