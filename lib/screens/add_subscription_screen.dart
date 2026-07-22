import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/article_scope_routes.dart';
import '../features/subscriptions/subscriptions.dart';
import '../l10n/app_localizations.dart';
import '../models/article_scope.dart';
import '../providers/add_subscription_controller.dart';
import '../services/rss/feed_discovery_service.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../ui/actions/remote_structure_feedback.dart' as remote_feedback;
import '../ui/app_drawer_scope.dart';
import '../ui/design_system/design_system.dart';
import '../utils/context_extensions.dart';
import '../utils/platform.dart';
import '../widgets/app_scrollbar.dart';
import '../widgets/staggered_reveal.dart';

class AddSubscriptionScreen extends ConsumerStatefulWidget {
  const AddSubscriptionScreen({super.key, this.initialCategoryId});

  final int? initialCategoryId;

  @override
  ConsumerState<AddSubscriptionScreen> createState() =>
      _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends ConsumerState<AddSubscriptionScreen> {
  static const _contentMaxWidth = 720.0;

  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _urlFocusNode = FocusNode();

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _discover() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    unawaited(
      ref
          .read(addSubscriptionControllerProvider.notifier)
          .discover(
            _urlController.text,
            initialCategoryId: widget.initialCategoryId,
          ),
    );
  }

