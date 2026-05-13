import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/article_scope_routes.dart';
import '../l10n/app_localizations.dart';
import '../models/article_scope.dart';
import '../models/nav_destination.dart';
import '../providers/account_providers.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../ui/actions/global_nav_actions.dart';
import '../ui/actions/subscription_actions.dart';
import 'account_avatar.dart';

class GlobalNavRail extends ConsumerWidget {
  const GlobalNavRail({super.key, required this.currentUri});

  final Uri currentUri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;
    final states = theme.fleurState;
    final dest = destinationForUri(currentUri);
    final activeAccount = ref.watch(activeAccountProvider);

    return Material(
      color: surfaces.nav,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                children: [
                  _GlobalNavRailItem(
                    key: const Key('global_nav_feeds_button'),
                    tooltip: l10n.feeds,
                    icon: FleurIcons.feeds,
                    selectedIcon: FleurIcons.feedsSelected,
                    selected: dest == GlobalNavDestination.feeds,
                    onPressed: () => handleGlobalNavSelection(
                      context,
                      ref,
                      GlobalNavDestination.feeds,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _GlobalNavRailItem(
                    key: const Key('global_nav_saved_button'),
                    tooltip: l10n.saved,
                    icon: FleurIcons.saved,
                    selectedIcon: FleurIcons.savedSelected,
                    selected: dest == GlobalNavDestination.saved,
                    onPressed: () => handleGlobalNavSelection(
                      context,
                      ref,
                      GlobalNavDestination.saved,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _GlobalNavRailItem(
                    key: const Key('global_nav_search_button'),
                    tooltip: l10n.search,
                    icon: FleurIcons.search,
                    selectedIcon: FleurIcons.searchSelected,
                    selected: dest == GlobalNavDestination.search,
                    onPressed: () => handleGlobalNavSelection(
                      context,
                      ref,
                      GlobalNavDestination.search,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _GlobalNavRailItem(
                    key: const Key('global_nav_add_button'),
                    tooltip: l10n.addSubscription,
                    icon: FleurIcons.add,
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      final id = await SubscriptionActions.addFeed(
                        context,
                        ref,
                        navigator: nav,
                      );
                      if (id == null) return;
                      SubscriptionActions.selectFeed(ref, id);
                      if (context.mounted) {
                        context.go(scopeLocation(ArticleScope.feed(id)));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GlobalNavRailItem(
                    key: const Key('global_nav_settings_button'),
                    tooltip: l10n.settings,
                    icon: FleurIcons.settings,
                    selectedIcon: FleurIcons.settingsSelected,
                    selected: dest == GlobalNavDestination.settings,
                    onPressed: () => handleGlobalNavSelection(
                      context,
                      ref,
                      GlobalNavDestination.settings,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Tooltip(
                    message: activeAccount.name,
                    child: SizedBox.square(
                      dimension: _kGlobalNavRailHitSize,
                      child: Center(
                        child: InkResponse(
                          key: const Key('global_nav_account_button'),
                          radius: _kGlobalNavRailHitSize / 2,
                          hoverColor: states.hoverTint,
                          onTap: () => context.go(
                            settingsLocation(tab: SettingsTab.services),
                          ),
                          child: AccountAvatar(
                            account: activeAccount,
                            radius: 18,
                            showTypeBadge: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const double _kGlobalNavRailHitSize = 48;
const double _kGlobalNavRailIconSize = 24;
const double _kGlobalNavRailHoverSize = 36;
const double _kGlobalNavRailSelectedSize = 40;
const double _kGlobalNavRailIndicatorRadius = 10;

class _GlobalNavRailItem extends StatefulWidget {
  const _GlobalNavRailItem({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selectedIcon,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final IconData? selectedIcon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_GlobalNavRailItem> createState() => _GlobalNavRailItemState();
}

class _GlobalNavRailItemState extends State<_GlobalNavRailItem> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final states = theme.fleurState;
    final selected = widget.selected;
    final active = selected || _hovered || _focused;
    final backgroundSize = selected
        ? _kGlobalNavRailSelectedSize
        : _kGlobalNavRailHoverSize;
    final iconColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    final backgroundColor = selected
        ? states.selectionTint
        : active
        ? states.hoverTint
        : Colors.transparent;

    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: widget.tooltip,
        child: InkResponse(
          onTap: widget.onPressed,
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) => setState(() => _focused = value),
          radius: _kGlobalNavRailHitSize / 2,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: states.pressedTint,
          child: SizedBox.square(
            dimension: _kGlobalNavRailHitSize,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                width: active ? backgroundSize : _kGlobalNavRailHoverSize,
                height: active ? backgroundSize : _kGlobalNavRailHoverSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    _kGlobalNavRailIndicatorRadius,
                  ),
                  color: backgroundColor,
                ),
                child: Icon(
                  selected ? widget.selectedIcon ?? widget.icon : widget.icon,
                  size: _kGlobalNavRailIconSize,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
