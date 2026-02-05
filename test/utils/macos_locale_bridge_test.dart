import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reader/utils/macos_locale_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_reader/app_locale');
  final calls = <String?>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'setPreferredLanguage') {
            return null;
          }
          final args = Map<String, Object?>.from(call.arguments as Map);
          calls.add(args['localeTag'] as String?);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('normalize locale tags for macOS language bridge', () async {
    Future<void> expectNormalization(String input, String expected) async {
      final before = calls.length;
      await MacOSLocaleBridge.setPreferredLanguage(input);
      expect(calls.length, before + 1);
      expect(calls.last, expected);
    }

    await expectNormalization('zh', 'zh-Hans');
    await expectNormalization('zh-HK', 'zh-Hant');
    await expectNormalization('en-GB', 'en');
    await expectNormalization('fr_CA', 'fr-CA');
  });
}
