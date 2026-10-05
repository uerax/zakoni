import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 弹弹 play 鉴权模式
enum DandanAuthMode {
  /// 开放平台标准签名模式（带 X-Auth, X-Timestamp, X-Signature）
  open,

  /// 内置通用兼容模式（直接携带 X-AppId, X-AppSecret）
  legacy,
}

/// 弹弹 play 配置管理中心
/// 支持持久化存储用户自定义凭证，防止内置共享凭证失效
class DandanConfigManager extends ChangeNotifier {
  DandanConfigManager._();
  static final DandanConfigManager instance = DandanConfigManager._();

  static const String _kAppIdKey = 'zakoni_dandan_app_id';
  static const String _kAppSecretKey = 'zakoni_dandan_app_secret';
  static const String _kApiEndpointKey = 'zakoni_dandan_api_endpoint';

  /// 默认通用公开客户端凭证 (保证开箱即用，1:1 对齐 animaku dandan.ts)
  static const String fallbackAppId = 'hvf6pzvxcm';
  static const String fallbackAppSecret = 'IZhcUIakoxFaK9xBBDJ9Bs1OU2s4kK5t';

  static const String defaultEndpoint = 'https://api.dandanplay.net';

  String _appId = '';
  String _appSecret = '';
  String _apiEndpoint = defaultEndpoint;
  bool _initialized = false;

  String get appId => _appId;
  String get appSecret => _appSecret;
  String get apiEndpoint => _apiEndpoint;
  bool get isInitialized => _initialized;

  /// 是否使用了用户自主配置的凭据
  bool get isCustomCredentials {
    final id = _appId.trim();
    final secret = _appSecret.trim();
    if (id.isEmpty || secret.isEmpty) return false;
    if (id == fallbackAppId && secret == fallbackAppSecret) return false;
    return true;
  }

  /// 当前生效的 AppId
  String get effectiveAppId => isCustomCredentials ? _appId.trim() : fallbackAppId;

  /// 当前生效的 AppSecret
  String get effectiveAppSecret => isCustomCredentials ? _appSecret.trim() : fallbackAppSecret;

  /// 当前生效的 API 服务端点
  String get effectiveEndpoint {
    var ep = _apiEndpoint.trim();
    if (ep.isEmpty) return defaultEndpoint;
    if (ep.endsWith('/')) ep = ep.substring(0, ep.length - 1);
    return ep;
  }

  /// 当前生效的鉴权模式
  DandanAuthMode get effectiveAuthMode =>
      isCustomCredentials ? DandanAuthMode.open : DandanAuthMode.legacy;

  /// 初始化本地配置
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final sp = await SharedPreferences.getInstance();
      _appId = sp.getString(_kAppIdKey) ?? '';
      _appSecret = sp.getString(_kAppSecretKey) ?? '';
      _apiEndpoint = sp.getString(_kApiEndpointKey) ?? defaultEndpoint;
    } catch (_) {}
    _initialized = true;
    notifyListeners();
  }

  /// 保存用户凭证
  Future<void> saveConfig({
    required String appId,
    required String appSecret,
    String? apiEndpoint,
  }) async {
    _appId = appId.trim();
    _appSecret = appSecret.trim();
    _apiEndpoint = (apiEndpoint != null && apiEndpoint.trim().isNotEmpty)
        ? apiEndpoint.trim()
        : defaultEndpoint;

    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kAppIdKey, _appId);
    await sp.setString(_kAppSecretKey, _appSecret);
    await sp.setString(_kApiEndpointKey, _apiEndpoint);

    notifyListeners();
  }

  /// 重置为应用内置默认配置
  Future<void> resetToDefault() async {
    _appId = '';
    _appSecret = '';
    _apiEndpoint = defaultEndpoint;

    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kAppIdKey);
    await sp.remove(_kAppSecretKey);
    await sp.remove(_kApiEndpointKey);

    notifyListeners();
  }

  /// 1:1 对齐 animaku dandan.ts 生成开放平台签名
  /// Signature = Base64(SHA256("${appId}${timestamp}${path}${secret}"))
  static String generateSignature({
    required String path,
    required int timestamp,
    required String appId,
    required String appSecret,
  }) {
    final raw = '$appId$timestamp$path$appSecret';
    final bytes = utf8.encode(raw);
    final digest = sha256.convert(bytes);
    return base64.encode(digest.bytes);
  }

  /// 联通性测试：验证当前配置是否有效
  Future<({bool success, String message})> testConnection({
    String? testAppId,
    String? testAppSecret,
    String? testEndpoint,
  }) async {
    final targetId = (testAppId ?? effectiveAppId).trim();
    final targetSecret = (testAppSecret ?? effectiveAppSecret).trim();
    var targetEp = (testEndpoint ?? effectiveEndpoint).trim();
    if (targetEp.endsWith('/')) targetEp = targetEp.substring(0, targetEp.length - 1);
    if (targetEp.isEmpty) targetEp = defaultEndpoint;

    final isCustom = targetId.isNotEmpty &&
        targetSecret.isNotEmpty &&
        !(targetId == fallbackAppId && targetSecret == fallbackAppSecret);

    final path = '/api/v2/bangumi/bgmtv/1';
    final url = '$targetEp$path';

    final headers = <String, String>{
      'User-Agent': 'Zakoni/1.0.0 (Anime Client)',
      'Accept': 'application/json',
    };

    if (isCustom) {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      headers['X-Auth'] = '1';
      headers['X-AppId'] = targetId;
      headers['X-Timestamp'] = timestamp.toString();
      headers['X-Signature'] = generateSignature(
        path: path,
        timestamp: timestamp,
        appId: targetId,
        appSecret: targetSecret,
      );
    } else {
      headers['X-AppId'] = targetId;
      headers['X-AppSecret'] = targetSecret;
    }

    try {
      final dio = Dio();
      final res = await dio.get<Map<String, dynamic>>(
        url,
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final data = res.data ?? <String, dynamic>{};
      final success = data['success'] as bool? ?? false;
      final errorCode = data['errorCode'] as int?;

      // 只要鉴权通过（无论是否找到指定条目或成功返回），说明 token/签名通过了开放平台验证
      if (success || errorCode == 7) {
        return (success: true, message: '连接成功，凭证有效！');
      }

      final errorMsg = data['errorMessage']?.toString() ?? '未知鉴权错误';
      return (success: false, message: '弹弹响应错误: $errorMsg');
    } catch (e) {
      if (e is DioException) {
        final resp = e.response;
        if (resp != null && resp.data is Map) {
          final errMap = resp.data as Map;
          final msg = errMap['errorMessage'] ?? errMap['message'] ?? resp.statusMessage;
          return (success: false, message: '鉴权失败 (${resp.statusCode}): $msg');
        }
        return (success: false, message: '网络请求失败: ${e.message}');
      }
      return (success: false, message: '测试异常: $e');
    }
  }
}
