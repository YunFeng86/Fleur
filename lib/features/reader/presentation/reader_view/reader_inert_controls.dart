part of '../reader_view.dart';

class _ReaderInertButton extends StatelessWidget {
  const _ReaderInertButton({required this.element});

  final dom.Element element;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _controlLabel(element, fallback: 'Button');
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Container(
          key: const Key('reader_inert_button'),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.fleurReader.codeBlockSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.fleurSurface.subtleDivider),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderInertInput extends StatelessWidget {
  const _ReaderInertInput({required this.element});

  final dom.Element element;

  @override
  Widget build(BuildContext context) {
    final type = (element.attributes['type'] ?? 'text').trim().toLowerCase();
    return type == 'color'
        ? _ReaderInertColorInput(element: element)
        : _ReaderInertTextInput(element: element, type: type);
  }
}

class _ReaderInertColorInput extends StatelessWidget {
  const _ReaderInertColorInput({required this.element});

  final dom.Element element;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = (element.attributes['value'] ?? '').trim();
    final color = _parseHexColor(value);
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Container(
          key: const Key('reader_inert_color_input'),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: theme.fleurReader.codeBlockSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.fleurSurface.subtleDivider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: theme.fleurSurface.subtleDivider),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                value.isEmpty ? 'color' : value,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderInertTextInput extends StatelessWidget {
  const _ReaderInertTextInput({required this.element, required this.type});

  final dom.Element element;
  final String type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = (element.attributes['value'] ?? '').trim();
    final label = value.isEmpty
        ? _controlLabel(element, fallback: type.isEmpty ? 'input' : type)
        : value;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Container(
          key: const Key('reader_inert_input'),
          constraints: const BoxConstraints(maxWidth: 180),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: theme.fleurReader.codeBlockSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.fleurSurface.subtleDivider),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

String _controlLabel(dom.Element element, {required String fallback}) {
  for (final value in [
    element.text,
    element.attributes['aria-label'],
    element.attributes['title'],
    element.attributes['value'],
  ]) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  }
  return fallback;
}

Color? _parseHexColor(String value) {
  final normalized = value.trim().toLowerCase();
  final match = RegExp(r'^#([0-9a-f]{6})$').firstMatch(normalized);
  if (match == null) return null;
  return Color(int.parse('ff${match.group(1)}', radix: 16));
}
