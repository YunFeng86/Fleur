import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import '../theme/app_theme.dart';
import '../providers/app_settings_providers.dart';
import '../utils/macos_locale_bridge.dart';
import '../utils/platform.dart';
import '../widgets/desktop_title_bar.dart';
import '../widgets/sidebar.dart';
import '../providers/query_providers.dart';
import '../providers/core_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/service_providers.dart';
import '../providers/auto_refresh_providers.dart';
import '../providers/unread_providers.dart';
import '../services/sync/sync_service.dart';
import '../ui/layout.dart';
import '../ui/global_nav.dart';

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
    ref.watch(autoRefreshControllerProvider);
    unawaited(ref.watch(notificationServiceProvider).init().catchError((_) {}));
    unawaited(MacOSLocaleBridge.setPreferredLanguage(localeTag));

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          builder: (context, child) {
            final content = child ?? const SizedBox.shrink();
            if (!isDesktop) return content;

            // Tooltips need an Overlay ancestor; since the title bar sits above the
            // Router/Navigator, we provide a top-level Overlay for desktop.
            return Overlay(
              initialEntries: [
                OverlayEntry(
                  opaque: true,
                  builder: (_) =>
                      _DesktopChrome(router: router, content: content),
                ),
              ],
            );
          },
          theme: AppTheme.light(scheme: lightDynamic),
          darkTheme: AppTheme.dark(scheme: darkDynamic),
          themeMode: appSettings?.themeMode ?? ThemeMode.system,
          locale: (localeTag == null) ? null : _localeFromTag(localeTag),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        );
      },
    );
  }
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
      'dashboard' => l10n.dashboard,
      'saved' => l10n.saved,
      'search' => l10n.search,
      'settings' => l10n.settings,
      '' || 'article' => l10n.feeds,
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
        final useCompactTopBar =
            globalNavModeForWidth(totalWidth) == GlobalNavMode.bottom;
        final title = useCompactTopBar ? l10n.appTitle : sectionTitle;
        final isArticleRoute =
            uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'article';
        final isFeedsSection = uri.pathSegments.isEmpty || isArticleRoute;
        final mode = desktopModeForWidth(width);
        final isArticleSeparatePage =
            isArticleRoute && !desktopReaderEmbedded(mode);
        final sidebarVisible = ref.watch(sidebarVisibleProvider);
        final drawerEnabled =
            !useCompactTopBar &&
            isFeedsSection &&
            sidebarVisible &&
            desktopSidebarInDrawer(mode) &&
            !isArticleSeparatePage;

        Future<BatchRefreshResult> refreshAll() async {
          final feedId = ref.read(selectedFeedIdProvider);
          final categoryId = ref.read(selectedCategoryIdProvider);
          if (feedId != null) {
            final r = await ref
                .read(syncServiceProvider)
                .refreshFeedSafe(feedId);
            return BatchRefreshResult([r]);
          }

          final feeds = await ref.read(feedRepositoryProvider).getAll();
          final filtered = (categoryId == null)
              ? feeds
              : (categoryId < 0
                    ? feeds.where((f) => f.categoryId == null)
                    : feeds.where((f) => f.categoryId == categoryId));
          return ref
              .read(syncServiceProvider)
              .refreshFeedsSafe(filtered.map((f) => f.id));
        }

        Future<void> markAllRead() async {
          final selectedFeedId = ref.read(selectedFeedIdProvider);
          final selectedCategoryId = ref.read(selectedCategoryIdProvider);
          await ref
              .read(articleRepositoryProvider)
              .markAllRead(
                feedId: selectedFeedId,
                categoryId: selectedFeedId == null ? selectedCategoryId : null,
              );
        }

        final leading = switch (mode) {
          _ when drawerEnabled => Builder(
            builder: (context) {
              return IconButton(
                tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu),
              );
            },
          ),
          _ when desktopSidebarInline(mode) => null,
          _ => null,
        };

        return Scaffold(
          drawer: drawerEnabled
              ? Drawer(
                  child: Sidebar(onSelectFeed: (_) {}, router: widget.router),
                )
              : null,
          body: Column(
            children: [
              DesktopTitleBar(
                title: title,
                leading: leading,
                actions: [
                  if (!useCompactTopBar && isFeedsSection) ...[
                    IconButton(
                      tooltip: l10n.refreshAll,
                      onPressed: () async {
                        final batch = await refreshAll();
                        if (!context.mounted) return;
                        final err = batch.firstError?.error;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              err == null
                                  ? l10n.refreshedAll
                                  : l10n.errorMessage(err.toString()),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final unreadOnly = ref.watch(unreadOnlyProvider);
                        return IconButton(
                          tooltip: unreadOnly ? l10n.showAll : l10n.unreadOnly,
                          onPressed: () =>
                              ref.read(unreadOnlyProvider.notifier).state =
                                  !unreadOnly,
                          icon: Icon(
                            unreadOnly
                                ? Icons.filter_alt
                                : Icons.filter_alt_outlined,
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: l10n.markAllRead,
                      onPressed: () async {
                        await markAllRead();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(l10n.done)));
                      },
                      icon: const Icon(Icons.done_all),
                    ),
                  ],
                ],
              ),
              Expanded(child: widget.content),
            ],
          ),
        );
      },
    );
  }
}
