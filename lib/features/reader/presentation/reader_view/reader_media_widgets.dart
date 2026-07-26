part of '../reader_view.dart';

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({
    required this.widthPx,
    required this.heightPx,
    required this.widthPercent,
    required this.heightPercent,
    required this.loadingProgress,
    required this.aspectRatio,
  });

  factory _ImagePlaceholder.fromElement({
    required dom.Element element,
    required double? loadingProgress,
    required double? aspectRatio,
  }) {
    final spec = _parseImageSizeSpec(element);
    return _ImagePlaceholder(
      widthPx: spec.widthPx,
      heightPx: spec.heightPx,
      widthPercent: spec.widthPercent,
      heightPercent: spec.heightPercent,
      loadingProgress: loadingProgress,
      aspectRatio: aspectRatio,
    );
  }

  static const double _fallbackAspectRatio = 4 / 3;

  final double? widthPx;
  final double? heightPx;
  final double? widthPercent;
  final double? heightPercent;
  final double? loadingProgress;
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = theme.fleurReader;
    final base = DecoratedBox(
      decoration: BoxDecoration(
        color: reader.codeBlockSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: loadingProgress == null
          ? null
          : Align(
              alignment: Alignment.bottomCenter,
              child: LinearProgressIndicator(
                value: loadingProgress,
                minHeight: 3,
                backgroundColor: theme.fleurSurface.card,
                color: theme.colorScheme.primary,
              ),
            ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth = _resolveLength(
          widthPx,
          widthPercent,
          constraints.maxWidth,
        );
        final resolvedHeight = _resolveLength(
          heightPx,
          heightPercent,
          constraints.maxHeight,
        );

        if (resolvedWidth != null && resolvedHeight != null) {
          return SizedBox(
            width: resolvedWidth,
            height: resolvedHeight,
            child: base,
          );
        }

        if (resolvedWidth != null) {
          return SizedBox(
            width: resolvedWidth,
            height: resolvedWidth / (aspectRatio ?? _fallbackAspectRatio),
            child: base,
          );
        }

        if (resolvedHeight != null) {
          return SizedBox(height: resolvedHeight, child: base);
        }

        if (constraints.hasBoundedWidth && constraints.maxWidth.isFinite) {
          return SizedBox(
            width: constraints.maxWidth,
            height:
                constraints.maxWidth / (aspectRatio ?? _fallbackAspectRatio),
            child: base,
          );
        }

        return SizedBox(height: 180, child: base);
      },
    );
  }

  static double? _resolveLength(double? px, double? percent, double max) {
    if (px != null && px > 0) return px;
    if (percent != null && percent > 0 && max.isFinite && max > 0) {
      return max * percent / 100;
    }
    return null;
  }
}

class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder({
    required this.widthPx,
    required this.heightPx,
    required this.widthPercent,
    required this.heightPercent,
    required this.label,
  });

  factory _ImageErrorPlaceholder.fromElement({required dom.Element element}) {
    final spec = _parseImageSizeSpec(element);
    final label =
        (element.attributes['alt'] ?? element.attributes['title'] ?? '').trim();
    return _ImageErrorPlaceholder(
      widthPx: spec.widthPx,
      heightPx: spec.heightPx,
      widthPercent: spec.widthPercent,
      heightPercent: spec.heightPercent,
      label: label.isEmpty ? 'Image failed to load' : label,
    );
  }

  final double? widthPx;
  final double? heightPx;
  final double? widthPercent;
  final double? heightPercent;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reader = theme.fleurReader;
    final content = DecoratedBox(
      key: const Key('reader_image_error_placeholder'),
      decoration: BoxDecoration(
        color: reader.codeBlockSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.fleurSurface.subtleDivider),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FleurIcons.brokenImage,
                size: 22,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth = _ImagePlaceholder._resolveLength(
          widthPx,
          widthPercent,
          constraints.maxWidth,
        );
        final resolvedHeight = _ImagePlaceholder._resolveLength(
          heightPx,
          heightPercent,
          constraints.maxHeight,
        );

        if (resolvedWidth != null && resolvedHeight != null) {
          return SizedBox(
            width: resolvedWidth,
            height: resolvedHeight,
            child: content,
          );
        }

        if (resolvedWidth != null) {
          return SizedBox(
            width: resolvedWidth,
            height: math.min(180, math.max(96, resolvedWidth * 0.36)),
            child: content,
          );
        }

        if (resolvedHeight != null) {
          return SizedBox(height: resolvedHeight, child: content);
        }

        if (constraints.hasBoundedWidth && constraints.maxWidth.isFinite) {
          return SizedBox(
            width: constraints.maxWidth,
            height: 140,
            child: content,
          );
        }

        return SizedBox(height: 140, child: content);
      },
    );
  }
}

