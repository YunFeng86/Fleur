import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../app/settings_routes.dart';
import '../ui/settings/subscriptions/subscriptions_settings_tab.dart';
import '../ui/settings/tabs/about_tab.dart';
import '../ui/settings/tabs/app_preferences_tab.dart';
import '../ui/settings/tabs/grouping_sorting_tab.dart';
import '../ui/settings/tabs/services_tab.dart';
import '../ui/settings/tabs/translation_ai_services_tab.dart';
import '../ui/settings/widgets/section_header.dart';
import '../ui/sidebar_layout.dart';
import '../ui/workspace_layers.dart';
import '../providers/subscription_settings_provider.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../utils/platform.dart';
import '../widgets/app_scrollbar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    this.initialTab,
    this.showBack = false,
    this.fallbackBackLocation = '/all',
  });

  final SettingsTab? initialTab;
  final bool showBack;
  final String fallbackBackLocation;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _kSettingsSidebarWidth = kDefaultWorkspaceSidebarWidth;
  static const _kSettingsMinContentWidth = 720.0;
  static const _kSettingsPaperMaxWidth = 960.0;
  static const _kSidebarPinnedWidth =
      _kSettingsSidebarWidth + _kSettingsMinContentWidth;
  static const _kLayerAnimationDuration = Duration(milliseconds: 180);

  // Nullable tab: null means "List View" in narrow mode or default first item
  // in wide mode.
  SettingsTab? _selectedTab;
  bool _sidebarOpen = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab == widget.initialTab) return;
    _selectedTab = widget.initialTab;
  }

  List<_SettingsPageItem> _buildItems(
    BuildContext context, {
    required bool showPageTitle,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return [
      _SettingsPageItem(
        tab: SettingsTab.appPreferences,
        icon: FleurIcons.appPreferences,
        selectedIcon: FleurIcons.appPreferencesSelected,
        label: l10n.appPreferences,
        content: AppPreferencesTab(showPageTitle: showPageTitle),
      ),
      _SettingsPageItem(
        tab: SettingsTab.subscriptions,
        icon: FleurIcons.feeds,
        selectedIcon: FleurIcons.feedsSelected,
        label: l10n.subscriptions,
        content: SubscriptionsSettingsTab(showPageTitle: showPageTitle),
      ),
      _SettingsPageItem(
        tab: SettingsTab.groupingAndSorting,
        icon: FleurIcons.grouping,
        selectedIcon: FleurIcons.groupingSelected,
        label: l10n.groupingAndSorting,
        content: GroupingSortingTab(showPageTitle: showPageTitle),
      ),
      _SettingsPageItem(
        tab: SettingsTab.services,
        icon: FleurIcons.services,
        selectedIcon: FleurIcons.servicesSelected,
        label: l10n.services,
        content: ServicesTab(showPageTitle: showPageTitle),
      ),
      _SettingsPageItem(
        tab: SettingsTab.translationAndAiServices,
        icon: FleurIcons.translationAi,
        selectedIcon: FleurIcons.translationAiSelected,
        label: l10n.translationAndAiServices,
        content: TranslationAiServicesTab(showPageTitle: showPageTitle),
      ),
      _SettingsPageItem(
        tab: SettingsTab.about,
        icon: FleurIcons.about,
        selectedIcon: FleurIcons.aboutSelected,
        label: l10n.about,
        content: AboutTab(showPageTitle: showPageTitle),
      ),
    ];
  }

  int? _selectedIndexFor(List<_SettingsPageItem> items) {
    final selectedTab = _selectedTab;
    if (selectedTab == null) return null;
    final index = items.indexWhere((item) => item.tab == selectedTab);
    return index < 0 ? null : index;
  }

  void _closeSettings() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(widget.fallbackBackLocation);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.fleurSurface.chrome,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final sidebarPinned = width >= _kSidebarPinnedWidth;
            final sidebarOpen = !sidebarPinned && _sidebarOpen;
            final items = _buildItems(context, showPageTitle: false);
            final currentSelectedIndex = _selectedIndexFor(items);
            final showingList = !sidebarPinned && currentSelectedIndex == null;
            final selectedIndex = currentSelectedIndex ?? 0;
            final selectedItem = items[selectedIndex];

            void selectTab(SettingsTab tab) {
              setState(() {
                _selectedTab = tab;
                if (!sidebarPinned) _sidebarOpen = false;
              });
            }

            void handleDetailBack() {
              // Subscriptions has its own internal list/detail back stack.
              if (selectedItem.tab == SettingsTab.subscriptions) {
                final notifier = ref.read(
                  subscriptionSelectionProvider.notifier,
                );
                final shouldPop = notifier.handleBack();
                if (!shouldPop) return;
              }
              setState(() => _selectedTab = null);
            }

            final content = showingList
                ? _SettingsListBody(items: items, onSelect: selectTab)
                : FocusTraversalGroup(child: selectedItem.content);
            final scene = _SettingsScene(
              width: width,
              sidebarPinned: sidebarPinned,
              sidebarOpen: sidebarOpen,
              title: showingList ? l10n.settings : selectedItem.label,
              sidebarTitle: l10n.settings,
              showSidebarButton: !sidebarPinned,
              onToggleSidebar: () {
                setState(() => _sidebarOpen = !_sidebarOpen);
              },
              onBack: showingList
                  ? (widget.showBack ? _closeSettings : null)
                  : handleDetailBack,
              items: items,
              sidebarSelectedIndex: sidebarPinned
                  ? selectedIndex
                  : currentSelectedIndex,
              selectedContentKey: showingList
                  ? const ValueKey('settings-list')
                  : ValueKey(selectedItem.tab),
              content: content,
              onSelect: selectTab,
            );

            if (!sidebarPinned && !showingList) {
              return PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, _) {
                  if (didPop) return;
                  handleDetailBack();
                },
                child: scene,
              );
            }

            return scene;
          },
        ),
      ),
    );
  }
}

