import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_reader/l10n/app_localizations.dart';

import 'router.dart';
import '../theme/app_theme.dart';
import '../providers/app_settings_providers.dart';
import '../utils/platform.dart';
import '../widgets/desktop_title_bar.dart';
import '../widgets/sidebar.dart';
import '../providers/query_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/service_providers.dart';
import '../providers/unread_providers.dart';
import '../ui/layout.dart';

class App extends ConsumerWidget {
  const App({super.key});

  Locale _localeFromTag(String tag) {
    // Accept both BCP-47 ("zh-Hant") and underscore ("zh_Hant") formats.
    final parts =
        tag.replaceAll('_', '-').split('-').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return Locale(tag);

    final languageCode = parts[0];
    String? scriptCode;
    String? countryCode;

    String normalizeScript(String s) =>
        s.length != 4 ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

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

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          builder: (context, child) {
            final content = child ?? const SizedBox.shrink();
            if (!isDesktop) return content;

            Future<void> refreshAll() async {
              final feedId = ref.read(selectedFeedIdProvider);
              final categoryId = ref.read(selectedCategoryIdProvider);
              if (feedId != null) {
                await ref.read(syncServiceProvider).refreshFeed(feedId);
                return;
              }

              final feeds = await ref.read(feedRepositoryProvider).getAll();
              final filtered = (categoryId == null)
                  ? feeds
                  : (categoryId < 0
                      ? feeds.where((f) => f.categoryId == null)
                      : feeds.where((f) => f.categoryId == categoryId));
              for (final f in filtered) {
                await ref.read(syncServiceProvider).refreshFeed(f.id);
              }
            }

            Future<void> markAllRead() async {
              final selectedFeedId = ref.read(selectedFeedIdProvider);
              final selectedCategoryId = ref.read(selectedCategoryIdProvider);
              await ref.read(articleRepositoryProvider).markAllRead(
                    feedId: selectedFeedId,
                    categoryId: selectedFeedId == null ? selectedCategoryId : null,
                  );
            }

            // Tooltips need an Overlay ancestor; since the title bar sits above the
            // Router/Navigator, we provide a top-level Overlay for desktop.
            return Overlay(
              initialEntries: [
                OverlayEntry(
                  opaque: true,
                  builder: (overlayContext) {
                    // Keep overlay chrome in sync with navigation and resize.
                    return ListenableBuilder(
                      listenable: router.routerDelegate,
                      builder: (context, _) {
                        final l10n = AppLocalizations.of(context)!;
                        final width = MediaQuery.sizeOf(context).width;
                        final uri = router.routerDelegate.currentConfiguration.uri;
                        final isArticleRoute = uri.pathSegments.isNotEmpty &&
                            uri.pathSegments.first == 'article';
                        final mode = desktopModeForWidth(width);
                        final isArticleSeparatePage =
                            isArticleRoute && !desktopReaderEmbedded(mode);
                        final drawerEnabled =
                            desktopSidebarInDrawer(mode) && !isArticleSeparatePage;

                        final leading = switch (mode) {
                          _ when drawerEnabled => Builder(
                              builder: (context) {
                                return IconButton(
                                  tooltip: MaterialLocalizations.of(context)
                                      .openAppDrawerTooltip,
                                  onPressed: () =>
                                      Scaffold.of(context).openDrawer(),
                                  icon: const Icon(Icons.menu),
                                );
                              },
                            ),
                          _ => null,
                        };

                        return Scaffold(
                          drawer: drawerEnabled
                              ? Drawer(
                                  child: Sidebar(
                                    onSelectFeed: (_) =>
                                        Navigator.of(overlayContext).maybePop(),
                                    router: router,
                                  ),
                                )
                              : null,
                          body: Column(
                            children: [
                              DesktopTitleBar(
                                title: l10n.appTitle,
                                leading: leading,
                                actions: [
                                  IconButton(
                                    tooltip: l10n.refreshAll,
                                    onPressed: () async {
                                      await refreshAll();
                                      if (!overlayContext.mounted) return;
                                      ScaffoldMessenger.of(overlayContext)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(l10n.refreshedAll)),
                                      );
                                    },
                                    icon: const Icon(Icons.refresh),
                                  ),
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final unreadOnly =
                                          ref.watch(unreadOnlyProvider);
                                      return IconButton(
                                        tooltip: unreadOnly
                                            ? l10n.showAll
                                            : l10n.unreadOnly,
                                        onPressed: () => ref
                                                .read(unreadOnlyProvider.notifier)
                                                .state =
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
                                      if (!overlayContext.mounted) return;
                                      ScaffoldMessenger.of(overlayContext)
                                          .showSnackBar(
                                        SnackBar(content: Text(l10n.done)),
                                      );
                                    },
                                    icon: const Icon(Icons.done_all),
                                  ),
                                  IconButton(
                                    tooltip: l10n.settings,
                                    onPressed: () => router.push('/settings'),
                                    icon: const Icon(Icons.settings_outlined),
                                  ),
                                ],
                              ),
                              Expanded(child: content),
                            ],
                          ),
                        );
                      },
                    );
                  },
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
