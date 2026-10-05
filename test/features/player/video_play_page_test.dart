import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakoni/features/player/pages/video_play_page.dart';
import 'package:zakoni/features/player/widgets/episode_picker_section.dart';
import 'package:zakoni/features/player/widgets/video_source_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoPlayPage 功能与交互设计测试', () {
    testWidgets('1. 点开番剧不默认播放第一集，展示占位引导', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VideoPlayPage(
            title: '测试动画',
            episodeCount: 12,
            currentEpisode: null, // 未起播
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证未起播提示条存在
      expect(find.text('分集已就绪 · 请在下方选择集数开始播放'), findsOneWidget);
      // 验证存在中央大播放按钮
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('2. 页面包含 3 个 Tab，且默认聚焦第 3 个「选集」Tab', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VideoPlayPage(
            title: '测试动画',
            episodeCount: 12,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证存在 3 个 Tab
      expect(find.widgetWithText(Tab, '番剧详情'), findsOneWidget);
      expect(find.widgetWithText(Tab, '视频源'), findsOneWidget);
      expect(find.widgetWithText(Tab, '选集'), findsOneWidget);

      // 验证默认显示的是 EpisodePickerSection（选集）
      expect(find.byType(EpisodePickerSection), findsOneWidget);
    });

    testWidgets('3. 选集组件支持正序/倒序切换', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodePickerSection(
              episodeCount: 5,
              onSelectEpisode: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 默认正序
      expect(find.text('正序'), findsOneWidget);
      expect(find.text('第 1 话'), findsOneWidget);
      expect(find.text('第 5 话'), findsOneWidget);

      // 点击切换为倒序
      await tester.tap(find.text('正序'));
      await tester.pumpAndSettle();

      expect(find.text('倒序'), findsOneWidget);
    });

    testWidgets('4. 优化点 1 验证：未探活的非绿色源点击后绝不跳转选集 Tab', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VideoPlayPage(
            title: '测试动画',
            episodeCount: 12,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 切换到「视频源」Tab
      await tester.tap(find.text('视频源'));
      await tester.pumpAndSettle();

      expect(find.byType(VideoSourceView), findsOneWidget);
      expect(find.text('girigiri'), findsOneWidget);

      // 点击处于待探活状态的girigiri
      await tester.tap(find.text('girigiri'));
      await tester.pumpAndSettle();

      // 严格验证：绝不跳转选集 Tab，仍然保持在视频源看板！
      expect(find.byType(VideoSourceView), findsOneWidget);
      expect(find.byType(EpisodePickerSection), findsNothing);
    });
  });
}