  void _submitCandidate(AddSubscriptionCandidate candidate) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) {
          return _AddSubscriptionConfirmDialog(candidate: candidate);
        },
      ),
    );
  }

  void _moveCandidateToSelectedCategory(AddSubscriptionCandidate candidate) {
    unawaited(
      ref
          .read(addSubscriptionControllerProvider.notifier)
          .moveCandidateToSelectedCategory(candidate),
    );
  }

  void _viewSubscription(int feedId) {
    SubscriptionFeedBrowsing.selectFeed(ref.read, feedId);
    context.go(scopeLocation(ArticleScope.feed(feedId)));
  }

  void _continueAdding() {
    ref.read(addSubscriptionControllerProvider.notifier).reset();
    _urlController.clear();
    _urlFocusNode.requestFocus();
  }

  void _finish() {
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(addSubscriptionControllerProvider);
    final useCompactTopBar = !isDesktop;
    final surfaces = Theme.of(context).fleurSurface;

    ref.listen<AddSubscriptionState>(addSubscriptionControllerProvider, (
      previous,
      next,
    ) {
      final completedFeedId = next.completedFeedId;
      if (completedFeedId != null &&
          completedFeedId != previous?.completedFeedId) {
        final failure = next.failure;
        if (failure == null) {
          context.showSnack(l10n.subscriptionAddedTitle);
        } else {
          context.showErrorMessage(_failureMessage(l10n, failure));
        }
        return;
      }

      final failure = next.failure;
      if (next.phase == AddSubscriptionPhase.error &&
          failure != null &&
          failure != previous?.failure) {
        context.showErrorMessage(_failureMessage(l10n, failure));
      }
    });

    final content = Material(
      color: surfaces.chrome,
      child: AppScrollbar(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                  child: StaggeredReveal(
                    enabled: isDesktop,
                    child: _AddSubscriptionTask(
                      formKey: _formKey,
                      urlController: _urlController,
                      urlFocusNode: _urlFocusNode,
                      state: state,
                      onDiscover: _discover,
                      onSubmitCandidate: _submitCandidate,
                      onMoveCandidateToSelectedCategory:
                          _moveCandidateToSelectedCategory,
                      onViewSubscription: _viewSubscription,
                      onContinueAdding: _continueAdding,
                      onDone: _finish,
                      onInputChanged: (value) {
                        final current = ref.read(
                          addSubscriptionControllerProvider,
                        );
                        if (!current.isBusy &&
                            current.phase != AddSubscriptionPhase.idle &&
                            value.trim() != current.input) {
                          ref
                              .read(addSubscriptionControllerProvider.notifier)
                              .reset();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!useCompactTopBar) return content;

    return Scaffold(
      appBar: AppBar(
        leading: AppDrawerScope.drawerLeading(context),
        title: Text(l10n.addSubscription),
      ),
      body: content,
    );
  }

  String _failureMessage(
    AppLocalizations l10n,
    AddSubscriptionFailure failure,
  ) {
    return switch (failure.kind) {
      AddSubscriptionFailureKind.unsupported => l10n.remoteCommandNotSupported,
      AddSubscriptionFailureKind.validation => l10n.selectCategory,
      AddSubscriptionFailureKind.noFeedsFound =>
        '${l10n.noFeedsFound}\n${l10n.noFeedsFoundHint}',
      AddSubscriptionFailureKind.remoteStructure =>
        failure.error == null
            ? l10n.remoteCommandUnavailable
            : remote_feedback.remoteStructureFailureMessage(
                l10n,
                failure.error!,
              ),
      AddSubscriptionFailureKind.discovery ||
      AddSubscriptionFailureKind.category ||
      AddSubscriptionFailureKind.submit =>
        failure.error?.toString() ?? l10n.remoteCommandUnavailable,
    };
  }
}

class _AddSubscriptionTask extends ConsumerWidget {
  const _AddSubscriptionTask({
    required this.formKey,
    required this.urlController,
    required this.urlFocusNode,
    required this.state,
    required this.onDiscover,
    required this.onSubmitCandidate,
    required this.onMoveCandidateToSelectedCategory,
    required this.onViewSubscription,
    required this.onContinueAdding,
    required this.onDone,
    required this.onInputChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController urlController;
  final FocusNode urlFocusNode;
  final AddSubscriptionState state;
  final VoidCallback onDiscover;
  final ValueChanged<AddSubscriptionCandidate> onSubmitCandidate;
  final ValueChanged<AddSubscriptionCandidate>
  onMoveCandidateToSelectedCategory;
  final ValueChanged<int> onViewSubscription;
  final VoidCallback onContinueAdding;
  final VoidCallback onDone;
  final ValueChanged<String> onInputChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final failure = state.failure;
    final hasResults = state.candidates.isNotEmpty;

    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.addSubscription,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 18),
          _DiscoveryInput(
            urlController: urlController,
            urlFocusNode: urlFocusNode,
            enabled: !state.isBusy,
            onChanged: onInputChanged,
            onDiscover: onDiscover,
          ),
          if (_showsProgress(state.phase)) ...[
            const SizedBox(height: 18),
            _ProgressStatus(text: _progressText(l10n, state.phase)),
          ],
          if (failure != null) ...[
            const SizedBox(height: 16),
            _InlineFailure(message: _failureMessage(l10n, failure)),
          ],
          if (state.refreshWarning != null) ...[
            const SizedBox(height: 16),
            _InlineWarning(message: l10n.subscriptionRefreshWarning),
          ],
          if (hasResults) ...[
            const SizedBox(height: 22),
            _SectionSurface(
              key: const Key('add_subscription_results'),
              title: l10n.subscriptionResultsFound(state.candidates.length),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SubscriptionResultList(
                    state: state,
                    onSubmitCandidate: onSubmitCandidate,
                    onMoveCandidateToSelectedCategory:
                        onMoveCandidateToSelectedCategory,
                    onViewSubscription: onViewSubscription,
                  ),
                ],
              ),
            ),
          ],
          if (hasResults) ...[
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  key: const Key('add_subscription_done_button'),
                  onPressed: onDone,
                  child: Text(l10n.done),
                ),
                OutlinedButton.icon(
                  key: const Key('add_subscription_continue_button'),
                  onPressed: state.isBusy ? null : onContinueAdding,
                  icon: const Icon(FleurIcons.add),
                  label: Text(l10n.continueAddingSubscription),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _showsProgress(AddSubscriptionPhase phase) {
    return switch (phase) {
      AddSubscriptionPhase.discovering ||
      AddSubscriptionPhase.loadingCategories ||
      AddSubscriptionPhase.creatingCategory => true,
      AddSubscriptionPhase.idle ||
      AddSubscriptionPhase.selectingFeed ||
      AddSubscriptionPhase.selectingCategory ||
      AddSubscriptionPhase.submitting ||
      AddSubscriptionPhase.alreadySubscribed ||
      AddSubscriptionPhase.success ||
      AddSubscriptionPhase.error => false,
    };
  }

  String _progressText(AppLocalizations l10n, AddSubscriptionPhase phase) {
    return switch (phase) {
      AddSubscriptionPhase.discovering => l10n.discoveringFeeds,
      AddSubscriptionPhase.loadingCategories => l10n.loadingCategories,
      AddSubscriptionPhase.creatingCategory => l10n.creatingCategory,
      AddSubscriptionPhase.submitting => l10n.addingSubscription,
      AddSubscriptionPhase.idle ||
      AddSubscriptionPhase.selectingFeed ||
      AddSubscriptionPhase.selectingCategory ||
      AddSubscriptionPhase.alreadySubscribed ||
      AddSubscriptionPhase.success ||
      AddSubscriptionPhase.error => l10n.addingSubscription,
    };
  }

  String _failureMessage(
    AppLocalizations l10n,
    AddSubscriptionFailure failure,
  ) {
    return switch (failure.kind) {
      AddSubscriptionFailureKind.unsupported => l10n.remoteCommandNotSupported,
      AddSubscriptionFailureKind.validation => l10n.selectCategory,
      AddSubscriptionFailureKind.noFeedsFound =>
        '${l10n.noFeedsFound}\n${l10n.noFeedsFoundHint}',
      AddSubscriptionFailureKind.remoteStructure =>
        failure.error == null
            ? l10n.remoteCommandUnavailable
            : remote_feedback.remoteStructureFailureMessage(
                l10n,
                failure.error!,
              ),
      AddSubscriptionFailureKind.discovery ||
      AddSubscriptionFailureKind.category ||
      AddSubscriptionFailureKind.submit =>
        failure.error?.toString() ?? l10n.remoteCommandUnavailable,
    };
  }
}

class _DiscoveryInput extends StatelessWidget {
  const _DiscoveryInput({
    required this.urlController,
    required this.urlFocusNode,
    required this.enabled,
    required this.onChanged,
    required this.onDiscover,
  });

  final TextEditingController urlController;
  final FocusNode urlFocusNode;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final field = TextFormField(
          key: const Key('add_subscription_url_field'),
          controller: urlController,
          focusNode: urlFocusNode,
          autofocus: true,
          enabled: enabled,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: l10n.feedOrWebsiteUrl,
            hintText: 'https://example.com',
            helperText: l10n.feedOrWebsiteUrlHint,
            prefixIcon: const Icon(FleurIcons.feed),
          ),
          validator: (value) {
            if ((value ?? '').trim().isEmpty) {
              return l10n.feedOrWebsiteUrl;
            }
            return null;
          },
          onChanged: onChanged,
          onFieldSubmitted: (_) => onDiscover(),
        );
        final button = FilledButton.icon(
          key: const Key('add_subscription_discover_button'),
          onPressed: enabled ? onDiscover : null,
          icon: const Icon(FleurIcons.search),
          label: Text(l10n.findFeeds),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [field, const SizedBox(height: 12), button],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: field),
            const SizedBox(width: 12),
            Padding(padding: const EdgeInsets.only(top: 4), child: button),
          ],
        );
      },
    );
  }
}

