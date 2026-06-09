import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../../../l10n/app_localizations.dart';
import '../../../providers/app_update_providers.dart';
import '../../../services/logging/app_logger.dart';
import '../../../services/update/app_update_manifest.dart';
import '../../../services/platform/shell_service.dart';
import '../../../theme/fleur_icons.dart';
import '../../../ui/update/app_update_dialog.dart';
import '../../../utils/context_extensions.dart';
import '../../../utils/path_manager.dart';
import '../../../utils/platform.dart';
import '../../../widgets/app_scrollbar.dart';
import '../widgets/section_header.dart';

class AboutTab extends ConsumerStatefulWidget {
  const AboutTab({super.key, this.showPageTitle = true});

  final bool showPageTitle;

  @override
  ConsumerState<AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends ConsumerState<AboutTab> {
  late final Future<String> _appDataPathFuture;
  late final Future<String> _logsPathFuture;
  late final Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _appDataPathFuture = PathManager.getSupportPath();
    _logsPathFuture = PathManager.getLogsPath();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  Future<void> _openFolder(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return;
    try {
      await ShellService.openPath(trimmed);
    } catch (e, s) {
      AppLogger.w(
        'Open support folder failed',
        tag: 'about',
        error: e,
        stackTrace: s,
        context: const <String, Object?>{'operation': 'openFolder'},
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      String message;
      if (e is FileSystemException) {
        final isNotFound =
            (e.osError?.errorCode == 2) || e.message == 'Path does not exist';
        if (isNotFound) {
          final missingPath = e.path ?? trimmed;
          message = l10n.errorMessage(l10n.pathNotFound(missingPath));
        } else {
          message = l10n.errorMessage(l10n.openFailedGeneral);
        }
      } else {
        // In sandboxed environments, open/launch failures are frequently caused
        // by permission issues rather than the path being missing.
        message = l10n.errorMessage(l10n.openFailedGeneral);
      }
      context.showErrorMessage(message);
    }
  }

  Future<void> _exportLogs() async {
    final l10n = AppLocalizations.of(context)!;

    File archive;
    try {
      archive = await AppLogger.createLogsArchive();
    } catch (e, s) {
      AppLogger.w(
        'Log archive creation failed',
        tag: 'about',
        error: e,
        stackTrace: s,
        context: const <String, Object?>{'operation': 'createLogsArchive'},
      );
      if (!mounted) return;
      context.showErrorMessage(l10n.errorMessage(e.toString()));
      return;
    }

    // file_selector_ios may throw UnimplementedError for save dialogs.
    // On iOS we export via the system share sheet so users can "Save to Files".
    if (isIOS) {
      try {
        await IosShareBridge.shareFile(
          path: archive.path,
          mimeType: 'application/zip',
          name: p.basename(archive.path),
        );
      } catch (e, s) {
        AppLogger.w(
          'Log archive share failed',
          tag: 'about',
          error: e,
          stackTrace: s,
          context: const <String, Object?>{'operation': 'shareLogsArchive'},
        );
        if (!mounted) return;
        context.showErrorMessage(l10n.errorMessage(e.toString()));
        return;
      }
      if (!mounted) return;
      context.showSnack(l10n.exportedLogs);
      return;
    }

    const group = XTypeGroup(
      label: 'ZIP',
      extensions: ['zip'],
      mimeTypes: ['application/zip'],
      uniformTypeIdentifiers: ['public.zip-archive'],
    );

    FileSaveLocation? loc;
    try {
      loc = await getSaveLocation(
        suggestedName: p.basename(archive.path),
        acceptedTypeGroups: [group],
      );
    } catch (e, s) {
      AppLogger.w(
        'Log archive save dialog failed',
        tag: 'about',
        error: e,
        stackTrace: s,
        context: const <String, Object?>{'operation': 'pickLogArchivePath'},
      );
      if (!mounted) return;
      context.showErrorMessage(l10n.errorMessage(e.toString()));
      return;
    }
    if (loc == null) return;

    try {
      await archive.copy(loc.path);
    } catch (e, s) {
      AppLogger.w(
        'Log archive copy failed',
        tag: 'about',
        error: e,
        stackTrace: s,
        context: const <String, Object?>{'operation': 'copyLogsArchive'},
      );
      if (!mounted) return;
      context.showErrorMessage(l10n.errorMessage(e.toString()));
      return;
    }
    if (!mounted) return;
    context.showSnack(l10n.exportedLogs);
  }

  Future<void> _showLicenseDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    try {
      final licenseText = await rootBundle.loadString('LICENSE');
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.openSourceLicense),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 400),
            child: AppScrollbar(
              child: SingleChildScrollView(
                child: SelectableText(
                  licenseText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.done),
            ),
          ],
        ),
      );
    } catch (e, s) {
      AppLogger.w(
        'License load failed',
        tag: 'about',
        error: e,
        stackTrace: s,
        context: const <String, Object?>{'operation': 'loadLicense'},
      );
      if (!mounted) return;
      context.showErrorMessage(l10n.errorMessage(l10n.licenseLoadFailed));
    }
  }

  Future<void> _checkForUpdates() async {
    final l10n = AppLocalizations.of(context)!;
    await ref.read(appUpdateControllerProvider.notifier).check();
    if (!mounted) return;
    final updateState = ref.read(appUpdateControllerProvider);
    switch (updateState.status) {
      case AppUpdateStatus.updateAvailable:
        final manifest = updateState.manifest;
        if (manifest != null) {
          await showAppUpdateDialog(context, manifest: manifest);
        }
        return;
      case AppUpdateStatus.upToDate:
        context.showSnack(l10n.upToDate);
        return;
      case AppUpdateStatus.error:
        context.showErrorMessage(l10n.updateCheckFailed);
        return;
      case AppUpdateStatus.idle:
      case AppUpdateStatus.checking:
        return;
    }
  }

  Future<void> _showUpdateDialog(AppUpdateManifest manifest) {
    return showAppUpdateDialog(context, manifest: manifest);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDesktopPlatform = isDesktop;
    final updateState = ref.watch(appUpdateControllerProvider);

    return FutureBuilder<PackageInfo>(
      future: _packageInfoFuture,
      builder: (context, packageSnapshot) {
        final packageInfo = packageSnapshot.data;

        return SettingsPageBody(
          children: [
            if (widget.showPageTitle) ...[
              SectionHeader(title: l10n.about),
              const SizedBox(height: 8),
            ],
            SettingsSection(
              title: l10n.about,
              child: SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.appTitle, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (packageInfo != null) ...[
                      _AboutVersionUpdateRow(
                        packageInfo: packageInfo,
                        updateState: updateState,
                        onCheck: _checkForUpdates,
                        onShowUpdate: (manifest) {
                          unawaited(_showUpdateDialog(manifest));
                        },
                      ),
                      if (updateState.status == AppUpdateStatus.error) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.updateCheckFailed,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ] else ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: _AboutUpdateButton(
                              state: updateState,
                              onCheck: _checkForUpdates,
                              onShowUpdate: (manifest) {
                                unawaited(_showUpdateDialog(manifest));
                              },
                              compact: constraints.maxWidth < 420,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (isDesktopPlatform) ...[
                      FutureBuilder<String>(
                        future: _appDataPathFuture,
                        builder: (context, snapshot) {
                          final path = snapshot.data;
                          return _AboutPathActionRow(
                            title: l10n.dataDirectory,
                            path: path,
                            copyButtonKey: const Key(
                              'about_data_directory_copy_button',
                            ),
                            openButtonKey: const Key(
                              'about_data_directory_open_button',
                            ),
                            copyLabel: l10n.copyPath,
                            openLabel: l10n.openFolder,
                            onCopy: path == null
                                ? null
                                : () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: path),
                                    );
                                    if (!context.mounted) return;
                                    context.showSnack(l10n.done);
                                  },
                            onOpen: path == null
                                ? null
                                : () {
                                    unawaited(_openFolder(path));
                                  },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<String>(
                        future: _logsPathFuture,
                        builder: (context, snapshot) {
                          final path = snapshot.data;
                          return _AboutPathActionRow(
                            title: l10n.logDirectory,
                            path: path,
                            copyButtonKey: const Key(
                              'about_log_directory_copy_button',
                            ),
                            openButtonKey: const Key(
                              'about_log_directory_open_button',
                            ),
                            copyLabel: l10n.copyPath,
                            openLabel: l10n.openLogFolder,
                            onCopy: path == null
                                ? null
                                : () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: path),
                                    );
                                    if (!context.mounted) return;
                                    context.showSnack(l10n.done);
                                  },
                            onOpen: path == null
                                ? null
                                : () {
                                    unawaited(_openFolder(path));
                                  },
                          );
                        },
                      ),
                    ],
                    if (!isDesktopPlatform) ...[
                      const SizedBox(height: 8),
                      SettingsActionButton(
                        key: const Key('about_export_logs_button'),
                        onPressed: () {
                          unawaited(_exportLogs());
                        },
                        icon: const Icon(FleurIcons.download),
                        label: Text(l10n.exportLogs),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SettingsSection(
              title: l10n.openSourceLicense,
              child: SettingsCard(
                padding: EdgeInsets.zero,
                child: SettingsControlRow(
                  title: Text(l10n.mitLicenseName),
                  control: _AboutActionButtons(
                    children: [
                      SettingsActionButton(
                        key: const Key('about_view_license_button'),
                        onPressed: _showLicenseDialog,
                        icon: const Icon(FleurIcons.document),
                        label: Text(l10n.viewLicense),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SettingsSection(
              title: l10n.thirdPartyLicenses,
              child: SettingsCard(
                padding: EdgeInsets.zero,
                child: SettingsControlRow(
                  title: Text(l10n.viewThirdPartyLicenses),
                  control: _AboutActionButtons(
                    children: [
                      SettingsActionButton(
                        key: const Key('about_third_party_licenses_button'),
                        onPressed: () {
                          showLicensePage(
                            context: context,
                            applicationName: l10n.appTitle,
                            applicationVersion: packageInfo?.version,
                          );
                        },
                        icon: const Icon(FleurIcons.article),
                        label: Text(l10n.viewThirdPartyLicenses),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SettingsSection(
              title: l10n.keyboardShortcuts,
              bottomSpacing: 0,
              child: SettingsCard(
                child: DefaultTextStyle(
                  style: theme.textTheme.bodyMedium!,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.shortcutNextPreviousArticle),
                      Text(l10n.shortcutBackForwardHistory),
                      Text(l10n.shortcutRefreshCurrentSelection),
                      Text(l10n.shortcutToggleUnreadOnly),
                      Text(l10n.shortcutToggleReadUnreadSelectedArticle),
                      Text(l10n.shortcutToggleStarSelectedArticle),
                      Text(l10n.shortcutSearchArticlesAndFindInPage),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AboutPathActionRow extends StatelessWidget {
  const _AboutPathActionRow({
    required this.title,
    required this.path,
    required this.copyButtonKey,
    required this.openButtonKey,
    required this.copyLabel,
    required this.openLabel,
    required this.onCopy,
    required this.onOpen,
  });

  final String title;
  final String? path;
  final Key copyButtonKey;
  final Key openButtonKey;
  final String copyLabel;
  final String openLabel;
  final VoidCallback? onCopy;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SettingsControlRow(
      padding: EdgeInsets.zero,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          SelectableText(path ?? '...', style: theme.textTheme.bodyMedium),
        ],
      ),
      control: _AboutActionButtons(
        children: [
          SettingsActionButton(
            key: copyButtonKey,
            onPressed: onCopy,
            label: Text(copyLabel),
          ),
          SettingsActionButton(
            key: openButtonKey,
            onPressed: onOpen,
            label: Text(openLabel),
          ),
        ],
      ),
    );
  }
}

class _AboutVersionUpdateRow extends StatelessWidget {
  const _AboutVersionUpdateRow({
    required this.packageInfo,
    required this.updateState,
    required this.onCheck,
    required this.onShowUpdate,
  });

  final PackageInfo packageInfo;
  final AppUpdateState updateState;
  final Future<void> Function() onCheck;
  final ValueChanged<AppUpdateManifest> onShowUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final versionBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          l10n.versionAndBuild(packageInfo.version, packageInfo.buildNumber),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (updateState.status == AppUpdateStatus.upToDate) ...[
          const SizedBox(height: 4),
          Text(
            l10n.upToDate,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 420;
        final effectiveUpdateButton = _AboutUpdateButton(
          state: updateState,
          onCheck: onCheck,
          onShowUpdate: onShowUpdate,
          compact: narrow,
        );
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              versionBlock,
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: effectiveUpdateButton,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: versionBlock),
            const SizedBox(width: 12),
            effectiveUpdateButton,
          ],
        );
      },
    );
  }
}

class _AboutUpdateButton extends StatelessWidget {
  const _AboutUpdateButton({
    required this.state,
    required this.onCheck,
    required this.onShowUpdate,
    this.compact = false,
  });

  final AppUpdateState state;
  final Future<void> Function() onCheck;
  final ValueChanged<AppUpdateManifest> onShowUpdate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final checking = state.status == AppUpdateStatus.checking;
    final manifest = state.hasUpdate ? state.manifest : null;
    final label = checking
        ? l10n.checkingForUpdates
        : (manifest == null ? l10n.checkForUpdates : l10n.goToOfficialUpdate);
    final onPressed = checking
        ? null
        : () {
            if (manifest != null) {
              onShowUpdate(manifest);
              return;
            }
            unawaited(onCheck());
          };
    final icon = manifest == null ? FleurIcons.refresh : FleurIcons.download;
    if (compact) {
      return IconButton(
        key: const Key('about_check_updates_button'),
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon),
      );
    }
    return SettingsActionButton(
      key: const Key('about_check_updates_button'),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      variant: manifest == null
          ? SettingsActionButtonVariant.outline
          : SettingsActionButtonVariant.filled,
    );
  }
}

class _AboutActionButtons extends StatelessWidget {
  const _AboutActionButtons({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: children,
      ),
    );
  }
}
