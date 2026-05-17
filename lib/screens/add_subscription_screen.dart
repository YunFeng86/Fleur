import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/article_scope_routes.dart';
import '../l10n/app_localizations.dart';
import '../models/article_scope.dart';
import '../providers/add_subscription_controller.dart';
import '../services/rss/feed_discovery_service.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../ui/actions/remote_structure_feedback.dart' as remote_feedback;
import '../ui/actions/subscription_actions.dart';
import '../ui/app_drawer_scope.dart';
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
  final _newCategoryController = TextEditingController();
  bool _showNewCategoryField = false;

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    _newCategoryController.dispose();
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

  void _createCategory() {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;
    unawaited(
      ref.read(addSubscriptionControllerProvider.notifier).createCategory(name),
    );
  }

  void _submit() {
    unawaited(ref.read(addSubscriptionControllerProvider.notifier).submit());
  }

  void _viewSubscription(int feedId) {
    SubscriptionActions.selectFeed(ref, feedId);
    context.go(scopeLocation(ArticleScope.feed(feedId)));
  }

  void _continueAdding() {
    ref.read(addSubscriptionControllerProvider.notifier).reset();
    _urlController.clear();
    _newCategoryController.clear();
    setState(() => _showNewCategoryField = false);
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

      final completedFeedId = next.completedFeedId;
      if (completedFeedId != null &&
          completedFeedId != previous?.completedFeedId) {
        final failure = next.failure;
        if (failure == null) {
          context.showSnack(l10n.addedAndSynced);
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
      color: Theme.of(context).colorScheme.surface,
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
                      newCategoryController: _newCategoryController,
                      showNewCategoryField: _showNewCategoryField,
                      state: state,
                      onDiscover: _discover,
                      onSubmit: _submit,
                      onCreateCategory: _createCategory,
                      onViewSubscription: _viewSubscription,
                      onContinueAdding: _continueAdding,
                      onDone: _finish,
                      onShowNewCategoryField: () {
                        setState(() => _showNewCategoryField = true);
                      },
                      onCancelNewCategory: () {
                        _newCategoryController.clear();
                        setState(() => _showNewCategoryField = false);
                      },
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
      AddSubscriptionFailureKind.noFeedsFound => l10n.noFeedsFound,
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
    required this.newCategoryController,
    required this.showNewCategoryField,
    required this.state,
    required this.onDiscover,
    required this.onSubmit,
    required this.onCreateCategory,
    required this.onViewSubscription,
    required this.onContinueAdding,
    required this.onDone,
    required this.onShowNewCategoryField,
    required this.onCancelNewCategory,
    required this.onInputChanged,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController urlController;
  final FocusNode urlFocusNode;
  final TextEditingController newCategoryController;
  final bool showNewCategoryField;
  final AddSubscriptionState state;
  final VoidCallback onDiscover;
  final VoidCallback onSubmit;
  final VoidCallback onCreateCategory;
  final ValueChanged<int> onViewSubscription;
  final VoidCallback onContinueAdding;
  final VoidCallback onDone;
  final VoidCallback onShowNewCategoryField;
  final VoidCallback onCancelNewCategory;
  final ValueChanged<String> onInputChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final failure = state.failure;
    final canSubmit =
        !state.isBusy &&
        state.selectedFeedUri != null &&
        state.categorySelected;
    final resultFeedId = state.completedFeedId ?? state.existingFeedId;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('add_subscription_url_field'),
                  controller: urlController,
                  focusNode: urlFocusNode,
                  autofocus: true,
                  enabled: !state.isBusy,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: l10n.feedOrWebsiteUrl,
                    hintText: 'https://example.com',
                    prefixIcon: const Icon(FleurIcons.feed),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return l10n.feedOrWebsiteUrl;
                    }
                    return null;
                  },
                  onChanged: onInputChanged,
                  onFieldSubmitted: (_) => onDiscover(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                key: const Key('add_subscription_discover_button'),
                onPressed: state.isBusy ? null : onDiscover,
                icon: const Icon(FleurIcons.search),
                label: Text(l10n.findFeeds),
              ),
            ],
          ),
          if (state.isBusy) ...[
            const SizedBox(height: 18),
            _ProgressStatus(text: _progressText(l10n, state.phase)),
          ],
          if (failure != null) ...[
            const SizedBox(height: 16),
            _InlineFailure(message: _failureMessage(l10n, failure)),
          ],
          if (state.phase == AddSubscriptionPhase.selectingFeed) ...[
            const SizedBox(height: 22),
            _FeedCandidateList(
              candidates: state.candidates,
              initialCategoryId: state.initialCategoryId,
            ),
          ],
          if (state.selectedFeedUri != null) ...[
            const SizedBox(height: 22),
            _SelectedFeed(uri: state.selectedFeedUri!),
          ],
          if (_showsCategorySection(state)) ...[
            const SizedBox(height: 22),
            _CategorySection(
              state: state,
              newCategoryController: newCategoryController,
              showNewCategoryField: showNewCategoryField,
              onCreateCategory: onCreateCategory,
              onShowNewCategoryField: onShowNewCategoryField,
              onCancelNewCategory: onCancelNewCategory,
            ),
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const Key('add_subscription_submit_button'),
                onPressed: canSubmit ? onSubmit : null,
                icon: const Icon(FleurIcons.add),
                label: Text(l10n.addSubscription),
              ),
            ),
          ],
          if (resultFeedId != null &&
              (state.phase == AddSubscriptionPhase.success ||
                  state.phase == AddSubscriptionPhase.alreadySubscribed)) ...[
            const SizedBox(height: 22),
            _CompletionPanel(
              feedId: resultFeedId,
              alreadySubscribed:
                  state.phase == AddSubscriptionPhase.alreadySubscribed,
              onViewSubscription: onViewSubscription,
              onContinueAdding: onContinueAdding,
              onDone: onDone,
            ),
          ],
        ],
      ),
    );
  }

  bool _showsCategorySection(AddSubscriptionState state) {
    return state.selectedFeedUri != null &&
        switch (state.phase) {
          AddSubscriptionPhase.selectingCategory ||
          AddSubscriptionPhase.creatingCategory ||
          AddSubscriptionPhase.submitting ||
          AddSubscriptionPhase.error => true,
          AddSubscriptionPhase.idle ||
          AddSubscriptionPhase.discovering ||
          AddSubscriptionPhase.selectingFeed ||
          AddSubscriptionPhase.loadingCategories ||
          AddSubscriptionPhase.alreadySubscribed ||
          AddSubscriptionPhase.success => false,
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
      AddSubscriptionFailureKind.noFeedsFound => l10n.noFeedsFound,
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

class _FeedCandidateList extends ConsumerWidget {
  const _FeedCandidateList({
    required this.candidates,
    required this.initialCategoryId,
  });

  final List<DiscoveredFeed> candidates;
  final int? initialCategoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return _SectionSurface(
      key: const Key('add_subscription_feed_candidates'),
      title: l10n.selectFeed,
      child: Column(
        children: [
          for (final candidate in candidates)
            ListTile(
              key: Key('add_subscription_candidate_${candidate.url}'),
              leading: const Icon(FleurIcons.feed),
              title: Text(
                _candidateTitle(candidate),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: _candidateTitle(candidate) == candidate.url
                  ? null
                  : Text(
                      candidate.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () {
                unawaited(
                  ref
                      .read(addSubscriptionControllerProvider.notifier)
                      .selectFeed(
                        candidate,
                        initialCategoryId: initialCategoryId,
                      ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _candidateTitle(DiscoveredFeed candidate) {
    final title = candidate.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    return candidate.url;
  }
}

class _SelectedFeed extends StatelessWidget {
  const _SelectedFeed({required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      key: const Key('add_subscription_selected_feed'),
      decoration: BoxDecoration(
        color: theme.fleurSurface.floating,
        border: Border.all(color: theme.fleurSurface.subtleDivider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: const Icon(FleurIcons.feed),
        title: Text(
          uri.toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _CompletionPanel extends StatelessWidget {
  const _CompletionPanel({
    required this.feedId,
    required this.alreadySubscribed,
    required this.onViewSubscription,
    required this.onContinueAdding,
    required this.onDone,
  });

  final int feedId;
  final bool alreadySubscribed;
  final ValueChanged<int> onViewSubscription;
  final VoidCallback onContinueAdding;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _SectionSurface(
      key: Key(
        alreadySubscribed
            ? 'add_subscription_existing'
            : 'add_subscription_success',
      ),
      title: alreadySubscribed
          ? l10n.subscriptionAlreadyExistsTitle
          : l10n.subscriptionAddedTitle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  alreadySubscribed ? FleurIcons.statusOk : FleurIcons.check,
                  color: scheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    alreadySubscribed
                        ? l10n.subscriptionAlreadyExistsMessage
                        : l10n.subscriptionAddedMessage,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
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
                  onPressed: onContinueAdding,
                  icon: const Icon(FleurIcons.add),
                  label: Text(l10n.continueAddingSubscription),
                ),
                FilledButton.icon(
                  key: const Key('add_subscription_view_button'),
                  onPressed: () => onViewSubscription(feedId),
                  icon: const Icon(FleurIcons.feed),
                  label: Text(l10n.viewSubscription),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends ConsumerWidget {
  const _CategorySection({
    required this.state,
    required this.newCategoryController,
    required this.showNewCategoryField,
    required this.onCreateCategory,
    required this.onShowNewCategoryField,
    required this.onCancelNewCategory,
  });

  final AddSubscriptionState state;
  final TextEditingController newCategoryController;
  final bool showNewCategoryField;
  final VoidCallback onCreateCategory;
  final VoidCallback onShowNewCategoryField;
  final VoidCallback onCancelNewCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selectedValue = state.categorySelected
        ? state.selectedCategoryId ?? 'uncategorized'
        : null;
    final optionsByValue = <Object, AddSubscriptionCategoryOption>{
      for (final option in state.categories) _categoryValue(option): option,
    };
    return _SectionSurface(
      key: const Key('add_subscription_categories'),
      title: l10n.selectCategory,
      child: RadioGroup<Object>(
        groupValue: selectedValue,
        onChanged: (value) {
          final option = optionsByValue[value];
          if (option == null || state.isBusy) return;
          ref
              .read(addSubscriptionControllerProvider.notifier)
              .selectCategory(option);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final option in state.categories)
              RadioListTile<Object>(
                key: Key(
                  option.isUncategorized
                      ? 'add_subscription_category_uncategorized'
                      : 'add_subscription_category_${option.id}',
                ),
                value: _categoryValue(option),
                enabled: !state.isBusy,
                title: Text(
                  option.isUncategorized ? l10n.uncategorized : option.title,
                ),
              ),
            if (showNewCategoryField)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('add_subscription_new_category_field'),
                        controller: newCategoryController,
                        enabled: !state.isBusy,
                        decoration: InputDecoration(labelText: l10n.name),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => onCreateCategory(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const Key('add_subscription_create_category_button'),
                      onPressed: state.isBusy ? null : onCreateCategory,
                      child: Text(l10n.create),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: l10n.cancel,
                      onPressed: state.isBusy ? null : onCancelNewCategory,
                      icon: const Icon(FleurIcons.clear),
                    ),
                  ],
                ),
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
      ),
    );
  }

  Object _categoryValue(AddSubscriptionCategoryOption option) {
    return option.isUncategorized ? 'uncategorized' : option.id!;
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
