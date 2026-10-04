import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/bangumi_client.dart';
import 'core/providers/bangumi_providers.dart';
import 'core/services/app_preferences.dart';
import 'core/services/watch_history_service.dart';
import 'core/utils/font_manager.dart';
import 'core/utils/scroll_behavior.dart';
import 'features/main_navigation_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化并恢复本地持久化配置（网络线路、字体、壁纸等）
  await AppPreferences.init();
  await WatchHistoryService.instance.getHistory();

  // 2. 依据运行平台动态调优 Flutter 全局 ImageCache 显存水线与图片缓存数量：
  // 移动端：100MB / 200 张，保障滑动流畅并防止显存溢出；
  // 桌面端：200MB / 400 张，适配大屏高分辨显示器，回滑零二次解码。
  final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  PaintingBinding.instance.imageCache.maximumSize = isDesktop ? 400 : 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = isDesktop
      ? 200 * 1024 * 1024
      : 100 * 1024 * 1024;

  runApp(const ZakoniApp());
}

class ZakoniApp extends StatelessWidget {
  final BangumiClient? client;

  const ZakoniApp({super.key, this.client});

  @override
  Widget build(BuildContext context) {
    // 采用 Anibaka 经典高雅动漫海蓝作为全局主强调色
    const primaryColor = Color(0xFF0077B6);

    return ProviderScope(
      overrides: [
        if (client != null) bangumiClientProvider.overrideWithValue(client!),
      ],
      child: ListenableBuilder(
        listenable: FontManager.instance,
        builder: (context, _) {
        final currentFont = FontManager.instance.activeFontFamily;
        final fontFallback = FontManager.fallbackFontFamilies;

        final cupertinoTextTheme = CupertinoTextThemeData(
          textStyle: TextStyle(
            fontFamily: currentFont,
            fontFamilyFallback: fontFallback,
          ),
          actionTextStyle: TextStyle(
            fontFamily: currentFont,
            fontFamilyFallback: fontFallback,
          ),
          tabLabelTextStyle: TextStyle(
            fontFamily: currentFont,
            fontFamilyFallback: fontFallback,
          ),
          navTitleTextStyle: TextStyle(
            fontFamily: currentFont,
            fontFamilyFallback: fontFallback,
          ),
          navLargeTitleTextStyle: TextStyle(
            fontFamily: currentFont,
            fontFamilyFallback: fontFallback,
          ),
          pickerTextStyle: TextStyle(
            fontFamily: currentFont,
            fontFamilyFallback: fontFallback,
          ),
          dateTimePickerTextStyle: TextStyle(
            fontFamily: currentFont,
            fontFamilyFallback: fontFallback,
          ),
        );

        return MaterialApp(
          title: 'Zakoni 动漫',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const AppScrollBehavior(),
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: currentFont,
            fontFamilyFallback: fontFallback,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryColor,
              primary: primaryColor,
              brightness: Brightness.light,
            ),
            cupertinoOverrideTheme: CupertinoThemeData(
              primaryColor: primaryColor,
              brightness: Brightness.light,
              textTheme: cupertinoTextTheme,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: currentFont,
            fontFamilyFallback: fontFallback,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryColor,
              primary: primaryColor,
              brightness: Brightness.dark,
            ),
            cupertinoOverrideTheme: CupertinoThemeData(
              primaryColor: primaryColor,
              brightness: Brightness.dark,
              textTheme: cupertinoTextTheme,
            ),
          ),
          themeMode: ThemeMode.system,
          home: MainNavigationShell(client: client),
        );
      },
    ),
  );
}
}
