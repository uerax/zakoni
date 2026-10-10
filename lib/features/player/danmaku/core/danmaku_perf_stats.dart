import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// 弹幕运行时性能诊断与统计追踪器
/// 仅在非 Release 构建或开启 DANMAKU_PERF 编译常量时激活
class DanmakuPerfStats {
  DanmakuPerfStats({this.onLog});

  /// 自定义日志回调（用于测试捕获或外部重定向），默认使用 debugPrint
  final void Function(String line)? onLog;

  /// 全局性能埋点开关
  static const bool enabled =
      !kReleaseMode || bool.fromEnvironment('DANMAKU_PERF', defaultValue: false);

  bool _isListening = false;
  TimingsCallback? _timingsCallback;

  // 帧时间统计（以微秒存储避免浮点累计误差）
  int _frameCount = 0;
  int _totalBuildUs = 0;
  int _maxBuildUs = 0;
  int _totalRasterUs = 0;
  int _maxRasterUs = 0;
  int _totalIntervalUs = 0;
  int _intervalCount = 0;
  int _lastVsyncStartUs = 0;
  int _lastFlushTimeMs = 0;

  // 弹幕业务指标
  int _layoutCount = 0;
  int _mergeCount = 0;
  int _droppedCount = 0;
  int _activeCount = 0;

  /// 启动帧性能采集
  void start() {
    if (!enabled || _isListening) return;
    _isListening = true;
    _lastFlushTimeMs = DateTime.now().millisecondsSinceEpoch;
    _timingsCallback = _onTimings;
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback!);
  }

  /// 停止帧性能采集并释放回调
  void stop() {
    if (!_isListening) return;
    _isListening = false;
    if (_timingsCallback != null) {
      SchedulerBinding.instance.removeTimingsCallback(_timingsCallback!);
      _timingsCallback = null;
    }
  }

  /// 记录新建 layout 次数
  void recordLayoutCreated([int count = 1]) {
    if (!enabled) return;
    _layoutCount += count;
  }

  /// 记录合流吸收次数
  void recordMerge([int count = 1]) {
    if (!enabled) return;
    _mergeCount += count;
  }

  /// 记录弹幕被丢弃次数
  void recordDropped([int count = 1]) {
    if (!enabled) return;
    _droppedCount += count;
  }

  /// 更新当前在场活动弹幕数
  void updateActiveCount(int count) {
    if (!enabled) return;
    _activeCount = count;
  }

  /// 帧回调处理
  void _onTimings(List<FrameTiming> timings) {
    if (!_isListening) return;
    handleTimings(timings);
  }

  /// 处理帧耗时数据（暴露供测试调用）
  @visibleForTesting
  void handleTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frameCount++;
      final buildUs = timing.buildDuration.inMicroseconds;
      final rasterUs = timing.rasterDuration.inMicroseconds;
      _totalBuildUs += buildUs;
      if (buildUs > _maxBuildUs) _maxBuildUs = buildUs;
      _totalRasterUs += rasterUs;
      if (rasterUs > _maxRasterUs) _maxRasterUs = rasterUs;

      final vsyncStartUs = timing.timestampInMicroseconds(FramePhase.vsyncStart);
      if (_lastVsyncStartUs > 0) {
        final intervalUs = vsyncStartUs - _lastVsyncStartUs;
        // 过滤切出窗口或长期暂停产生的异常跨度 (> 500ms)
        if (intervalUs > 0 && intervalUs < 500000) {
          _totalIntervalUs += intervalUs;
          _intervalCount++;
        }
      }
      _lastVsyncStartUs = vsyncStartUs;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFlushTimeMs >= 1000 && _frameCount > 0) {
      flush(now);
    }
  }

  /// 手动刷新当前统计窗口并输出日志（公开方法方便测试触发）
  void flush([int? nowMs]) {
    if (_frameCount == 0) return;

    final avgIntervalMs = _intervalCount > 0
        ? (_totalIntervalUs / _intervalCount) / 1000.0
        : 0.0;
    final intervalStr = avgIntervalMs > 0
        ? '${avgIntervalMs.toStringAsFixed(1)}ms (~${(1000.0 / avgIntervalMs).round()}Hz)'
        : '--';

    final avgBuildMs = (_totalBuildUs / _frameCount) / 1000.0;
    final maxBuildMs = _maxBuildUs / 1000.0;
    final avgRasterMs = (_totalRasterUs / _frameCount) / 1000.0;
    final maxRasterMs = _maxRasterUs / 1000.0;

    final line = '[DanmakuPerf] 帧间隔: $intervalStr | '
        'build: ${avgBuildMs.toStringAsFixed(1)}ms (max ${maxBuildMs.toStringAsFixed(1)}ms) | '
        'raster: ${avgRasterMs.toStringAsFixed(1)}ms (max ${maxRasterMs.toStringAsFixed(1)}ms) | '
        '新建 layout: $_layoutCount | 合流: $_mergeCount | 在场: $_activeCount | 丢弃: $_droppedCount';

    if (onLog != null) {
      onLog!(line);
    } else {
      debugPrint(line);
    }

    // 重置统计窗口
    _frameCount = 0;
    _totalBuildUs = 0;
    _maxBuildUs = 0;
    _totalRasterUs = 0;
    _maxRasterUs = 0;
    _totalIntervalUs = 0;
    _intervalCount = 0;
    _layoutCount = 0;
    _mergeCount = 0;
    _droppedCount = 0;
    _lastFlushTimeMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  }
}
