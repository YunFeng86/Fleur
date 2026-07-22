import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fleur/features/accounts/accounts.dart';

import '../../../l10n/app_localizations.dart';
import '../application/subscription_structure_commands.dart';
import '../../../providers/backend_capabilities_provider.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/service_providers.dart';
import '../../../services/sync/backend_capabilities.dart';
import '../../../services/sync/remote_subscription_structure_executor.dart';
import '../../../utils/context_extensions.dart';
import 'add_subscription_screen.dart';
import 'subscription_remote_feedback.dart' as remote_feedback;

typedef SubscriptionStructureDialogPresenter =
    Future<T?> Function<T>({required WidgetBuilder builder});

abstract final class SubscriptionStructureActions {
  static BackendCapabilities _capabilities(WidgetRef ref) {
    return ref.read(backendCapabilitiesProvider);
  }

  static bool _isOnlineRequired(
    BackendCapabilities capabilities,
    BackendFeature feature,
  ) {
    return capabilities.availability(feature) ==
        FeatureAvailability.onlineRequired;
  }

  static Future<MinifluxRemoteSubscriptionStructureExecutor>
  _buildMinifluxStructureExecutorFromRead(
    WidgetRef ref,
    Account account,
  ) async {
    final client = await ref
        .read(remoteClientFactoryProvider)
        .miniflux(account);
    return MinifluxRemoteSubscriptionStructureExecutor(client);
  }

  static SubscriptionStructureCommands _structureCommands(WidgetRef ref) {
    final account = ref.read(activeAccountProvider);
    return SubscriptionStructureCommands(
      capabilities: _capabilities(ref),
      account: account,
      feeds: ref.read(feedRepositoryProvider),
      categories: ref.read(categoryRepositoryProvider),
      buildExecutor: () =>
          _buildMinifluxStructureExecutorFromRead(ref, account),
    );
  }

  static Future<T?> _presentDialog<T>(
    BuildContext context, {
    SubscriptionStructureDialogPresenter? dialogPresenter,
    required WidgetBuilder builder,
  }) {
    if (dialogPresenter != null) {
      return dialogPresenter<T>(builder: builder);
    }
    return showDialog<T>(context: context, builder: builder);
  }

