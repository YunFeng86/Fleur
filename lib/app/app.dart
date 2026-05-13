import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fleur/l10n/app_localizations.dart';

import 'article_scope_routes.dart';
import 'router.dart';
import '../models/article_scope.dart';
import '../providers/app_settings_providers.dart';
import '../providers/auto_refresh_providers.dart';
import '../providers/background_sync_providers.dart';
import '../providers/outbox_flush_providers.dart';
import '../providers/service_providers.dart';
import '../services/logging/app_logger.dart';
import '../services/notifications/notification_service.dart';
import '../services/settings/app_settings.dart';
import '../theme/app_theme.dart';
import '../theme/seed_color_presets.dart';
import '../utils/macos_locale_bridge.dart';
import '../widgets/db_recovery_notice.dart';

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
              return DbRecoveryNoticeOverlay(child: content);
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
