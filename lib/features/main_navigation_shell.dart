import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/bangumi_client.dart';
import '../core/providers/bangumi_providers.dart';
import '../core/utils/appearance_manager.dart';
import 'category/pages/category_page.dart';
import 'common/widgets/app_floating_bottom_bar.dart';
import 'common/widgets/nav_custom_icons.dart';
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
  late final PageController _pageController;
  int _currentIndex = 0;
  int _refreshKey = 0;
  String? _targetCategory;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? ref.read(bangumiClientProvider);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
              // 2. 现代 App 高性能水平平移滑动转场架构（诉求 2）：
              // - 禁用手势拖拽（NeverScrollableScrollPhysics），彻底切断与内部货架列表的手势竞技场冲突；
              // - 每个页面独立包裹 RepaintBoundary，滑动时由 GPU 显存纹理直接位移合成，0 冗余重绘；
              // - 新页面若在加载中，秒级先呈现高性能单通道流光骨架屏，网络后台异步拉取，彻底告别全员卡顿；
              // - 点击底栏时以 280ms Curves.easeOutCubic 呈现正统且平滑的横向水平滑入滑出。
              PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  RepaintBoundary(
                    child: HomePage(
                      key: ValueKey('home_$_refreshKey'),
                      client: _client,
                      onNavigateToCategory: (category) {
                        setState(() {
                          _targetCategory = category;
                          _currentIndex = 1;
                        });
                        _pageController.animateToPage(
                          1,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    ),
                  ),
                  RepaintBoundary(
                    child: CategoryPage(
                      key: ValueKey('category_${_refreshKey}_$_targetCategory'),
                      client: _client,
                      initialCategory: _targetCategory,
                    ),
                  ),
                  RepaintBoundary(
                    child: SettingsPage(
                      client: _client,
                      onSettingsChanged: () {
                        PaintingBinding.instance.imageCache.clear();
                        PaintingBinding.instance.imageCache.clearLiveImages();
                        setState(() {
                          _refreshKey++;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: AppFloatingBottomBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              if (_currentIndex == index) return;
              setState(() {
                _currentIndex = index;
              });
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
              );
            },
            items: [
              // Tab 0: 首页 (专属吉祥物：Q 弹果冻)
              AppFloatingNavItem(
                builder: (context, color, isSelected) => JellyNavIcon(
                  color: color,
                  isSelected: isSelected,
                ),
              ),
              // Tab 1: 分类索引 (萌系企鹅剪影)
              AppFloatingNavItem(
                builder: (context, color, isSelected) => PenguinNavIcon(
                  color: color,
                  isSelected: isSelected,
                ),
              ),
              // Tab 2: 系统设置 (保持原状)
              const AppFloatingNavItem(
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
