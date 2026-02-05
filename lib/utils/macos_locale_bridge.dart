import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platform.dart';

class MacOSLocaleBridge {
  static const MethodChannel _channel = MethodChannel(
    'flutter_reader/app_locale',
  );
  static String? _lastLocaleTag;

  static Future<void> setPreferredLanguage(String? localeTag) async {
    if (!isMacOS) return;
    final normalized = _normalizeLocaleTag(localeTag);
    if (_lastLocaleTag == normalized) return;
    try {
      await _channel.invokeMethod('setPreferredLanguage', {
        'localeTag': normalized,
      });
      _lastLocaleTag = normalized;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('macOS language bridge failed: $e');
      }
    }
  }

  static String? _normalizeLocaleTag(String? localeTag) {
    final raw = localeTag?.trim();
    if (raw == null || raw.isEmpty) return null;
    final tag = raw.replaceAll('_', '-');
    final lower = tag.toLowerCase();
    if (lower.startsWith('zh')) {
      final parts = lower.split('-');
      if (parts.contains('hant') ||
          parts.contains('tw') ||
          parts.contains('hk') ||
          parts.contains('mo')) {
        return 'zh-Hant';
      }
      if (parts.contains('hans') ||
          parts.contains('cn') ||
          parts.contains('sg') ||
          parts.contains('my')) {
        return 'zh-Hans';
      }
      return 'zh-Hans';
    }
    if (lower.startsWith('en')) return 'en';
    return tag;
  }
}
