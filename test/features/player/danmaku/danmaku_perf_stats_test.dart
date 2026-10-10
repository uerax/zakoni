import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/features/player/danmaku/core/danmaku_perf_stats.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DanmakuPerfStats 性能埋点统计测试', () {
    test('单秒指标累加与日志格式化输出', () {
      final logs = <String>[];
      final stats = DanmakuPerfStats(onLog: logs.add);

      stats.recordLayoutCreated(3);
      stats.recordMerge(2);
      stats.recordDropped(1);
      stats.updateActiveCount(42);

      // 构造模拟 120Hz (~8.3ms) FrameTiming 数据
      final timings = [
        FrameTiming(
          vsyncStart: 1000000,
          buildStart: 1001000,
          buildFinish: 1003000, // build: 2ms
          rasterStart: 1003500,
          rasterFinish: 1006500, // raster: 3ms
          rasterFinishWallTime: 1006500,
        ),
        FrameTiming(
          vsyncStart: 1008333, // 间隔 8.33ms (120Hz)
          buildStart: 1009000,
          buildFinish: 1010000, // build: 1ms
          rasterStart: 1010500,
          rasterFinish: 1015500, // raster: 5ms
          rasterFinishWallTime: 1015500,
        ),
      ];

      stats.handleTimings(timings);
      stats.flush();

      expect(logs.length, equals(1));
      final log = logs.first;
      expect(log, contains('[DanmakuPerf]'));
      expect(log, contains('帧间隔: 8.3ms (~120Hz)'));
      expect(log, contains('build: 1.5ms (max 2.0ms)'));
      expect(log, contains('raster: 4.0ms (max 5.0ms)'));
      expect(log, contains('新建 layout: 3'));
      expect(log, contains('合流: 2'));
      expect(log, contains('在场: 42'));
      expect(log, contains('丢弃: 1'));
    });

    test('60Hz 帧间隔识别与计算', () {
      final logs = <String>[];
      final stats = DanmakuPerfStats(onLog: logs.add);

      // 构造模拟 60Hz (~16.7ms) FrameTiming 数据
      final timings = [
        FrameTiming(
          vsyncStart: 1000000,
          buildStart: 1001000,
          buildFinish: 1002000,
          rasterStart: 1002500,
          rasterFinish: 1004500,
          rasterFinishWallTime: 1004500,
        ),
        FrameTiming(
          vsyncStart: 1016666, // 间隔 16.67ms (60Hz)
          buildStart: 1017000,
          buildFinish: 1018000,
          rasterStart: 1018500,
          rasterFinish: 1020500,
          rasterFinishWallTime: 1020500,
        ),
      ];

      stats.handleTimings(timings);
      stats.flush();

      expect(logs.length, equals(1));
      expect(logs.first, contains('帧间隔: 16.7ms (~60Hz)'));
    });

    test('生命周期 start 与 stop 安全调用', () {
      final stats = DanmakuPerfStats();
      expect(() => stats.start(), returnsNormally);
      expect(() => stats.start(), returnsNormally); // 重复调用不崩溃
      expect(() => stats.stop(), returnsNormally);
      expect(() => stats.stop(), returnsNormally); // 重复调用不崩溃
    });

    test('统计重置与零状态格式', () {
      final logs = <String>[];
      final stats = DanmakuPerfStats(onLog: logs.add);

      // 没有帧时不输出日志
      stats.flush();
      expect(logs.isEmpty, isTrue);
    });
  });
}
