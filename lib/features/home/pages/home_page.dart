import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/models/bangumi/bangumi_calendar.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import '../../../core/network/bangumi_client.dart';
import '../../../core/utils/responsive.dart';
import '../../common/widgets/anime_card.dart';
import '../../common/widgets/shimmer_loading.dart';
import '../../search/pages/search_page.dart';
import '../widgets/home_banner_carousel.dart';
import '../widgets/home_desktop_hero.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/rank_horizontal_section.dart';
import '../widgets/today_anime_shelf.dart';

class HomePage extends StatefulWidget {
  final BangumiClient client;
  final ValueChanged<String>? onNavigateToCategory;

  const HomePage({
    super.key,
    required this.client,
    this.onNavigateToCategory,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  // 业务配置：精选探索模块预留开关（后续完善后可直接切为 true 开启）
  static const bool _showExploreSection = false;

  late Future<({
    List<BangumiItem> today,
    String weekdayName,
    List<BangumiItem> tv,
    List<BangumiItem> movies,
    List<BangumiItem> ova,
  })> _dataFuture;

  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);
  bool _isTopBarVisible = true;
  double _downScrollAccumulator = 0.0;
  double _upScrollAccumulator = 0.0;

  // 保证页面切走后状态保活不被销毁，切回 0ms 瞬间呈现，不重复请求网络
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollOffsetNotifier.dispose();
    super.dispose();
  }

  void _loadData({bool forceRefresh = false}) {
    setState(() {
      _dataFuture = _fetchHomeData(forceRefresh: forceRefresh);
    });
  }

  void _onShelfViewAllTap(String category) {
    // 点击“浏览全部”快捷入口：通知外层主壳切换到底栏“分类”标签页并定位分类
    if (widget.onNavigateToCategory != null) {
      widget.onNavigateToCategory!(category);
    }
  }

