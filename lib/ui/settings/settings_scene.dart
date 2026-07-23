import 'package:flutter/material.dart';

import '../../app/settings_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/fleur_icons.dart';
import '../../theme/fleur_theme_extensions.dart';
import '../../widgets/app_scrollbar.dart';
import '../adaptive_workspace_layout.dart';
import '../design_system/design_system.dart';
import '../motion.dart';
import '../shell_chrome_layout.dart';
import '../shell_frame_geometry.dart';
import '../shell_frame_topology.dart';
import '../shell_temporary_navigation.dart';
import '../sidebar_layout.dart';
import '../workspace_layers.dart';
import 'settings_search_view.dart';
import 'widgets/settings_controls.dart';

const double _kSettingsSidebarWidth = kDefaultWorkspaceSidebarWidth;
const double _kSettingsPaperMaxWidth = 960;
const double _kSettingsSearchPaperGap = 8;
const double _kSettingsPinnedHeaderInset = 14;
const Duration _kLayerAnimationDuration = Duration(milliseconds: 180);

double _settingsHeaderLeadingInset({
  required BuildContext context,
  required double sceneWidth,
  required ShellFrameGeometry frameGeometry,
  required bool sidebarPinned,
}) {
  final availableWidth =
      (frameGeometry.contentWidth - frameGeometry.contentLeadingInset)
          .clamp(0.0, double.infinity)
          .toDouble();
  final paperWidth = sidebarPinned
      ? availableWidth.clamp(0.0, _kSettingsPaperMaxWidth).toDouble()
      : availableWidth;
  final paperLeft =
      frameGeometry.translatedContentLeft +
      frameGeometry.contentLeadingInset +
      (availableWidth - paperWidth) / 2;
  final scope = ShellLayerScope.maybeOf(context);
  final shellAvoidanceLeft =
      frameGeometry.translatedContentLeft + (scope?.headerLeadingInset ?? 0);
  var leadingInset = shellAvoidanceLeft - paperLeft;

  if (sidebarPinned) {
    final referenceContentLeft =
        (kDefaultWorkspaceSidebarWidth + kSidebarContentDividerWidth)
            .clamp(0.0, sceneWidth)
            .toDouble();
    final referenceContentWidth = sceneWidth - referenceContentLeft;
    final referencePaperWidth = referenceContentWidth
        .clamp(0.0, _kSettingsPaperMaxWidth)
        .toDouble();
    final referencePaperLeft =
        referenceContentLeft +
        (referenceContentWidth - referencePaperWidth) / 2;
    final stableLeadingInset =
        referencePaperLeft + _kSettingsPinnedHeaderInset - paperLeft;
    if (stableLeadingInset > leadingInset) {
      leadingInset = stableLeadingInset;
    }
  }

  return leadingInset.clamp(0.0, double.infinity).toDouble();
}

class SettingsScene extends StatelessWidget {
  const SettingsScene({
    super.key,
    required this.width,
    required this.height,
    required this.navigationPresentation,
    required this.temporaryNavigationOpen,
    required this.railWidth,
    required this.frameGeometry,
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
    required this.navigationToggleFocusNode,
    required this.temporaryNavigationFocusNode,
  });

  final double width;
  final double height;
  final WorkspaceNavigationPresentation navigationPresentation;
  final bool temporaryNavigationOpen;
  final double railWidth;
  final ShellFrameGeometry frameGeometry;
  final String title;
  final String sidebarTitle;
  final bool showSidebarButton;
  final VoidCallback onToggleSidebar;
  final VoidCallback? onBack;
  final List<SettingsPageItem> items;
  final int? sidebarSelectedIndex;
  final Key selectedContentKey;
  final Widget content;
  final ValueChanged<SettingsTab> onSelect;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool searchFocused;
  final FocusNode navigationToggleFocusNode;
  final FocusScopeNode temporaryNavigationFocusNode;

