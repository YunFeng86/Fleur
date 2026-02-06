import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings_providers.dart';
import 'service_providers.dart';

/// Resolve favicon URL for a given site URL.
///
/// This provider is intentionally cached by Riverpod (family param) and
/// additionally persisted on disk via [FaviconStore] to avoid frequent network
/// fetches when scrolling.
final faviconUrlProvider = FutureProvider.family<String?, Uri>((
  ref,
  siteUri,
) async {
  final settings = ref.watch(appSettingsProvider).valueOrNull;
  final ua = settings?.webUserAgent.trim();
  final effectiveUa = (ua != null && ua.isNotEmpty) ? ua : null;

  return ref
      .watch(faviconServiceProvider)
      .resolveFaviconUrl(siteUri, userAgent: effectiveUa);
});

/// Returns a cached favicon image file for a URL (downloaded if missing).
///
/// Note: this is best-effort; it can fail due to network or invalid URLs.
final faviconFileProvider = FutureProvider.family<File?, String>((
  ref,
  url,
) async {
  final cache = ref.watch(cacheManagerProvider);
  try {
    final file = await cache.getSingleFile(url);
    return file;
  } catch (_) {
    return null;
  }
});
