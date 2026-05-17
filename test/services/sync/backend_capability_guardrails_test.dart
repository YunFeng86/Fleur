import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _rawBackendTypePattern =
    r'AccountType\.(?:local|miniflux|fever)|'
    r'\b(?:_?account|activeAccount)\.type\b';

final _rawBackendTypeRegex = RegExp(_rawBackendTypePattern);

const _allowedRawBackendTypeUses = <String, String>{
  'lib/app/account_gate.dart':
      'logs account database open failures for diagnostics only',
  'lib/providers/account_providers.dart':
      'creates the default local account state',
  'lib/providers/backend_capabilities_provider.dart':
      'derives capabilities from the active account',
  'lib/providers/backend_content_capabilities_provider.dart':
      'derives content capabilities from the active account',
  'lib/providers/backend_sync_semantics_provider.dart':
      'derives sync semantics from the active account',
  'lib/providers/add_subscription_controller.dart':
      'constructs the Miniflux add-subscription executor after capability gating',
  'lib/providers/service_providers.dart':
      'selects the concrete sync service implementation',
  'lib/services/accounts/account.dart': 'defines AccountType serialization',
  'lib/services/accounts/account_cleanup_service.dart':
      'deletes credentials by concrete account type',
  'lib/services/accounts/account_store.dart':
      'creates and normalizes local account records',
  'lib/services/actions/article_action_service.dart':
      'uses concrete remote clients after capability gating',
  'lib/services/background/background_sync_service.dart':
      'derives background capabilities from the active account',
  'lib/services/sync/backend_capabilities.dart':
      'declares the backend capability matrix',
  'lib/services/sync/backend_content_capabilities.dart':
      'declares the backend content capability matrix',
  'lib/services/sync/backend_sync_semantics.dart':
      'declares the backend sync semantics matrix',
  'lib/services/sync/remote_client_factory.dart':
      'centralizes remote credential lookup and client construction',
  'lib/ui/dialogs/add_account_dialogs.dart': 'creates concrete account types',
  'lib/ui/settings/tabs/services_tab.dart':
      'renders account creation and account type labels',
  'lib/widgets/account_avatar.dart': 'renders account type icons',
  'lib/widgets/account_manager_dialog.dart':
      'renders and creates concrete account types',
};

const _operationalCapabilityFiles = <String, String>{
  'lib/providers/outbox_status_providers.dart': 'backendCapabilitiesProvider',
  'lib/providers/outbox_flush_providers.dart': 'backendCapabilitiesProvider',
  'lib/providers/background_sync_providers.dart': 'backendCapabilitiesProvider',
  'lib/widgets/outbox_status_action.dart': 'backendCapabilitiesProvider',
  'lib/ui/home/home_scene_commands.dart': 'backendCapabilitiesProvider',
  'lib/ui/actions/subscription_actions.dart': 'backendCapabilitiesProvider',
  'lib/ui/settings/subscriptions/subscription_toolbar.dart':
      'backendCapabilitiesProvider',
  'lib/ui/sidebar/sidebar_tree.dart': 'BackendCapabilities',
  'lib/widgets/sidebar.dart': 'backendCapabilitiesProvider',
  'lib/ui/settings/subscriptions/settings_detail_panel.dart':
      'backendCapabilitiesProvider',
};

const _contentCapabilityFiles = <String, String>{
  'lib/ui/settings/subscriptions/settings_detail_panel.dart':
      'backendContentCapabilitiesProvider',
  'lib/ui/settings/tabs/services_tab.dart':
      'backendContentCapabilitiesProvider',
};

const _syncSemanticsFiles = <String, String>{
  'lib/screens/home_screen.dart': 'backendSyncSemanticsProvider',
  'lib/ui/home/home_scene_commands.dart': 'backendSyncSemanticsProvider',
  'lib/ui/settings/subscriptions/subscription_toolbar.dart':
      'backendSyncSemanticsProvider',
  'lib/ui/settings/subscriptions/settings_detail_panel.dart':
      'backendSyncSemanticsProvider',
  'lib/ui/sidebar/sidebar_tree.dart': 'BackendSyncSemantics',
  'lib/ui/settings/tabs/services_tab.dart': 'backendSyncSemanticsProvider',
  'lib/widgets/sidebar.dart': 'backendSyncSemanticsProvider',
};

