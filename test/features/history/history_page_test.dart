import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakoni/core/services/app_preferences.dart';
import 'package:zakoni/features/history/pages/history_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.init();
  });

  group('HistoryPage widget tests', () {
    testWidgets('Renders stats bar, time groups, and history cards with video sources', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryPage(),
        ),
      );
      await tester.pumpAndSettle();

      // 顶部标题
      expect(find.text('播放历史'), findsOneWidget);

      // 统计指标胶囊栏
      expect(find.text('在追番剧'), findsOneWidget);
      expect(find.text('今日观看'), findsOneWidget);
      expect(find.text('累计观看'), findsOneWidget);
      expect(find.text('3 部'), findsOneWidget); // 在追 3 部
      expect(find.text('2 部'), findsOneWidget); // 今日观看 2 部

      // 历史记录卡片与视频源
      expect(find.text('葬送的芙莉莲'), findsOneWidget);
      expect(find.text('cycani'), findsOneWidget);
      expect(find.text('第 14 话'), findsOneWidget);

      expect(find.text('迷宫饭'), findsOneWidget);
      expect(find.text('anime1'), findsOneWidget);
      expect(find.text('第 8 话'), findsOneWidget);

      expect(find.text('间谍过家家 第二季'), findsOneWidget);
      expect(find.text('omofun'), findsOneWidget);
      expect(find.text('第 4 话'), findsOneWidget);
    });

    testWidgets('Supports clearing all records through dialog', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryPage(),
        ),
      );
      await tester.pumpAndSettle();

      // 点击右上角清空图标
      await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
      await tester.pumpAndSettle();

      // 弹出确认弹窗
      expect(find.text('清空播放历史'), findsOneWidget);
      expect(find.text('确定要清空全部播放历史记录吗？此操作不可撤销。'), findsOneWidget);

      // 点击确认清空
      await tester.tap(find.text('确认清空'));
      await tester.pumpAndSettle();

      // 展示空状态
      expect(find.text('暂无播放历史'), findsOneWidget);
      expect(find.text('快去挑选喜欢的动画开始追番吧'), findsOneWidget);
      expect(find.byIcon(Icons.history_toggle_off_rounded), findsOneWidget);
    });
  });
}
