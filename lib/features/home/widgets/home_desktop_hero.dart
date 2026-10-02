import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import '../../common/widgets/anime_card.dart';
import '../../common/widgets/shimmer_loading.dart';
import 'home_banner_carousel.dart';

/// 桌面/宽屏端 Hero 分栏黄金排版（类似 B站/流媒体桌面端模式）：
/// 1. 左侧：高屏占比精选轮播图（Banner Carousel）；
/// 2. 右侧：与左侧等高对齐的“今日放送” 2行 × 3列 6 宫格矩阵；
/// 3. 支持右上角“换一批 / 翻页”微交互与平滑动画；
/// 4. 彻底解决大屏下单列轮播两边留白过宽与纯横向滑动割裂的问题。
class HomeDesktopHero extends StatefulWidget {
  final List<BangumiItem> bannerItems;
  final List<BangumiItem> todayItems;
  final String weekdayName;

  const HomeDesktopHero({
    super.key,
    required this.bannerItems,
    required this.todayItems,
    required this.weekdayName,
  });

  @override
  State<HomeDesktopHero> createState() => _HomeDesktopHeroState();
}

class _HomeDesktopHeroState extends State<HomeDesktopHero> {
  late final PageController _gridPageController;
  int _gridPageIndex = 0;

  static const double _heroHeight = 340.0;
  static const int _cardsPerPage = 6;

  int get _totalPages => (widget.todayItems.length / _cardsPerPage).ceil().clamp(1, 99);

  @override
  void initState() {
    super.initState();
    _gridPageController = PageController();
  }

  @override
  void dispose() {
    _gridPageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_totalPages <= 1) return;
    final next = (_gridPageIndex + 1) % _totalPages;
    _gridPageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _prevPage() {
    HapticFeedback.lightImpact();
    if (_totalPages <= 1) return;
    final prev = (_gridPageIndex - 1 + _totalPages) % _totalPages;
    _gridPageController.animateToPage(
      prev,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: _heroHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 左侧：精选轮播图（flex: 5，占比约 46%）
          Expanded(
            flex: 5,
            child: HomeBannerCarousel(
              items: widget.bannerItems,
              height: _heroHeight,
              padding: EdgeInsets.zero,
              borderRadius: 14,
            ),
          ),
          const SizedBox(width: 14),

          // 2. 右侧：今日放送 6 宫格矩阵（flex: 6，占比约 54%）
          Expanded(
            flex: 6,
            child: Container(
              height: _heroHeight,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(12)
                    : Colors.black.withAlpha(8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withAlpha(22)
                      : Colors.black.withAlpha(14),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 头部：标题与“换一批/翻页”控件
                  _buildHeader(theme, isDark),
                  const SizedBox(height: 8),

                  // 2行 × 3列 6宫格翻页视图
                  Expanded(
                    child: PageView.builder(
                      controller: _gridPageController,
                      itemCount: _totalPages,
                      onPageChanged: (index) {
                        setState(() {
                          _gridPageIndex = index;
                        });
                      },
                      itemBuilder: (context, pageIndex) {
                        return _buildSixGridPage(pageIndex);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 标题栏：轻量矢量图标 + 今日放送 + 翻页与换一批操作
  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.today_rounded,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 7),
        Text(
          '今日放送',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: theme.textTheme.titleMedium?.color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${widget.weekdayName} · ${widget.todayItems.length} 部更新',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.normal,
          ),
        ),
        const Spacer(),

        // 翻页指示与控制按钮组
        if (_totalPages > 1) ...[
          Text(
            '${_gridPageIndex + 1} / $_totalPages',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          _buildActionIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: '上一组',
            onTap: _prevPage,
            isDark: isDark,
          ),
          const SizedBox(width: 2),
          _buildActionIconButton(
            icon: Icons.chevron_right_rounded,
            tooltip: '下一组',
            onTap: _nextPage,
            isDark: isDark,
          ),
          const SizedBox(width: 6),
          // B站风格“换一批”按钮
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _nextPage,
              borderRadius: BorderRadius.circular(100),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 13,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '换一批',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Icon(
              icon,
              size: 18,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  /// 单页 6 宫格矩阵（2 行 × 3 列），通过 Row + Column + Expanded 严格等比填充
  Widget _buildSixGridPage(int pageIndex) {
    final startIndex = pageIndex * _cardsPerPage;

    return Column(
      children: [
        // 第 1 排（3 部）
        Expanded(
          child: Row(
            children: [
              _buildGridCard(startIndex + 0),
              const SizedBox(width: 8),
              _buildGridCard(startIndex + 1),
              const SizedBox(width: 8),
              _buildGridCard(startIndex + 2),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 第 2 排（3 部）
        Expanded(
          child: Row(
            children: [
              _buildGridCard(startIndex + 3),
              const SizedBox(width: 8),
              _buildGridCard(startIndex + 4),
              const SizedBox(width: 8),
              _buildGridCard(startIndex + 5),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGridCard(int index) {
    if (index < widget.todayItems.length) {
      return Expanded(
        child: AnimeCard(
          item: widget.todayItems[index],
          compact: true,
        ),
      );
    }
    // 最后一页不足 6 部时用空白占位填充，确保规整对齐
    return const Expanded(
      child: SizedBox.shrink(),
    );
  }
}

/// 1:1 桌面端分栏 Hero 流光骨架屏
class ShimmerDesktopHero extends StatelessWidget {
  const ShimmerDesktopHero({super.key});

  static const double _heroHeight = 340.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: _heroHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧轮播图骨架
          const Expanded(
            flex: 5,
            child: ShimmerBannerCarousel(
              height: _heroHeight,
              padding: EdgeInsets.zero,
              borderRadius: 14,
            ),
          ),
          const SizedBox(width: 14),

          // 右侧 6 宫格骨架
          Expanded(
            flex: 6,
            child: Container(
              height: _heroHeight,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLoading(
                    child: Container(
                      height: 18,
                      width: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: const [
                              Expanded(child: ShimmerAnimeCard()),
                              SizedBox(width: 8),
                              Expanded(child: ShimmerAnimeCard()),
                              SizedBox(width: 8),
                              Expanded(child: ShimmerAnimeCard()),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Row(
                            children: const [
                              Expanded(child: ShimmerAnimeCard()),
                              SizedBox(width: 8),
                              Expanded(child: ShimmerAnimeCard()),
                              SizedBox(width: 8),
                              Expanded(child: ShimmerAnimeCard()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
