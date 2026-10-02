/// 全局应用常量配置与版本声明
class AppConstants {
  const AppConstants._();

  /// 应用语义化版本号
  static const String appVersion = '1.0.0';

  /// 应用构建版本号
  static const int buildNumber = 1;

  /// 应用标识名称
  static const String appName = 'zakoni';

  /// 开发者个人/组织 ID
  static const String developerId = 'uerax';

  /// 开源项目主页仓库地址
  static const String projectUrl = 'https://github.com/uerax/zakoni';

  /// 遵循 Bangumi 官方 API 开发者准则规范生成的合规 User-Agent:
  /// 格式: <开发者ID>/<应用名>/<版本号> (<项目主页URL>)
  static const String bangumiUserAgent =
      '$developerId/$appName/$appVersion ($projectUrl)';
}
