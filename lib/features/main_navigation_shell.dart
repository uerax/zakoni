import 'package:flutter/material.dart';
import '../core/network/bangumi_client.dart';
import '../core/utils/appearance_manager.dart';
import 'category/pages/category_page.dart';
import 'common/widgets/app_floating_bottom_bar.dart';
import 'home/pages/home_page.dart';
import 'settings/pages/settings_page.dart';

class MainNavigationShell extends StatefulWidget {
  final BangumiClient? client;

  const MainNavigationShell({super.key, this.client});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late final BangumiClient _client;
  int _currentIndex = 0;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? BangumiClient();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pageKey = switch (_currentIndex) {
      0 => 'home',
      1 => 'category',
      2 => 'settings',
      _ => 'home',
    };

    return ListenableBuilder(
      listenable: AppearanceManager.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          // 允许页面内容向下穿透延展到底部，透过苹果风格悬浮毛玻璃胶囊呈现动态磨砂质感
          extendBody: true,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 0. 基础底衬颜色（深浅主题自动适配）
              Positioned.fill(
                child: ColoredBox(color: theme.scaffoldBackgroundColor),
              ),
              // 1. 全局或页面专属自定义背景壁纸（支持各页面单独覆盖与视窗裁剪）
              AppearanceManager.instance.buildWallpaperLayer(pageKey: pageKey),
              // 2. 使用 IndexedStack 保活所有主要页面，切换导航栏时 0 延迟；切换线路时根据 _refreshKey 彻底重建
              IndexedStack(
                index: _currentIndex,
                children: [
                  HomePage(
                    key: ValueKey('home_$_refreshKey'),
                    client: _client,
                    onNavigateToCategory: (category) {
                      setState(() {
                        _currentIndex = 1;
                      });
                    },
                  ),
                  CategoryPage(
                    key: ValueKey('category_$_refreshKey'),
                    client: _client,
                  ),
                  SettingsPage(
                    client: _client,
                    onSettingsChanged: () {
                      PaintingBinding.instance.imageCache.clear();
                      PaintingBinding.instance.imageCache.clearLiveImages();
                      setState(() {
                        _refreshKey++;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: AppFloatingBottomBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: const [
              // Tab 0: 首页 (番剧大厅 + 连载周历)
              AppFloatingNavItem(
                unselectedIcon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
              ),
              // Tab 1: 分类索引 (四宫格矩阵，苹果/现代流媒体官方规范)
              AppFloatingNavItem(
                unselectedIcon: Icons.grid_view_outlined,
                selectedIcon: Icons.grid_view_rounded,
              ),
              // Tab 2: 系统设置
              AppFloatingNavItem(
                unselectedIcon: Icons.settings_outlined,
                selectedIcon: Icons.settings_rounded,
              ),
            ],
          ),
        );
      },
    );
  }
}
