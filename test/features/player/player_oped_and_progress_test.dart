import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/core/services/bangumi_oped_service.dart';
import 'package:zakoni/features/player/controller/playback_controller.dart';
import 'package:zakoni/features/player/danmaku/danmaku.dart';
import 'package:zakoni/features/player/widgets/player_controls.dart';
import 'package:zakoni/features/player/widgets/player_progress_bar.dart';
import 'package:zakoni/features/player/widgets/player_skip_toast.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BangumiOpedService 片头片尾数据解析测试', () {
    test('1. 正确解析标准文本格式与 -1 哨兵值', () {
      const rawText = '''
1;90;180;1350;1440
2;60;150;-1;-1
3;-1;-1;1200;1300
# 注释行或空行
malformed line
4;10;100;200;300
''';

      final service = BangumiOpedService.instance;
      final result = service.parseOpedData(rawText);

      expect(result.length, equals(4));

      // Ep 1: 有 OP 和 ED
      expect(result[1]?.hasOp, isTrue);
      expect(result[1]?.opStart, equals(90));
      expect(result[1]?.opEnd, equals(180));
      expect(result[1]?.hasEd, isTrue);
      expect(result[1]?.edStart, equals(1350));
      expect(result[1]?.edEnd, equals(1440));

      // Ep 2: 仅有 OP
      expect(result[2]?.hasOp, isTrue);
      expect(result[2]?.hasEd, isFalse);

      // Ep 3: 仅有 ED
      expect(result[3]?.hasOp, isFalse);
      expect(result[3]?.hasEd, isTrue);

      // Ep 4
      expect(result[4]?.hasOp, isTrue);
      expect(result[4]?.hasEd, isTrue);
    });

    test('2. 重复集数按第一条优先原则', () {
      const rawText = '''
1;90;180;1350;1440
1;100;190;1360;1450
''';

      final service = BangumiOpedService.instance;
      final result = service.parseOpedData(rawText);

      expect(result.length, equals(1));
      expect(result[1]?.opStart, equals(90));
    });
  });

  group('PlayerProgressBar 复合进度条渲染与交互测试', () {
    testWidgets('1. 进度条渲染包含弹幕波形、OP/ED 区间与缓冲条', (tester) async {
      Duration? started;
      Duration? ended;

      final danmakuItems = [
        DanmakuItem(text: '弹幕1', timeMs: 5000),
        DanmakuItem(text: '弹幕2', timeMs: 5200),
        DanmakuItem(text: '弹幕3', timeMs: 5400),
        DanmakuItem(text: '弹幕4', timeMs: 12000),
        DanmakuItem(text: '弹幕5', timeMs: 12500),
        DanmakuItem(text: '弹幕6', timeMs: 12800),
      ];

      const oped = EpisodeOpedSegment(
        episode: 1,
        opStart: 10,
        opEnd: 30,
        edStart: 100,
        edEnd: 120,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                child: PlayerProgressBar(
                  position: const Duration(seconds: 40),
                  duration: const Duration(seconds: 140),
                  buffer: const Duration(seconds: 80),
                  opedSegment: oped,
                  danmakuItems: danmakuItems,
                  onChangeStart: (d) => started = d,
                  onChanged: (_) {},
                  onChangeEnd: (d) => ended = d,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证存在进度条组件
      expect(find.byType(PlayerProgressBar), findsOneWidget);

      // 点击进度条中间位置 (约 50% 处，即 70 秒)
      await tester.tap(find.byType(PlayerProgressBar));
      await tester.pumpAndSettle();

      expect(started, isNotNull);
      expect(ended, isNotNull);
      expect(ended!.inSeconds, inInclusiveRange(65, 75));
    });
  });

  group('PlayerControls 自动跳过片头与撤销联动测试', () {
    late ZakoniPlaybackController controller;

    setUp(() {
      controller = ZakoniPlaybackController();
    });

    tearDown(() async {
      await controller.dispose();
    });

    testWidgets('1. 播放行进至 OP 区间时自动触发跳过并弹出撤销 Toast，点击撤销可回跳',
        (tester) async {
      const oped = EpisodeOpedSegment(
        episode: 1,
        opStart: 10,
        opEnd: 30,
        edStart: 100,
        edEnd: 120,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 450,
              child: PlayerControls(
                controller: controller,
                title: '自动跳过测试',
                opedSegment: oped,
                autoSkipOped: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 模拟视频起播中，并且播放时间步进到 11 秒（OP 起始点之内）
      controller.core.value = controller.core.value.copyWith(playing: true);
      controller.timeline.value = controller.timeline.value.copyWith(
        position: const Duration(seconds: 11),
        duration: const Duration(seconds: 140),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证已自动跳转至 30 秒（OP 结束处）
      expect(controller.timeline.value.position.inSeconds, equals(30));

      // 验证撤销浮标展示
      expect(find.byType(PlayerSkipToast), findsOneWidget);
      expect(find.text('撤销'), findsOneWidget);

      // 点击撤销
      await tester.tap(find.text('撤销'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证回跳到 OP 起始点 10 秒
      expect(controller.timeline.value.position.inSeconds, equals(10));
    });
  });
}
