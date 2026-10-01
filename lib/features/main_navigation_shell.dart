import 'package:flutter/material.dart';
import '../core/network/bangumi_client.dart';
import 'common/widgets/app_floating_bottom_bar.dart';
import 'home/pages/home_page.dart';
import 'settings/pages/settings_page.dart';
import 'timeline/pages/timeline_page.dart';

class MainNavigationShell extends StatefulWidget {
  final BangumiClient? client;

  const MainNavigationShell({super.key, this.client});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late final BangumiClient _client;
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? BangumiClient();
    _pages = [
      HomePage(client: _client),
      TimelinePage(client: _client),
      SettingsPage(
        client: _client,
        onSettingsChanged: () {
          setState(() {});
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 允许页面内容向下穿透延展到底部，透过苹果风格悬浮毛玻璃胶囊呈现动态磨砂质感
      extendBody: true,
      // 使用 IndexedStack 保活所有主要页面，切换导航栏时 0 延迟，且完整保留各自的滚动位置
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: AppFloatingBottomBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          AppFloatingNavItem(
            unselectedIcon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: '首页',
          ),
          AppFloatingNavItem(
            unselectedIcon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month_rounded,
            label: '时间表',
          ),
          AppFloatingNavItem(
            unselectedIcon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            label: '设置',
          ),
        ],
      ),
    );
  }
}
