import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../app/article_scope_routes.dart';
import '../models/article_scope.dart';
import '../providers/backend_sync_semantics_provider.dart';
import '../providers/core_providers.dart';
import '../providers/outbox_status_providers.dart';
import '../theme/fleur_icons.dart';
import '../theme/fleur_theme_extensions.dart';
import '../widgets/fleur_capsule_button_group.dart';
import '../widgets/outbox_status_action.dart';
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

  bool _showOutboxAction(WidgetRef ref) {
    final outboxPending =
        ref.watch(outboxPendingCountProvider).valueOrNull ?? 0;
    final syncSemantics = ref.watch(backendSyncSemanticsProvider);
    return outboxPending > 0 &&
        (syncSemantics.isAccountWideRefresh ||
            syncSemantics.isFeedScopedRefresh);
  }

  Widget _sidebarDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Sidebar(
          onSelectScope: (scope) => _goToScope(context, scope),
          router: GoRouter.maybeOf(context),
        ),
      ),
    );
  }

  Widget _desktopSidebar({
    required BuildContext context,
    required double width,
  }) {
    final surfaces = Theme.of(context).fleurSurface;
    return SizedBox(
      width: width,
      child: Material(
        color: surfaces.sidebar,
        child: Column(
          children: [
            if (isDesktop) const SizedBox(height: _kShellControlsHeight),
            Expanded(
              child: Sidebar(
                onSelectScope: (scope) => _goToScope(context, scope),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _withDesktopControlsOverlay({
    required BuildContext context,
    required WidgetRef ref,
    required Widget child,
    required VoidCallback? openDrawer,
    required SidebarPresentationMode presentationMode,
  }) {
    if (!isDesktop) return child;
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          left: 0,
          top: 0,
          width: isMacOS ? 240 : 176,
          child: _ShellControlsHost(
            canPop: _canPop(context),
            onPop: () => _pop(context),
            canOpenDrawer: openDrawer != null,
            openDrawer: openDrawer,
            onToggleSidebar: openDrawer == null
                ? () => _toggleSidebar(ref)
                : null,
            onSearch: () => _goToSearch(context),
            presentationMode: presentationMode,
            showOutboxAction: _showOutboxAction(ref),
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
          child: Stack(
            children: [
              Positioned.fill(
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
              Positioned(
                left: 0,
                top: 0,
                width: isMacOS ? 240 : 176,
                child: _ShellControlsHost(
                  canPop: _canPop(context),
                  onPop: () => _pop(context),
                  canOpenDrawer: false,
                  openDrawer: null,
                  onToggleSidebar: () => _toggleSidebar(ref),
                  onSearch: () => _goToSearch(context),
                  presentationMode: presentationMode,
                  showOutboxAction: _showOutboxAction(ref),
                ),
              ),
            ],
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
              child: _withDesktopControlsOverlay(
                context: context,
                ref: ref,
                openDrawer: openDrawer,
                presentationMode: presentationMode,
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

const double _kShellControlsHeight = 40;

class _ShellControlsHost extends StatelessWidget {
  const _ShellControlsHost({
    required this.canPop,
    required this.onPop,
    required this.canOpenDrawer,
    required this.openDrawer,
    required this.onToggleSidebar,
    required this.onSearch,
    required this.presentationMode,
    required this.showOutboxAction,
  });

  final bool canPop;
  final VoidCallback onPop;
  final bool canOpenDrawer;
  final VoidCallback? openDrawer;
  final VoidCallback? onToggleSidebar;
  final VoidCallback onSearch;
  final SidebarPresentationMode presentationMode;
  final bool showOutboxAction;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final canUseDrawer = canOpenDrawer && openDrawer != null;
    final sidebarExpanded =
        presentationMode == SidebarPresentationMode.expanded;
    final sidebarTooltip = canUseDrawer
        ? MaterialLocalizations.of(context).openAppDrawerTooltip
        : (sidebarExpanded ? l10n.collapse : l10n.expand);
    final sidebarIcon = canUseDrawer
        ? FleurIcons.sidebarExpand
        : (sidebarExpanded
              ? FleurIcons.sidebarCollapse
              : FleurIcons.sidebarExpand);
    final sidebarAction = canUseDrawer ? openDrawer : onToggleSidebar;

    return SizedBox(
      height: _kShellControlsHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final macTrafficLightInset = constraints.maxWidth >= 120 ? 72.0 : 8.0;
          final leftPadding = isMacOS ? macTrafficLightInset : 8.0;

          return Row(
            children: [
              SizedBox(width: leftPadding),
              FleurCapsuleButtonGroup(
                key: const Key('shell_controls_capsule'),
                children: [
                  FleurCapsuleIconButton(
                    key: const Key('shell_sidebar_button'),
                    tooltip: sidebarTooltip,
                    onPressed: sidebarAction,
                    icon: sidebarIcon,
                  ),
                  FleurCapsuleIconButton(
                    key: const Key('shell_back_button'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: canPop ? onPop : null,
                    icon: FleurIcons.back,
                  ),
                  FleurCapsuleIconButton(
                    key: const Key('shell_search_button'),
                    tooltip: l10n.search,
                    onPressed: onSearch,
                    icon: FleurIcons.search,
                  ),
                  if (showOutboxAction)
                    const OutboxStatusAction(
                      key: Key('shell_outbox_button'),
                      compact: true,
                    ),
                ],
              ),
              Expanded(child: DragToMoveArea(child: const SizedBox.expand())),
            ],
          );
        },
      ),
    );
  }
}
