import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakoni/features/player/controller/playback_controller.dart';
import 'package:zakoni/features/player/danmaku/danmaku.dart';
import 'package:zakoni/features/player/services/player_preferences_service.dart';
import 'package:zakoni/features/player/widgets/controls/danmaku_settings_icon.dart';
import 'package:zakoni/features/player/widgets/player_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerControls 底栏紧凑防溢出与自动连播测试', () {
    late ZakoniPlaybackController controller;
    late DanmakuController danmakuController;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      danmakuController = DanmakuController();
      controller = ZakoniPlaybackController(
        danmakuController: danmakuController,
      );
    });

    tearDown(() async {
      await controller.dispose();
      danmakuController.dispose();
    });

    testWidgets('1. 手机窄屏(360dp)下 1.25x 倍速且时长大于 1 小时，底栏不发生 RenderFlex 溢出',
        (tester) async {
      await controller.setPlaybackRate(1.25);
      controller.timeline.value = controller.timeline.value.copyWith(
        duration: const Duration(hours: 1, minutes: 15, seconds: 30),
        position: const Duration(minutes: 5, seconds: 20),
      );

      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 240,
              child: PlayerControls(
                controller: controller,
                title: '超长剧场版动画',
                danmakuController: danmakuController,
                isFullscreen: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      FlutterError.onError = oldHandler;
      expect(errors, isEmpty);

      // 验证控制栏呈现自绘弹幕图标与 1.25x 按钮
      expect(find.byType(DanmakuSettingsIcon), findsOneWidget);
      expect(find.text('1.25x'), findsOneWidget);

      // 验证时间戳正确按时分秒格式渲染
      expect(find.text('00:05:20 / 01:15:30'), findsOneWidget);

      // 验证上一集和下一集按钮已从控制栏移除
      expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
      expect(find.byIcon(Icons.skip_next_rounded), findsNothing);
    });

    testWidgets('2. 播放器设置面板中支持开关「自动播放下一集」并持久化', (tester) async {
      await PlayerPreferencesService.instance.initialize();
      final autoPlayNotifier = ValueNotifier<bool>(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 450,
              child: PlayerControls(
                controller: controller,
                autoPlayNextNotifier: autoPlayNotifier,
                isFullscreen: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 打开播放设置
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // 验证「自动播放下一集」开关存在且初始为 true
      expect(find.text('自动播放下一集'), findsOneWidget);
      expect(autoPlayNotifier.value, isTrue);

      // 切换开关
      await tester.tap(find.text('自动播放下一集'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(autoPlayNotifier.value, isFalse);
      expect(PlayerPreferencesService.instance.autoPlayNext, isFalse);

      // 再次切换回开启
      await tester.tap(find.text('自动播放下一集'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(autoPlayNotifier.value, isTrue);
      expect(PlayerPreferencesService.instance.autoPlayNext, isTrue);

      autoPlayNotifier.dispose();
    });
  });
}