class _ProgressStatus extends StatelessWidget {
  const _ProgressStatus({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('add_subscription_progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }
}

class _InlineFailure extends StatelessWidget {
  const _InlineFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      key: const Key('add_subscription_error'),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      key: const Key('add_subscription_warning'),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              FleurIcons.syncWarning,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionResultList extends StatelessWidget {
  const _SubscriptionResultList({
    required this.state,
    required this.onSubmitCandidate,
    required this.onMoveCandidateToSelectedCategory,
    required this.onViewSubscription,
  });

  final AddSubscriptionState state;
  final ValueChanged<AddSubscriptionCandidate> onSubmitCandidate;
  final ValueChanged<AddSubscriptionCandidate>
  onMoveCandidateToSelectedCategory;
  final ValueChanged<int> onViewSubscription;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < state.candidates.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _SubscriptionResultRow(
            candidate: state.candidates[i],
            state: state,
            onSubmitCandidate: onSubmitCandidate,
            onMoveCandidateToSelectedCategory:
                onMoveCandidateToSelectedCategory,
            onViewSubscription: onViewSubscription,
          ),
        ],
      ],
    );
  }
}

class _SubscriptionResultRow extends StatelessWidget {
  const _SubscriptionResultRow({
    required this.candidate,
    required this.state,
    required this.onSubmitCandidate,
    required this.onMoveCandidateToSelectedCategory,
    required this.onViewSubscription,
  });

