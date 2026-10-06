import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/features/player/widgets/video_player_layouts.dart';

void main() {
  group('VideoPlayerDesktopLayout 桌面端黄金比例布局测试', () {
    testWidgets('1920x1080 桌面端右侧栏锁定为 420px，左侧播放器分得 1500px 剩余空间', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const keyPlayer = Key('player_widget');
      const keyTab = Key('tab_section');

      await tester.pumpWidget(
        MaterialApp(
          home: VideoPlayerDesktopLayout(
            title: '测试桌面布局',
            onBackPressed: () {},
            playerWidget: const SizedBox(key: keyPlayer),
            tabSection: const SizedBox(key: keyTab),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tabBox = tester.getRect(find.byKey(keyTab));
      expect(tabBox.width, equals(420.0));

      // 验证左侧可用空间为 1920 - 420 = 1500
      // 内部播放器包含 16px padding，可用宽为 1500 - 32 = 1468
      // 1080 高度减去 AppBar (56) 与 padding (32) 剩余 992，1468 / (16/9) = 825.75 <= 992
      final playerBox = tester.getRect(find.byKey(keyPlayer));
      expect(playerBox.width, closeTo(1468.0, 1.0));
      expect(playerBox.height, closeTo(1468.0 / (16 / 9), 1.0));
      // 验证播放器紧贴顶部 padding (AppBar 高度 56 + padding 16 = 72)，绝非垂直居中
      expect(playerBox.top, equals(72.0));
    });

    testWidgets('1000x800 中等窗口下右侧栏触发 360px 保底下限', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const keyPlayer = Key('player_widget');
      const keyTab = Key('tab_section');

      await tester.pumpWidget(
        MaterialApp(
          home: VideoPlayerDesktopLayout(
            title: '测试桌面布局',
            onBackPressed: () {},
            playerWidget: const SizedBox(key: keyPlayer),
            tabSection: const SizedBox(key: keyTab),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tabBox = tester.getRect(find.byKey(keyTab));
      expect(tabBox.width, equals(360.0)); // 1000 * 0.23 = 230 < 360 -> clamped to 360
    });

    testWidgets('矮窗口 (1920x600) 下播放器按 16:9 Contain 自适应高度，绝对不产生溢出', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const keyPlayer = Key('player_widget');
      const keyTab = Key('tab_section');

      await tester.pumpWidget(
        MaterialApp(
          home: VideoPlayerDesktopLayout(
            title: '测试桌面布局',
            onBackPressed: () {},
            playerWidget: const SizedBox(key: keyPlayer),
            tabSection: const SizedBox(key: keyTab),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final playerBox = tester.getRect(find.byKey(keyPlayer));
      // 可用高度受限：高度小于宽度撑满时的 16:9
      expect(playerBox.height, lessThanOrEqualTo(600.0));
      expect(playerBox.width / playerBox.height, closeTo(16 / 9, 0.05));
    });
  });
}
