import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/account_providers.dart';
import '../../providers/app_settings_providers.dart';
import '../../providers/backend_capabilities_provider.dart';
import '../../providers/repository_providers.dart';
import '../../providers/service_providers.dart';
import '../../services/sync/backend_capabilities.dart';
import '../../services/logging/app_logger.dart';
import '../../services/logging/log_context.dart';
import '../../services/sync/remote_subscription_structure_executor.dart';
import '../../services/sync/sync_service.dart';
import '../../services/sync/sync_mutex.dart';
import '../../widgets/app_scrollbar.dart';
import '../actions/remote_structure_feedback.dart' as remote_feedback;
import '../../utils/context_extensions.dart';
import 'text_input_dialog.dart';

@visibleForTesting
String addSubscriptionRemoteStructureFailureMessageForTest(
  AppLocalizations l10n,
  Object error,
) {
  return remote_feedback.remoteStructureFailureMessage(l10n, error);
}

sealed class _CategoryPick {
  const _CategoryPick();
}

final class _CategoryPickUncategorized extends _CategoryPick {
  const _CategoryPickUncategorized();
}

final class _CategoryPickId extends _CategoryPick {
  const _CategoryPickId(this.id);

  final int id;
}

final class _CategoryPickCreate extends _CategoryPick {
  const _CategoryPickCreate();
}

class _AddSubscriptionDialog extends StatefulWidget {
  const _AddSubscriptionDialog();

  @override
  State<_AddSubscriptionDialog> createState() => _AddSubscriptionDialogState();
}

class _AddSubscriptionDialogState extends State<_AddSubscriptionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.addSubscription),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: l10n.feedOrWebsiteUrl,
          hintText: 'https://example.com',
        ),
        autofocus: true,
        keyboardType: TextInputType.url,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.add),
        ),
      ],
    );
  }
}

