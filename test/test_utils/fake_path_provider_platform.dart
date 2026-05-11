import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform({
    required String documentsPath,
    required String supportPath,
    required String cachePath,
    String? temporaryPath,
  }) : _documentsPath = documentsPath,
       _supportPath = supportPath,
       _cachePath = cachePath,
       _temporaryPath = temporaryPath;

  final String _documentsPath;
  final String _supportPath;
  final String _cachePath;
  final String? _temporaryPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => _documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async => _supportPath;

  @override
  Future<String?> getApplicationCachePath() async => _cachePath;

  @override
  Future<String?> getTemporaryPath() async => _temporaryPath;
}
