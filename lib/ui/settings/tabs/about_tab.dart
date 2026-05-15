import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../../../l10n/app_localizations.dart';
import '../../../services/logging/app_logger.dart';
import '../../../services/platform/shell_service.dart';
import '../../../theme/fleur_icons.dart';
import '../../../utils/context_extensions.dart';
import '../../../utils/path_manager.dart';
import '../../../utils/platform.dart';
import '../../../widgets/app_scrollbar.dart';
import '../widgets/section_header.dart';

class AboutTab extends StatefulWidget {
  const AboutTab({super.key, this.showPageTitle = true});

  final bool showPageTitle;

  @override
  State<AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<AboutTab> {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDesktopPlatform = isDesktop;

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
                    const SizedBox(height: 12),
                    if (packageInfo != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.version,
                                  style: theme.textTheme.labelLarge,
                                ),
                                const SizedBox(height: 4),
                                SelectableText(packageInfo.version),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.buildNumber,
                                  style: theme.textTheme.labelLarge,
                                ),
                                const SizedBox(height: 4),
                                SelectableText(packageInfo.buildNumber),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (isDesktopPlatform) ...[
                      FutureBuilder<String>(
                        future: _appDataPathFuture,
                        builder: (context, snapshot) {
                          final path = snapshot.data;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.dataDirectory,
                                style: theme.textTheme.labelLarge,
                              ),
                              const SizedBox(height: 4),
                              SelectableText(path ?? '...'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SettingsActionButton(
                                    key: const Key(
                                      'about_data_directory_copy_button',
                                    ),
                                    onPressed: path == null
                                        ? null
                                        : () async {
                                            await Clipboard.setData(
                                              ClipboardData(text: path),
                                            );
                                            if (!context.mounted) return;
                                            context.showSnack(l10n.done);
                                          },
                                    label: Text(l10n.copyPath),
                                  ),
                                  SettingsActionButton(
                                    key: const Key(
                                      'about_data_directory_open_button',
                                    ),
                                    onPressed: path == null
                                        ? null
                                        : () {
                                            unawaited(_openFolder(path));
                                          },
                                    label: Text(l10n.openFolder),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<String>(
                        future: _logsPathFuture,
                        builder: (context, snapshot) {
                          final path = snapshot.data;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.logDirectory,
                                style: theme.textTheme.labelLarge,
                              ),
                              const SizedBox(height: 4),
                              SelectableText(path ?? '...'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SettingsActionButton(
                                    key: const Key(
                                      'about_log_directory_copy_button',
                                    ),
                                    onPressed: path == null
                                        ? null
                                        : () async {
                                            await Clipboard.setData(
                                              ClipboardData(text: path),
                                            );
                                            if (!context.mounted) return;
                                            context.showSnack(l10n.done);
                                          },
                                    label: Text(l10n.copyPath),
                                  ),
                                  SettingsActionButton(
                                    key: const Key(
                                      'about_log_directory_open_button',
                                    ),
                                    onPressed: path == null
                                        ? null
                                        : () {
                                            unawaited(_openFolder(path));
                                          },
                                    label: Text(l10n.openLogFolder),
                                  ),
                                ],
                              ),
                            ],
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.mitLicenseName,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
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
            SettingsSection(
              title: l10n.thirdPartyLicenses,
              child: SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.viewThirdPartyLicenses,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
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
