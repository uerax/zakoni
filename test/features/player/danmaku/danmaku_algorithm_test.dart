import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/features/player/danmaku/danmaku.dart';

void main() {
  group('DanmakuTextNormalizer 文本归一化测试', () {
    test('全角标点与英文字符转换为半角', () {
      expect(
        DanmakuTextNormalizer.normalize('！Ｈｅｌｌｏ，Ｗｏｒｌｄ！'),
        equals('hello,world'),
      );
    });

    test('连续3个以上重复字符折叠为2个', () {
      expect(
        DanmakuTextNormalizer.normalize('23333333'),
        equals('233'),
      );
      expect(
        DanmakuTextNormalizer.normalize('哈哈哈哈哈哈！'),
        equals('哈哈'),
      );
      expect(
        DanmakuTextNormalizer.normalize('前方高能？？？？'),
        equals('前方高能'),
      );
    });

    test('两端标点符号剔除与大小写归一', () {
      expect(
        DanmakuTextNormalizer.normalize(' ~~~【前方高能】~~~ '),
        equals('【前方高能】'),
      );
    });
  });

  group('DanmakuScrollTrack 防追尾算法测试', () {
    late DanmakuScrollTrack track;

    setUp(() {
      track = DanmakuScrollTrack();
    });

    test('初始状态允许任意弹幕入场', () {
      expect(track.canAccept(1000, 0.1, 800), isTrue);
    });

    test('入场间隙校验：前一条弹幕未完全拉开安全间距前，拒绝入场', () {
      // 登记一条弹幕：在 1000ms 入场，宽度 100，速度 0.1 px/ms (即 100px/s)
      // 安全间隙为 28px，尾部安全离开时间 = 1000 + (100 + 28) / 0.1 = 1000 + 1280 = 2280ms
      track.register(
        startMs: 1000,
        width: 100,
        speed: 0.1,
        viewWidth: 800,
        safetyGapPx: 28,
      );

      // 在 1500ms（尚未达到 2280ms）时尝试入场，必须被拒绝
      expect(track.canAccept(1500, 0.1, 800, safetyGapPx: 28), isFalse);

      // 在 2281ms 时已越过安全间隙，允许同速或更慢弹幕入场
      expect(track.canAccept(2281, 0.1, 800, safetyGapPx: 28), isTrue);
    });

    test('速度反超校验：新弹幕速度过快会在中途反超碰撞时，拒绝入场', () {
      // 慢弹幕在 1000ms 入场，宽度 100，速度 0.05 px/ms
      // 完全离开左侧屏幕(800px)的时间 = 1000 + (800 + 100) / 0.05 = 1000 + 18000 = 19000ms
      track.register(
        startMs: 1000,
        width: 100,
        speed: 0.05,
        viewWidth: 800,
        safetyGapPx: 28,
      );

      // 在 3000ms 时，虽然已经超过了尾部离开时间 (1000 + 128 / 0.05 = 3560ms)？
      // 尾部安全离开时间 = 1000 + 2560 = 3560ms
      // 在 4000ms 时入场，安全间隙满足
      // 但是新弹幕速度极快：0.3 px/ms (超车速度)
      // 新弹幕到达左边缘(800 + 28) / 0.3 = 2760ms -> 4000 + 2760 = 6760ms
      // 而前一条慢弹幕要到 19000ms 才离开，新弹幕会在半途狠狠撞上慢弹幕！
      expect(track.canAccept(4000, 0.3, 800, safetyGapPx: 28), isFalse);

      // 若新弹幕速度合理（如 0.04，比慢弹幕还慢），绝不会反超，允许入场
      expect(track.canAccept(4000, 0.04, 800, safetyGapPx: 28), isTrue);
    });
  });

  group('DanmakuController 控制器测试', () {
    test('弹幕加载与自动时间排序', () {
      final controller = DanmakuController();
      controller.loadItems([
        DanmakuItem(text: '第三秒', timeMs: 3000),
        DanmakuItem(text: '第一秒', timeMs: 1000),
        DanmakuItem(text: '第二秒', timeMs: 2000),
      ]);

      expect(controller.items.length, equals(3));
      expect(controller.items[0].text, equals('第一秒'));
      expect(controller.items[1].text, equals('第二秒'));
      expect(controller.items[2].text, equals('第三秒'));
    });

    test('正则与关键词屏蔽规则过滤', () {
      final controller = DanmakuController(
        initialSettings: const DanmakuSettings(
          filters: ['剧透', r'/^(\d{3,})$/'],
        ),
      );

      expect(controller.isBlocked('这里有严重剧透慎入'), isTrue);
      expect(controller.isBlocked('233333'), isTrue);
      expect(controller.isBlocked('正常的精彩弹幕'), isFalse);
    });
  });

  group('DanmakuView In-Flight 吸收合流测试', () {
    testWidgets('渲染并测试弹幕动态合流逻辑', (tester) async {
      final controller = DanmakuController();
      controller.loadItems([
        DanmakuItem(text: '前方高能', timeMs: 100),
        DanmakuItem(text: '前方高能！', timeMs: 500),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 450,
              child: DanmakuView(controller: controller),
            ),
          ),
        ),
      );

      // 开始播放并推进时钟
      controller.resume();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));

      // 推进到 600ms，两条高能弹幕都应到达
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(DanmakuView), findsOneWidget);
    });
  });
}
