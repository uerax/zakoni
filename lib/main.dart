import 'package:flutter/material.dart';
import 'core/network/bangumi_client.dart';
import 'core/utils/font_manager.dart';
import 'core/utils/scroll_behavior.dart';
import 'features/main_navigation_shell.dart';

void main() {
  runApp(const ZakoniApp());
}

class ZakoniApp extends StatelessWidget {
  final BangumiClient? client;

  const ZakoniApp({super.key, this.client});

  @override
  Widget build(BuildContext context) {
    // 采用 Anibaka 经典高雅动漫海蓝作为全局主强调色
    const primaryColor = Color(0xFF0077B6);

    return ListenableBuilder(
      listenable: FontManager.instance,
      builder: (context, _) {
        final currentFont = FontManager.instance.activeFontFamily;

        return MaterialApp(
          title: 'Zakoni 动漫',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const AppScrollBehavior(),
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: currentFont,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryColor,
              primary: primaryColor,
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: currentFont,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryColor,
              primary: primaryColor,
              brightness: Brightness.dark,
            ),
          ),
          themeMode: ThemeMode.system,
          home: MainNavigationShell(client: client),
        );
      },
    );
  }
}
