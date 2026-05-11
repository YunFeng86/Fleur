import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';

import '../models/nav_destination.dart';
import '../ui/global_nav.dart';
import '../ui/settings/subscriptions/subscriptions_settings_tab.dart';
import '../ui/settings/tabs/about_tab.dart';
import '../ui/settings/tabs/app_preferences_tab.dart';
import '../ui/settings/tabs/grouping_sorting_tab.dart';
import '../ui/settings/tabs/services_tab.dart';
import '../ui/settings/tabs/translation_ai_services_tab.dart';
import '../ui/settings/widgets/section_header.dart';
import '../providers/subscription_settings_provider.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../utils/platform.dart';
import '../widgets/app_scrollbar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.initialTab});

  final SettingsTab? initialTab;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasGlobalNav = GlobalNavScope.maybeOf(context)?.hasGlobalNav ?? false;
    // Desktop has a top title bar provided by App chrome; avoid in-page AppBar.
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
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    tooltip: MaterialLocalizations.of(
                                      context,
                                    ).backButtonTooltip,
                                    icon: const Icon(Icons.arrow_back),
                                    onPressed: handleDetailBack,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
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
                      leading: hasGlobalNav ? null : const BackButton(),
                      title: Text(l10n.settings),
                    )
                  : null,
              body: SettingsPageBody(
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
                            trailing: const Icon(FleurIcons.expand, size: 20),
                            onTap: () {
                              setState(() => _selectedTab = items[index].tab);
                            },
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
                  leading: hasGlobalNav ? null : const BackButton(),
                  title: Text(l10n.settings),
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
