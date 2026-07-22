import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/subscription_settings_commands.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../models/category.dart';
import '../../../../../models/feed.dart';
import '../../../../../providers/app_settings_providers.dart';
import '../../../../../providers/backend_content_capabilities_provider.dart';
import '../../../../../services/settings/app_settings.dart';
import '../../../../../ui/settings/widgets/settings_controls.dart';
import '../settings_inheritance_helper.dart';
import 'inherited_bool_setting_tile.dart';

class SubscriptionSyncSettingsSection extends ConsumerWidget {
  const SubscriptionSyncSettingsSection({
    super.key,
    this.feed,
    this.category,
    required this.appSettings,
  });

  final Feed? feed;
  final Category? category;
  final AppSettings appSettings;

  bool get _isGlobal => feed == null && category == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final contentCapabilities = ref.watch(backendContentCapabilitiesProvider);

    return SettingsSection(
      title: l10n.sync,
      child: SettingsCard(
        padding: EdgeInsets.zero,
        child: SettingsTileGroup(
          children: [
            InheritedBoolSettingTile(
              title: l10n.enableSync,
              currentValue: feed != null
                  ? feed!.syncEnabled
                  : category?.syncEnabled,
              effectiveValue: SettingsInheritanceHelper.resolveSyncEnabled(
                feed,
                category,
                appSettings,
              ),
              isGlobal: _isGlobal,
              onChanged: (value) => _setSyncEnabled(ref, value),
            ),
            if (contentCapabilities.canPrefetchImages)
              InheritedBoolSettingTile(
                title: l10n.syncImages,
                currentValue: feed != null
                    ? feed!.syncImages
                    : category?.syncImages,
                effectiveValue: SettingsInheritanceHelper.resolveSyncImages(
                  feed,
                  category,
                  appSettings,
                ),
                isGlobal: _isGlobal,
                onChanged: (value) => _setSyncImages(ref, value),
              ),
            if (contentCapabilities.canFetchWebPages)
              InheritedBoolSettingTile(
                title: l10n.syncWebPages,
                currentValue: feed != null
                    ? feed!.syncWebPages
                    : category?.syncWebPages,
                effectiveValue: SettingsInheritanceHelper.resolveSyncWebPages(
                  feed,
                  category,
                  appSettings,
                ),
                isGlobal: _isGlobal,
                onChanged: (value) => _setSyncWebPages(ref, value),
              ),
            InheritedBoolSettingTile(
              title: l10n.autoAiSummary,
              currentValue: feed != null
                  ? feed!.showAiSummary
                  : category?.showAiSummary,
              effectiveValue: SettingsInheritanceHelper.resolveShowAiSummary(
                feed,
                category,
                appSettings,
              ),
              isGlobal: _isGlobal,
              onChanged: (value) => _setShowAiSummary(ref, value),
            ),
            InheritedBoolSettingTile(
              title: l10n.autoTranslate,
              currentValue: feed != null
                  ? feed!.autoTranslate
                  : category?.autoTranslate,
              effectiveValue: SettingsInheritanceHelper.resolveAutoTranslate(
                feed,
                category,
                appSettings,
              ),
              isGlobal: _isGlobal,
              onChanged: (value) => _setAutoTranslate(ref, value),
            ),
          ],
        ),
      ),
    );
  }

  void _setSyncEnabled(WidgetRef ref, bool? value) {
    if (feed != null) {
      unawaited(
        SubscriptionSettingsCommands.updateFeedSettings(
          ref,
          feedId: feed!.id,
          syncEnabled: value,
          updateSyncEnabled: true,
        ),
      );
    } else if (category != null) {
      unawaited(
        SubscriptionSettingsCommands.updateCategorySettings(
          ref,
          categoryId: category!.id,
          syncEnabled: value,
          updateSyncEnabled: true,
        ),
      );
    } else {
      unawaited(
        ref.read(appSettingsProvider.notifier).setSyncEnabled(value ?? true),
      );
    }
  }

  void _setSyncImages(WidgetRef ref, bool? value) {
    if (feed != null) {
      unawaited(
        SubscriptionSettingsCommands.updateFeedSettings(
          ref,
          feedId: feed!.id,
          syncImages: value,
          updateSyncImages: true,
        ),
      );
    } else if (category != null) {
      unawaited(
        SubscriptionSettingsCommands.updateCategorySettings(
          ref,
          categoryId: category!.id,
          syncImages: value,
          updateSyncImages: true,
        ),
      );
    } else {
      unawaited(
        ref.read(appSettingsProvider.notifier).setSyncImages(value ?? true),
      );
    }
  }

  void _setSyncWebPages(WidgetRef ref, bool? value) {
    if (feed != null) {
      unawaited(
        SubscriptionSettingsCommands.updateFeedSettings(
          ref,
          feedId: feed!.id,
          syncWebPages: value,
          updateSyncWebPages: true,
        ),
      );
    } else if (category != null) {
      unawaited(
        SubscriptionSettingsCommands.updateCategorySettings(
          ref,
          categoryId: category!.id,
          syncWebPages: value,
          updateSyncWebPages: true,
        ),
      );
    } else {
      unawaited(
        ref.read(appSettingsProvider.notifier).setSyncWebPages(value ?? false),
      );
    }
  }

  void _setShowAiSummary(WidgetRef ref, bool? value) {
    if (feed != null) {
      unawaited(
        SubscriptionSettingsCommands.updateFeedSettings(
          ref,
          feedId: feed!.id,
          showAiSummary: value,
          updateShowAiSummary: true,
        ),
      );
    } else if (category != null) {
      unawaited(
        SubscriptionSettingsCommands.updateCategorySettings(
          ref,
          categoryId: category!.id,
          showAiSummary: value,
          updateShowAiSummary: true,
        ),
      );
    } else {
      unawaited(
        ref.read(appSettingsProvider.notifier).setShowAiSummary(value ?? false),
      );
    }
  }

  void _setAutoTranslate(WidgetRef ref, bool? value) {
    if (feed != null) {
      unawaited(
        SubscriptionSettingsCommands.updateFeedSettings(
          ref,
          feedId: feed!.id,
          autoTranslate: value,
          updateAutoTranslate: true,
        ),
      );
    } else if (category != null) {
      unawaited(
        SubscriptionSettingsCommands.updateCategorySettings(
          ref,
          categoryId: category!.id,
          autoTranslate: value,
          updateAutoTranslate: true,
        ),
      );
    } else {
      unawaited(
        ref.read(appSettingsProvider.notifier).setAutoTranslate(value ?? false),
      );
    }
  }
}
