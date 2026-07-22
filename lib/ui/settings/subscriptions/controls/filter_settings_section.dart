import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../models/category.dart';
import '../../../../../models/feed.dart';
import '../../../../../providers/app_settings_providers.dart';
import '../../../../../services/settings/app_settings.dart';
import '../../../../../theme/fleur_icons.dart';
import '../../widgets/section_header.dart';
import '../settings_inheritance_helper.dart';
import '../subscription_actions.dart';
import 'inherited_bool_setting_tile.dart';

class SubscriptionFilterSettingsSection extends ConsumerWidget {
  const SubscriptionFilterSettingsSection({
    super.key,
    this.feed,
    this.category,
    required this.appSettings,
  });

  final Feed? feed;
  final Category? category;
  final AppSettings appSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final effectiveEnabled = SettingsInheritanceHelper.resolveFilterEnabled(
      feed,
      category,
      appSettings,
    );

    return SettingsSection(
      title: l10n.filter,
      child: SettingsCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InheritedBoolSettingTile(
              title: l10n.enableFilter,
              currentValue: feed != null
                  ? feed!.filterEnabled
                  : category?.filterEnabled,
              effectiveValue: effectiveEnabled,
              isGlobal: feed == null && category == null,
              onChanged: (value) {
                if (feed != null) {
                  unawaited(
                    SubscriptionActions.updateFeedSettings(
                      context,
                      ref,
                      feedId: feed!.id,
                      filterEnabled: value,
                      updateFilterEnabled: true,
                    ),
                  );
                } else if (category != null) {
                  unawaited(
                    SubscriptionActions.updateCategorySettings(
                      context,
                      ref,
                      categoryId: category!.id,
                      filterEnabled: value,
                      updateFilterEnabled: true,
                    ),
                  );
                } else {
                  unawaited(
                    ref
                        .read(appSettingsProvider.notifier)
                        .setFilterEnabled(value ?? false),
                  );
                }
              },
            ),
            if (effectiveEnabled) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _FilterKeywordsInput(
                  feed: feed,
                  category: category,
                  appSettings: appSettings,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterKeywordsInput extends ConsumerStatefulWidget {
  const _FilterKeywordsInput({
    this.feed,
    this.category,
    required this.appSettings,
  });

  final Feed? feed;
  final Category? category;
  final AppSettings appSettings;

  @override
  ConsumerState<_FilterKeywordsInput> createState() =>
      _FilterKeywordsInputState();
}

class _FilterKeywordsInputState extends ConsumerState<_FilterKeywordsInput> {
  late final FocusNode _focusNode;
  late final TextEditingController _controller;

  String get _effectiveValue => SettingsInheritanceHelper.resolveFilterKeywords(
    widget.feed,
    widget.category,
    widget.appSettings,
  );

  String? get _currentValue => widget.feed != null
      ? widget.feed!.filterKeywords
      : widget.category?.filterKeywords;

  bool get _isGlobal => widget.feed == null && widget.category == null;

  bool get _isInherit =>
      !_isGlobal && (_currentValue == null || _currentValue!.trim().isEmpty);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = TextEditingController(
      text: _isGlobal
          ? widget.appSettings.filterKeywords
          : _isInherit
          ? _effectiveValue
          : _currentValue,
    );
  }

  @override
  void didUpdateWidget(covariant _FilterKeywordsInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = _isGlobal
        ? widget.appSettings.filterKeywords
        : _isInherit
        ? _effectiveValue
        : (_currentValue ?? '');
    if (_controller.text != nextText) {
      _controller.text = nextText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      readOnly: _isInherit,
      decoration: InputDecoration(
        hintText: _isInherit && _effectiveValue.trim().isEmpty
            ? l10n.defaultValue
            : null,
        helperText: l10n.filterKeywordsHint,
        helperMaxLines: 2,
        suffixIcon: _buildSuffixIcon(l10n),
      ),
      minLines: 1,
      maxLines: 3,
      onChanged: _isInherit ? null : _save,
    );
  }

  Widget? _buildSuffixIcon(AppLocalizations l10n) {
    if (_isGlobal) return null;
    if (_isInherit) {
      return IconButton(
        icon: const Icon(FleurIcons.rename),
        tooltip: l10n.edit,
        onPressed: () {
          final seed = _effectiveValue;
          _controller.text = seed;
          _save(seed);
          _focusNode.requestFocus();
          _controller.selection = TextSelection.collapsed(offset: seed.length);
        },
      );
    }
    if (_currentValue == null || _currentValue!.trim().isEmpty) return null;

    return IconButton(
      icon: const Icon(FleurIcons.inherit),
      tooltip: l10n.inherit,
      onPressed: () {
        _controller.text = _effectiveValue;
        _save(null);
      },
    );
  }

  void _save(String? value) {
    final trimmed = value?.trim();
    final next = trimmed == null || trimmed.isEmpty ? null : trimmed;
    if (_isGlobal) {
      unawaited(
        ref.read(appSettingsProvider.notifier).setFilterKeywords(next ?? ''),
      );
    } else if (widget.feed != null) {
      unawaited(
        SubscriptionActions.updateFeedSettings(
          context,
          ref,
          feedId: widget.feed!.id,
          filterKeywords: next,
          updateFilterKeywords: true,
        ),
      );
    } else if (widget.category != null) {
      unawaited(
        SubscriptionActions.updateCategorySettings(
          context,
          ref,
          categoryId: widget.category!.id,
          filterKeywords: next,
          updateFilterKeywords: true,
        ),
      );
    }
  }
}
