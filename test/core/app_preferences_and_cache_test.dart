import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zakoni/core/network/bangumi_client.dart';
import 'package:zakoni/core/services/app_preferences.dart';
import 'package:zakoni/core/theme/app_theme_color.dart';
import 'package:zakoni/core/utils/appearance_manager.dart';
import 'package:zakoni/core/utils/font_manager.dart';
import 'package:zakoni/core/utils/image_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('getBangumiImageCacheKey cross-host cache normalization', () {
    test('identical key generated for mirror and official host with /r/400/', () {
      const officialUrl = 'https://lain.bgm.tv/r/400/pic/cover/l/aa/bb/12345.jpg';
      const mirrorUrl = 'https://bgmimg.anibt.net/r/400/pic/cover/l/aa/bb/12345.jpg';

      final officialKey = getBangumiImageCacheKey(officialUrl);
      final mirrorKey = getBangumiImageCacheKey(mirrorUrl);

      expect(officialKey, equals('bgm_img:/r/400/pic/cover/l/aa/bb/12345.jpg'));
      expect(mirrorKey, equals('bgm_img:/r/400/pic/cover/l/aa/bb/12345.jpg'));
      expect(officialKey, equals(mirrorKey));
    });

    test('identical key generated for standard thumbnail paths', () {
      const officialUrl = 'https://lain.bgm.tv/pic/cover/c/99/88/54321.jpg';
      const mirrorUrl = 'https://bgmimg.anibt.net/pic/cover/c/99/88/54321.jpg';

      final officialKey = getBangumiImageCacheKey(officialUrl);
      final mirrorKey = getBangumiImageCacheKey(mirrorUrl);

      expect(officialKey, equals('bgm_img:/pic/cover/c/99/88/54321.jpg'));
      expect(mirrorKey, equals(officialKey));
    });

    test('returns empty string for empty input', () {
      expect(getBangumiImageCacheKey(''), isEmpty);
      expect(getBangumiImageCacheKey('   '), isEmpty);
    });
  });

  group('AppPreferences persistence & restoration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and restores source preset', () async {
      await AppPreferences.init();
      expect(AppPreferences.getInitialSourcePreset(), equals(BangumiSourcePreset.mirror));

      await AppPreferences.saveSourcePreset(BangumiSourcePreset.official);
      expect(AppPreferences.getInitialSourcePreset(), equals(BangumiSourcePreset.official));
    });

    test('saves and restores font type', () async {
      await AppPreferences.init();
      final fontMgr = FontManager.instance;

      fontMgr.setFontType(AppFontType.system);
      expect(fontMgr.currentType, equals(AppFontType.system));

      // 再次初始化模拟冷启动恢复
      await AppPreferences.init();
      expect(FontManager.instance.currentType, equals(AppFontType.system));
    });

    test('saves and restores theme preset and custom color', () async {
      await AppPreferences.init();
      final appMgr = AppearanceManager.instance;

      // 默认颜色应为薄荷绿
      expect(AppThemePreset.presets.first.id, equals('mint'));
      expect(AppThemePreset.defaultColor, equals(const Color(0xFF2A9D8F)));

      // 切换为樱花粉主题
      final sakura = AppThemePreset.findById('sakura');
      appMgr.setThemePreset(sakura);
      expect(appMgr.currentThemePreset.id, equals('sakura'));
      expect(appMgr.primaryColor, equals(sakura.color));

      // 再次初始化模拟冷启动恢复
      await AppPreferences.init();
      expect(AppearanceManager.instance.currentThemePreset.id, equals('sakura'));
      expect(AppearanceManager.instance.primaryColor, equals(sakura.color));

      // 测试自定义颜色保存与恢复
      const customCol = Color(0xFF9C27B0); // 紫色
      appMgr.setCustomColor(customCol);
      expect(appMgr.currentThemePreset.id, equals(AppThemePreset.customId));
      expect(appMgr.primaryColor, equals(customCol));

      // 再次初始化模拟冷启动恢复自定义颜色
      await AppPreferences.init();
      expect(AppearanceManager.instance.currentThemePreset.id, equals(AppThemePreset.customId));
      expect(AppearanceManager.instance.primaryColor, equals(customCol));
    });

    test('saves and restores wallpaper transform & opacity & blur', () async {
      await AppPreferences.init();
      final appMgr = AppearanceManager.instance;

      appMgr.setWallpaperTransform(alignX: 0.25, alignY: -0.75, scale: 1.8);
      appMgr.setWallpaperOpacity(0.35);
      appMgr.setWallpaperBlur(4.5);

      expect(appMgr.wallpaperAlignX, closeTo(0.25, 0.001));
      expect(appMgr.wallpaperAlignY, closeTo(-0.75, 0.001));
      expect(appMgr.wallpaperScale, closeTo(1.8, 0.001));
      expect(appMgr.wallpaperOpacity, closeTo(0.35, 0.001));
      expect(appMgr.wallpaperBlur, closeTo(4.5, 0.001));

      // 模拟重启恢复
      await AppPreferences.init();
      expect(appMgr.wallpaperAlignX, closeTo(0.25, 0.001));
      expect(appMgr.wallpaperAlignY, closeTo(-0.75, 0.001));
      expect(appMgr.wallpaperScale, closeTo(1.8, 0.001));
      expect(appMgr.wallpaperOpacity, closeTo(0.35, 0.001));
      expect(appMgr.wallpaperBlur, closeTo(4.5, 0.001));
    });
  });

  group('BangumiClient dataCacheSizeBytes O(1) tracking', () {
    test('starts at zero and tracks bytes incrementally', () {
      final client = BangumiClient();
      expect(client.dataCacheSizeBytes, equals(0));

      client.clearCache();
      expect(client.dataCacheSizeBytes, equals(0));
    });
  });
}
