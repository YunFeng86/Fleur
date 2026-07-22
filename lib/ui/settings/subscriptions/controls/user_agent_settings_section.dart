import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../providers/app_settings_providers.dart';
import '../../../../../services/network/user_agents.dart';
import '../../../../../services/settings/app_settings.dart';
import '../../../../../theme/fleur_icons.dart';
import '../../widgets/settings_controls.dart';

class SubscriptionUserAgentSettingsSection extends ConsumerStatefulWidget {
  const SubscriptionUserAgentSettingsSection({
    super.key,
    required this.appSettings,
  });

  final AppSettings appSettings;

  @override
  ConsumerState<SubscriptionUserAgentSettingsSection> createState() =>
      _SubscriptionUserAgentSettingsSectionState();
}

class _SubscriptionUserAgentSettingsSectionState
    extends ConsumerState<SubscriptionUserAgentSettingsSection> {
  late final TextEditingController _rssController;
  late final TextEditingController _webController;

  @override
  void initState() {
    super.initState();
    _rssController = TextEditingController(
      text: widget.appSettings.rssUserAgent,
    );
    _webController = TextEditingController(
      text: widget.appSettings.webUserAgent,
    );
  }

  @override
  void didUpdateWidget(
    covariant SubscriptionUserAgentSettingsSection oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appSettings.rssUserAgent != widget.appSettings.rssUserAgent &&
        _rssController.text != widget.appSettings.rssUserAgent) {
      _rssController.text = widget.appSettings.rssUserAgent;
    }
    if (oldWidget.appSettings.webUserAgent != widget.appSettings.webUserAgent &&
        _webController.text != widget.appSettings.webUserAgent) {
      _webController.text = widget.appSettings.webUserAgent;
    }
  }

  @override
  void dispose() {
    _rssController.dispose();
    _webController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsSection(
      title: l10n.userAgent,
      bottomSpacing: 0,
      child: SettingsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _rssController,
              decoration: InputDecoration(
                labelText: l10n.rssUserAgent,
                helperText: l10n.userAgentRssHint,
                helperMaxLines: 2,
                suffixIcon: IconButton(
                  icon: const Icon(FleurIcons.reset),
                  tooltip: l10n.resetToDefault,
                  onPressed: () {
                    _rssController.text = UserAgents.rss;
                    unawaited(
                      ref
                          .read(appSettingsProvider.notifier)
                          .setRssUserAgent(UserAgents.rss),
                    );
                  },
                ),
              ),
              minLines: 1,
              maxLines: 3,
              onChanged: (value) => unawaited(
                ref.read(appSettingsProvider.notifier).setRssUserAgent(value),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _webController,
              decoration: InputDecoration(
                labelText: l10n.webUserAgent,
                helperText: l10n.userAgentWebHint,
                helperMaxLines: 2,
                suffixIcon: IconButton(
                  icon: const Icon(FleurIcons.reset),
                  tooltip: l10n.resetToDefault,
                  onPressed: () {
                    final userAgent = UserAgents.webForCurrentPlatform();
                    _webController.text = userAgent;
                    unawaited(
                      ref
                          .read(appSettingsProvider.notifier)
                          .setWebUserAgent(userAgent),
                    );
                  },
                ),
              ),
              minLines: 1,
              maxLines: 3,
              onChanged: (value) => unawaited(
                ref.read(appSettingsProvider.notifier).setWebUserAgent(value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