Future<int?> showAddSubscriptionDialog(
  BuildContext context,
  WidgetRef ref, {
  NavigatorState? navigator,
  int? initialCategoryId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final nav = navigator ?? Navigator.of(context);

  final account = ref.read(activeAccountProvider);
  final capabilities = ref.read(backendCapabilitiesProvider);
  const feature = BackendFeature.addSubscription;
  final addSubscriptionAvailability = capabilities.availability(feature);
  if (!capabilities.isVisible(feature)) {
    if (context.mounted) {
      context.showSnack(l10n.errorMessage(l10n.remoteCommandNotSupported));
    }
    return null;
  }

  final url = await nav.push<String?>(
    DialogRoute<String?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      useSafeArea: true,
      builder: (context) => const _AddSubscriptionDialog(),
    ),
  );
  if (url == null || url.trim().isEmpty) return null;
  if (!context.mounted) return null;

  final rootNav = Navigator.of(context, rootNavigator: true);

  String remoteStructureFailureMessage(Object error) {
    return remote_feedback.remoteStructureFailureMessage(l10n, error);
  }

  Map<String, Object?> addSubscriptionFailureContext(
    Object error,
    String operation,
  ) {
    final extra = <String, Object?>{
      'accountId': account.id,
      'accountType': capabilities.diagnosticAccountType,
      'operation': operation,
    };
    if (error is DioException) {
      return logContextForDioException(error, extra: extra);
    }
    final baseUrl = account.baseUrl?.trim();
    final uri = baseUrl == null || baseUrl.isEmpty
        ? null
        : Uri.tryParse(baseUrl);
    if (uri == null) return extra;
    return logContextForUri(uri, extra: extra);
  }

  void logAddSubscriptionFailure(
    String operation,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    AppLogger.w(
      'Add subscription failed',
      tag: 'subscription',
      error: error,
      stackTrace: stackTrace,
      context: addSubscriptionFailureContext(error, operation),
    );
  }

  void showRemoteStructureFailure(
    Object error, {
    String operation = 'addSubscription',
    StackTrace? stackTrace,
  }) {
    logAddSubscriptionFailure(operation, error, stackTrace);
    if (!context.mounted) return;
    context.showSnack(l10n.errorMessage(remoteStructureFailureMessage(error)));
  }

  Future<T> showBlockingProgress<T>(
    String message,
    Future<T> Function() op,
  ) async {
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
                  Expanded(child: Text(message)),
                ],
              ),
            ),
          );
        },
      ).then((_) {}),
    );
    try {
      return await op();
    } finally {
      try {
        if (rootNav.mounted && rootNav.canPop()) rootNav.pop();
      } catch (_) {
        // ignore: best-effort
      }
    }
  }

  Future<Uri?> resolveFeedUri(String input) async {
    final appSettings = ref.read(appSettingsProvider).valueOrNull;
    final ua = (appSettings?.webUserAgent ?? '').trim().isEmpty
        ? null
        : appSettings!.webUserAgent.trim();

    final candidates = await ref
        .read(feedDiscoveryServiceProvider)
        .discover(input, userAgent: ua);

    if (candidates.isEmpty) return null;

    if (candidates.length == 1) {
      return Uri.tryParse(candidates.first.url);
    }

    if (!context.mounted) return null;
    final candidateDialogHeight = (MediaQuery.sizeOf(context).height * 0.6)
        .clamp(200.0, 420.0)
        .toDouble();
    final picked = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.selectFeed),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: candidateDialogHeight,
            ),
            child: AppScrollbar(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final c in candidates)
                      () {
                        final title = (c.title ?? '').trim().isEmpty
                            ? c.url
                            : c.title!.trim();
                        final subtitle = title == c.url ? null : c.url;
                        return ListTile(
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: subtitle == null
                              ? null
                              : Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: () => Navigator.of(context).pop(c.url),
                        );
                      }(),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
    if (picked == null) return null;
    return Uri.tryParse(picked);
  }

  Uri? feedUri;
  try {
    feedUri = await showBlockingProgress(
      l10n.discoveringFeeds,
      () => resolveFeedUri(url),
    );
  } catch (e, s) {
    logAddSubscriptionFailure('discoverFeed', e, s);
    if (context.mounted) {
      context.showSnack(l10n.errorMessage(e.toString()));
    }
    return null;
  }
  if (feedUri == null) {
    if (context.mounted) {
      context.showSnack(l10n.errorMessage(l10n.noFeedsFound));
    }
    return null;
  }

  Future<({bool canceled, int? categoryId})> pickLocalCategoryId() async {
    while (true) {
      final cats = await ref.read(categoryRepositoryProvider).getAll();
      cats.sort((a, b) => a.name.compareTo(b.name));
      if (!context.mounted) return (canceled: true, categoryId: null);

      final picked = await showDialog<_CategoryPick?>(
        context: context,
        builder: (context) {
          return SimpleDialog(
            title: Text(l10n.selectCategory),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.of(
                  context,
                ).pop(const _CategoryPickUncategorized()),
                child: Text(l10n.uncategorized),
              ),
              for (final c in cats)
                SimpleDialogOption(
                  onPressed: () =>
                      Navigator.of(context).pop(_CategoryPickId(c.id)),
                  child: Text(c.name),
                ),
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.of(context).pop(const _CategoryPickCreate()),
                child: Text(l10n.newCategory),
              ),
            ],
          );
        },
      );

      if (picked == null) return (canceled: true, categoryId: null);

      switch (picked) {
        case _CategoryPickUncategorized():
          return (canceled: false, categoryId: null);
        case _CategoryPickId(:final id):
          return (canceled: false, categoryId: id);
        case _CategoryPickCreate():
          if (!context.mounted) return (canceled: true, categoryId: null);
          final name = await showTextInputDialog(
            context,
            title: l10n.newCategory,
            labelText: l10n.name,
            confirmText: l10n.create,
          );
          if (name == null) continue;
          final trimmed = name.trim();
          if (trimmed.isEmpty) continue;
          try {
            final id = await ref
                .read(categoryRepositoryProvider)
                .upsertByName(trimmed);
            return (canceled: false, categoryId: id);
          } catch (e, s) {
            if (!context.mounted) {
              return (canceled: true, categoryId: null);
            }
            showRemoteStructureFailure(
              e,
              operation: 'createLocalCategoryForSubscription',
              stackTrace: s,
            );
          }
      }
    }
  }

  Future<MinifluxRemoteSubscriptionStructureExecutor>
  buildMinifluxStructureExecutor() async {
    final client = await ref
        .read(remoteClientFactoryProvider)
        .miniflux(account);
    return MinifluxRemoteSubscriptionStructureExecutor(client);
  }

  Future<({bool canceled, int? categoryId})> pickMinifluxCategoryId(
    RemoteSubscriptionStructureExecutor executor,
  ) async {
    while (true) {
      late final List<Map<String, Object?>> rawCats;
      try {
        rawCats = await showBlockingProgress(
          l10n.loadingCategories,
          executor.listCategories,
        );
      } catch (e, s) {
        if (context.mounted) {
          showRemoteStructureFailure(
            e,
            operation: 'listRemoteCategories',
            stackTrace: s,
          );
        }
        return (canceled: true, categoryId: null);
      }
      final cats =
          rawCats
              .where((c) => c['id'] is int && c['title'] is String)
              .map(
                (c) =>
                    (id: c['id'] as int, title: (c['title'] as String).trim()),
              )
              .where((c) => c.id > 0 && c.title.isNotEmpty)
              .toList(growable: false)
            ..sort((a, b) => a.title.compareTo(b.title));

      if (!context.mounted) return (canceled: true, categoryId: null);

      final picked = await showDialog<_CategoryPick?>(
        context: context,
        builder: (context) {
          return SimpleDialog(
            title: Text(l10n.selectCategory),
            children: [
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.of(context).pop(const _CategoryPickCreate()),
                child: Text(l10n.newCategory),
              ),
              for (final c in cats)
                SimpleDialogOption(
                  onPressed: () =>
                      Navigator.of(context).pop(_CategoryPickId(c.id)),
                  child: Text(c.title),
                ),
            ],
          );
        },
      );

      if (picked == null) return (canceled: true, categoryId: null);

      switch (picked) {
        case _CategoryPickId(:final id):
          return (canceled: false, categoryId: id);
        case _CategoryPickCreate():
          if (!context.mounted) return (canceled: true, categoryId: null);
          final name = await showTextInputDialog(
            context,
            title: l10n.newCategory,
            labelText: l10n.name,
            confirmText: l10n.create,
          );
          if (name == null) continue;
          final trimmed = name.trim();
          if (trimmed.isEmpty) continue;
          try {
            final created = await showBlockingProgress(
              l10n.creatingCategory,
              () => executor.createCategory(trimmed),
            );
            final id = created['id'];
            if (id is! int || id <= 0) {
              throw StateError(
                'Unexpected Miniflux response for create category',
              );
            }
            return (canceled: false, categoryId: id);
          } catch (e, s) {
            if (!context.mounted) {
              return (canceled: true, categoryId: null);
            }
            showRemoteStructureFailure(
              e,
              operation: 'createRemoteCategoryForSubscription',
              stackTrace: s,
            );
          }
        case _CategoryPickUncategorized():
          // Not reachable for Miniflux: we don't show this option.
          continue;
      }
    }
  }

  Future<int?> resolveFeedIdByUrl(String url) async {
    String normalize(String input) {
      return input.trim().replaceAll(RegExp(r'/+$'), '');
    }

    final feeds = ref.read(feedRepositoryProvider);
    final direct = await feeds.getByUrl(url);
    if (direct != null) return direct.id;

    final target = normalize(url);
    if (target.isNotEmpty && target != url.trim()) {
      final alt = await feeds.getByUrl(target);
      if (alt != null) return alt.id;
    }
    if (target.isNotEmpty) {
      final alt = await feeds.getByUrl('$target/');
      if (alt != null) return alt.id;
    }

    final all = await feeds.getAll();
    for (final f in all) {
      if (normalize(f.url) == target) return f.id;
    }
    return null;
  }

  if (addSubscriptionAvailability != FeatureAvailability.onlineRequired) {
    final catPick = initialCategoryId == null
        ? await pickLocalCategoryId()
        : (canceled: false, categoryId: initialCategoryId);
    if (catPick.canceled) return null;

    final id = await ref
        .read(feedRepositoryProvider)
        .upsertUrl(feedUri.toString());
    await ref
        .read(feedRepositoryProvider)
        .setCategory(feedId: id, categoryId: catPick.categoryId);

    final r = await showBlockingProgress(
      l10n.addingSubscription,
      () => ref.read(syncServiceProvider).refreshFeedSafe(id),
    );
    if (!context.mounted) return id;
    context.showSnack(
      r.ok ? l10n.addedAndSynced : l10n.errorMessage(r.error.toString()),
    );
    return id;
  }

  MinifluxRemoteSubscriptionStructureExecutor executor;
  try {
    executor = await buildMinifluxStructureExecutor();
  } catch (e, s) {
    showRemoteStructureFailure(
      e,
      operation: 'buildRemoteSubscriptionClient',
      stackTrace: s,
    );
    return null;
  }

  int? initialRemoteCategoryId;
  if (initialCategoryId != null) {
    final category = await ref
        .read(categoryRepositoryProvider)
        .getById(initialCategoryId);
    final remoteId = int.tryParse((category?.remoteId ?? '').trim());
    if (remoteId != null && remoteId > 0) {
      initialRemoteCategoryId = remoteId;
    }
  }

  int? categoryId = initialRemoteCategoryId;
  if (categoryId == null) {
    final catPick = await pickMinifluxCategoryId(executor);
    if (catPick.canceled) return null;
    categoryId = catPick.categoryId;
  }
  final effectiveCategoryId = categoryId;
  if (effectiveCategoryId == null || effectiveCategoryId <= 0) return null;

  BatchRefreshResult batch;
  try {
    batch = await showBlockingProgress(l10n.addingSubscription, () async {
      return SyncMutex.instance.run('sync', () async {
        await executor.createFeed(
          feedUrl: feedUri.toString(),
          categoryId: effectiveCategoryId,
        );
        return ref.read(syncServiceProvider).refreshFeedsSafe(const []);
      });
    });
  } catch (e, s) {
    showRemoteStructureFailure(
      e,
      operation: 'createRemoteSubscription',
      stackTrace: s,
    );
    return null;
  }

  final id = await resolveFeedIdByUrl(feedUri.toString());
  if (!context.mounted) return id;
  final err = batch.firstError?.error;
  context.showSnack(
    err == null ? l10n.addedAndSynced : l10n.errorMessage(err.toString()),
  );
  return id;
}
