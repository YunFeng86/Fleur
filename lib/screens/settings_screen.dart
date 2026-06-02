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
  static const _kSettingsMinContentWidth = 720.0;
  static const _kSettingsPaperMaxWidth = 960.0;
  static const _kSettingsSearchPaperGap = 8.0;
  static const _kSidebarPinnedWidth =
      _kSettingsSidebarWidth + _kSettingsMinContentWidth;
  static const _kLayerAnimationDuration = Duration(milliseconds: 180);

  // Nullable tab: null means "List View" in narrow mode or default first item
  // in wide mode.
  SettingsTab? _selectedTab;
  bool _sidebarOpen = false;
  final SettingsTargetController _targetController = SettingsTargetController();
  Timer? _highlightTimer;
  String? _pendingInitialSettingId;

  @override
  void initState() {
    super.initState();
    _selectedTab =
        widget.initialTab ?? _tabForSettingId(widget.initialSettingId);
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
    _pendingInitialSettingId = widget.initialSettingId;
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
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

  void _revealTarget(String targetId) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final targetContext = _targetController.contextFor(targetId);
      if (targetContext == null) return;
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
    });
  }

  void _selectSearchEntry(SettingsSearchEntry entry) {
    setState(() {
      _selectedTab = entry.tab;
      _sidebarOpen = false;
    });
    final targetId = entry.targetId;
    if (targetId != null) _revealTarget(targetId);
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
        final targetId = entry?.targetId ?? trimmed;
        if (entry?.targetId != null ||
            _targetController.contextFor(targetId) != null) {
          _revealTarget(targetId);
        }
      });
    }

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
              onBack: sidebarPinned
                  ? (widget.showBack ? _closeSettings : null)
                  : showingList
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
              searchEntries: searchEntries,
              onSearchEntrySelected: _selectSearchEntry,
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
    required this.searchEntries,
    required this.onSearchEntrySelected,
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
  final List<SettingsSearchEntry> searchEntries;
  final ValueChanged<SettingsSearchEntry> onSearchEntrySelected;

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
              searchEntries: searchEntries,
              onSearchEntrySelected: onSearchEntrySelected,
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
    required this.searchEntries,
    required this.onSearchEntrySelected,
    required this.child,
  });

  final bool sidebarPinned;
  final bool sidebarOpen;
  final String title;
  final bool showSidebarButton;
  final VoidCallback onToggleSidebar;
  final VoidCallback? onBack;
  final Key selectedContentKey;
  final List<SettingsSearchEntry> searchEntries;
  final ValueChanged<SettingsSearchEntry> onSearchEntrySelected;
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
              entries: searchEntries,
              onSelected: onSearchEntrySelected,
            ),
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
                  _SettingsSearchDock(
                    insidePaper: false,
                    entries: searchEntries,
                    onSelected: onSearchEntrySelected,
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

class _SettingsSearchDock extends StatefulWidget {
  const _SettingsSearchDock({
    required this.insidePaper,
    required this.entries,
    required this.onSelected,
  });

  final bool insidePaper;
  final List<SettingsSearchEntry> entries;
  final ValueChanged<SettingsSearchEntry> onSelected;

  @override
  State<_SettingsSearchDock> createState() => _SettingsSearchDockState();
}

class _SettingsSearchDockState extends State<_SettingsSearchDock> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleSearchChanged);
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _SettingsSearchDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries && _overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.removeListener(_handleSearchChanged);
    _focusNode.removeListener(_handleFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (_focusNode.hasFocus) _showOverlay();
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      _showOverlay();
    } else {
      scheduleMicrotask(_removeOverlay);
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildOverlay(BuildContext context) {
    final box = this.context.findRenderObject() as RenderBox?;
    final width =
        box?.size.width ?? _SettingsScreenState._kSettingsPaperMaxWidth;
    final results = searchSettingsEntries(widget.entries, _controller.text);

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _focusNode.unfocus(),
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 6),
              child: Material(
                type: MaterialType.transparency,
                child: SizedBox(
                  width: width,
                  child: _SettingsSearchResultsPanel(
                    results: results,
                    onSelected: (entry) {
                      _controller.clear();
                      _focusNode.unfocus();
                      _removeOverlay();
                      widget.onSelected(entry);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = widget.insidePaper ? 12.0 : 16.0;
    return SizedBox(
      key: Key(
        widget.insidePaper
            ? 'settings_search_inside_paper'
            : 'settings_search_outside_paper',
      ),
      height: widget.insidePaper ? 50 : 56,
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _SettingsScreenState._kSettingsPaperMaxWidth,
            ),
            child: CompositedTransformTarget(
              link: _layerLink,
              child: _SettingsSearchField(
                controller: _controller,
                focusNode: _focusNode,
              ),
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
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaces = theme.fleurSurface;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          key: const Key('settings_search_placeholder'),
          height: 40,
          decoration: BoxDecoration(
            color: surfaces.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: surfaces.subtleDivider),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(FleurIcons.search, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration.collapsed(
                    hintText: l10n.settingsSearchHint,
                    hintStyle: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  style: theme.textTheme.bodySmall,
                  textInputAction: TextInputAction.search,
                ),
              ),
              if (controller.text.isNotEmpty)
                IconButton(
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).deleteButtonTooltip,
                  onPressed: controller.clear,
                  icon: const Icon(FleurIcons.close, size: 16),
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(32),
                    minimumSize: const Size.square(32),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsSearchResultsPanel extends StatelessWidget {
  const _SettingsSearchResultsPanel({
    required this.results,
    required this.onSelected,
  });

  final List<SettingsSearchEntry> results;
  final ValueChanged<SettingsSearchEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaces = theme.fleurSurface;
    final dark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      key: const Key('settings_search_results_panel'),
      decoration: BoxDecoration(
        color: surfaces.floating,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: surfaces.subtleDivider),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: dark ? 0.28 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: results.isEmpty
              ? Padding(
                  key: const Key('settings_search_no_results'),
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.settingsSearchNoResults,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : AppScrollbar(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: surfaces.subtleDivider),
                    itemBuilder: (context, index) {
                      final entry = results[index];
                      final sectionText = entry.section.isEmpty
                          ? settingsSearchEntryKindLabel(l10n, entry.kind)
                          : '${settingsSearchEntryKindLabel(l10n, entry.kind)} · ${entry.section}';

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: Key('settings_search_result_${entry.id}'),
                          onTap: () => onSelected(entry),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  settingsSearchEntryIcon(entry),
                                  size: 18,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        entry.subtitle.isEmpty
                                            ? sectionText
                                            : '$sectionText · ${entry.subtitle}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
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
