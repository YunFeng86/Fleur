import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import 'article_scope_routes.dart';
import 'router.dart';
import '../models/article_scope.dart';
import '../providers/app_settings_providers.dart';
import '../providers/auto_refresh_providers.dart';
import '../providers/background_sync_providers.dart';
import '../providers/backend_sync_semantics_provider.dart';
import '../providers/core_providers.dart';
import '../providers/outbox_flush_providers.dart';
import '../providers/outbox_status_providers.dart';
import '../providers/service_providers.dart';
import '../services/logging/app_logger.dart';
import '../services/notifications/notification_service.dart';
import '../services/settings/app_settings.dart';
import '../ui/app_menu.dart';
import '../ui/global_nav.dart';
import '../ui/layout.dart';
import '../theme/app_theme.dart';
import '../theme/seed_color_presets.dart';
import '../utils/macos_locale_bridge.dart';
import '../utils/platform.dart';
import '../widgets/db_recovery_notice.dart';
import '../widgets/desktop_title_bar.dart';
import '../widgets/outbox_status_action.dart';
import '../widgets/sidebar.dart';

typedef PreferredLanguageApplier = Future<void> Function(String? localeTag);

final preferredLanguageApplierProvider = Provider<PreferredLanguageApplier>(
  (ref) => MacOSLocaleBridge.setPreferredLanguage,
);

class App extends ConsumerWidget {
  const App({super.key});

  Locale _localeFromTag(String tag) {
    // Accept both BCP-47 ("zh-Hant") and underscore ("zh_Hant") formats.
    final parts = tag
        .replaceAll('_', '-')
        .split('-')
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return Locale(tag);

    final languageCode = parts[0];
    String? scriptCode;
    String? countryCode;

    String normalizeScript(String s) => s.length != 4
        ? s
        : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

    if (parts.length >= 2) {
      final p1 = parts[1];
      if (p1.length == 4) {
        scriptCode = normalizeScript(p1);
      } else if (p1.length == 2 || p1.length == 3) {
        countryCode = p1.toUpperCase();
      }
    }

    if (parts.length >= 3) {
      final p2 = parts[2];
      if (scriptCode == null && p2.length == 4) {
        scriptCode = normalizeScript(p2);
      } else if (countryCode == null && (p2.length == 2 || p2.length == 3)) {
        countryCode = p2.toUpperCase();
      }
    }

    return Locale.fromSubtags(
      languageCode: languageCode,
      scriptCode: scriptCode,
      countryCode: countryCode,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appSettings = ref.watch(appSettingsProvider).valueOrNull;
    final localeTag = appSettings?.localeTag;
    final useDynamicColor = appSettings?.useDynamicColor ?? true;
    final seedColorPreset =
        appSettings?.seedColorPreset ?? SeedColorPreset.blue;
    return AppControllerHost(
      child: DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            onGenerateTitle: (context) =>
                AppLocalizations.of(context)!.appTitle,
            builder: (context, child) {
              final content = child ?? const SizedBox.shrink();
              final wrapped = DbRecoveryNoticeOverlay(child: content);
              if (!isDesktop) return wrapped;

              // Tooltips need an Overlay ancestor; since the title bar sits above the
              // Router/Navigator, we provide a top-level Overlay for desktop.
              return Overlay(
                initialEntries: [
                  OverlayEntry(
                    opaque: true,
                    builder: (_) => AppMenuHost(
                      child: _DesktopChrome(router: router, content: wrapped),
                    ),
                  ),
                ],
              );
            },
            theme: AppTheme.light(
              scheme: useDynamicColor ? lightDynamic : null,
              seedColorPreset: seedColorPreset,
            ),
            darkTheme: AppTheme.dark(
              scheme: useDynamicColor ? darkDynamic : null,
              seedColorPreset: seedColorPreset,
            ),
            themeMode: appSettings?.themeMode ?? ThemeMode.system,
            locale: (localeTag == null) ? null : _localeFromTag(localeTag),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          );
        },
      ),
    );
  }
}

class AppRuntimeHost extends ConsumerStatefulWidget {
  const AppRuntimeHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppRuntimeHost> createState() => _AppRuntimeHostState();
}

class _AppRuntimeHostState extends ConsumerState<AppRuntimeHost> {
  ProviderSubscription<AsyncValue<AppSettings>>? _appSettingsSubscription;

  NotificationService? _notificationService;
  String? _lastPreferredLanguageTag;