void main() {
  test('raw backend-type references stay in the documented allowlist', () {
    final missingReasons = _allowedRawBackendTypeUses.entries
        .where((entry) => entry.value.trim().isEmpty)
        .map((entry) => entry.key)
        .toList(growable: false);
    expect(
      missingReasons,
      isEmpty,
      reason: 'Every raw backend-type allowlist entry must explain why.',
    );

    final occurrences = _rawBackendTypeOccurrences(_libDartFiles());
    final allowedPaths = _allowedRawBackendTypeUses.keys.toSet();
    final actualPaths = occurrences
        .map((occurrence) => occurrence.path)
        .toSet();
    final unexpected = occurrences
        .where((occurrence) => !allowedPaths.contains(occurrence.path))
        .toList(growable: false);
    expect(
      unexpected,
      isEmpty,
      reason:
          'Use BackendCapabilities/backendCapabilitiesProvider for operation '
          'checks, BackendContentCapabilities/backendContentCapabilitiesProvider '
          'for content checks, or add a documented allowlist reason.\n'
          '${_formatOccurrences(unexpected)}',
    );

    final staleAllowedPaths = allowedPaths.difference(actualPaths).toList()
      ..sort();
    expect(
      staleAllowedPaths,
      isEmpty,
      reason: 'Remove stale backend capability guardrail allowlist entries.',
    );
  });

  test('migrated operational surfaces stay capability-driven', () {
    for (final entry in _operationalCapabilityFiles.entries) {
      final path = entry.key;
      final contents = File(path).readAsStringSync();
      final occurrences = _rawBackendTypeOccurrences([File(path)]);

      expect(
        occurrences,
        isEmpty,
        reason:
            '$path must use shared capability providers instead of raw '
            'AccountType checks.\n'
            '${_formatOccurrences(occurrences)}',
      );
      expect(
        contents,
        contains(entry.value),
        reason: '$path should remain wired to the shared capability surface.',
      );
    }
  });

  test('content UI surfaces stay content-capability-driven', () {
    for (final entry in _contentCapabilityFiles.entries) {
      final path = entry.key;
      final contents = File(path).readAsStringSync();

      expect(
        contents,
        contains(entry.value),
        reason:
            '$path should use BackendContentCapabilities for content-fetch UI.',
      );
      expect(
        contents,
        isNot(contains('BackendFeature.serverContentFetchMode')),
        reason:
            '$path should not route content-fetch UI through operation '
            'BackendFeature values.',
      );
    }
  });

  test('sync semantics UI surfaces stay semantics-driven', () {
    for (final entry in _syncSemanticsFiles.entries) {
      final path = entry.key;
      final contents = File(path).readAsStringSync();

      expect(
        contents,
        contains(entry.value),
        reason: '$path should use BackendSyncSemantics for sync semantics UI.',
      );
    }
  });

  test('background sync only derives capabilities from raw account type', () {
    const path = 'lib/services/background/background_sync_service.dart';
    final contents = File(path).readAsStringSync();
    final withoutAllowedDerivations = contents.replaceAll(
      RegExp(
        r'BackendCapabilities\.forAccountType\(\s*'
        r'(?:activeAccount|account)\.type\s*,?\s*\)',
        multiLine: true,
      ),
      '',
    );

    expect(
      withoutAllowedDerivations,
      isNot(contains(RegExp(_rawBackendTypePattern))),
      reason:
          '$path may read raw account type only when deriving '
          'BackendCapabilities.',
    );
  });

  test(
    'add subscription controller keeps operation dispatch capability-driven',
    () {
      const path = 'lib/providers/add_subscription_controller.dart';
      final contents = File(path).readAsStringSync();

      expect(
        contents,
        contains('backendCapabilitiesProvider'),
        reason:
            '$path must use BackendCapabilities/backendCapabilitiesProvider '
            'for add-subscription operation dispatch.',
      );
      expect(contents, contains('BackendFeature.addSubscription'));
      expect(contents, contains('isOnlineRequired'));
    },
  );
}

List<File> _libDartFiles() {
  final files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(_isDartSource)
          .toList(growable: false)
        ..sort((a, b) => _posixPath(a).compareTo(_posixPath(b)));
  return files;
}

bool _isDartSource(File file) {
  final path = _posixPath(file);
  if (!path.endsWith('.dart')) return false;
  if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) return false;
  return !path.contains('/generated/');
}

List<_RawBackendTypeOccurrence> _rawBackendTypeOccurrences(
  Iterable<File> files,
) {
  final occurrences = <_RawBackendTypeOccurrence>[];
  for (final file in files) {
    final path = _posixPath(file);
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i += 1) {
      final line = lines[i];
      if (!_rawBackendTypeRegex.hasMatch(line)) continue;
      occurrences.add(
        _RawBackendTypeOccurrence(path: path, line: i + 1, source: line.trim()),
      );
    }
  }
  return occurrences;
}

String _formatOccurrences(List<_RawBackendTypeOccurrence> occurrences) {
  if (occurrences.isEmpty) return 'No raw backend-type occurrences found.';
  return occurrences
      .map(
        (occurrence) =>
            '${occurrence.path}:${occurrence.line}: ${occurrence.source}',
      )
      .join('\n');
}

String _posixPath(File file) {
  return file.path.replaceAll(r'\', '/');
}

class _RawBackendTypeOccurrence {
  const _RawBackendTypeOccurrence({
    required this.path,
    required this.line,
    required this.source,
  });

  final String path;
  final int line;
  final String source;

  @override
  String toString() => '$path:$line: $source';
}