  static Future<String?> _presentTextInputDialog(
    BuildContext context, {
    SubscriptionStructureDialogPresenter? dialogPresenter,
    required String title,
    String? labelText,
    String initialText = '',
    String? confirmText,
  }) async {
    final controller = TextEditingController(text: initialText);
    try {
      return _presentDialog<String>(
        context,
        dialogPresenter: dialogPresenter,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(labelText: labelText),
              autofocus: true,
              onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  MaterialLocalizations.of(dialogContext).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text),
                child: Text(
                  confirmText ??
                      MaterialLocalizations.of(dialogContext).okButtonLabel,
                ),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  static Future<int?> addFeed(
    BuildContext context,
    WidgetRef ref, {
    NavigatorState? navigator,
    int? initialCategoryId,
  }) async {
    final capabilities = _capabilities(ref);
    if (!capabilities.isVisible(BackendFeature.addSubscription)) {
      final l10n = AppLocalizations.of(context)!;
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return null;
    }

    final location = _addSubscriptionLocation(
      initialCategoryId: initialCategoryId,
    );
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(location);
      return null;
    }

    await (navigator ?? Navigator.of(context)).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            AddSubscriptionScreen(initialCategoryId: initialCategoryId),
      ),
    );
    return null;
  }

  static String _addSubscriptionLocation({int? initialCategoryId}) {
    if (initialCategoryId == null) return '/add-subscription';
    return Uri(
      path: '/add-subscription',
      queryParameters: <String, String>{
        'categoryId': initialCategoryId.toString(),
      },
    ).toString();
  }

  static Future<int?> addCategory(
    BuildContext context,
    WidgetRef ref, {
    SubscriptionStructureDialogPresenter? dialogPresenter,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = _capabilities(ref);
    const feature = BackendFeature.addCategory;
    if (!capabilities.isVisible(feature)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return null;
    }

    final name = await _presentTextInputDialog(
      context,
      dialogPresenter: dialogPresenter,
      title: l10n.newCategory,
      labelText: l10n.name,
      confirmText: l10n.create,
    );
    if (!context.mounted) return null;
    if (name == null || name.trim().isEmpty) return null;

    try {
      return await _structureCommands(ref).addCategory(name);
    } catch (error, stackTrace) {
      remote_feedback.logSubscriptionFailure(
        ref,
        'createCategory',
        error,
        stackTrace,
      );
      if (!context.mounted) return null;
      remote_feedback.showRemoteStructureFailure(context, l10n, error);
      return null;
    }
  }

  static Future<void> renameCategory(
    BuildContext context,
    WidgetRef ref, {
    required int categoryId,
    required String currentName,
    SubscriptionStructureDialogPresenter? dialogPresenter,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = _capabilities(ref);
    const feature = BackendFeature.renameCategory;
    if (!capabilities.isVisible(feature)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return;
    }

    final next = await _presentTextInputDialog(
      context,
      dialogPresenter: dialogPresenter,
      title: l10n.rename,
      labelText: l10n.name,
      initialText: currentName,
      confirmText: l10n.done,
    );
    if (!context.mounted) return;
    if (next == null) return;

    final trimmed = next.trim();
    if (trimmed.isEmpty) return;

    if (!_isOnlineRequired(capabilities, feature)) {
      try {
        await _structureCommands(ref).renameCategory(
          categoryId: categoryId,
          currentName: currentName,
          nextName: trimmed,
        );
      } catch (e) {
        if (!context.mounted) return;
        final msg = e.toString().contains('already exists')
            ? l10n.nameAlreadyExists
            : e.toString();
        context.showErrorMessage(l10n.errorMessage(msg));
      }
      return;
    }

    try {
      await _structureCommands(ref).renameCategory(
        categoryId: categoryId,
        currentName: currentName,
        nextName: trimmed,
      );
    } on CategoryNameConflictException {
      if (!context.mounted) return;
      context.showErrorMessage(l10n.errorMessage(l10n.nameAlreadyExists));
    } catch (error, stackTrace) {
      remote_feedback.logSubscriptionFailure(
        ref,
        'renameCategory',
        error,
        stackTrace,
      );
      if (!context.mounted) return;
      remote_feedback.showRemoteStructureFailure(context, l10n, error);
    }
  }

  static Future<bool> deleteCategory(
    BuildContext context,
    WidgetRef ref, {
    required int categoryId,
    SubscriptionStructureDialogPresenter? dialogPresenter,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = _capabilities(ref);
    if (!capabilities.isVisible(BackendFeature.deleteCategory)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return false;
    }
    final isOnlineRequired = _isOnlineRequired(
      capabilities,
      BackendFeature.deleteCategory,
    );
    final ok = await _presentDialog<bool>(
      context,
      dialogPresenter: dialogPresenter,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteCategoryConfirmTitle),
          content: Text(
            isOnlineRequired
                ? l10n.remoteDeleteCategoryConfirmContent
                : l10n.deleteCategoryConfirmContent,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (!context.mounted) return false;
    if (ok != true) return false;

    return _deleteCategoryConfirmed(context, ref, categoryId);
  }

  static Future<bool> _deleteCategoryConfirmed(
    BuildContext context,
    WidgetRef ref,
    int categoryId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (!_capabilities(ref).isVisible(BackendFeature.deleteCategory)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return false;
    }

    try {
      await _structureCommands(ref).deleteCategory(categoryId);
      if (!context.mounted) return true;
      context.showSnack(l10n.categoryDeleted);
      return true;
    } catch (error, stackTrace) {
      remote_feedback.logSubscriptionFailure(
        ref,
        'deleteCategory',
        error,
        stackTrace,
      );
      if (!context.mounted) return false;
      remote_feedback.showRemoteStructureFailure(context, l10n, error);
      return false;
    }
  }

  static Future<void> editFeedTitle(
    BuildContext context,
    WidgetRef ref, {
    required int feedId,
    required String? currentTitle,
    SubscriptionStructureDialogPresenter? dialogPresenter,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentTitle ?? '');
    try {
      final next = await _presentDialog<String?>(
        context,
        dialogPresenter: dialogPresenter,
        builder: (context) {
          return buildEditFeedTitleDialog(
            context,
            l10n: l10n,
            controller: controller,
          );
        },
      );
      if (next == null) return;
      await ref
          .read(feedRepositoryProvider)
          .setUserTitle(feedId: feedId, userTitle: next);
    } finally {
      controller.dispose();
    }
  }

  static Widget buildEditFeedTitleDialog(
    BuildContext context, {
    required AppLocalizations l10n,
    required TextEditingController controller,
  }) {
    return AlertDialog(
      title: Text(l10n.edit),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: l10n.name),
        autofocus: true,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(''),
          child: Text(l10n.delete),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(l10n.done),
        ),
      ],
    );
  }

  static Future<bool> deleteFeed(
    BuildContext context,
    WidgetRef ref, {
    required int feedId,
    SubscriptionStructureDialogPresenter? dialogPresenter,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (!_capabilities(ref).isVisible(BackendFeature.deleteSubscription)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return false;
    }

    final ok = await _presentDialog<bool>(
      context,
      dialogPresenter: dialogPresenter,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteSubscriptionConfirmTitle),
          content: Text(l10n.deleteSubscriptionConfirmContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
    if (!context.mounted) return false;
    if (ok != true) return false;

    return _deleteFeedConfirmed(context, ref, feedId);
  }

  static Future<bool> _deleteFeedConfirmed(
    BuildContext context,
    WidgetRef ref,
    int feedId,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = _capabilities(ref);
    if (!capabilities.isVisible(BackendFeature.deleteSubscription)) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return false;
    }

    try {
      await _structureCommands(ref).deleteFeed(feedId);
      if (!context.mounted) return true;
      context.showSnack(l10n.deleted);
      return true;
    } catch (error, stackTrace) {
      remote_feedback.logSubscriptionFailure(
        ref,
        'deleteFeed',
        error,
        stackTrace,
      );
      if (!context.mounted) return false;
      remote_feedback.showRemoteStructureFailure(context, l10n, error);
      return false;
    }
  }

  static Future<void> moveFeedToCategory(
    BuildContext context,
    WidgetRef ref, {
    required int feedId,
    SubscriptionStructureDialogPresenter? dialogPresenter,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final capabilities = _capabilities(ref);
    final canMoveToCategory = capabilities.isVisible(
      BackendFeature.moveSubscriptionToCategory,
    );
    final canMoveToUncategorized = capabilities.isVisible(
      BackendFeature.moveSubscriptionToUncategorized,
    );
    if (!canMoveToCategory && !canMoveToUncategorized) {
      remote_feedback.showUnsupportedRemoteCommand(context, l10n);
      return;
    }

    final isOnlineRequired = _isOnlineRequired(
      capabilities,
      BackendFeature.moveSubscriptionToCategory,
    );
    final cats = await ref.read(categoryRepositoryProvider).getAll();
    if (!context.mounted) return;

    if (!canMoveToUncategorized && cats.isEmpty) {
      context.showErrorMessage(l10n.remoteCommandRequiresCategory);
      return;
    }

    final selected = await _presentDialog<_MoveFeedCategoryPick?>(
      context,
      dialogPresenter: dialogPresenter,
      builder: (context) {
        return SimpleDialog(
          title: Text(l10n.moveToCategory),
          children: [
            if (canMoveToUncategorized)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.of(context).pop(const _MoveFeedToUncategorized()),
                child: Text(l10n.uncategorized),
              ),
            for (final c in cats)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.of(context).pop(_MoveFeedToCategory(c.id)),
                child: Text(c.name),
              ),
          ],
        );
      },
    );

    if (selected == null) return;

    final categoryId = switch (selected) {
      _MoveFeedToUncategorized() => null,
      _MoveFeedToCategory(:final categoryId) => categoryId,
    };

    if (!isOnlineRequired) {
      await _structureCommands(
        ref,
      ).moveFeedToCategory(feedId: feedId, categoryId: categoryId);
      return;
    }

    final feature = categoryId == null
        ? BackendFeature.moveSubscriptionToUncategorized
        : BackendFeature.moveSubscriptionToCategory;
    if (!capabilities.isVisible(feature)) {
      final message = categoryId == null
          ? l10n.remoteCommandRequiresCategory
          : l10n.remoteCommandNotSupported;
      if (!context.mounted) return;
      context.showErrorMessage(message);
      return;
    }

    try {
      await _structureCommands(
        ref,
      ).moveFeedToCategory(feedId: feedId, categoryId: categoryId);
    } catch (error, stackTrace) {
      remote_feedback.logSubscriptionFailure(
        ref,
        'moveFeedToCategory',
        error,
        stackTrace,
      );
      if (!context.mounted) return;
      remote_feedback.showRemoteStructureFailure(context, l10n, error);
    }
  }
}

sealed class _MoveFeedCategoryPick {
  const _MoveFeedCategoryPick();
}

final class _MoveFeedToUncategorized extends _MoveFeedCategoryPick {
  const _MoveFeedToUncategorized();
}

final class _MoveFeedToCategory extends _MoveFeedCategoryPick {
  const _MoveFeedToCategory(this.categoryId);

  final int categoryId;
}
