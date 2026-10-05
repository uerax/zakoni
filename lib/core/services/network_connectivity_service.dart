import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// 全局网络连通性与计费网络（移动蜂窝数据）感知服务
/// 负责实时监听系统网络类型变化，供播放器自适应调节缓存策略（Wi-Fi 150MB / 蜂窝数据 16MB）
class NetworkConnectivityService {
  NetworkConnectivityService._();

  static final NetworkConnectivityService instance =
      NetworkConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final ValueNotifier<bool> _isMeteredNotifier = ValueNotifier<bool>(false);
  final StreamController<bool> _meteredController =
      StreamController<bool>.broadcast();

  bool _initialized = false;

  /// 当前是否处于计费网络（移动蜂窝数据 2G/3G/4G/5G）
  bool get isMetered => _isMeteredNotifier.value;

  /// 计费网络状态 ValueListenable
  ValueListenable<bool> get isMeteredListenable => _isMeteredNotifier;

  /// 计费网络状态变更 Stream
  Stream<bool> get onMeteredChanged => _meteredController.stream;

  /// 初始化服务并启动系统广播监听
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initialResults = await _connectivity.checkConnectivity();
      _applyConnectivityResults(initialResults);
    } catch (e) {
      debugPrint('[NetworkConnectivityService] 初始化检测网络类型失败: $e');
    }

    _subscription = _connectivity.onConnectivityChanged.listen(
      _applyConnectivityResults,
      onError: (Object error) {
        debugPrint('[NetworkConnectivityService] 网络状态监听异常: $error');
      },
    );
  }

  void _applyConnectivityResults(List<ConnectivityResult> results) {
    final metered = _resolveMetered(results);
    if (_isMeteredNotifier.value != metered) {
      _isMeteredNotifier.value = metered;
      _meteredController.add(metered);
      debugPrint(
        '[NetworkConnectivityService] 网络环境变更: '
        '${metered ? "移动蜂窝计费网络 (4G/5G)" : "高速无计费网络 (Wi-Fi/有线以太网)"}',
      );
    }
  }

  /// 特殊处理说明：
  /// 1. 桌面端（Windows / macOS / Linux）多数情况下为 Wi-Fi 或有线连接，默认视作无计费高速网络；
  /// 2. 当连接结果中明确包含 wifi 或 ethernet 时，即使同时存在其他隧道/连接，也判定为无计费；
  /// 3. 当仅有 mobile 连接时，判定为移动蜂窝计费网络；
  /// 4. 处于无网络 (none) 或其他未知状态时，维持上一次的判定结果，避免因弱网短暂波动误触发频繁降级。
  bool _resolveMetered(List<ConnectivityResult> results) {
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      if (results.contains(ConnectivityResult.mobile)) {
        return true;
      }
      return false;
    }

    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return false;
    }

    if (results.contains(ConnectivityResult.mobile)) {
      return true;
    }

    return _isMeteredNotifier.value;
  }

  /// 释放监听资源（通常随应用进程生命周期）
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _meteredController.close();
    _isMeteredNotifier.dispose();
  }
}