  @override
  Widget build(BuildContext context) {
    final surfaces = Theme.of(context).fleurSurface;
    final sidebarExpanded =
        navigationPresentation == WorkspaceNavigationPresentation.expanded;
    final sidebarRail =
        navigationPresentation == WorkspaceNavigationPresentation.rail;
    final sidebarPinned = sidebarExpanded || sidebarRail;
    final headerLeadingInset = _settingsHeaderLeadingInset(
      context: context,
      sceneWidth: width,
      frameGeometry: frameGeometry,
      sidebarPinned: sidebarPinned,
    );
    final expandedSidebar = _SettingsSidebar(
      title: sidebarTitle,
      railWidth: railWidth,
      items: items,
      selectedIndex: sidebarSelectedIndex,
      onSelect: onSelect,
    );
    final visibleExpandedSidebar = temporaryNavigationOpen
        ? FocusScope.withExternalFocusNode(
            focusScopeNode: temporaryNavigationFocusNode,
            autofocus: true,
            child: expandedSidebar,
          )
        : expandedSidebar;

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
                width: _kSettingsSidebarWidth,
                child: visibleExpandedSidebar,
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
                  floating:
                      frameGeometry.topology.navigationSurface ==
                      ShellNavigationSurface.floatingIsland,
                  items: items,
                  selectedIndex: sidebarSelectedIndex,
                  onSelect: onSelect,
                ),
              ),
            if (!temporaryNavigationOpen &&
                (sidebarExpanded || frameGeometry.structuralRailVisible))
              Positioned(
                key: const Key('settings_sidebar_divider'),
                left: frameGeometry.contentLeft - kSidebarContentDividerWidth,
                top: 0,
                bottom: 0,
                width: kSidebarContentDividerWidth,
                child: ColoredBox(color: surfaces.subtleDivider),
              ),
            AnimatedPositioned(
              key: const Key('settings_content_layer'),
              duration: AppMotion.effectiveDuration(
                context,
                _kLayerAnimationDuration,
              ),
              curve: Curves.easeOutCubic,
              left: frameGeometry.translatedContentLeft,
              top: 0,
              bottom: 0,
              width: frameGeometry.contentWidth,
              child: ShellTemporarySceneGate(
                navigationOpen: temporaryNavigationOpen,
                child: Padding(
                  key: const Key('settings_content_avoidance'),
                  padding: EdgeInsets.only(
                    left: frameGeometry.contentLeadingInset,
                  ),
                  child: _SettingsContentLayer(
                    sidebarPinned: sidebarPinned,
                    sidebarOpen: temporaryNavigationOpen,
                    headerLeadingInset: headerLeadingInset,
                    title: title,
                    showSidebarButton: showSidebarButton,
                    onToggleSidebar: onToggleSidebar,
                    onBack: onBack,
                    selectedContentKey: selectedContentKey,
                    searchController: searchController,
                    searchFocusNode: searchFocusNode,
                    searchFocused: searchFocused,
                    navigationToggleFocusNode: navigationToggleFocusNode,
                    child: content,
                  ),
                ),
              ),
            ),
            if (temporaryNavigationOpen)
              Positioned(
                key: const Key('settings_navigation_scrim'),
                left: _kSettingsSidebarWidth,
                top: 0,
                right: 0,
                bottom: 0,
                child: ShellNavigationDismissScrim(
                  onDismiss: onToggleSidebar,
                  color: Colors.black.withValues(alpha: 0.08),
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
    required this.floating,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final double width;
  final bool floating;
  final List<SettingsPageItem> items;
  final int? selectedIndex;
  final ValueChanged<SettingsTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.fleurSurface;
    final scheme = theme.colorScheme;
    final scope = ShellLayerScope.maybeOf(context);
    final reserveShellTools =
        scope != null &&
        scope.shellChromeLayout?.profile == ShellChromeProfile.integratedCorner;

    final navigationList = AppScrollbar(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = index == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Center(
              child: FleurShellIconButton(
                key: Key('settings_rail_nav_${item.tab.queryValue}'),
                tooltip: item.label,
                onPressed: () => onSelect(item.tab),
                icon: FleurAnimatedIcon(
                  icon: selected ? item.selectedIcon : item.icon,
                  size: 18,
                ),
                selected: selected,
                size: 40,
                selectedBackgroundColor: surfaces.cardSelected,
                selectedForegroundColor: scheme.primary,
                unselectedForegroundColor: scheme.onSurfaceVariant,
                adaptiveTapTarget: true,
              ),
            ),
          );
        },
      ),
    );

    return Material(
      color: floating ? Colors.transparent : surfaces.sidebar,
      child: Column(
        children: [
          SizedBox(
            key: const Key('settings_rail_header'),
            height: kWorkspaceHeaderHeight,
            child: reserveShellTools
                ? null
                : Center(
                    child: Icon(
                      FleurIcons.settingsSelected,
                      size: 18,
                      color: scheme.primary,
                    ),
                  ),
          ),
          Expanded(
            child: floating
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final desiredHeight = items.length * 44.0 + 8;
                        final islandHeight = desiredHeight
                            .clamp(0.0, constraints.maxHeight)
                            .toDouble();
                        const radius = BorderRadius.all(Radius.circular(999));
                        return Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            height: islandHeight,
                            child: DecoratedBox(
                              key: const Key('settings_collapsed_rail_surface'),
                              decoration: BoxDecoration(
                                color: surfaces.floating,
                                border: Border.all(
                                  color: surfaces.subtleDivider,
                                ),
                                borderRadius: radius,
                              ),
                              child: ClipRRect(
                                borderRadius: radius,
                                child: navigationList,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : navigationList,
          ),
        ],
      ),
    );
  }
}