  final AddSubscriptionCandidate candidate;
  final AddSubscriptionState state;
  final ValueChanged<AddSubscriptionCandidate> onSubmitCandidate;
  final ValueChanged<AddSubscriptionCandidate>
  onMoveCandidateToSelectedCategory;
  final ValueChanged<int> onViewSubscription;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('add_subscription_result_${candidate.feed.url}'),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final details = _ResultDetails(candidate: candidate);
          final action = _ResultAction(
            candidate: candidate,
            state: state,
            onSubmitCandidate: onSubmitCandidate,
            onMoveCandidateToSelectedCategory:
                onMoveCandidateToSelectedCategory,
            onViewSubscription: onViewSubscription,
          );
          final content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ResultAvatar(candidate: candidate),
              const SizedBox(width: 14),
              Expanded(child: details),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content,
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: content),
              const SizedBox(width: 16),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 132),
                  child: action,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResultDetails extends StatelessWidget {
  const _ResultDetails({required this.candidate});

  final AddSubscriptionCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feed = candidate.feed;
    final title = _feedDisplayTitle(feed);
    final domain = _domainLabel(feed);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          domain,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          feed.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SourceChip(label: _sourceLabel(context, feed.source)),
            if (candidate.isAlreadySubscribed)
              _SourceChip(
                label: AppLocalizations.of(
                  context,
                )!.subscriptionAlreadyExistsTitle,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _ResultPreview(feed: feed),
      ],
    );
  }
}

class _ResultPreview extends StatelessWidget {
  const _ResultPreview({required this.feed});

