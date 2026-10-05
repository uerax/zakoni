import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/features/player/controller/playback_controller.dart';
import 'package:zakoni/features/player/danmaku/danmaku.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZakoniPlaybackController 状态与控制测试', () {
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

    test('初始状态值校验', () {
      final core = controller.core.value;
      final timeline = controller.timeline.value;

      expect(core.playing, isFalse);
      expect(core.loading, isTrue);
      expect(core.buffering, isFalse);
      expect(core.playbackRate, equals(1.0));
      expect(core.volume, equals(1.0));
      expect(core.muted, isFalse);

      expect(timeline.position, equals(Duration.zero));
      expect(timeline.duration, equals(Duration.zero));
      expect(timeline.previewPosition, isNull);
    });

    test('拖拽 Seek 预览状态流转测试', () async {
      expect(controller.timeline.value.isSeekingPreview, isFalse);

      // 用户拖动滑块至 30 秒处
      controller.updateSeekPreview(const Duration(seconds: 30));

      expect(controller.timeline.value.isSeekingPreview, isTrue);
      expect(
        controller.timeline.value.displayPosition,
        equals(const Duration(seconds: 30)),
      );

      // 松开滑块，预览位置被重置，真实 position 被更新
      await controller.endSeekPreview();
      expect(controller.timeline.value.isSeekingPreview, isFalse);
      expect(
        controller.timeline.value.position,
        equals(const Duration(seconds: 30)),
      );
    });

    test('音量调整与静音切换测试', () async {
      expect(controller.core.value.muted, isFalse);
      expect(controller.core.value.volume, equals(1.0));

      // 设置音量为 50%
      await controller.setVolume(0.5);
      expect(controller.core.value.volume, equals(0.5));
      expect(controller.core.value.muted, isFalse);

      // 切换静音
      await controller.toggleMute();
      expect(controller.core.value.muted, isTrue);
      expect(controller.core.value.volume, equals(0.0));

      // 取消静音，恢复之前的 50% 音量
      await controller.toggleMute();
      expect(controller.core.value.muted, isFalse);
      expect(controller.core.value.volume, equals(0.5));
    });

    test('Seek 操作主动清除偶发错误状态', () async {
      // 模拟先前产生的偶发错误
      controller.core.value = controller.core.value.copyWith(
        errorMessage: 'Some transient network error',
      );
      expect(controller.core.value.hasError, isTrue);

      // 用户触发 Seek
      await controller.seek(const Duration(seconds: 45));

      // 验证错误已被清除
      expect(controller.core.value.hasError, isFalse);
      expect(controller.core.value.errorMessage, isNull);
    });

    test('自适应分级网络状态字段与拷贝流转测试', () {
      expect(controller.core.value.isMeteredNetwork, isFalse);

      controller.core.value = controller.core.value.copyWith(
        isMeteredNetwork: true,
      );
      expect(controller.core.value.isMeteredNetwork, isTrue);

      controller.core.value = controller.core.value.copyWith(
        isMeteredNetwork: false,
      );
      expect(controller.core.value.isMeteredNetwork, isFalse);
    });
  });
}
