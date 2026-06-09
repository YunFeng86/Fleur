import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_update_manifest.dart';
import 'app_version_compare.dart';

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.manifest,
    required this.isUpdateAvailable,
    required this.currentVersion,
  });

  final AppUpdateManifest manifest;
  final bool isUpdateAvailable;
  final String currentVersion;
}

typedef PackageInfoLoader = Future<PackageInfo> Function();

class AppUpdateService {
  const AppUpdateService({
    required Dio dio,
    required Uri manifestUri,
    PackageInfoLoader packageInfoLoader = PackageInfo.fromPlatform,
  }) : _dio = dio,
       _manifestUri = manifestUri,
       _packageInfoLoader = packageInfoLoader;

  final Dio _dio;
  final Uri _manifestUri;
  final PackageInfoLoader _packageInfoLoader;

  Future<AppUpdateCheckResult> checkLatest({String? currentVersion}) async {
    final packageInfo = currentVersion == null
        ? await _packageInfoLoader()
        : null;
    final effectiveCurrentVersion = currentVersion ?? packageInfo!.version;
    final manifest = await fetchLatestManifest();
    return AppUpdateCheckResult(
      manifest: manifest,
      currentVersion: effectiveCurrentVersion,
      isUpdateAvailable: isRemoteVersionNewer(
        currentVersion: effectiveCurrentVersion,
        remoteVersion: manifest.version,
      ),
    );
  }

  Future<AppUpdateManifest> fetchLatestManifest() async {
    final response = await _dio.getUri<Object?>(
      _manifestUri,
      options: Options(
        responseType: ResponseType.json,
        headers: const {'Accept': 'application/json'},
      ),
    );
    final data = response.data;
    if (data is Map<String, Object?>) {
      return AppUpdateManifest.fromJson(data);
    }
    if (data is Map) {
      return AppUpdateManifest.fromJson(Map<String, Object?>.from(data));
    }
    if (data is String) {
      return AppUpdateManifest.fromJson(jsonDecode(data));
    }
    throw const FormatException('Update manifest response was not JSON');
  }
}
