import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/favicon_providers.dart';

class FaviconAvatar extends ConsumerWidget {
  const FaviconAvatar({
    super.key,
    required this.siteUri,
    required this.size,
    this.fallbackIcon = Icons.rss_feed,
    this.fallbackColor,
  });

  final Uri? siteUri;
  final double size;
  final IconData fallbackIcon;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    Widget fallback() {
      return Icon(
        fallbackIcon,
        size: size,
        color: fallbackColor ?? theme.colorScheme.onSurfaceVariant,
      );
    }

    final uri = siteUri;
    if (uri == null) return fallback();

    final key = _normalizeProviderKey(uri);
    if (key == null) return fallback();

    // Important: normalize family key to site-level (scheme + host) to avoid
    // provider instance explosion when article URLs differ by path/query.
    final asyncUrl = ref.watch(faviconUrlProvider(key));
    return asyncUrl.when(
      loading: fallback,
      error: (error, stackTrace) => fallback(),
      data: (url) {
        final u = (url ?? '').trim();
        if (u.isEmpty) return fallback();

        final asyncFile = ref.watch(faviconFileProvider(u));
        return asyncFile.when(
          loading: fallback,
          error: (error, stackTrace) => fallback(),
          data: (file) {
            if (file == null) return fallback();
            return ClipOval(
              child: Image.file(
                file,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback(),
              ),
            );
          },
        );
      },
    );
  }

  Uri? _normalizeProviderKey(Uri input) {
    Uri? parsed;
    if (input.host.isNotEmpty) {
      parsed = input;
    } else {
      // Handle inputs like "example.com" that parse as a path-only Uri.
      parsed = Uri.tryParse('https://${input.toString().trim()}');
    }

    if (parsed == null || parsed.host.isEmpty) return null;

    final scheme = (parsed.scheme == 'http' || parsed.scheme == 'https')
        ? parsed.scheme
        : 'https';
    return Uri(scheme: scheme, host: parsed.host.toLowerCase());
  }
}
