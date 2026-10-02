import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import '../../../core/network/bangumi_client.dart';
import '../../../core/utils/appearance_manager.dart';
import '../../common/widgets/anime_card.dart';
import '../../common/widgets/shimmer_loading.dart';
import '../../timeline/pages/timeline_page.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/rank_horizontal_section.dart';

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

  late Future<({List<BangumiItem> tv, List<BangumiItem> movies, List<BangumiItem> ova})> _dataFuture;
  int _headerTabIndex = 0; // 0: 番剧, 1: 连载

  // 保证页面切走后状态保活不被销毁，切回 0ms 瞬间呈现，不重复请求网络
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData({bool forceRefresh = false}) {
    setState(() {
      _dataFuture = _fetchHomeData(forceRefresh: forceRefresh);
    });
  }

  void _onShelfViewAllTap(String category) {
    // 点击末端“浏览全部”专属探索卡片：通知外层主壳切换到底栏“分类”标签页并定位分类
    if (widget.onNavigateToCategory != null) {
      widget.onNavigateToCategory!(category);
    }
  }

  Future<({List<BangumiItem> tv, List<BangumiItem> movies, List<BangumiItem> ova})> _fetchHomeData({
    bool forceRefresh = false,
  }) async {
    final results = await Future.wait([
      widget.client.getTrending(limit: 18, forceRefresh: forceRefresh),
      widget.client.getHotMovies(limit: 18, forceRefresh: forceRefresh),
      widget.client.getHotOva(limit: 18, forceRefresh: forceRefresh),
    ]);

    return (
      tv: results[0],
      movies: results[1],
      ova: results[2],
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

          // 1. 底层：内容区域（IndexedStack 保活番剧大厅与连载周历，双向切换 0 延迟）
          Positioned.fill(
            child: IndexedStack(
              index: _headerTabIndex,
              children: [
                _buildAnimeContent(context, theme, safeTop),
                TimelinePage(client: widget.client, showAppBar: false),
              ],
            ),
          ),

          // 2. 顶层：悬浮的毛玻璃顶部胶囊导航栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: HomeTopBar(
                selectedIndex: _headerTabIndex,
                onTabChanged: (index) {
                  setState(() {
                    _headerTabIndex = index;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimeContent(BuildContext context, ThemeData theme, double safeTop) {
    return FutureBuilder<({List<BangumiItem> tv, List<BangumiItem> movies, List<BangumiItem> ova})>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 彻底告别粗暴转圈菊花：以 1:1 动态流光骨架屏无缝垫底，呈现现代 iOS 级即时响应感
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
        final tv = data?.tv ?? [];
        final movies = data?.movies ?? [];
        final ova = data?.ova ?? [];

        // 精选探索流预留数据（开关开启时使用）
        final exploreItems = <BangumiItem>[
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
              // 顶部预留安全高度（状态栏 + 极简胶囊栏整体高度 48px），首屏内容紧贴胶囊下沿，上滑时穿透并呈现高斯模糊
              SliverToBoxAdapter(
                child: SizedBox(height: safeTop + 48),
              ),

              // 货架 1：热门 TV 番剧独立货架（Netflix / Apple TV 经典货架陈列）
              SliverToBoxAdapter(
                child: AnimeHorizontalShelf(
                  title: '🏆 热门 TV 番剧',
                  items: tv,
                  defaultStatType: 'heat',
                  viewAllSubtitle: '浏览全部 TV',
                  onViewAllTap: () => _onShelfViewAllTap('TV'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // 货架 2：热门剧场版独立货架
              SliverToBoxAdapter(
                child: AnimeHorizontalShelf(
                  title: '🎬 热门剧场版',
                  items: movies,
                  defaultStatType: 'collect',
                  viewAllSubtitle: '浏览全部剧场版',
                  onViewAllTap: () => _onShelfViewAllTap('剧场版'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // 货架 3：热门 OVA / 特别篇独立货架
              SliverToBoxAdapter(
                child: AnimeHorizontalShelf(
                  title: '📀 热门 OVA / 特别篇',
                  items: ova,
                  defaultStatType: 'collect',
                  viewAllSubtitle: '浏览全部 OVA',
                  onViewAllTap: () => _onShelfViewAllTap('OVA'),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              if (_showExploreSection) ...[
                const SliverToBoxAdapter(
                  child: SizedBox(height: 12),
                ),

                // 纵向双列探索板块大标题（iOS HIG 报刊式大标题排印）
                if (uniqueExploreItems.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Text(
                            '✨ 精选探索',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
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

                // 纵向双列精选瀑布流网格（搭载按压物理回弹卡片与 Animaku 语义三色标签）
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

  /// 1:1 动态流光骨架屏结构：对应 3 行独立货架的平滑加载占位
  Widget _buildShimmerSkeleton(BuildContext context, ThemeData theme, double safeTop) {
    Widget buildShelfSkeletonRow(String title) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: ShimmerLoading(
              child: Container(
                height: 20,
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
              itemBuilder: (_, __) => const ShimmerRankCard(),
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
            child: SizedBox(height: safeTop + 48),
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
                    height: 20,
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
                  (_, __) => const ShimmerAnimeCard(),
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
