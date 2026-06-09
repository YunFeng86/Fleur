@Tags(['global_logger'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:fleur/services/logging/app_logger.dart';
import 'package:fleur/services/logging/app_provider_observer.dart';
import 'package:fleur/services/logging/log_context.dart';
import 'package:fleur/services/settings/translation_ai_settings.dart';
import 'package:fleur/services/settings/translation_ai_settings_store.dart';
import 'package:fleur/utils/path_manager.dart';

import '../../test_utils/fake_path_provider_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PathProviderPlatform originalPlatform;
  late Directory tempDir;

  setUpAll(() {
    originalPlatform = PathProviderPlatform.instance;
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
    tempDir = await Directory.systemTemp.createTemp('fleur_logger_test_');
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
  });

  tearDown(() async {
    await AppLogger.resetForTests();
    PathManager.resetForTests();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  tearDownAll(() {
    PathProviderPlatform.instance = originalPlatform;
  });

  test(
    'writes stable sanitized context with warning error and stack',
    () async {
      await AppLogger.ensureInitialized();

      AppLogger.w(
        'warning with context',
        tag: 'test',
        error: StateError('boom'),
        stackTrace: StackTrace.fromString('stack-line'),
        context: const <String, Object?>{
          'zeta': 'last',
          'apiKey': 'secret-value',
          'alpha': 'first',
          'multi': 'line\nbreak',
          'nothing': null,
        },
      );
      final logFile = await AppLogger.getActiveLogFile();
      await AppLogger.resetForTests();
      final contents = await logFile!.readAsString();

      expect(contents, contains('[W] [test] warning with context'));
      expect(contents, contains('error: Bad state: boom'));
      expect(
        contents,
        contains(
          'context: alpha=first apiKey=<redacted> multi=line break zeta=last',
        ),
      );
      expect(contents, contains('stack-line'));
      expect(contents, isNot(contains('secret-value')));
      expect(contents, isNot(contains('nothing=')));
    },
  );

  test('createLogsArchive includes manifest and log file', () async {
    await AppLogger.ensureInitialized();
    AppLogger.i('archive marker', tag: 'test');

    final archiveFile = await AppLogger.createLogsArchive();
    final archive = ZipDecoder().decodeBytes(await archiveFile.readAsBytes());
    final names = archive.files.map((file) => file.name).toSet();

    expect(names, contains('manifest.txt'));
    expect(names.any((name) => name.startsWith('logs/fleur_')), isTrue);

    final manifest = utf8.decode(
      archive.files.firstWhere((file) => file.name == 'manifest.txt').content,
    );
    expect(manifest, contains('Fleur log export'));
    expect(manifest, contains('package: fleur'));
  });

  test('Dio log context strips query, fragment, headers, and body', () {
    final requestOptions = RequestOptions(
      path: '/v1/items',
      baseUrl: 'https://api.example.com',
      method: 'POST',
      queryParameters: const <String, Object?>{'token': 'secret'},
      headers: const <String, Object?>{'Authorization': 'Bearer secret'},
      data: const <String, Object?>{'body': 'secret'},
    );
    final error = DioException(
      requestOptions: requestOptions,
      response: Response<void>(statusCode: 503, requestOptions: requestOptions),
      type: DioExceptionType.badResponse,
    );

    final context = logContextForDioException(
      error,
      extra: const <String, Object?>{'operation': 'sync'},
    );

    expect(context['method'], 'POST');
    expect(context['host'], 'api.example.com');
    expect(context['path'], '/v1/items');
    expect(context['statusCode'], 503);
    expect(context['dioType'], 'badResponse');
    expect(context.toString(), isNot(contains('token=secret')));
    expect(context.toString(), isNot(contains('Authorization')));
    expect(context.toString(), isNot(contains('body')));
  });

  test('provider observer logs provider failures', () async {
    await AppLogger.ensureInitialized();
    final failingProvider = Provider<int>(
      name: 'failingProvider',
      (ref) => throw StateError('provider boom'),
    );
    final container = ProviderContainer(
      observers: const <ProviderObserver>[AppProviderObserver()],
    );
    addTearDown(container.dispose);

    expect(() => container.read(failingProvider), throwsStateError);
    final logFile = await AppLogger.getActiveLogFile();
    await AppLogger.resetForTests();
    final contents = await logFile!.readAsString();

    expect(contents, contains('[E] [provider] Provider failed'));
    expect(contents, contains('failingProvider'));
    expect(contents, contains('provider boom'));
  });

  test('translation AI settings load warning does not log prompts', () async {
    await AppLogger.ensureInitialized();
    final file = await PathManager.translationAiSettingsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '{"aiSummaryPrompt":"Private summary prompt",'
      '"aiTranslationPrompt":"Private translation prompt"',
    );

    final settings = await TranslationAiSettingsStore().load();
    final logFile = await AppLogger.getActiveLogFile();
    await AppLogger.resetForTests();
    final contents = await logFile!.readAsString();

    expect(settings.toJson(), TranslationAiSettings.defaults().toJson());
    expect(
      contents,
      contains('[W] [settings] Settings load failed; using defaults'),
    );
    expect(contents, contains('error: FormatException'));
    expect(contents, contains('file=translation_ai_settings'));
    expect(contents, isNot(contains('Private summary prompt')));
    expect(contents, isNot(contains('Private translation prompt')));
  });
}
