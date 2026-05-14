import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../app/article_scope_routes.dart';
import '../models/article_scope.dart';
import '../providers/core_providers.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../widgets/fleur_capsule_button_group.dart';
import '../widgets/sidebar.dart';
import '../utils/platform.dart';
import 'app_drawer_scope.dart';
import 'app_menu.dart';
import 'layout.dart';
import 'layout_spec.dart';
import 'sidebar_layout.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.currentUri, required this.child});

  final Uri currentUri;
  final Widget child;

  bool _isArticleRoute(Uri uri) => uri.pathSegments.contains('article');

  double _listWidthForArticleUri(Uri uri) {
    final seg0 = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    return switch (seg0) {
      'search' => kDesktopListWidth,
      _ => kHomeListWidth,
    };
  }

  bool _isReaderEmbedded({required LayoutSpec spec, required Uri uri}) {
    if (!_isArticleRoute(uri)) return true;
    if (isDesktop) {
      return spec.desktopEmbedsReader;
    }
    return spec.canEmbedReader(listWidth: _listWidthForArticleUri(uri));
  }

  void _goToScope(BuildContext context, ArticleScope scope) {
    final router = GoRouter.maybeOf(context);
    final location = scopeLocation(scope);
    if (router != null) {
      router.go(location);
      return;
    }
    unawaited(Navigator.of(context).pushNamed(location));
  }

  void _goToSearch(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/search');
      return;
    }
    unawaited(Navigator.of(context).pushNamed('/search'));
  }

  void _toggleSidebar(WidgetRef ref) {
    final notifier = ref.read(sidebarPresentationModeProvider.notifier);
    notifier.state = notifier.state == SidebarPresentationMode.expanded
        ? SidebarPresentationMode.collapsed
        : SidebarPresentationMode.expanded;
  }

  void _pop(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
      return;
    }
    unawaited(Navigator.of(context).maybePop());
  }

  bool _canPop(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    return router?.canPop() ?? Navigator.canPop(context);
  }

  Widget _sidebarDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Sidebar(
          onSelectScope: (scope) => _goToScope(context, scope),
          router: GoRouter.maybeOf(context),
          presentationModeOverride: SidebarPresentationMode.expanded,
        ),
      ),
    );
  }

  Widget _desktopSidebar({
    required BuildContext context,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Sidebar(
        onSelectScope: (scope) => _goToScope(context, scope),
        reserveShellHeader: isDesktop,
      ),
    );
  }

  Widget _withInlineShellControlsOverlay({
    required BuildContext context,
    required WidgetRef ref,
    required Widget child,
    required SidebarPresentationMode presentationMode,
  }) {
    if (!isDesktop) return child;
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          left: isMacOS ? 72 : 12,
          top: 8,
          child: _InlineShellControlsHost(
            presentationMode: presentationMode,
            canPop: _canPop(context),
            onToggleSidebar: () => _toggleSidebar(ref),
            onPop: () => _pop(context),
            onSearch: () => _goToSearch(context),
          ),
        ),
      ],
    );
  }

  Widget _withDesktopDrawerControlsOverlay({
    required BuildContext context,
    required Widget child,
    required VoidCallback? openDrawer,
  }) {
    if (!isDesktop || openDrawer == null) return child;
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          left: 0,
          top: 0,
          child: _DrawerControlsHost(
            canPop: _canPop(context),
            onPop: () => _pop(context),
            openDrawer: openDrawer,
            onSearch: () => _goToSearch(context),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.sizeOf(context);
    final presentationMode = ref.watch(sidebarPresentationModeProvider);
    final spec = LayoutSpec.fromTotalSize(
      totalWidth: size.width,
      totalHeight: size.height,
      sidebarPresentationMode: presentationMode,
    );
    final surfaces = Theme.of(context).fleurSurface;
    final hideNavForReaderPage =
        _isArticleRoute(currentUri) &&
        !_isReaderEmbedded(spec: spec, uri: currentUri);

    Widget wrapShell(Widget shell) {
      return AppMenuHost(
        child: DecoratedBox(
          decoration: BoxDecoration(color: surfaces.chrome),
          child: shell,
        ),
      );
    }

    if (hideNavForReaderPage) {
      // Dedicated reader pages should maximize content; they have their own
      // back button (ReaderView/ReaderScreen).
      return wrapShell(AppDrawerScope(hasAppDrawer: false, child: child));
    }

    final showInlineSidebar = spec.hasInlineSidebar;
    final sidebarWidth = sidebarWidthForPresentationMode(presentationMode);

    if (showInlineSidebar) {
      return wrapShell(
        AppDrawerScope(
          hasAppDrawer: true,
          child: _withInlineShellControlsOverlay(
            context: context,
            ref: ref,
            presentationMode: presentationMode,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _desktopSidebar(context: context, width: sidebarWidth),
                SizedBox(
                  key: const Key('app_shell_sidebar_divider'),
                  width: kSidebarContentDividerWidth,
                  child: ColoredBox(color: surfaces.subtleDivider),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      );
    }

    return wrapShell(
      Scaffold(
        drawer: _sidebarDrawer(context),
        body: Builder(
          builder: (scaffoldContext) {
            void openDrawer() => Scaffold.of(scaffoldContext).openDrawer();

            return AppDrawerScope(
              hasAppDrawer: true,
              openDrawer: openDrawer,
              child: _withDesktopDrawerControlsOverlay(
                context: context,
                openDrawer: openDrawer,
                child: MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InlineShellControlsHost extends StatelessWidget {
  const _InlineShellControlsHost({
    required this.presentationMode,
    required this.canPop,
    required this.onToggleSidebar,
    required this.onPop,
    required this.onSearch,
  });

  final SidebarPresentationMode presentationMode;
  final bool canPop;
  final VoidCallback onToggleSidebar;
  final VoidCallback onPop;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sidebarExpanded =
        presentationMode == SidebarPresentationMode.expanded;
    final controls = [
      _ShellControlData(
        key: const Key('shell_sidebar_button'),
        tooltip: sidebarExpanded ? l10n.collapse : l10n.expand,
        onPressed: onToggleSidebar,
        icon: sidebarExpanded
            ? FleurIcons.sidebarCollapse
            : FleurIcons.sidebarExpand,
      ),
      _ShellControlData(
        key: const Key('shell_back_button'),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: canPop ? onPop : null,
        icon: FleurIcons.back,
      ),
      _ShellControlData(
        key: const Key('shell_forward_button'),
        tooltip: MaterialLocalizations.of(context).nextPageTooltip,
        onPressed: null,
        icon: FleurIcons.forward,
      ),
      _ShellControlData(
        key: const Key('shell_search_button'),
        tooltip: l10n.search,
        onPressed: onSearch,
        icon: FleurIcons.search,
      ),
    ];

    if (!sidebarExpanded) {
      return FleurCapsuleButtonGroup(
        key: const Key('shell_controls_capsule'),
        height: 40,
        padding: EdgeInsets.zero,
        children: [
          for (final control in controls)
            FleurCapsuleIconButton(
              key: control.key,
              tooltip: control.tooltip,
              onPressed: control.onPressed,
              icon: control.icon,
              size: 40,
              iconSize: 20,
            ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final control in controls)
          _DrawerControlButton(
            key: control.key,
            tooltip: control.tooltip,
            onPressed: control.onPressed,
            icon: control.icon,
          ),
      ],
    );
  }
}

class _ShellControlData {
  const _ShellControlData({
    required this.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final Key key;
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
}

class _DrawerControlsHost extends StatelessWidget {
  const _DrawerControlsHost({
    required this.canPop,
    required this.onPop,
    required this.openDrawer,
    required this.onSearch,
  });

  final bool canPop;
  final VoidCallback onPop;
  final VoidCallback openDrawer;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      key: const Key('shell_drawer_controls'),
      height: kWorkspaceHeaderHeight,
      child: Padding(
        padding: EdgeInsets.only(left: isMacOS ? 72 : 8, top: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DrawerControlButton(
              key: const Key('shell_sidebar_button'),
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
              onPressed: openDrawer,
              icon: FleurIcons.sidebarExpand,
            ),
            _DrawerControlButton(
              key: const Key('shell_back_button'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: canPop ? onPop : null,
              icon: FleurIcons.back,
            ),
            _DrawerControlButton(
              key: const Key('shell_forward_button'),
              tooltip: MaterialLocalizations.of(context).nextPageTooltip,
              onPressed: null,
              icon: FleurIcons.forward,
            ),
            _DrawerControlButton(
              key: const Key('shell_search_button'),
              tooltip: l10n.search,
              onPressed: onSearch,
              icon: FleurIcons.search,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerControlButton extends StatelessWidget {
  const _DrawerControlButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(40),
        minimumSize: const Size.square(40),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
