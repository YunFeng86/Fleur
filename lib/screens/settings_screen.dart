import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../app/settings_routes.dart';
import '../ui/app_drawer_scope.dart';
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
import '../widgets/fleur_selectable_button.dart';
import '../widgets/fleur_selection_transition.dart';
import '../widgets/fleur_shell_icon_button.dart';

part '../ui/settings/settings_scene.dart';
part '../ui/settings/settings_search_view.dart';

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
            final canExpandInline =
                AdaptiveWorkspaceArrangement.resolve(
                  totalWidth: width,
                  preferredNavigation: SidebarPresentationMode.expanded,
                  navigationMetrics:
                      shellChromeLayout.workspaceNavigationMetrics,
                  requirements: WorkspaceLayoutRequirements.settings,
                  hasReader: false,
                ).navigationPresentation ==
                WorkspaceNavigationPresentation.expanded;
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
            void toggleNavigation() {
              final shellToggle = AppDrawerScope.drawerOpenerOf(context);
              if (shellToggle != null) {
                shellToggle();
                return;
              }
              final result = WorkspaceNavigationToggleResult.resolve(
                presentation: navigationPresentation,
                preferredNavigation: preferredNavigation,
                temporaryNavigationOpen: temporaryNavigationOpen,
                canExpandInline: canExpandInline,
              );
              ref.read(settingsSidebarPresentationModeProvider.notifier).state =
                  result.preferredNavigation;
              ref.read(settingsTemporaryNavigationOpenProvider.notifier).state =
                  result.temporaryNavigationOpen;
            }

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
              showSidebarButton: !shellChromeLayout.placesControlsInTitleBar,
              onToggleSidebar: toggleNavigation,
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
