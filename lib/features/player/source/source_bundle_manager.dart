import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:zakoni/features/player/source/models/source_models.dart';
import 'package:zakoni/features/player/source/native_source_runtime.dart';

/// 适配器更新检查结果
class BundleUpdateCheckResult {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String? changelog;
  final String? downloadUrl;

  const BundleUpdateCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    this.changelog,
    this.downloadUrl,
  });
}

/// 视频源全局生命周期与业务管理器
/// 已彻底移除 QuickJS / JS Bundle，由原生 Dart 直接调度
class SourceBundleManager extends ChangeNotifier {
  SourceBundleManager({
    NativeSourceRuntime? runtime,
    Dio? dio,
  }) : _runtime = runtime ?? NativeSourceRuntime(dio: dio);

  static SourceBundleManager? _instance;
  static SourceBundleManager get instance => _instance ??= SourceBundleManager();

  final NativeSourceRuntime _runtime;

  NativeSourceRuntime get runtime => _runtime;
  bool get isReady => _runtime.isInitialized;
  String? get lastError => null;
  SourceBundleMeta? get meta => _runtime.bundleMeta;
  List<SourceMeta> get sources => _runtime.availableSources;

  /// 原生初始化 (瞬时就绪)
  Future<void> initialize() async {
    notifyListeners();
  }

  /// 检查原生解析器版本
  Future<BundleUpdateCheckResult> checkUpdate() async {
    final currentVer = meta?.version ?? '2.0.0-native';
    return BundleUpdateCheckResult(
      hasUpdate: false,
      currentVersion: currentVer,
      latestVersion: currentVer,
      changelog: '当前已运行于高性能纯原生 Dart 视频源内核',
    );
  }

  /// 下载并热应用更新 (纯原生内核已内置高优解析)
  Future<bool> applyUpdate(String downloadUrl) async {
    notifyListeners();
    return true;
  }

  /// 恢复出厂配置
  Future<void> resetToFactory() async {
    notifyListeners();
  }
}