class _SettingsScene extends StatelessWidget {
  const _SettingsScene({
    required this.width,
    required this.sidebarPinned,
    required this.sidebarOpen,
    required this.title,
    required this.sidebarTitle,
    required this.showSidebarButton,
    required this.onToggleSidebar,
    required this.onBack,
    required this.items,
    required this.sidebarSelectedIndex,
    required this.selectedContentKey,
    required this.content,
    required this.onSelect,
  });

  final double width;
  final bool sidebarPinned;
  final bool sidebarOpen;
  final String title;
  final String sidebarTitle;
  final bool showSidebarButton;
  final VoidCallback onToggleSidebar;
  final VoidCallback? onBack;
  final List<_SettingsPageItem> items;
  final int? sidebarSelectedIndex;
  final Key selectedContentKey;
  final Widget content;
  final ValueChanged<SettingsTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).fleurSurface;
    final sidebarVisible = sidebarPinned || sidebarOpen;
    final contentLeft = sidebarPinned
        ? _SettingsScreenState._kSettingsSidebarWidth +
              kSidebarContentDividerWidth
        : (sidebarOpen ? _SettingsScreenState._kSettingsSidebarWidth : 0.0);
    final contentWidth = sidebarPinned
        ? (width - contentLeft).clamp(0.0, double.infinity).toDouble()
        : width;

    return ColoredBox(
      color: surfaces.chrome,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          if (sidebarVisible)
            Positioned(
              key: const Key('settings_sidebar'),
              left: 0,
              top: 0,
              bottom: 0,
              width: _SettingsScreenState._kSettingsSidebarWidth,
              child: _SettingsSidebar(
                title: sidebarTitle,
                items: items,
                selectedIndex: sidebarSelectedIndex,
                onSelect: onSelect,
              ),
            ),
          if (sidebarPinned)
            Positioned(
              key: const Key('settings_sidebar_divider'),
              left: _SettingsScreenState._kSettingsSidebarWidth,
              top: 0,
              bottom: 0,
              width: kSidebarContentDividerWidth,
              child: ColoredBox(color: surfaces.subtleDivider),
            ),
          AnimatedPositioned(
            key: const Key('settings_content_layer'),
            duration: _SettingsScreenState._kLayerAnimationDuration,
            curve: Curves.easeOutCubic,
            left: contentLeft,
            top: 0,
            bottom: 0,
            width: contentWidth,
            child: _SettingsContentLayer(
              sidebarPinned: sidebarPinned,
              sidebarOpen: sidebarOpen,
              title: title,
              showSidebarButton: showSidebarButton,
              onToggleSidebar: onToggleSidebar,
              onBack: onBack,
              selectedContentKey: selectedContentKey,
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({
    required this.title,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final String title;
  final List<_SettingsPageItem> items;
  final int? selectedIndex;
  final ValueChanged<SettingsTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).fleurSurface;

    return Material(
      color: surfaces.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsSidebarHeader(title: title),
          Expanded(
            child: AppScrollbar(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                children: [
                  for (var index = 0; index < items.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _SettingsNavigationTile(
                        key: Key('settings_nav_${items[index].tab.queryValue}'),
                        item: items[index],
                        selected: index == selectedIndex,
                        onTap: () => onSelect(items[index].tab),
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

class _SettingsSidebarHeader extends StatelessWidget {
  const _SettingsSidebarHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scope = ShellLayerScope.maybeOf(context);
    final metrics =
        scope?.macOSWindowChromeMetrics ?? MacOSWindowChromeMetrics.fallback;
    final avoidTrafficLights = isMacOS && metrics.trafficLightsVisible;
    final leadingLeft = avoidTrafficLights ? metrics.safeInset : 16.0;

    return SizedBox(
      height: kWorkspaceHeaderHeight,
      child: Padding(
        padding: EdgeInsets.only(left: leadingLeft, right: 12),
        child: Row(
          children: [
            Icon(
              FleurIcons.settingsSelected,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsListBody extends StatelessWidget {
  const _SettingsListBody({required this.items, required this.onSelect});

  final List<_SettingsPageItem> items;
  final ValueChanged<SettingsTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return SettingsPageBody(
      maxWidth: 720,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _SettingsNavigationTile(
              key: Key('settings_list_nav_${item.tab.queryValue}'),
              item: item,
              trailing: const Icon(FleurIcons.expand, size: 18),
              onTap: () => onSelect(item.tab),
            ),
          ),
      ],
    );
  }
}

class _SettingsContentLayer extends StatelessWidget {
  const _SettingsContentLayer({
    required this.sidebarPinned,
    required this.sidebarOpen,
    required this.title,
    required this.showSidebarButton,
    required this.onToggleSidebar,
    required this.onBack,
    required this.selectedContentKey,
    required this.child,
  });

  final bool sidebarPinned;
  final bool sidebarOpen;
  final String title;
  final bool showSidebarButton;
  final VoidCallback onToggleSidebar;
  final VoidCallback? onBack;
  final Key selectedContentKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).fleurSurface;
    final paper = _SettingsPaperSurface(
      borderRadius: sidebarPinned
          ? const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            )
          : BorderRadius.zero,
      child: Column(
        children: [
          _SettingsSceneHeader(
            title: title,
            sidebarPinned: sidebarPinned,
            sidebarOpen: sidebarOpen,
            showSidebarButton: showSidebarButton,
            onToggleSidebar: onToggleSidebar,
            onBack: onBack,
          ),
          if (!sidebarPinned) const _SettingsSearchDock(insidePaper: true),
          Divider(height: 1, color: surfaces.subtleDivider),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: KeyedSubtree(key: selectedContentKey, child: child),
            ),
          ),
        ],
      ),
    );

    if (!sidebarPinned) return paper;

    return LayoutBuilder(
      builder: (context, constraints) {
        final paperWidth = constraints.maxWidth
            .clamp(0.0, _SettingsScreenState._kSettingsPaperMaxWidth)
            .toDouble();

        return ColoredBox(
          color: surfaces.chrome,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: paperWidth,
              child: Column(
                children: [
                  const _SettingsSearchDock(insidePaper: false),
                  Expanded(child: paper),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SettingsSceneHeader extends StatelessWidget {
  const _SettingsSceneHeader({
    required this.title,
    required this.sidebarPinned,
    required this.sidebarOpen,
    required this.showSidebarButton,
    required this.onToggleSidebar,
    required this.onBack,
  });

  final String title;
  final bool sidebarPinned;
  final bool sidebarOpen;
  final bool showSidebarButton;
  final VoidCallback onToggleSidebar;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scope = ShellLayerScope.maybeOf(context);
    final metrics =
        scope?.macOSWindowChromeMetrics ?? MacOSWindowChromeMetrics.fallback;
    final avoidTrafficLights =
        !sidebarPinned &&
        !sidebarOpen &&
        isMacOS &&
        metrics.trafficLightsVisible;
    final leadingLeft = avoidTrafficLights ? metrics.safeInset : 8.0;
    final rowTop = avoidTrafficLights
        ? metrics.shellControlTopInset
        : kShellControlTopInset;

    return SizedBox(
      height: kWorkspaceHeaderHeight,
      child: Stack(
        children: [
          Positioned(
            left: leadingLeft,
            top: rowTop,
            right: 12,
            height: kShellControlSize,
            child: Row(
              children: [
                if (showSidebarButton)
                  _SettingsHeaderButton(
                    key: const Key('settings_sidebar_button'),
                    tooltip: sidebarOpen
                        ? AppLocalizations.of(context)!.collapse
                        : AppLocalizations.of(context)!.expand,
                    icon: sidebarOpen
                        ? FleurIcons.sidebarCollapse
                        : FleurIcons.sidebarExpand,
                    onPressed: onToggleSidebar,
                  ),
                if (onBack != null)
                  _SettingsHeaderButton(
                    key: const Key('settings_back_button'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    icon: FleurIcons.back,
                    onPressed: onBack,
                  ),
                if (showSidebarButton || onBack != null)
                  const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPaperSurface extends StatelessWidget {
  const _SettingsPaperSurface({
    required this.child,
    required this.borderRadius,
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaces = theme.fleurSurface;
    final dark = theme.brightness == Brightness.dark;
    final shadowColor = theme.shadowColor.withValues(alpha: dark ? 0.28 : 0.10);

    return DecoratedBox(
      key: const Key('settings_paper_surface'),
      decoration: BoxDecoration(
        color: surfaces.list,
        borderRadius: borderRadius,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: dark ? 0.18 : 0.38),
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 26,
            spreadRadius: dark ? 0 : 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: borderRadius, child: child),
    );
  }
}

class _SettingsHeaderButton extends StatelessWidget {
  const _SettingsHeaderButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: kShellControlIconSize),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(kShellControlSize),
        minimumSize: const Size.square(kShellControlSize),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _SettingsSearchDock extends StatelessWidget {
  const _SettingsSearchDock({required this.insidePaper});

  final bool insidePaper;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = insidePaper ? 12.0 : 16.0;
    return SizedBox(
      key: Key(
        insidePaper
            ? 'settings_search_inside_paper'
            : 'settings_search_outside_paper',
      ),
      height: insidePaper ? 50 : 56,
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _SettingsScreenState._kSettingsPaperMaxWidth,
            ),
            child: const _SettingsSearchPlaceholder(),
          ),
        ),
      ),
    );
  }
}

class _SettingsSearchPlaceholder extends StatelessWidget {
  const _SettingsSearchPlaceholder();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Semantics(
      label: l10n.settingsSearchHint,
      readOnly: true,
      child: Container(
        key: const Key('settings_search_placeholder'),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: dark
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: dark ? 0.12 : 0.22),
          ),
        ),
        child: Row(
          children: [
            Icon(FleurIcons.search, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.settingsSearchHint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsNavigationTile extends StatelessWidget {
  const _SettingsNavigationTile({
    super.key,
    required this.item,
    required this.onTap,
    this.selected = false,
    this.trailing,
  });

  final _SettingsPageItem item;
  final VoidCallback onTap;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaces = theme.fleurSurface;
    final dark = theme.brightness == Brightness.dark;
    final selectedColor = Color.alphaBlend(
      scheme.primary.withAlpha(dark ? 58 : 36),
      surfaces.sidebar,
    );
    final iconColor = selected ? scheme.primary : scheme.onSurfaceVariant;
    final textColor = selected ? scheme.onSurface : scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 18,
                color: iconColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                IconTheme.merge(
                  data: IconThemeData(color: scheme.onSurfaceVariant),
                  child: trailing!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsPageItem {
  final SettingsTab tab;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget content;

  const _SettingsPageItem({
    required this.tab,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.content,
  });
}