  void _navigateToSearch([String? query]) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => SearchPage(initialQuery: query),
      ),
    );
  }

  /// 货架响应式对齐容器：
  /// 特殊处理说明：
  /// 1. 桌面/宽屏端（>= 840dp）：通过 Center + ConstrainedBox(maxWidth: 1200) 与顶栏和 Hero 区域基线严格垂直对齐，两边优雅留白；
  /// 2. 手机与平板竖屏（< 840dp）：直接返回原货架组件，保持 100% 贴边无阻碍全宽滑动流与边缘露头（Peek）手势引导，零视觉副作用。
  Widget _buildResponsiveShelf(Widget shelf) {
    if (context.isDesktop) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppBreakpoints.maxContentWidth),
          child: shelf,
        ),
      );
    }
    return shelf;
  }

  Future<({
    List<BangumiItem> today,
    String weekdayName,
    List<BangumiItem> tv,
    List<BangumiItem> movies,
    List<BangumiItem> ova,
  })> _fetchHomeData({
    bool forceRefresh = false,
  }) async {
    final results = await Future.wait([
      widget.client.getCalendar(forceRefresh: forceRefresh),
      widget.client.getTrending(limit: 18, forceRefresh: forceRefresh),
      widget.client.getHotMovies(limit: 18, forceRefresh: forceRefresh),
      widget.client.getHotOva(limit: 18, forceRefresh: forceRefresh),
    ]);

    final calendarDays = results[0] as List<BangumiCalendarDay>;
    final tv = results[1] as List<BangumiItem>;
    final movies = results[2] as List<BangumiItem>;
    final ova = results[3] as List<BangumiItem>;

    final now = DateTime.now();
    final todayWeekday = now.weekday; // 1=Mon .. 7=Sun
    const weekLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekdayName = weekLabels[(todayWeekday - 1).clamp(0, 6)];

    final todayItems = calendarDays
        .firstWhere(
          (d) => d.weekday.id == todayWeekday,
          orElse: () => calendarDays.isNotEmpty
              ? calendarDays[0]
              : BangumiCalendarDay(
                  weekday: BangumiWeekday(
                    id: todayWeekday,
                    en: '',
                    cn: weekdayName,
                    ja: '',
                  ),
                  items: const [],
                ),
        )
        .items;

    return (
      today: todayItems,
      weekdayName: weekdayName,
      tv: tv,
      movies: movies,
      ova: ova,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final safeTop = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 0. 极底：动态弥散环境光晕（Ambient Mesh Glow），赋予全屏通透景深与毛玻璃流光折射
          Positioned(
            top: -120,
            left: -80,
            right: -80,
            height: 420,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 0.85,
                    colors: [
                      theme.colorScheme.primary.withAlpha(isDark ? 36 : 22),
                      theme.colorScheme.primary.withAlpha(isDark ? 10 : 6),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 1. 底层：内容流区域（包裹滚动通知监听，驱动顶部栏毛玻璃与 Quick-Return 平滑显隐）
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.axis == Axis.vertical) {
                  _scrollOffsetNotifier.value = notification.metrics.pixels;

                  final isDesktop = context.isDesktop;

                  if (isDesktop) {
                    // 桌面端无条件常驻吸顶显示，绝不执行上下收起动画
                    if (!_isTopBarVisible) {
                      setState(() {
                        _isTopBarVisible = true;
                      });
                    }
                  } else if (notification is ScrollUpdateNotification) {
                    final currentPixels = notification.metrics.pixels;
                    final delta = notification.scrollDelta ?? 0.0;

                    // 1. 顶部零点保护：距离顶部 10px 以内无条件强制显现
                    if (currentPixels <= 10) {
                      if (!_isTopBarVisible) {
                        setState(() {
                          _isTopBarVisible = true;
                        });
                      }
                      _downScrollAccumulator = 0.0;
                      _upScrollAccumulator = 0.0;
                    }
                    // 2. 向下滑动（内容向上走，阅读浏览模式）：累积下滚超过 20px 触发平滑收起
                    else if (delta > 1.5) {
                      _downScrollAccumulator += delta;
                      _upScrollAccumulator = 0.0;
                      if (_downScrollAccumulator > 20.0 && _isTopBarVisible) {
                        setState(() {
                          _isTopBarVisible = false;
                        });
                      }
                    }
                    // 3. 向上滑动（内容向下走，意图回滚或搜索）：累积上滚超过 12px 触发快速召回显现
                    else if (delta < -1.5) {
                      _upScrollAccumulator += delta.abs();
                      _downScrollAccumulator = 0.0;
                      if (_upScrollAccumulator > 12.0 && !_isTopBarVisible) {
                        setState(() {
                          _isTopBarVisible = true;
                        });
                      }
                    }
                  }
                }
                return false;
              },
              child: _buildAnimeContent(context, theme, safeTop),
            ),
          ),

          // 2. 顶层：B 站式全宽平滑延伸沉浸顶部导航栏（支持下滑收起上滑显现）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: HomeTopBar(
              isVisible: _isTopBarVisible,
              scrollOffsetNotifier: _scrollOffsetNotifier,
              onSearchTap: _navigateToSearch,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimeContent(BuildContext context, ThemeData theme, double safeTop) {
    return FutureBuilder<({
      List<BangumiItem> today,
      String weekdayName,
      List<BangumiItem> tv,
      List<BangumiItem> movies,
      List<BangumiItem> ova,
    })>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 1:1 动态流光骨架屏无缝垫底，呈现即时响应感
          return _buildShimmerSkeleton(context, theme, safeTop);
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    '加载失败',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _loadData(forceRefresh: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重试'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data;
        final today = data?.today ?? [];
        final weekdayName = data?.weekdayName ?? '今日';
        final tv = data?.tv ?? [];
        final movies = data?.movies ?? [];
        final ova = data?.ova ?? [];

        // 精选探索流预留数据（开关开启时使用）
        final exploreItems = <BangumiItem>[
          ...today,
          ...tv,
          ...movies,
          ...ova,
        ];
        final seenIds = <int>{};
        final uniqueExploreItems = exploreItems.where((item) => seenIds.add(item.id)).toList();

        return RefreshIndicator(
          onRefresh: () async {
            _loadData(forceRefresh: true);
            await _dataFuture;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            // 核心防卡顿防线：精确限制可视区外预加载距离（250px），未进入视口的卡片不发起网络下载
            scrollCacheExtent: const ScrollCacheExtent.pixels(250),
            slivers: [
              // 顶部预留安全高度（状态栏 + 顶栏高度 42px），首屏内容在滚动时穿透并呈现高斯模糊磨砂效果
              SliverToBoxAdapter(
                child: SizedBox(height: safeTop + 42),
              ),

              // 顶部轮播与今日放送：响应式双模式（宽屏模式下左右分栏，窄屏模式下纵向流）
              SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= AppBreakpoints.medium;

                    if (isDesktop && (tv.isNotEmpty || today.isNotEmpty)) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 12),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: AppBreakpoints.maxContentWidth),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: HomeDesktopHero(
                                bannerItems: tv,
                                todayItems: today,
                                weekdayName: weekdayName,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    // 移动端/窄屏模式（原布局保持不变）
                    return Column(
                      children: [
                        if (tv.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          HomeBannerCarousel(items: tv),
                          const SizedBox(height: 10),
                        ],
                        if (today.isNotEmpty) ...[
                          TodayAnimeShelf(
                            items: today,
                            weekdayName: weekdayName,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    );
                  },
                ),
              ),

              // 货架 1：热门 TV 番剧独立货架
              SliverToBoxAdapter(
                child: _buildResponsiveShelf(
                  AnimeHorizontalShelf(
                    icon: Icons.tv_rounded,
                    title: '热门 TV 番剧',
                    items: tv,
                    defaultStatType: 'heat',
                    viewAllSubtitle: '浏览全部 TV',
                    onViewAllTap: () => _onShelfViewAllTap('TV'),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // 货架 2：热门剧场版独立货架
              SliverToBoxAdapter(
                child: _buildResponsiveShelf(
                  AnimeHorizontalShelf(
                    icon: Icons.movie_filter_rounded,
                    title: '热门剧场版',
                    items: movies,
                    defaultStatType: 'collect',
                    viewAllSubtitle: '浏览全部剧场版',
                    onViewAllTap: () => _onShelfViewAllTap('剧场版'),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // 货架 3：热门 OVA / 特别篇独立货架
              SliverToBoxAdapter(
                child: _buildResponsiveShelf(
                  AnimeHorizontalShelf(
                    icon: Icons.album_rounded,
                    title: '热门 OVA / 特别篇',
                    items: ova,
                    defaultStatType: 'collect',
                    viewAllSubtitle: '浏览全部 OVA',
                    onViewAllTap: () => _onShelfViewAllTap('OVA'),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              if (_showExploreSection) ...[
                const SliverToBoxAdapter(
                  child: SizedBox(height: 12),
                ),

                // 纵向双列探索板块大标题
                if (uniqueExploreItems.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.explore_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '精选探索',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${uniqueExploreItems.length} 部精选',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 纵向双列精选瀑布流网格
                if (uniqueExploreItems.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.65,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return AnimeCard(item: uniqueExploreItems[index]);
                        },
                        childCount: uniqueExploreItems.length,
                      ),
                    ),
                  ),
              ],

              // 底部留出 96px 安全高度，保证页面滑动至最底端时不会被悬浮毛玻璃胶囊遮挡
              const SliverToBoxAdapter(
                child: SizedBox(height: 96),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 1:1 动态流光骨架屏结构：对应轮播图、今日更新与 3 行独立货架的平滑加载占位
  Widget _buildShimmerSkeleton(BuildContext context, ThemeData theme, double safeTop) {
    Widget buildShelfSkeletonRow(String title) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: ShimmerLoading(
              child: Container(
                height: 18,
                width: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 250,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 4,
              itemBuilder: (context, index) => const ShimmerRankCard(),
            ),
          ),
        ],
      );
    }

    return Shimmer(
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(height: safeTop + 42),
          ),
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 840;

                if (isDesktop) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: ShimmerDesktopHero(),
                        ),
                      ),
                    ),
                  );
                }

                return const Column(
                  children: [
                    SizedBox(height: 8),
                    ShimmerBannerCarousel(),
                    SizedBox(height: 10),
                    ShimmerTodayShelf(),
                    SizedBox(height: 12),
                  ],
                );
              },
            ),
          ),
          // 3 行独立货架骨架流光
          SliverToBoxAdapter(
            child: buildShelfSkeletonRow('TV 番剧'),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: buildShelfSkeletonRow('剧场版'),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: buildShelfSkeletonRow('OVA 特别篇'),
          ),

          if (_showExploreSection) ...[
            const SliverToBoxAdapter(
              child: SizedBox(height: 14),
            ),
            // 探索标题骨架
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ShimmerLoading(
                  child: Container(
                    height: 18,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            // 双列网格骨架（6 张卡片占位）
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.65,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const ShimmerAnimeCard(),
                  childCount: 6,
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(
            child: SizedBox(height: 96),
          ),
        ],
      ),
    );
  }
}
