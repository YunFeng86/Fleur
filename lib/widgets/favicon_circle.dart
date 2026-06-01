import 'package:flutter/material.dart';

import '../theme/fleur_theme_extensions.dart';
import 'favicon_avatar.dart';

/// A shared circular container for displaying a site's favicon.
///
/// This keeps the "shape + color + feel" consistent across the app wherever we
/// show a feed/site icon.
class FaviconCircle extends StatelessWidget {
  const FaviconCircle({
    super.key,
    required this.siteUri,
    this.diameter = 28,
    this.avatarSize = 18,
    this.backgroundColor,
    this.fallbackIcon = Icons.rss_feed,
    this.fallbackColor,
  });

  final Uri? siteUri;

  /// Diameter of the circle container.
  final double diameter;

  /// Size passed to [FaviconAvatar] (also used for fallback icon size).
  final double avatarSize;

  /// Optional override for the circle background color.
  final Color? backgroundColor;

  final IconData fallbackIcon;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.fleurSurface.card,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: FaviconAvatar(
        siteUri: siteUri,
        size: avatarSize,
        fallbackIcon: fallbackIcon,
        fallbackColor: fallbackColor ?? theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