  @override
  void initState() {
    super.initState();
    _notificationService = ref.read(notificationServiceProvider);
    _bindNotificationTapHandler();
    unawaited(_initializeNotifications());
    unawaited(_requestNotificationPermissions());
    _appSettingsSubscription = ref.listenManual<AsyncValue<AppSettings>>(
      appSettingsProvider,
      _handleAppSettingsChanged,
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _appSettingsSubscription?.close();
    super.dispose();
  }

  void _bindNotificationTapHandler() {
    _notificationService?.setOnNotificationTap((tap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final router = ref.read(routerProvider);
        switch (tap) {
          case NotificationTapHome():
            router.go('/');
            return;
          case NotificationTapArticle(articleId: final articleId):
            router.go(scopedArticleLocation(ArticleScope.all, articleId));
            return;
        }
      });
    });
  }

  void _handleAppSettingsChanged(
    AsyncValue<AppSettings>? previous,
    AsyncValue<AppSettings> next,
  ) {
    if (next.isLoading && next.valueOrNull == null) return;
    final localeTag = next.valueOrNull?.localeTag;
    if (_lastPreferredLanguageTag == localeTag) return;
    _lastPreferredLanguageTag = localeTag;
    unawaited(_syncPreferredLanguage(localeTag));
  }

  Future<void> _initializeNotifications() async {
    final notificationService = _notificationService;
    if (notificationService == null) return;
    try {
      await notificationService.init();
    } on MissingPluginException {
      // Explicit unsupported path: do not surface as a startup failure.
    } catch (e) {
      AppLogger.w('Notification startup init failed', tag: 'notify', error: e);
    }
  }

  Future<void> _requestNotificationPermissions() async {
    final notificationService = _notificationService;
    if (notificationService == null) return;
    try {
      await notificationService.requestPermissions();
    } on MissingPluginException {
      // Explicit unsupported path: do not surface as a startup failure.
    } catch (e) {
      AppLogger.w(
        'Notification permission request failed',
        tag: 'notify',
        error: e,
      );
    }
  }

  Future<void> _syncPreferredLanguage(String? localeTag) async {
    final applyPreferredLanguage = ref.read(preferredLanguageApplierProvider);
    try {
      await applyPreferredLanguage(localeTag);
    } catch (e) {
      AppLogger.w('Preferred language sync failed', tag: 'runtime', error: e);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AppControllerHost extends ConsumerStatefulWidget {
  const AppControllerHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppControllerHost> createState() => _AppControllerHostState();
}

class _AppControllerHostState extends ConsumerState<AppControllerHost> {
  ProviderSubscription<void>? _autoRefreshSubscription;
  ProviderSubscription<void>? _outboxFlushSubscription;
  ProviderSubscription<void>? _backgroundSyncSubscription;

  @override
  void initState() {
    super.initState();
    _autoRefreshSubscription = ref.listenManual<void>(
      autoRefreshControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    _outboxFlushSubscription = ref.listenManual<void>(
      outboxFlushControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    _backgroundSyncSubscription = ref.listenManual<void>(
      backgroundSyncControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _autoRefreshSubscription?.close();
    _outboxFlushSubscription?.close();
    _backgroundSyncSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _DesktopChrome extends ConsumerStatefulWidget {
  const _DesktopChrome({required this.router, required this.content});

  final GoRouter router;
  final Widget content;

  @override
  ConsumerState<_DesktopChrome> createState() => _DesktopChromeState();
}

class _DesktopChromeState extends ConsumerState<_DesktopChrome> {
  final _routerVersion = ValueNotifier<int>(0);
  bool _routerChangeScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_handleRouterChange);
  }

  @override
  void didUpdateWidget(covariant _DesktopChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(_handleRouterChange);
      widget.router.routerDelegate.addListener(_handleRouterChange);
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_handleRouterChange);
    _routerVersion.dispose();
    super.dispose();
  }

  void _handleRouterChange() {
    if (!mounted) return;
    if (_routerChangeScheduled) return;
    _routerChangeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routerChangeScheduled = false;
      if (!mounted) return;
      _routerVersion.value++;
    });
  }

  String _sectionTitleForUri(AppLocalizations l10n, Uri uri) {
    final seg = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    return switch (seg) {
      'starred' || 'read-later' => l10n.saved,
      'search' => l10n.search,
      'settings' => l10n.settings,
      '' || 'all' || 'feed' || 'category' || 'tag' => l10n.feeds,
      _ => l10n.feeds,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _routerVersion,
      builder: (context, _, child) {
        final l10n = AppLocalizations.of(context)!;
        final totalWidth = MediaQuery.sizeOf(context).width;
        final width = effectiveContentWidth(totalWidth);
        final uri = widget.router.routerDelegate.currentConfiguration.uri;
        final sectionTitle = _sectionTitleForUri(l10n, uri);
        // Desktop always has a top chrome (DesktopTitleBar), so avoid creating
        // a second in-page "compact" app bar even when the window is narrow.
        final title = sectionTitle;
        final isArticleRoute =
            uri.pathSegments.isNotEmpty && uri.pathSegments.contains('article');
        final firstSegment = uri.pathSegments.isEmpty
            ? ''
            : uri.pathSegments.first;
        final isFeedsSection = switch (firstSegment) {
          '' ||
          'all' ||
          'starred' ||
          'read-later' ||
          'feed' ||
          'category' ||
          'tag' => true,
          _ => false,
        };
        final mode = desktopModeForWidth(width);
        final isArticleSeparatePage =
            isArticleRoute && !desktopReaderEmbedded(mode);
        final sidebarVisible = ref.watch(sidebarVisibleProvider);
        final drawerEnabled =
            isFeedsSection &&
            sidebarVisible &&
            desktopSidebarInDrawer(mode) &&
            !isArticleSeparatePage;
        final canPop = widget.router.canPop();
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
                onPressed: () => widget.router.pop(),
                icon: const Icon(Icons.arrow_back),
              )
            : (drawerEnabled
                  ? Builder(
                      builder: (context) {
                        return IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).openAppDrawerTooltip,
                          onPressed: () => Scaffold.of(context).openDrawer(),
                          icon: const Icon(Icons.menu),
                        );
                      },
                    )
                  : null);

        return Scaffold(
          drawer: drawerEnabled
              ? Drawer(
                  child: SafeArea(
                    child: Padding(
                      // On macOS (hidden title bar), the drawer can overlap the
                      // system traffic lights and our custom title bar.
                      padding: EdgeInsets.only(
                        top: isMacOS ? AppTheme.desktopTitleBarHeight : 0,
                      ),
                      child: Sidebar(
                        onSelectScope: (scope) {
                          widget.router.go(scopeLocation(scope));
                        },
                        router: widget.router,
                      ),
                    ),
                  ),
                )
              : null,
          body: Column(
            children: [
              DesktopTitleBar(
                title: title,
                leading: leading,
                actions: [if (showOutboxAction) const OutboxStatusAction()],
              ),
              Expanded(child: widget.content),
            ],
          ),
        );
      },
    );
  }
}