class _MediaEmbedCard extends StatelessWidget {
  const _MediaEmbedCard({
    required this.kind,
    required this.url,
    required this.onOpen,
  });

  final String kind;
  final String url;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = Uri.tryParse(url)?.host;
    final label = _mediaLabel(url, host);
    final canOpen = url.trim().isNotEmpty;
    return Container(
      key: const Key('reader_media_embed_card'),
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: theme.fleurReader.codeBlockSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.fleurSurface.subtleDivider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: canOpen ? onOpen : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  canOpen ? FleurIcons.openExternal : FleurIcons.brokenImage,
                  size: 22,
                  color: canOpen
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$kind media',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        canOpen ? label : 'Media source unavailable',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  FleurIcons.chevronRight,
                  size: 18,
                  color: canOpen
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurfaceVariant.withAlpha(120),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _mediaLabel(String url, String? host) {
    if (host != null && host.isNotEmpty) return host;
    final path = Uri.tryParse(url)?.pathSegments.lastOrNull;
    if (path != null && path.trim().isNotEmpty) return path;
    return url;
  }
}

class _ImageSizeSpec {
  const _ImageSizeSpec({
    this.widthPx,
    this.heightPx,
    this.widthPercent,
    this.heightPercent,
  });

  final double? widthPx;
  final double? heightPx;
  final double? widthPercent;
  final double? heightPercent;
}

_ImageSizeSpec _parseImageSizeSpec(dom.Element element) {
  final attrs = element.attributes;
  final style = attrs['style'] ?? '';

  final styleWidth = _parseCssLength(_extractStyleValue(style, 'width'));
  final styleHeight = _parseCssLength(_extractStyleValue(style, 'height'));
  final attrWidth = _parseCssLength(attrs['width']);
  final attrHeight = _parseCssLength(attrs['height']);
  final dataWidth = _parseCssLength(attrs['data-width']);
  final dataHeight = _parseCssLength(attrs['data-height']);

  return _ImageSizeSpec(
    widthPx: styleWidth.px ?? attrWidth.px ?? dataWidth.px,
    heightPx: styleHeight.px ?? attrHeight.px ?? dataHeight.px,
    widthPercent: styleWidth.percent ?? attrWidth.percent ?? dataWidth.percent,
    heightPercent:
        styleHeight.percent ?? attrHeight.percent ?? dataHeight.percent,
  );
}

_CssLength _parseCssLength(String? raw) {
  if (raw == null) return const _CssLength();
  final value = raw.trim().toLowerCase();
  if (value.isEmpty) return const _CssLength();
  if (value.endsWith('%')) {
    final number = double.tryParse(value.replaceAll('%', '').trim());
    return _CssLength(percent: number);
  }
  final cleaned = value.replaceAll('px', '').trim();
  return _CssLength(px: double.tryParse(cleaned));
}

String? _extractStyleValue(String style, String key) {
  if (style.isEmpty) return null;
  final regex = RegExp('$key\\s*:\\s*([^;]+)', caseSensitive: false);
  final match = regex.firstMatch(style);
  return match?.group(1)?.trim();
}

class _CssLength {
  const _CssLength({this.px, this.percent});

  final double? px;
  final double? percent;
}

String? _mediaSourceForElement(dom.Element element) {
  final direct = element.attributes['src']?.trim();
  if (direct != null && direct.isNotEmpty) return direct;
  final source = element.querySelector('source[src]');
  final nested = source?.attributes['src']?.trim();
  return nested == null || nested.isEmpty ? null : nested;
}
