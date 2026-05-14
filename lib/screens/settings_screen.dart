import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../app/settings_routes.dart';
import '../ui/app_drawer_scope.dart';
import '../ui/settings/subscriptions/subscriptions_settings_tab.dart';
import '../ui/settings/tabs/about_tab.dart';
import '../ui/settings/tabs/app_preferences_tab.dart';
import '../ui/settings/tabs/grouping_sorting_tab.dart';
import '../ui/settings/tabs/services_tab.dart';
import '../ui/settings/tabs/translation_ai_services_tab.dart';
import '../ui/settings/widgets/section_header.dart';
import '../ui/sidebar_layout.dart';
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
  static const _kTwoColumnWidth = 900.0;

  // Nullable tab: null means "List View" in narrow mode or default first item
  // in wide mode.
  SettingsTab? _selectedTab;

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
    final hasAppDrawer = AppDrawerScope.maybeOf(context)?.hasAppDrawer ?? false;
    // Desktop settings stays chrome-less until the dedicated settings page
    // refresh takes over its own top controls.
    final useCompactTopBar = !isDesktop;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isStacked = constraints.maxWidth < _kTwoColumnWidth;
          final previewItems = _buildItems(context, showPageTitle: true);
          final selectedIndex = _selectedIndexFor(previewItems);
          final isShowingDetail = isStacked && selectedIndex != null;
          final items = _buildItems(context, showPageTitle: !isShowingDetail);
          final currentSelectedIndex = _selectedIndexFor(items);

          if (isStacked) {
            // Stacked Layout (mobile / narrow desktop / medium desktop)
            // State-driven: If selection exists, show Detail. Else show List.
            if (currentSelectedIndex != null) {
              final item = items[currentSelectedIndex];

              void handleDetailBack() {
                // Special-case Subscriptions tab: allow in-page back (feed -> list -> categories)
                // before leaving the tab back to the Settings list.
                if (item.tab == SettingsTab.subscriptions) {
                  final notifier = ref.read(
                    subscriptionSelectionProvider.notifier,
                  );
                  final shouldPop = notifier.handleBack();
                  if (!shouldPop) return;
                }
                setState(() => _selectedTab = null);
              }

              return PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, _) {
                  if (didPop) return;
                  handleDetailBack();
                },
                child: Scaffold(
                  appBar: useCompactTopBar
                      ? AppBar(
                          leading: BackButton(onPressed: handleDetailBack),
                          title: Text(item.label),
                        )
                      : null,
                  body: useCompactTopBar
                      ? item.content
                      : Column(
                          children: [
                            SettingsPageHeader(
                              title: item.label,
                              onBack: handleDetailBack,
                            ),
                            const Divider(height: 1),
                            Expanded(child: item.content),
                          ],
                        ),
                ),
              );
            }

            return Scaffold(
              appBar: useCompactTopBar
                  ? AppBar(
                      leading: hasAppDrawer
                          ? AppDrawerScope.drawerLeading(context)
                          : BackButton(
                              onPressed: widget.showBack
                                  ? _closeSettings
                                  : null,
                            ),
                      title: Text(l10n.settings),
                    )
                  : null,
              body: Column(
                children: [
                  if (!useCompactTopBar && widget.showBack)
                    SettingsPageHeader(
                      title: l10n.settings,
                      onBack: _closeSettings,
                    ),
                  Expanded(
                    child: SettingsPageBody(
                      maxWidth: 720,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        SettingsCard(
                          padding: EdgeInsets.zero,
                          child: SettingsTileGroup(
                            children: [
                              for (var index = 0; index < items.length; index++)
                                SettingsTile(
                                  leading: Icon(items[index].icon, size: 20),
                                  title: Text(items[index].label),
                                  trailing: const Icon(
                                    FleurIcons.expand,
                                    size: 20,
                                  ),
                                  onTap: () {
                                    setState(
                                      () => _selectedTab = items[index].tab,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // Two-column Layout
          // Ensure valid selection
          final currentIndex = currentSelectedIndex ?? 0;
          final selectedItem = items[currentIndex];

          return Column(
            children: [
              if (useCompactTopBar)
                AppBar(
                  leading: hasAppDrawer
                      ? AppDrawerScope.drawerLeading(context)
                      : BackButton(
                          onPressed: widget.showBack ? _closeSettings : null,
                        ),
                  title: Text(l10n.settings),
                ),
              if (!useCompactTopBar && widget.showBack)
                SettingsPageHeader(
                  title: l10n.settings,
                  onBack: _closeSettings,
                ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Sidebar
                    Material(
                      color: theme.fleurSurface.sidebar,
                      child: SizedBox(
                        width: 280,
                        child: AppScrollbar(
                          child: ListView(
                            padding: const EdgeInsets.all(12),
                            children: [
                              SettingsCard(
                                padding: EdgeInsets.zero,
                                child: SettingsTileGroup(
                                  children: [
                                    for (
                                      var index = 0;
                                      index < items.length;
                                      index++
                                    )
                                      SettingsTile(
                                        selected: index == currentIndex,
                                        leading: Icon(
                                          index == currentIndex
                                              ? items[index].selectedIcon
                                              : items[index].icon,
                                          size: 20,
                                        ),
                                        title: Text(items[index].label),
                                        onTap: () {
                                          setState(() {
                                            _selectedTab = items[index].tab;
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Right Content Area
                    Expanded(
                      child: FocusTraversalGroup(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey(currentIndex),
                            child: Scaffold(
                              backgroundColor: Colors.transparent,
                              body: selectedItem.content,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SettingsPageHeader extends StatelessWidget {
  const SettingsPageHeader({
    super.key,
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('settings_page_header'),
      height: kWorkspaceHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              key: const Key('settings_back_button'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(FleurIcons.back),
              onPressed: onBack,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
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
