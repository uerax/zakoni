import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakoni/core/services/app_preferences.dart';
import 'package:zakoni/core/utils/appearance_manager.dart';
import 'package:zakoni/features/settings/widgets/wallpaper_settings_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences.init();
    final appMgr = AppearanceManager.instance;
    appMgr.clearWallpaper(pageKey: 'all');
    appMgr.clearWallpaper(pageKey: 'home');
    appMgr.clearWallpaper(pageKey: 'category');
    appMgr.clearWallpaper(pageKey: 'settings');
    appMgr.setWallpaperOpacity(0.18);
    appMgr.setWallpaperBlur(1.0);
  });

  group('WallpaperSettingsTile scope and adjustment controls tests', () {
    testWidgets('shows only all, home, category in scope selector, without settings button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WallpaperSettingsTile(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('全部应用'), findsOneWidget);
      expect(find.text('首页'), findsOneWidget);
      expect(find.text('分类'), findsOneWidget);
      // '设置' 作用域按钮已被移除
      expect(find.text('设置'), findsNothing);
    });

    testWidgets('controls (crop, clear, sliders) are hidden when no wallpaper uploaded for current scope', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WallpaperSettingsTile(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('调整画面取景'), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(find.text('不透明度'), findsNothing);
      expect(find.text('高斯模糊'), findsNothing);
    });

    testWidgets('controls appear when wallpaper uploaded and update reactively during slider drag', (tester) async {
      final appMgr = AppearanceManager.instance;
      // 模拟全局上传了壁纸
      appMgr.setWallpaperPath('dummy/wallpaper.png', pageKey: 'all');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WallpaperSettingsTile(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 上传了图片后，取景、清除、不透明度、高斯模糊全部展示
      expect(find.text('调整画面取景'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      expect(find.text('不透明度'), findsOneWidget);
      expect(find.text('18%'), findsOneWidget);
      expect(find.text('高斯模糊'), findsOneWidget);
      expect(find.text('1.0 px'), findsOneWidget);

      // 验证拖动条存在两个 Slider
      final sliders = find.byType(Slider);
      expect(sliders, findsNWidgets(2));

      // 拖动不透明度 Slider
      final opacitySlider = sliders.first;
      await tester.drag(opacitySlider, const Offset(60, 0));
      await tester.pumpAndSettle();

      // 验证反应灵敏，数值与管理状态已更新
      expect(appMgr.wallpaperOpacity, greaterThan(0.18));
      expect(find.text('${(appMgr.wallpaperOpacity * 100).toInt()}%'), findsOneWidget);

      // 拖动高斯模糊 Slider
      final blurSlider = sliders.last;
      await tester.drag(blurSlider, const Offset(60, 0));
      await tester.pumpAndSettle();

      expect(appMgr.wallpaperBlur, greaterThan(1.0));
      expect(find.text('${appMgr.wallpaperBlur.toStringAsFixed(1)} px'), findsOneWidget);
    });
  });
}
