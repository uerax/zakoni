import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/features/player/controller/playback_controller.dart';
import 'package:zakoni/features/player/danmaku/danmaku.dart';
import 'package:zakoni/features/player/widgets/player_controls.dart';
import 'package:zakoni/features/player/widgets/player_indicators.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerControls 现代交互与控制增强测试', () {
    late ZakoniPlaybackController controller;
    late DanmakuController danmakuController;

    setUp(() {
      danmakuController = DanmakuController();
      controller = ZakoniPlaybackController(
        danmakuController: danmakuController,
      );
    });

    tearDown(() async {
      await controller.dispose();
      danmakuController.dispose();
    });

    testWidgets('1. 基础 UI 元素完整呈现（快进快退10s、播放暂停、倍速、锁屏、选集）', (tester) async {
      bool fullscreenToggled = false;
      bool episodePickerOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 450,
              child: PlayerControls(
                controller: controller,
                title: '测试动画第01话',
                danmakuController: danmakuController,
                isFullscreen: true,
                onToggleFullscreen: () => fullscreenToggled = true,
                onOpenEpisodePicker: () => episodePickerOpened = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证标题呈现
      expect(find.text('测试动画第01话'), findsOneWidget);

      // 验证快退 10 秒与快进 10 秒图标
      expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);
      expect(find.byIcon(Icons.forward_10_rounded), findsOneWidget);

      // 验证存在播放按钮
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // 验证倍速按钮存在
      expect(find.text('1.0x'), findsOneWidget);

      // 验证选集按钮存在
      expect(find.text('选集'), findsOneWidget);

      // 验证存在屏幕锁定浮动按钮
      expect(find.byType(PlayerLockFloatingButton), findsOneWidget);
      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);

      // 点击选集按钮
      await tester.tap(find.text('选集'));
      await tester.pumpAndSettle();
      expect(episodePickerOpened, isTrue);

      // 点击全屏按钮
      expect(find.byIcon(Icons.fullscreen_exit_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
      await tester.pumpAndSettle();
      expect(fullscreenToggled, isTrue);
    });

    testWidgets('2. 屏幕锁定交互测试（锁定后隐藏控制栏并屏蔽手势，解锁恢复）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 450,
              child: PlayerControls(
                controller: controller,
                title: '锁屏测试',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点击屏幕锁按钮
      await tester.tap(find.byType(PlayerLockFloatingButton));
      await tester.pumpAndSettle();

      // 此时变为已锁定图标
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      // 控制栏顶部与底部应被隐藏/忽略指针交互
      final topText = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.text('锁屏测试'),
          matching: find.byType(AnimatedOpacity),
        ).first,
      );
      expect(topText.opacity, equals(0.0));

      // 再次点击解锁
      await tester.tap(find.byType(PlayerLockFloatingButton));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);
      final unlockedTopText = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.text('锁屏测试'),
          matching: find.byType(AnimatedOpacity),
        ).first,
      );
      expect(unlockedTopText.opacity, equals(1.0));
    });

    testWidgets('3. 桌面端键盘快捷键测试（Space 切换播放/暂停，ArrowLeft/Right 快退快进，M 静音）',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 450,
              child: PlayerControls(
                controller: controller,
                title: '快捷键测试',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.core.value.playing, isFalse);

      // 按空格键 -> 切换播放
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(controller.core.value.playing, isTrue);

      // 再次按空格键 -> 暂停
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(controller.core.value.playing, isFalse);

      // 按 M 键 -> 静音切换
      expect(controller.core.value.muted, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pumpAndSettle();
      expect(controller.core.value.muted, isTrue);

      // 再次按 M 键 -> 恢复声音
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pumpAndSettle();
      expect(controller.core.value.muted, isFalse);
    });

    testWidgets('4. HUD 指示器独立渲染与外观测试', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const PlayerVerticalLevelIndicator(
                  value: 0.75,
                  isBrightness: true,
                  visible: true,
                ),
                PlayerSeekPreviewIndicator(
                  visible: true,
                  targetPosition: const Duration(minutes: 5, seconds: 20),
                  totalDuration: const Duration(minutes: 24, seconds: 10),
                  deltaSeconds: 30,
                ),
                const PlayerSpeedHoldIndicator(
                  visible: true,
                  speed: 2.0,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证亮度百分比
      expect(find.text('75%'), findsOneWidget);
      // 验证 Seek 目标时间与增量
      expect(find.text('+30s'), findsOneWidget);
      expect(find.text('05:20'), findsOneWidget);
      // 验证倍速提示
      expect(find.text('2.0x 极速播放中'), findsOneWidget);
    });
  });
}
