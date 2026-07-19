import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../app/settings_routes.dart';
import '../ui/settings/subscriptions/subscriptions_settings_tab.dart';
import '../ui/settings/tabs/about_tab.dart';
import '../ui/settings/tabs/app_preferences_tab.dart';
import '../ui/settings/tabs/appearance_tab.dart';
import '../ui/settings/tabs/grouping_sorting_tab.dart';
import '../ui/settings/tabs/services_tab.dart';
import '../ui/settings/tabs/translation_ai_services_tab.dart';
import '../ui/settings/settings_search_index.dart';
import '../ui/settings/settings_targets.dart';
import '../ui/settings/widgets/section_header.dart';
import '../ui/adaptive_workspace_layout.dart';
import '../ui/shell_chrome_layout.dart';
import '../ui/sidebar_layout.dart';
import '../ui/workspace_layers.dart';
import '../providers/core_providers.dart';
import '../providers/subscription_settings_provider.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../utils/platform.dart';
import '../widgets/app_scrollbar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    this.initialTab,
    this.initialSettingId,
    this.showBack = false,
    this.fallbackBackLocation = '/all',
  });

  final SettingsTab? initialTab;
  final String? initialSettingId;
  final bool showBack;
  final String fallbackBackLocation;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _kSettingsSidebarWidth = kDefaultWorkspaceSidebarWidth;
  static const _kSettingsPaperMaxWidth = 960.0;
  static const _kSettingsSearchPaperGap = 8.0;
  static const _kLayerAnimationDuration = Duration(milliseconds: 180);

  // Nullable tab: null means "List View" in narrow mode or default first item
  // in wide mode.
  SettingsTab? _selectedTab;
  AppearanceDetailPage? _appearanceDetailPage;
  final SettingsTargetController _targetController = SettingsTargetController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _highlightTimer;
  String? _pendingInitialSettingId;
  String? _pendingRevealTargetId;
  String _searchQuery = '';
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    _targetController.addListener(_handleTargetControllerChanged);
    _searchController.addListener(_handleSearchChanged);
    _searchFocusNode.addListener(_handleSearchFocusChanged);
    _selectedTab =
        widget.initialTab ?? _tabForSettingId(widget.initialSettingId);
    _appearanceDetailPage = null;
    _pendingInitialSettingId = widget.initialSettingId;
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab == widget.initialTab &&
        oldWidget.initialSettingId == widget.initialSettingId) {
      return;
    }
    _selectedTab =
        widget.initialTab ?? _tabForSettingId(widget.initialSettingId);
    _appearanceDetailPage = null;
    _pendingInitialSettingId = widget.initialSettingId;
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _searchFocusNode.removeListener(_handleSearchFocusChanged);
    _searchController.removeListener(_handleSearchChanged);
    _targetController.removeListener(_handleTargetControllerChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    _targetController.dispose();
    super.dispose();
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
        content: AppPreferencesTab(
          showPageTitle: showPageTitle,
          targetController: _targetController,
        ),
      ),
      _SettingsPageItem(
        tab: SettingsTab.appearance,
        icon: FleurIcons.appearance,
        selectedIcon: FleurIcons.appearanceSelected,
        label: l10n.appearance,
        content: AppearanceTab(
          showPageTitle: showPageTitle,
          targetController: _targetController,
          detailPage: _appearanceDetailPage,
          onOpenFontsDetail: () {
            setState(() => _appearanceDetailPage = AppearanceDetailPage.fonts);
          },
          onCloseDetail: () {
            setState(() => _appearanceDetailPage = null);
          },
        ),
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
        content: GroupingSortingTab(
          showPageTitle: showPageTitle,
          targetController: _targetController,
        ),
      ),
      _SettingsPageItem(
        tab: SettingsTab.services,
        icon: FleurIcons.services,
        selectedIcon: FleurIcons.servicesSelected,
        label: l10n.services,
        content: ServicesTab(
          showPageTitle: showPageTitle,
          targetController: _targetController,
        ),
      ),
      _SettingsPageItem(
        tab: SettingsTab.translationAndAiServices,
        icon: FleurIcons.translationAi,
        selectedIcon: FleurIcons.translationAiSelected,
        label: l10n.translationAndAiServices,
        content: TranslationAiServicesTab(
          showPageTitle: showPageTitle,
          targetController: _targetController,
        ),
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

  SettingsTab? _tabForSettingId(String? settingId) {
    final id = settingId?.trim();
    if (id == null || id.isEmpty) return null;
    if (id == 'page.${SettingsTab.appPreferences.queryValue}' ||
        id.startsWith('app_preferences.')) {
      return SettingsTab.appPreferences;
    }
    if (id == 'page.${SettingsTab.appearance.queryValue}' ||
        id.startsWith('appearance.')) {
      return SettingsTab.appearance;
    }
    if (id == 'page.${SettingsTab.subscriptions.queryValue}' ||
        id.startsWith('subscriptions.')) {
      return SettingsTab.subscriptions;
    }
    if (id == 'page.${SettingsTab.groupingAndSorting.queryValue}' ||
        id.startsWith('grouping_sorting.')) {
      return SettingsTab.groupingAndSorting;
    }
    if (id == 'page.${SettingsTab.services.queryValue}' ||
        id.startsWith('services.')) {
      return SettingsTab.services;
    }
    if (id == 'page.${SettingsTab.translationAndAiServices.queryValue}' ||
        id.startsWith('translation_ai.')) {
      return SettingsTab.translationAndAiServices;
    }
    if (id == 'page.${SettingsTab.about.queryValue}' ||
        id.startsWith('about.')) {
      return SettingsTab.about;
    }
    return null;
  }

  SettingsSearchEntry? _entryForSettingId(
    List<SettingsSearchEntry> entries,
    String settingId,
  ) {
    for (final entry in entries) {
      if (entry.id == settingId || entry.targetId == settingId) return entry;
    }
    return null;
  }

  void _handleSearchChanged() {
    final query = _searchController.text;
    if (query == _searchQuery) return;
    setState(() => _searchQuery = query);
  }

  void _handleSearchFocusChanged() {
    final focused = _searchFocusNode.hasFocus;
    if (focused == _searchFocused) return;
    setState(() => _searchFocused = focused);
  }

  void _handleTargetControllerChanged() {
    _tryRevealPendingTarget();
  }

  void _queueRevealTarget(String targetId) {
    _pendingRevealTargetId = targetId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tryRevealPendingTarget();
    });
  }

  void _tryRevealPendingTarget() {
    final targetId = _pendingRevealTargetId;
    if (targetId == null || !_targetController.isRegistered(targetId)) return;
    final targetContext = _targetController.contextFor(targetId);
    if (targetContext == null) return;
    _pendingRevealTargetId = null;
    unawaited(_revealVisibleTarget(targetId, targetContext));
  }

  Future<void> _revealVisibleTarget(
    String targetId,
    BuildContext targetContext,
  ) async {
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
    if (!mounted) return;
    _targetController.highlight(targetId);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _targetController.clear(targetId);
      _highlightTimer = null;
    });
  }

  void _selectSearchEntry(SettingsSearchEntry entry) {
    _searchFocusNode.unfocus();
    if (_searchController.text.isNotEmpty) _searchController.clear();
    setState(() {
      _selectedTab = entry.tab;
      _appearanceDetailPage = null;
      _searchQuery = '';
    });
    ref.read(settingsTemporaryNavigationOpenProvider.notifier).state = false;
    final targetId = entry.targetId;
    if (targetId != null) _queueRevealTarget(targetId);
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
    final searchEntries = buildSettingsSearchEntries(l10n);

    if (_pendingInitialSettingId case final settingId?
        when settingId.trim().isNotEmpty) {
      _pendingInitialSettingId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final trimmed = settingId.trim();
        final entry = _entryForSettingId(searchEntries, trimmed);
        final tab = entry?.tab ?? _tabForSettingId(trimmed);
        if (tab != null && tab != _selectedTab) {
          setState(() => _selectedTab = tab);
        }
        final targetId = entry?.targetId;
        if (targetId != null) _queueRevealTarget(targetId);
      });
    }

    return Scaffold(
      backgroundColor: theme.fleurSurface.chrome,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final scope = ShellLayerScope.maybeOf(context);
            final shellChromeLayout =
                scope?.shellChromeLayout ?? ShellChromeLayout.resolve();
            final preferredNavigation = ref.watch(
              settingsSidebarPresentationModeProvider,
            );
            final arrangement =
                scope?.workspaceArrangement ??
                AdaptiveWorkspaceArrangement.resolve(
                  totalWidth: width,
                  preferredNavigation: preferredNavigation,
                  navigationMetrics:
                      shellChromeLayout.workspaceNavigationMetrics,
                  requirements: WorkspaceLayoutRequirements.settings,
                  hasReader: false,
                );
            final navigationPresentation = arrangement.navigationPresentation;
            final sidebarExpanded =
                navigationPresentation ==
                WorkspaceNavigationPresentation.expanded;
            final sidebarRail =
                navigationPresentation == WorkspaceNavigationPresentation.rail;
            final temporaryNavigationOpen = ref.watch(
              settingsTemporaryNavigationOpenProvider,
            );
            final railWidth = shellChromeLayout.placesControlsInTitleBar
                ? kTitleBarExpectedSidebarRailWidth
                : kSidebarRailWidth;
            final items = _buildItems(context, showPageTitle: false);
            final trimmedSearchQuery = _searchQuery.trim();
            final showingSearchResults = trimmedSearchQuery.isNotEmpty;
            final currentSelectedIndex = _selectedIndexFor(items);
            final showingList =
                navigationPresentation ==
                    WorkspaceNavigationPresentation.offCanvas &&
                currentSelectedIndex == null;
            final selectedIndex = currentSelectedIndex ?? 0;
            final selectedItem = items[selectedIndex];
            final tabLabels = {for (final item in items) item.tab: item.label};
            final searchResults = showingSearchResults
                ? searchSettingsEntries(searchEntries, trimmedSearchQuery)
                : const <SettingsSearchEntry>[];

            void selectTab(SettingsTab tab) {
              setState(() {
                _selectedTab = tab;
                _appearanceDetailPage = null;
              });
              ref.read(settingsTemporaryNavigationOpenProvider.notifier).state =
                  false;
            }

            void handleDetailBack() {
              if (selectedItem.tab == SettingsTab.appearance &&
                  _appearanceDetailPage != null) {
                setState(() => _appearanceDetailPage = null);
                return;
              }
              // Subscriptions has its own internal list/detail back stack.
              if (selectedItem.tab == SettingsTab.subscriptions) {
                final notifier = ref.read(
                  subscriptionSelectionProvider.notifier,
                );
                final shouldPop = notifier.handleBack();
                if (!shouldPop) return;
              }
              setState(() {
                _selectedTab = null;
                _appearanceDetailPage = null;
              });
            }

            void handleChromeBack() {
              if (selectedItem.tab == SettingsTab.appearance &&
                  _appearanceDetailPage != null) {
                setState(() => _appearanceDetailPage = null);
                return;
              }
              _closeSettings();
            }

            final content = showingSearchResults
                ? _SettingsSearchResultsBody(
                    query: trimmedSearchQuery,
                    results: searchResults,
                    tabLabels: tabLabels,
                    onSelected: _selectSearchEntry,
                  )
                : showingList
                ? _SettingsListBody(items: items, onSelect: selectTab)
                : FocusTraversalGroup(child: selectedItem.content);
            final scene = _SettingsScene(
              width: width,
              height: constraints.maxHeight,
              navigationPresentation: navigationPresentation,
              temporaryNavigationOpen: temporaryNavigationOpen,
              railWidth: railWidth,
              title: showingSearchResults || showingList
                  ? l10n.settings
                  : selectedItem.label,
              sidebarTitle: l10n.settings,
              showSidebarButton:
                  navigationPresentation ==
                      WorkspaceNavigationPresentation.offCanvas &&
                  !shellChromeLayout.placesControlsInTitleBar,
              onToggleSidebar: () =>
                  ref
                          .read(
                            settingsTemporaryNavigationOpenProvider.notifier,
                          )
                          .state =
                      !temporaryNavigationOpen,
              onBack: sidebarExpanded || sidebarRail
                  ? (widget.showBack ? handleChromeBack : null)
                  : showingList
                  ? (widget.showBack ? _closeSettings : null)
                  : handleDetailBack,
              items: items,
              sidebarSelectedIndex: sidebarExpanded || sidebarRail
                  ? selectedIndex
                  : currentSelectedIndex,
              selectedContentKey: showingSearchResults
                  ? const ValueKey('settings-search-results')
                  : showingList
                  ? const ValueKey('settings-list')
                  : ValueKey(selectedItem.tab),
              content: content,
              onSelect: selectTab,
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              searchFocused: _searchFocused,
            );

            if (!sidebarExpanded && !sidebarRail && !showingList) {
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
    required this.height,
    required this.navigationPresentation,
    required this.temporaryNavigationOpen,
    required this.railWidth,
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
    required this.searchController,
    required this.searchFocusNode,
    required this.searchFocused,
  });

  final double width;
  final double height;
  final WorkspaceNavigationPresentation navigationPresentation;
  final bool temporaryNavigationOpen;
  final double railWidth;
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
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool searchFocused;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).fleurSurface;
    final sidebarExpanded =
        navigationPresentation == WorkspaceNavigationPresentation.expanded;
    final sidebarRail =
        navigationPresentation == WorkspaceNavigationPresentation.rail;
    final structuralContentLeft = sidebarExpanded
        ? _SettingsScreenState._kSettingsSidebarWidth +
              kSidebarContentDividerWidth
        : sidebarRail
        ? railWidth
        : 0.0;
    final contentLeft = temporaryNavigationOpen
        ? _SettingsScreenState._kSettingsSidebarWidth
        : structuralContentLeft;
    final contentWidth = (width - structuralContentLeft)
        .clamp(0.0, double.infinity)
        .toDouble();
    final sidebarPinned = sidebarExpanded || sidebarRail;

    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: surfaces.chrome,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (sidebarExpanded || temporaryNavigationOpen)
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
            if (sidebarRail && !temporaryNavigationOpen)
              Positioned(
                key: const Key('settings_navigation_rail'),
                left: 0,
                top: 0,
                bottom: 0,
                width: railWidth,
                child: _SettingsNavigationRail(
                  width: railWidth,
                  items: items,
                  selectedIndex: sidebarSelectedIndex,
                  onSelect: onSelect,
                ),
              ),
            if ((sidebarExpanded || sidebarRail) && !temporaryNavigationOpen)
              Positioned(
                key: const Key('settings_sidebar_divider'),
                left: structuralContentLeft - kSidebarContentDividerWidth,
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
                sidebarOpen: temporaryNavigationOpen,
                title: title,
                showSidebarButton: showSidebarButton,
                onToggleSidebar: onToggleSidebar,
                onBack: onBack,
                selectedContentKey: selectedContentKey,
                searchController: searchController,
                searchFocusNode: searchFocusNode,
                searchFocused: searchFocused,
                child: content,
              ),
            ),
            if (temporaryNavigationOpen)
              Positioned(
                key: const Key('settings_navigation_scrim'),
                left: _SettingsScreenState._kSettingsSidebarWidth,
                top: 0,
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggleSidebar,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsNavigationRail extends StatelessWidget {
  const _SettingsNavigationRail({
    required this.width,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final double width;
  final List<_SettingsPageItem> items;
  final int? selectedIndex;
  final ValueChanged<SettingsTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;
    final scheme = theme.colorScheme;

    return Material(
      color: surfaces.sidebar,
      child: Column(
        children: [
          SizedBox(
            height: kWorkspaceHeaderHeight,
            child: Center(
              child: Icon(
                FleurIcons.settingsSelected,
                size: 18,
                color: scheme.primary,
              ),
            ),
          ),
          Expanded(
            child: AppScrollbar(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = index == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Center(
                      child: IconButton(
                        key: Key('settings_rail_nav_${item.tab.queryValue}'),
                        tooltip: item.label,
                        onPressed: () => onSelect(item.tab),
                        icon: Icon(
                          selected ? item.selectedIcon : item.icon,
                          size: 18,
                        ),
                        style: IconButton.styleFrom(
                          foregroundColor: selected
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          backgroundColor: selected
                              ? surfaces.cardSelected
                              : Colors.transparent,
                          fixedSize: const Size.square(40),
                          minimumSize: const Size.square(40),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
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
    required this.searchController,
    required this.searchFocusNode,
    required this.searchFocused,
    required this.child,
  });

  final bool sidebarPinned;
  final bool sidebarOpen;
  final String title;
  final bool showSidebarButton;
  final VoidCallback onToggleSidebar;
  final VoidCallback? onBack;
  final Key selectedContentKey;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool searchFocused;
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
          if (!sidebarPinned)
            _SettingsSearchDock(
              insidePaper: true,
              controller: searchController,
              focusNode: searchFocusNode,
              focused: searchFocused,
            ),
          Divider(height: 1, color: surfaces.subtleDivider),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: [...previousChildren, ?currentChild],
                );
              },
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
                  _SettingsSearchDock(
                    insidePaper: false,
                    controller: searchController,
                    focusNode: searchFocusNode,
                    focused: searchFocused,
                  ),
                  const SizedBox(
                    height: _SettingsScreenState._kSettingsSearchPaperGap,
                  ),
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
    final rowTop = isMacOS
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
    final surfaces = theme.fleurSurface;
    final dark = theme.brightness == Brightness.dark;
    final shadowColor = theme.shadowColor.withValues(alpha: dark ? 0.28 : 0.10);

    return DecoratedBox(
      key: const Key('settings_paper_surface'),
      decoration: BoxDecoration(
        color: surfaces.list,
        borderRadius: borderRadius,
        border: Border.all(color: surfaces.subtleDivider),
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
  const _SettingsSearchDock({
    required this.insidePaper,
    required this.controller,
    required this.focusNode,
    required this.focused,
  });

  final bool insidePaper;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = insidePaper ? 12.0 : 16.0;
    return SizedBox(
      key: Key(
        insidePaper
            ? 'settings_search_inside_paper'
            : 'settings_search_outside_paper',
      ),
      height: insidePaper ? 56 : 64,
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _SettingsSearchField(
              controller: controller,
              focusNode: focusNode,
              focused: focused,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSearchField extends StatelessWidget {
  const _SettingsSearchField({
    required this.controller,
    required this.focusNode,
    required this.focused,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaces = theme.fleurSurface;
    final dark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return SizedBox(
          key: const Key('settings_search_placeholder'),
          height: 44,
          child: AnimatedContainer(
            key: const Key('settings_search_field_surface'),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: surfaces.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: focused ? scheme.primary : surfaces.subtleDivider,
                width: focused ? 2 : 1,
              ),
              boxShadow: focused
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(
                          alpha: dark ? 0.24 : 0.18,
                        ),
                        blurRadius: 0,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  FleurIcons.search,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: l10n.settingsSearchHint,
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: true,
                      fillColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: theme.textTheme.bodyMedium,
                    textInputAction: TextInputAction.search,
                  ),
                ),
                if (controller.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                      onPressed: controller.clear,
                      icon: const Icon(FleurIcons.close, size: 16),
                      style: IconButton.styleFrom(
                        foregroundColor: scheme.onPrimary,
                        backgroundColor: scheme.onSurfaceVariant,
                        fixedSize: const Size.square(30),
                        minimumSize: const Size.square(30),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 14),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsSearchResultsBody extends StatelessWidget {
  const _SettingsSearchResultsBody({
    required this.query,
    required this.results,
    required this.tabLabels,
    required this.onSelected,
  });

  final String query;
  final List<SettingsSearchEntry> results;
  final Map<SettingsTab, String> tabLabels;
  final ValueChanged<SettingsSearchEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    final grouped = <SettingsTab, List<SettingsSearchEntry>>{};
    for (final entry in results) {
      grouped.putIfAbsent(entry.tab, () => []).add(entry);
    }

    return SettingsPageBody(
      key: const Key('settings_search_results_body'),
      maxWidth: 760,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      children: results.isEmpty
          ? [const _SettingsSearchEmptyState()]
          : [
              for (final group in grouped.entries)
                _SettingsSearchResultGroup(
                  title: tabLabels[group.key] ?? group.key.queryValue,
                  query: query,
                  results: group.value,
                  onSelected: onSelected,
                ),
            ],
    );
  }
}

class _SettingsSearchEmptyState extends StatelessWidget {
  const _SettingsSearchEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      key: const Key('settings_search_no_results'),
      padding: const EdgeInsets.symmetric(vertical: 88),
      child: Column(
        children: [
          Icon(FleurIcons.search, size: 28, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            l10n.settingsSearchNoResults,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSearchResultGroup extends StatelessWidget {
  const _SettingsSearchResultGroup({
    required this.title,
    required this.query,
    required this.results,
    required this.onSelected,
  });

  final String title;
  final String query;
  final List<SettingsSearchEntry> results;
  final ValueChanged<SettingsSearchEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _SettingsSearchCountBadge(
                label: l10n.settingsSearchResultCount(results.length),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: surfaces.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: surfaces.subtleDivider),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  for (var index = 0; index < results.length; index++) ...[
                    if (index > 0)
                      Divider(height: 1, color: surfaces.subtleDivider),
                    _SettingsSearchResultRow(
                      entry: results[index],
                      query: query,
                      path: _settingsSearchEntryPath(
                        l10n,
                        title,
                        results[index],
                      ),
                      onSelected: onSelected,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSearchCountBadge extends StatelessWidget {
  const _SettingsSearchCountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: dark ? 0.28 : 0.42),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: dark ? Colors.amber.shade100 : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SettingsSearchResultRow extends StatelessWidget {
  const _SettingsSearchResultRow({
    required this.entry,
    required this.query,
    required this.path,
    required this.onSelected,
  });

  final SettingsSearchEntry entry;
  final String query;
  final String path;
  final ValueChanged<SettingsSearchEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaces = theme.fleurSurface;
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final pathStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('settings_search_result_${entry.id}'),
        onTap: () => onSelected(entry),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: surfaces.cardSelected,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: Icon(
                    settingsSearchEntryIcon(entry),
                    size: 17,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: _settingsSearchHighlightSpans(
                          entry.title,
                          query,
                          titleStyle,
                          _settingsSearchHighlightStyle(titleStyle, context),
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: _settingsSearchHighlightSpans(
                          path,
                          query,
                          pathStyle,
                          _settingsSearchHighlightStyle(pathStyle, context),
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(FleurIcons.expand, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

String _settingsSearchEntryPath(
  AppLocalizations l10n,
  String tabLabel,
  SettingsSearchEntry entry,
) {
  if (entry.kind == SettingsSearchEntryKind.page) {
    return settingsSearchEntryKindLabel(l10n, entry.kind);
  }
  if (entry.section.isEmpty) return tabLabel;
  return '$tabLabel / ${entry.section}';
}

TextStyle _settingsSearchHighlightStyle(
  TextStyle? baseStyle,
  BuildContext context,
) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  return (baseStyle ?? const TextStyle()).copyWith(
    backgroundColor: Colors.amber.withValues(alpha: dark ? 0.36 : 0.48),
    color: baseStyle?.color,
  );
}

List<TextSpan> _settingsSearchHighlightSpans(
  String text,
  String query,
  TextStyle? baseStyle,
  TextStyle highlightStyle,
) {
  final normalizedText = text.toLowerCase();
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty || !normalizedText.contains(normalizedQuery)) {
    return [TextSpan(text: text, style: baseStyle)];
  }

  final spans = <TextSpan>[];
  var cursor = 0;
  while (cursor < text.length) {
    final match = normalizedText.indexOf(normalizedQuery, cursor);
    if (match < 0) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
      break;
    }
    if (match > cursor) {
      spans.add(
        TextSpan(text: text.substring(cursor, match), style: baseStyle),
      );
    }
    final end = match + normalizedQuery.length;
    spans.add(
      TextSpan(text: text.substring(match, end), style: highlightStyle),
    );
    cursor = end;
  }
  return spans;
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
    final selectedColor = surfaces.cardSelected;
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
