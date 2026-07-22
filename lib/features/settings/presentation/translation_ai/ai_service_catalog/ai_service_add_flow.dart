import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fleur/l10n/app_localizations.dart';
import 'package:fleur/theme/fleur_icons.dart';
import 'package:fleur/ui/dialogs/side_panel.dart';
import 'package:fleur/widgets/app_scrollbar.dart';

import 'ai_service_editor_dialog.dart';
import 'ai_service_templates.dart';
import '../ai_service_api_type_display.dart';

/// Selects a provider template and opens the editor that persists the service.
Future<void> showAddAiServiceFlow(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final picked = await showSidePanel<AiServiceTemplate>(
    context,
    builder: (panelContext) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.addAiService),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: MaterialLocalizations.of(
                panelContext,
              ).closeButtonTooltip,
              icon: const Icon(FleurIcons.close),
              onPressed: () => Navigator.of(panelContext).pop(),
            ),
          ],
        ),
        body: AppScrollbar(
          child: ListView(
            children: [
              for (final template in aiServiceTemplates)
                ListTile(
                  leading: Icon(apiTypeIcon(template.apiType)),
                  title: Text(template.name),
                  subtitle: Text(apiTypeLabel(template.apiType)),
                  onTap: () => Navigator.of(panelContext).pop(template),
                ),
            ],
          ),
        ),
      );
    },
  );
  if (picked == null || !context.mounted) return;
  await showAiServiceEditorDialog(context, ref, template: picked);
}
