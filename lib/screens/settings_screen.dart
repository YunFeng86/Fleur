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
import '../providers/subscription_settings_provider.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isStacked = constraints.maxWidth < _kTwoColumnWidth;
            final previewItems = _buildItems(context, showPageTitle: true);
            final selectedIndex = _selectedIndexFor(previewItems);
            final isShowingDetail = isStacked && selectedIndex != null;
            final items = _buildItems(context, showPageTitle: !isShowingDetail);
            final currentSelectedIndex = _selectedIndexFor(items);

            if (isStacked) {
              if (currentSelectedIndex != null) {
                final item = items[currentSelectedIndex];

                void handleDetailBack() {
                  // Subscriptions has its own internal list/detail back stack.
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
                  child: _SettingsStackedPaper(
                    title: item.label,
                    onBack: handleDetailBack,
                    child: item.content,
                  ),
                );
              }

              return _SettingsStackedListPaper(
                title: l10n.settings,
                showBack: widget.showBack,
                onBack: _closeSettings,
                items: items,
                onSelect: (tab) => setState(() => _selectedTab = tab),
              );
            }

            final currentIndex = currentSelectedIndex ?? 0;
            final selectedItem = items[currentIndex];

            return _SettingsTwoColumnPaper(
              title: l10n.settings,
              showBack: widget.showBack,
              onBack: _closeSettings,
              items: items,
              selectedIndex: currentIndex,
              selectedItem: selectedItem,
              onSelect: (tab) => setState(() => _selectedTab = tab),
            );
          },
        ),
      ),
    );
  }
}

class _SettingsStackedPaper extends StatelessWidget {
  const _SettingsStackedPaper({
    required this.title,
    required this.onBack,
    required this.child,
  });

  final String title;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: _SettingsPaperSurface(
        child: Column(
          children: [
            _SettingsPaperToolbar(title: title, onBack: onBack),
            const Divider(height: 1),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _SettingsStackedListPaper extends StatelessWidget {
  const _SettingsStackedListPaper({
    required this.title,
    required this.showBack,
    required this.onBack,
    required this.items,
    required this.onSelect,
  });

  final String title;
  final bool showBack;
  final VoidCallback onBack;
  final List<_SettingsPageItem> items;
  final ValueChanged<SettingsTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: _SettingsPaperSurface(
        child: Column(
          children: [
            _SettingsPaperToolbar(
              title: title,
              onBack: showBack ? onBack : null,
            ),
            const Divider(height: 1),
            Expanded(
              child: SettingsPageBody(
                maxWidth: 720,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SettingsNavigationTile(
                        key: Key('settings_nav_${item.tab.queryValue}'),
                        item: item,
                        trailing: const Icon(FleurIcons.expand, size: 20),
                        onTap: () => onSelect(item.tab),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTwoColumnPaper extends StatelessWidget {
  const _SettingsTwoColumnPaper({
    required this.title,
    required this.showBack,
    required this.onBack,
    required this.items,
    required this.selectedIndex,
    required this.selectedItem,
    required this.onSelect,
  });

  final String title;
  final bool showBack;
  final VoidCallback onBack;
  final List<_SettingsPageItem> items;
  final int selectedIndex;
  final _SettingsPageItem selectedItem;
  final ValueChanged<SettingsTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: theme.fleurSurface.sidebar,
          child: SizedBox(
            width: 280,
            child: AppScrollbar(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
                    child: Row(
                      children: [
                        const Icon(FleurIcons.settingsSelected, size: 22),
                        const SizedBox(width: 12),
                        Text(title, style: theme.textTheme.titleLarge),
                      ],
                    ),
                  ),
                  for (var index = 0; index < items.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
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
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 32, 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: _SettingsPaperSurface(
                  child: Column(
                    children: [
                      _SettingsPaperToolbar(
                        title: selectedItem.label,
                        onBack: showBack ? onBack : null,
                      ),
                      const Divider(height: 1),
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
                              key: ValueKey(selectedIndex),
                              child: selectedItem.content,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsPaperSurface extends StatelessWidget {
  const _SettingsPaperSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final shadowColor = theme.shadowColor.withValues(alpha: dark ? 0.28 : 0.10);

    return DecoratedBox(
      key: const Key('settings_paper_surface'),
      decoration: BoxDecoration(
        color: dark
            ? scheme.surfaceContainerLow
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
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
      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
    );
  }
}

class _SettingsPaperToolbar extends StatelessWidget {
  const _SettingsPaperToolbar({required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final titleRow = Row(
          children: [
            if (onBack != null) ...[
              BackButton(onPressed: onBack),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );

        if (compact) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: [
                titleRow,
                const SizedBox(height: 12),
                const _SettingsSearchPlaceholder(),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              SizedBox(width: 260, child: titleRow),
              const SizedBox(width: 16),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: const _SettingsSearchPlaceholder(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: dark
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: dark ? 0.12 : 0.22),
          ),
        ),
        child: Row(
          children: [
            Icon(FleurIcons.search, size: 19, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.settingsSearchHint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
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
      scheme.primary.withAlpha(dark ? 88 : 70),
      surfaces.sidebar,
    );
    final iconColor = selected ? scheme.primary : scheme.onSurfaceVariant;
    final textColor = selected ? scheme.onSurface : scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 20,
                color: iconColor,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
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
