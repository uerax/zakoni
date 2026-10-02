import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/bangumi_client.dart';
import '../core/providers/bangumi_providers.dart';
import '../core/utils/appearance_manager.dart';
import 'category/pages/category_page.dart';
import 'common/widgets/app_floating_bottom_bar.dart';
import 'home/pages/home_page.dart';
import 'settings/pages/settings_page.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  final BangumiClient? client;

  const MainNavigationShell({super.key, this.client});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  late final BangumiClient _client;
  int _currentIndex = 0;
  int _refreshKey = 0;
  String? _targetCategory;

  // 严格遵循工业级标准规范：记录已激活挂载的 Tab 集合（冷启动默认仅激活首页 Tab 0）
  // 未被点击过的 Tab 绝不挂载、绝不提前发起后台网络请求，首次点击后激活并常驻内存永久保活
  final Set<int> _activatedTabs = {0};

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? ref.read(bangumiClientProvider);
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
              // 2. 使用 IndexedStack 保活所有已激活的页面，切换导航栏时 0 延迟；切换线路时根据 _refreshKey 彻底重建
              IndexedStack(
                index: _currentIndex,
                children: [
                  HomePage(
                    key: ValueKey('home_$_refreshKey'),
                    client: _client,
                    onNavigateToCategory: (category) {
                      setState(() {
                        _activatedTabs.add(1);
                        _targetCategory = category;
                        _currentIndex = 1;
                      });
                    },
                  ),
                  _activatedTabs.contains(1)
                      ? CategoryPage(
                          key: ValueKey('category_${_refreshKey}_$_targetCategory'),
                          client: _client,
                          initialCategory: _targetCategory,
                        )
                      : const SizedBox.shrink(),
                  _activatedTabs.contains(2)
                      ? SettingsPage(
                          client: _client,
                          onSettingsChanged: () {
                            PaintingBinding.instance.imageCache.clear();
                            PaintingBinding.instance.imageCache.clearLiveImages();
                            setState(() {
                              _refreshKey++;
                            });
                          },
                        )
                      : const SizedBox.shrink(),
                ],
              ),
            ],
          ),
          bottomNavigationBar: AppFloatingBottomBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _activatedTabs.add(index);
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