class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({
    required this.title,
    required this.railWidth,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final String title;
  final double railWidth;
  final List<SettingsPageItem> items;
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
                        railWidth: railWidth,
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
    final chromeLayout =
        scope?.shellChromeLayout ?? ShellChromeLayout.resolve();
    final metrics =
        scope?.macOSWindowChromeMetrics ?? MacOSWindowChromeMetrics.fallback;
    final avoidTrafficLights =
        chromeLayout.profile == ShellChromeProfile.integratedCorner &&
        metrics.trafficLightsVisible;
    final leadingLeft = avoidTrafficLights ? metrics.safeInset : 16.0;
    final reserveShellTools =
        scope != null &&
        chromeLayout.profile == ShellChromeProfile.integratedCorner;

    return SizedBox(
      key: const Key('settings_sidebar_header'),
      height: kWorkspaceHeaderHeight,
      child: reserveShellTools
          ? null
          : Padding(
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

class SettingsListBody extends StatelessWidget {
  const SettingsListBody({
    super.key,
    required this.items,
    required this.onSelect,
  });

  final List<SettingsPageItem> items;
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
    required this.headerLeadingInset,
    required this.title,
    required this.showSidebarButton,
    required this.onToggleSidebar,
    required this.onBack,
    required this.selectedContentKey,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchFocused,
    required this.navigationToggleFocusNode,
    required this.child,
  });

  final bool sidebarPinned;
  final bool sidebarOpen;
  final double headerLeadingInset;
  final String title;
  final bool showSidebarButton;
  final VoidCallback onToggleSidebar;
  final VoidCallback? onBack;
  final Key selectedContentKey;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool searchFocused;
  final FocusNode navigationToggleFocusNode;
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
            headerLeadingInset: headerLeadingInset,
            showSidebarButton: showSidebarButton,
            onToggleSidebar: onToggleSidebar,
            onBack: onBack,
            navigationToggleFocusNode: navigationToggleFocusNode,
          ),
          if (!sidebarPinned)
            SettingsSearchDock(
              insidePaper: true,
              controller: searchController,
              focusNode: searchFocusNode,
              focused: searchFocused,
            ),
          Divider(height: 1, color: surfaces.subtleDivider),
          Expanded(
            child: KeyedSubtree(key: selectedContentKey, child: child),
          ),
        ],
      ),
    );

    if (!sidebarPinned) return paper;

    return LayoutBuilder(
      builder: (context, constraints) {
        final paperWidth = constraints.maxWidth
            .clamp(0.0, _kSettingsPaperMaxWidth)
            .toDouble();

        return ColoredBox(
          color: surfaces.chrome,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: paperWidth,
              child: Column(
                children: [
                  SettingsSearchDock(
                    insidePaper: false,
                    controller: searchController,
                    focusNode: searchFocusNode,
                    focused: searchFocused,
                  ),
                  const SizedBox(height: _kSettingsSearchPaperGap),
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
    required this.headerLeadingInset,
    required this.showSidebarButton,
    required this.onToggleSidebar,
    required this.onBack,
    required this.navigationToggleFocusNode,
  });

  final String title;
  final bool sidebarPinned;
  final bool sidebarOpen;
  final double headerLeadingInset;
  final bool showSidebarButton;
  final VoidCallback onToggleSidebar;
  final VoidCallback? onBack;
  final FocusNode navigationToggleFocusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scope = ShellLayerScope.maybeOf(context);
    final chromeLayout =
        scope?.shellChromeLayout ?? ShellChromeLayout.resolve();
    final integratedCorner =
        chromeLayout.profile == ShellChromeProfile.integratedCorner;
    final metrics =
        scope?.macOSWindowChromeMetrics ?? MacOSWindowChromeMetrics.fallback;
    final avoidTrafficLights =
        !sidebarPinned &&
        !sidebarOpen &&
        integratedCorner &&
        metrics.trafficLightsVisible;
    final baseLeadingLeft = avoidTrafficLights ? metrics.safeInset : 8.0;
    final leadingLeft = headerLeadingInset > baseLeadingLeft
        ? headerLeadingInset
        : baseLeadingLeft;
    final rowTop = integratedCorner
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
                    focusNode: navigationToggleFocusNode,
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
                      key: const Key('settings_scene_title'),
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
    this.focusNode,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return FleurShellIconButton(
      focusNode: focusNode,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: kShellControlIconSize),
      size: kShellControlSize,
    );
  }
}

class _SettingsNavigationTile extends StatelessWidget {
  const _SettingsNavigationTile({
    super.key,
    required this.item,
    this.railWidth = kSidebarRailWidth,
    required this.onTap,
    this.selected = false,
    this.trailing,
  });

  final SettingsPageItem item;
  final double railWidth;
  final VoidCallback onTap;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surfaces = theme.fleurSurface;

    return Semantics(
      button: true,
      selected: selected,
      child: FleurSelectableButton(
        key: Key('settings_nav_button_${item.tab.queryValue}'),
        selected: selected,
        onPressed: onTap,
        minimumHeight: 42,
        padding: EdgeInsetsDirectional.fromSTEB(railWidth / 2 - 21, 8, 12, 8),
        alignment: AlignmentDirectional.centerStart,
        borderRadius: BorderRadius.circular(22),
        selectedBackgroundColor: surfaces.cardSelected,
        selectedForegroundColor: scheme.primary,
        unselectedForegroundColor: scheme.onSurfaceVariant,
        child: Row(
          children: [
            Icon(item.icon, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
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
    );
  }
}

class SettingsPageItem {
  final SettingsTab tab;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget content;

  const SettingsPageItem({
    required this.tab,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.content,
  });
}
