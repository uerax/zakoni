import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import '../../../core/network/bangumi_client.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/rank_horizontal_section.dart';

class HomePage extends StatefulWidget {
  final BangumiClient client;

  const HomePage({
    super.key,
    required this.client,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  late Future<({List<BangumiItem> tv, List<BangumiItem> movies, List<BangumiItem> ova})> _dataFuture;
  int _headerTabIndex = 0; // 0: 番剧, 1: 分类
  int _rankCategoryIndex = 0; // 0: TV, 1: 剧场版, 2: OVA

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

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 顶部胶囊导航栏：【番剧】、【分类】、搜索、用户头像
            HomeTopBar(
              selectedIndex: _headerTabIndex,
              onTabChanged: (index) {
                setState(() {
                  _headerTabIndex = index;
                });
              },
            ),

            // 主体区域
            Expanded(
              child: _headerTabIndex == 0
                  ? _buildAnimeContent(context, theme)
                  : _buildCategoryPlaceholder(context, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimeContent(BuildContext context, ThemeData theme) {
    return FutureBuilder<({List<BangumiItem> tv, List<BangumiItem> movies, List<BangumiItem> ova})>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在加载精选番剧...'),
              ],
            ),
          );
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

        final currentRankItems = switch (_rankCategoryIndex) {
          0 => tv,
          1 => movies,
          2 => ova,
          _ => tv,
        };

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
              // 热门排行单行横向拖动板块 (Anibaka 经典交互，支持 TV / 剧场版 / OVA 切换)
              SliverToBoxAdapter(
                child: RankHorizontalSection(
                  items: currentRankItems,
                  selectedCategoryIndex: _rankCategoryIndex,
                  onCategoryChanged: (index) {
                    setState(() {
                      _rankCategoryIndex = index;
                    });
                  },
                  onMoreTap: () {
                    // 与 Animaku 一致：点击“更多”直接切换到分类过滤视图
                    setState(() {
                      _headerTabIndex = 1;
                    });
                  },
                ),
              ),

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

  Widget _buildCategoryPlaceholder(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.category_outlined,
            size: 56,
            color: theme.colorScheme.primary.withAlpha(160),
          ),
          const SizedBox(height: 12),
          Text(
            '分类检索功能设计中',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '后续将支持按题材、年份、标签等细分筛选',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