  final DiscoveredFeed feed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (feed.previewItems.isEmpty) {
      return Text(
        l10n.subscriptionPreviewUnavailable,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in feed.previewItems.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(width: 4, height: 4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ResultAvatar extends StatelessWidget {
  const _ResultAvatar({required this.candidate});

  final AddSubscriptionCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: 24,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      child: Text(
        _avatarText(candidate.feed),
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ResultAction extends StatelessWidget {
  const _ResultAction({
    required this.candidate,
    required this.state,
    required this.onSubmitCandidate,
    required this.onMoveCandidateToSelectedCategory,
    required this.onViewSubscription,
  });

  final AddSubscriptionCandidate candidate;
  final AddSubscriptionState state;
  final ValueChanged<AddSubscriptionCandidate> onSubmitCandidate;
  final ValueChanged<AddSubscriptionCandidate>
  onMoveCandidateToSelectedCategory;
  final ValueChanged<int> onViewSubscription;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isActive = state.activeCandidateUrl == candidate.feed.url;
    if (isActive) {
      return FilledButton.icon(
        key: Key('add_subscription_result_busy_${candidate.feed.url}'),
        onPressed: null,
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text(l10n.addingSubscription),
      );
    }

    final existingFeedId = candidate.existingFeedId;
    if (existingFeedId != null) {
      if (_canMoveCandidateToSelectedCategory(state, candidate)) {
        return OutlinedButton.icon(
          key: Key('add_subscription_result_move_${candidate.feed.url}'),
          onPressed: state.isBusy
              ? null
              : () => onMoveCandidateToSelectedCategory(candidate),
          icon: const Icon(FleurIcons.moveToCategory),
          label: Text(l10n.moveToCurrentCategory),
        );
      }
      return OutlinedButton.icon(
        key: Key('add_subscription_result_view_${candidate.feed.url}'),
        onPressed: state.isBusy
            ? null
            : () => onViewSubscription(existingFeedId),
        icon: const Icon(FleurIcons.feed),
        label: Text(l10n.viewSubscription),
      );
    }

    return FilledButton.icon(
      key: Key('add_subscription_result_add_${candidate.feed.url}'),
      onPressed: state.isBusy ? null : () => onSubmitCandidate(candidate),
      icon: const Icon(FleurIcons.add),
      label: Text(l10n.add),
    );
  }
}

bool _canMoveCandidateToSelectedCategory(
  AddSubscriptionState state,
  AddSubscriptionCandidate candidate,
) {
  return candidate.isAlreadySubscribed &&
      state.initialCategoryId != null &&
      state.categorySelected &&
      candidate.existingCategoryId != state.selectedCategoryId;
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.fleurSurface.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _AddSubscriptionConfirmDialog extends ConsumerStatefulWidget {
  const _AddSubscriptionConfirmDialog({required this.candidate});

  final AddSubscriptionCandidate candidate;

  @override
  ConsumerState<_AddSubscriptionConfirmDialog> createState() =>
      _AddSubscriptionConfirmDialogState();
}

class _AddSubscriptionConfirmDialogState
    extends ConsumerState<_AddSubscriptionConfirmDialog> {
  final _newCategoryController = TextEditingController();
  bool _showNewCategoryField = false;

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  void _createCategory() {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;
    unawaited(
      ref.read(addSubscriptionControllerProvider.notifier).createCategory(name),
    );
  }

  void _submit() {
    Navigator.of(context).pop();
    unawaited(
      ref
          .read(addSubscriptionControllerProvider.notifier)
          .submitCandidate(widget.candidate),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AddSubscriptionState>(addSubscriptionControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.phase == AddSubscriptionPhase.creatingCategory &&
          next.phase == AddSubscriptionPhase.selectingCategory &&
          next.failure == null) {
        _newCategoryController.clear();
        if (mounted) setState(() => _showNewCategoryField = false);
      }
    });

    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(addSubscriptionControllerProvider);
    final canSubmit = !state.isBusy && state.categorySelected;
    return Dialog(
      key: const Key('add_subscription_confirm_dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        key: const Key('add_subscription_confirm_panel'),
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.addSubscription,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              _ConfirmCandidateSummary(candidate: widget.candidate),
              const SizedBox(height: 16),
              if (state.categories.isNotEmpty)
                _CategorySection(
                  state: state,
                  padding: EdgeInsets.zero,
                  newCategoryController: _newCategoryController,
                  showNewCategoryField: _showNewCategoryField,
                  onCreateCategory: _createCategory,
                  onShowNewCategoryField: () {
                    setState(() => _showNewCategoryField = true);
                  },
                  onCancelNewCategory: () {
                    _newCategoryController.clear();
                    setState(() => _showNewCategoryField = false);
                  },
                )
              else
                _ProgressStatus(text: l10n.loadingCategories),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: state.isBusy
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton.icon(
                    key: const Key('add_subscription_confirm_add_button'),
                    onPressed: canSubmit ? _submit : null,
                    icon: const Icon(FleurIcons.add),
                    label: Text(l10n.add),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmCandidateSummary extends StatelessWidget {
  const _ConfirmCandidateSummary({required this.candidate});

  final AddSubscriptionCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final feed = candidate.feed;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ResultAvatar(candidate: candidate),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _feedDisplayTitle(feed),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                feed.url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategorySection extends ConsumerWidget {
  const _CategorySection({
    required this.state,
    required this.newCategoryController,
    required this.showNewCategoryField,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
    required this.onCreateCategory,
    required this.onShowNewCategoryField,
    required this.onCancelNewCategory,
  });

  final AddSubscriptionState state;
  final TextEditingController newCategoryController;
  final bool showNewCategoryField;
  final EdgeInsetsGeometry padding;
  final VoidCallback onCreateCategory;
  final VoidCallback onShowNewCategoryField;
  final VoidCallback onCancelNewCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final Object? selectedValue = state.categorySelected
        ? state.selectedCategoryId ?? 'uncategorized'
        : null;
    final optionsByValue = <Object?, AddSubscriptionCategoryOption>{
      for (final option in state.categories) _categoryValue(option): option,
    };
    return Padding(
      key: const Key('add_subscription_categories'),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FleurSelectField<Object?>(
            key: const Key('add_subscription_category_dropdown'),
            value: selectedValue,
            hint: Text(l10n.selectCategory),
            leadingIcon: FleurIcons.category,
            enableSearch: state.categories.length > 8,
            searchHint: l10n.search,
            options: [
              for (final option in state.categories)
                FleurSelectOption<Object?>(
                  key: Key(
                    option.isUncategorized
                        ? 'add_subscription_category_uncategorized'
                        : 'add_subscription_category_${option.id}',
                  ),
                  value: _categoryValue(option),
                  searchText: option.isUncategorized
                      ? l10n.uncategorized
                      : option.title,
                  label: Text(
                    option.isUncategorized ? l10n.uncategorized : option.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: state.isBusy
                ? null
                : (value) {
                    final option = optionsByValue[value];
                    if (option == null) return;
                    ref
                        .read(addSubscriptionControllerProvider.notifier)
                        .selectCategory(option);
                  },
          ),
          const SizedBox(height: 12),
          if (showNewCategoryField)
            _NewCategoryInput(
              controller: newCategoryController,
              enabled: !state.isBusy,
              onCreateCategory: onCreateCategory,
              onCancelNewCategory: onCancelNewCategory,
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('add_subscription_show_new_category_button'),
                onPressed: state.isBusy ? null : onShowNewCategoryField,
                icon: const Icon(FleurIcons.addCategory),
                label: Text(l10n.newCategory),
              ),
            ),
        ],
      ),
    );
  }

  Object _categoryValue(AddSubscriptionCategoryOption option) {
    return option.isUncategorized ? 'uncategorized' : option.id!;
  }
}

class _NewCategoryInput extends StatelessWidget {
  const _NewCategoryInput({
    required this.controller,
    required this.enabled,
    required this.onCreateCategory,
    required this.onCancelNewCategory,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onCreateCategory;
  final VoidCallback onCancelNewCategory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final field = TextField(
      key: const Key('add_subscription_new_category_field'),
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(labelText: l10n.name),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onCreateCategory(),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(
          key: const Key('add_subscription_create_category_button'),
          onPressed: enabled ? onCreateCategory : null,
          child: Text(l10n.create),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: l10n.cancel,
          onPressed: enabled ? onCancelNewCategory : null,
          icon: const Icon(FleurIcons.clear),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: field),
            const SizedBox(width: 8),
            Padding(padding: const EdgeInsets.only(top: 4), child: actions),
          ],
        );
      },
    );
  }
}

class _SectionSurface extends StatelessWidget {
  const _SectionSurface({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.fleurSurface.floating,
        border: Border.all(color: theme.fleurSurface.subtleDivider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          child,
        ],
      ),
    );
  }
}

String _sourceLabel(BuildContext context, DiscoveredFeedSource source) {
  final l10n = AppLocalizations.of(context)!;
  return switch (source) {
    DiscoveredFeedSource.direct => l10n.feedSourceDirect,
    DiscoveredFeedSource.alternateLink => l10n.feedSourceAlternate,
    DiscoveredFeedSource.commonPath => l10n.feedSourceCommonPath,
  };
}

String _feedDisplayTitle(DiscoveredFeed feed) {
  final title = feed.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  final siteTitle = feed.siteTitle?.trim();
  if (siteTitle != null && siteTitle.isNotEmpty) return siteTitle;
  final domain = _domainLabel(feed);
  if (domain.isNotEmpty) return domain;
  return feed.url;
}

String _domainLabel(DiscoveredFeed feed) {
  for (final value in [feed.siteUrl, feed.url]) {
    final uri = Uri.tryParse((value ?? '').trim());
    if (uri == null || uri.host.isEmpty) continue;
    return uri.host.replaceFirst(RegExp(r'^www\.'), '');
  }
  return '';
}

String _avatarText(DiscoveredFeed feed) {
  final source = _feedDisplayTitle(feed).trim().isNotEmpty
      ? _feedDisplayTitle(feed).trim()
      : _domainLabel(feed);
  if (source.isEmpty) return 'R';
  return String.fromCharCode(source.runes.first).toUpperCase();
}
