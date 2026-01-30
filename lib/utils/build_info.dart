/// 构建信息常量
///
/// 这些值在CI构建时通过 --dart-define 注入
/// 本地开发时使用默认值
class AppBuildInfo {
  /// Git Commit Hash (短版本，如 a1b2c3d)
  static const String commitHash = String.fromEnvironment(
    'APP_COMMIT_HASH',
    defaultValue: 'dev',
  );

  /// 构建时间 (UTC格式)
  static const String buildTime = String.fromEnvironment(
    'APP_BUILD_TIME',
    defaultValue: 'unknown',
  );

  /// 构建号 (GitHub Actions run_number)
  static const String buildNumber = String.fromEnvironment(
    'APP_BUILD_NUMBER',
    defaultValue: '0',
  );
}
