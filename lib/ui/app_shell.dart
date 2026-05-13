import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../app/article_scope_routes.dart';
import '../models/article_scope.dart';
import '../providers/backend_sync_semantics_provider.dart';
import '../providers/core_providers.dart';
import '../providers/outbox_status_providers.dart';
import '../theme/fleur_theme_extensions.dart';
import '../widgets/desktop_title_bar.dart';
import '../widgets/outbox_status_action.dart';
import '../widgets/sidebar.dart';
import 'app_menu.dart';
import 'global_nav.dart';
import 'layout.dart';
import 'layout_spec.dart';
import '../utils/platform.dart';

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

  String _sectionTitleForUri(AppLocalizations l10n, Uri uri) {
    final seg = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    return switch (seg) {
      'starred' || 'read-later' => l10n.saved,
      'search' => l10n.search,
      'add-subscription' => l10n.addSubscription,
      'settings' => l10n.settings,
      '' || 'all' || 'feed' || 'category' || 'tag' => l10n.feeds,
      _ => l10n.feeds,
    };
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

  void _pop(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
      return;
    }
    unawaited(Navigator.of(context).maybePop());
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

  Widget _withDesktopTitleBar({
    required BuildContext context,
    required WidgetRef ref,
    required Widget child,
    required bool drawerAvailable,
    required VoidCallback? openDrawer,
  }) {
    if (!isDesktop) return child;

    final l10n = AppLocalizations.of(context)!;
    final router = GoRouter.maybeOf(context);
    final canPop = router?.canPop() ?? Navigator.canPop(context);
    final outboxPending =
        ref.watch(outboxPendingCountProvider).valueOrNull ?? 0;
    final syncSemantics = ref.watch(backendSyncSemanticsProvider);
    final showOutboxAction =
        outboxPending > 0 &&
        (syncSemantics.isAccountWideRefresh ||
            syncSemantics.isFeedScopedRefresh);

    final leading = canPop
        ? IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => _pop(context),
            icon: const Icon(Icons.arrow_back),
          )
        : (drawerAvailable && openDrawer != null
              ? IconButton(
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).openAppDrawerTooltip,
                  onPressed: openDrawer,
                  icon: const Icon(Icons.menu),
                )
              : null);

    return Column(
      children: [
        DesktopTitleBar(
          title: _sectionTitleForUri(l10n, currentUri),
          leading: leading,
          actions: [if (showOutboxAction) const OutboxStatusAction()],
        ),
        Expanded(child: child),
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
      return wrapShell(
        _withDesktopTitleBar(
          context: context,
          ref: ref,
          drawerAvailable: false,
          openDrawer: null,
          child: GlobalNavScope(hasGlobalNav: false, child: child),
        ),
      );
    }

    final showInlineSidebar = spec.hasInlineSidebar;
    final sidebarWidth = sidebarWidthForPresentationMode(presentationMode);

    if (showInlineSidebar) {
      return wrapShell(
        _withDesktopTitleBar(
          context: context,
          ref: ref,
          drawerAvailable: false,
          openDrawer: null,
          child: GlobalNavScope(
            hasGlobalNav: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: sidebarWidth,
                  child: Sidebar(
                    onSelectScope: (scope) => _goToScope(context, scope),
                  ),
                ),
                const SizedBox(width: kPaneGap),
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

            return GlobalNavScope(
              hasGlobalNav: true,
              openDrawer: openDrawer,
              child: _withDesktopTitleBar(
                context: context,
                ref: ref,
                drawerAvailable: true,
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
