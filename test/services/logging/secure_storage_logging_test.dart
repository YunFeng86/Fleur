import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:fleur/services/accounts/account.dart';
import 'package:fleur/services/accounts/credential_store.dart';
import 'package:fleur/services/logging/app_logger.dart';
import 'package:fleur/services/settings/translation_ai_secret_store.dart';
import 'package:fleur/utils/path_manager.dart';

import '../../test_utils/fake_path_provider_platform.dart';

const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform originalPathProvider;
  late Directory tempDir;

  setUpAll(() {
    originalPathProvider = PathProviderPlatform.instance;
    PackageInfo.setMockInitialValues(
      appName: 'Fleur',
      packageName: 'fleur',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
      installerStore: null,
    );
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'fleur_secure_storage_logging_test_',
    );
    final documents = await Directory(
      '${tempDir.path}/documents',
    ).create(recursive: true);
    final support = await Directory(
      '${tempDir.path}/support',
    ).create(recursive: true);
    final cache = await Directory(
      '${tempDir.path}/cache',
    ).create(recursive: true);
    final temporary = await Directory(
      '${tempDir.path}/temporary',
    ).create(recursive: true);
    PathProviderPlatform.instance = FakePathProviderPlatform(
      documentsPath: documents.path,
      supportPath: support.path,
      cachePath: cache.path,
      temporaryPath: temporary.path,
    );
    PathManager.resetForTests();
    await AppLogger.resetForTests();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (_) async {
          throw PlatformException(
            code: '-34018',
            message: 'Unexpected security result code',
            details: -34018,
          );
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
    await AppLogger.resetForTests();
    PathManager.resetForTests();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  tearDownAll(() {
    PathProviderPlatform.instance = originalPathProvider;
  });

  test(
    'credential store logs secure storage failures without secrets',
    () async {
      await AppLogger.ensureInitialized();
      final store = CredentialStore();

      await expectLater(
        store.setApiToken(
          'account-1',
          AccountType.miniflux,
          'super-secret-token',
        ),
        throwsA(isA<PlatformException>()),
      );
      final contents = await _readActiveLog();

      expect(
        contents,
        contains('[E] [credential] Credential storage operation failed'),
      );
      expect(contents, contains('accountId=account-1'));
      expect(contents, contains('accountType=miniflux'));
      expect(contents, contains('credentialKind=apiToken'));
      expect(contents, contains('operation=setApiToken'));
      expect(contents, contains('platformCode=-34018'));
      expect(
        contents,
        contains('platformMessage=Unexpected security result code'),
      );
      expect(contents, isNot(contains('super-secret-token')));
      expect(contents, isNot(contains('miniflux_api_token')));
    },
  );

  test(
    'translation secret store logs secure storage failures without keys',
    () async {
      await AppLogger.ensureInitialized();
      final store = TranslationAiSecretStore();

      await expectLater(
        store.setAiServiceApiKey('service-1', 'super-secret-api-key'),
        throwsA(isA<PlatformException>()),
      );
      final contents = await _readActiveLog();

      expect(
        contents,
        contains(
          '[E] [credential] Translation credential storage operation failed',
        ),
      );
      expect(contents, contains('credentialKind=aiServiceApiKey'));
      expect(contents, contains('operation=setAiServiceApiKey'));
      expect(contents, contains('service=translation_ai'));
      expect(contents, contains('serviceId=service-1'));
      expect(contents, contains('platformCode=-34018'));
      expect(contents, isNot(contains('super-secret-api-key')));
      expect(contents, isNot(contains('api_key')));
    },
  );
}

Future<String> _readActiveLog() async {
  final logFile = await AppLogger.getActiveLogFile();
  await AppLogger.resetForTests();
  return logFile!.readAsString();
}
