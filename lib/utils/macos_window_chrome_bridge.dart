import 'package:flutter/services.dart';

import '../ui/sidebar_layout.dart';
import 'platform.dart';

typedef MacOSWindowChromeMetricsChanged =
    void Function(MacOSWindowChromeMetrics metrics);

class MacOSWindowChromeBridge {
  static const MethodChannel _channel = MethodChannel(
    'com.cloudwind.fleur/window_controls',
  );

  static MacOSWindowChromeMetrics _latestMetrics =
      MacOSWindowChromeMetrics.fallback;

  static MacOSWindowChromeMetrics get latestMetrics => _latestMetrics;

  static Future<MacOSWindowChromeMetrics> configureTitlebarChrome() async {
    return _invokeMetricsMethod('configureTitlebarChrome');
  }

  static Future<MacOSWindowChromeMetrics> getTitlebarChromeMetrics() async {
    return _invokeMetricsMethod('getTitlebarChromeMetrics');
  }

  static Future<void> performWindowDrag() async {
    if (!isMacOS) return;
    try {
      await _channel.invokeMethod<void>('performWindowDrag');
    } on MissingPluginException {
      // Widget tests and non-macOS embedders may not register this channel.
    }
  }

  static Future<void> performWindowZoom() async {
    if (!isMacOS) return;
    try {
      await _channel.invokeMethod<void>('performWindowZoom');
    } on MissingPluginException {
      // Widget tests and non-macOS embedders may not register this channel.
    }
  }

  static void setMetricsChangedHandler(
    MacOSWindowChromeMetricsChanged? handler,
  ) {
    if (!isMacOS) return;
    if (handler == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'titlebarChromeMetricsChanged':
          final metrics = MacOSWindowChromeMetrics.fromMap(call.arguments);
          _latestMetrics = metrics;
          handler(metrics);
          return null;
        default:
          throw MissingPluginException(
            'No handler for ${call.method} on ${_channel.name}',
          );
      }
    });
  }

  static Future<MacOSWindowChromeMetrics> _invokeMetricsMethod(
    String method,
  ) async {
    if (!isMacOS) return _latestMetrics;
    final result = await _channel.invokeMethod<Object?>(method);
    final metrics = MacOSWindowChromeMetrics.fromMap(result);
    _latestMetrics = metrics;
    return metrics;
  }
}
