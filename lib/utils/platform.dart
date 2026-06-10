import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

TargetPlatform get _effectiveTargetPlatform =>
    debugFleurTargetPlatformOverride ?? defaultTargetPlatform;

TargetPlatform get effectiveTargetPlatform => _effectiveTargetPlatform;

TargetPlatform? debugFleurTargetPlatformOverride;

bool get isDesktop =>
    !kIsWeb &&
    (_effectiveTargetPlatform == TargetPlatform.windows ||
        _effectiveTargetPlatform == TargetPlatform.macOS ||
        _effectiveTargetPlatform == TargetPlatform.linux);

bool get isAndroid =>
    !kIsWeb && _effectiveTargetPlatform == TargetPlatform.android;

bool get isIOS => !kIsWeb && _effectiveTargetPlatform == TargetPlatform.iOS;

bool get isMacOS => !kIsWeb && _effectiveTargetPlatform == TargetPlatform.macOS;

bool get isWindows =>
    !kIsWeb && _effectiveTargetPlatform == TargetPlatform.windows;

bool get isLinux => !kIsWeb && _effectiveTargetPlatform == TargetPlatform.linux;

bool get supportsBackgroundSyncPlatform => isAndroid || isIOS;

class IosShareBridge {
  static const MethodChannel _channel = MethodChannel(
    'com.cloudwind.fleur/ios_share',
  );

  /// 在 iOS 上弹出系统分享/导出面板（包含“存储到文件”等）。
  static Future<void> shareFile({
    required String path,
    String? mimeType,
    String? name,
  }) async {
    if (!isIOS) return;
    await _channel.invokeMethod<void>('shareFile', {
      'path': path,
      'mimeType': mimeType,
      'name': name,
    });
  }
}
