import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import '../../common/widgets/anime_card.dart';
import '../../common/widgets/cached_anime_image.dart';

/// 热门排行单行横向拖动组件（Anibaka 经典交互）：
/// 1. 左侧标题“🏆 热门排行”，中间支持【TV】/【剧场版】/【OVA】分类切换，右侧提供【更多 >】快速跳转分类过滤；
/// 2. 横向 ListView 设置 scrollCacheExtent: 150，严格控制可视区预加载范围，配合 CachedAnimeImage 实现
///    “只有快滑动接近视口才触发图片下载”，彻底避免首屏几十张图片瞬时高并发堵塞网络和掉帧；
/// 3. 支持桌面端双重滚动适配：鼠标左键按住拖拽滑动 + 普通鼠标滚轮上下滚动自动转横向平滑滚动。
class RankHorizontalSection extends StatefulWidget {
  static const double cardWidth = 136;
  static const double cardAspectRatio = 2 / 3;
  static const double cardHeight = cardWidth / cardAspectRatio; // 204

  static const Color _goldColor = Color(0xFFFFD700);
  static const Color _silverColor = Color(0xFFC0C0C0);
  static const Color _bronzeColor = Color(0xFFCD7F32);

  static const List<String> categories = ['TV', '剧场版', 'OVA'];

  final List<BangumiItem> items;
  final int selectedCategoryIndex;
  final ValueChanged<int> onCategoryChanged;

  const RankHorizontalSection({
    super.key,
    required this.items,
    required this.selectedCategoryIndex,
    required this.onCategoryChanged,
  });

  @override
  State<RankHorizontalSection> createState() => _RankHorizontalSectionState();
}

class _RankHorizontalSectionState extends State<RankHorizontalSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant RankHorizontalSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换分类标签时，将横向滚动列表平滑重置回首项
    if (oldWidget.selectedCategoryIndex != widget.selectedCategoryIndex) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 依据 Animaku 规范解析卡片左下角统计指标：
  /// 1. 热门排行/TV类：必定展示热度值（如 "4.6k 热度"）；
  /// 2. 剧场版/OVA/其他类：优先展示已看人数（如 "5.9w 已看"）；
  /// 3. 兜底：若无上述字段则顺次取在看人数或热度。
  ({String count, String label})? _resolveCardStat(BangumiItem item) {
    if (widget.selectedCategoryIndex == 0) {
      if (item.heat != null && item.heat! > 0) {
        return (count: formatCompactCount(item.heat), label: '热度');
      }
      if (item.doing != null && item.doing! > 0) {
        return (count: formatCompactCount(item.doing), label: '热度');
      }
      if (item.collect != null && item.collect! > 0) {
        return (count: formatCompactCount(item.collect), label: '热度');
      }
      return null;
    }

    if (item.collect != null && item.collect! > 0) {
      return (count: formatCompactCount(item.collect), label: '已看');
    }

    if (item.heat != null && item.heat! > 0) {
      return (count: formatCompactCount(item.heat), label: '热度');
    }

    if (item.doing != null && item.doing! > 0) {
      return (count: formatCompactCount(item.doing), label: '在看');
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 6),
        SizedBox(
          height: RankHorizontalSection.cardHeight + 46,
          child: widget.items.isEmpty
              ? _buildEmptyOrLoading(context)
              : Listener(
                  // 针对桌面端（Windows/macOS）的鼠标滚轮适配：
                  // 将普通垂直滚轮滚动的 delta 平滑映射到横向滚动，无需用户按住 Shift
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent) {
                      final double delta = pointerSignal.scrollDelta.dy != 0
                          ? pointerSignal.scrollDelta.dy
                          : pointerSignal.scrollDelta.dx;
                      if (delta != 0 && _scrollController.hasClients) {
                        final double targetOffset = (_scrollController.offset + delta).clamp(
                          0.0,
                          _scrollController.position.maxScrollExtent,
                        );
                        _scrollController.jumpTo(targetOffset);
                      }
                    }
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    key: ValueKey('rank_list_${widget.selectedCategoryIndex}'),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    // 核心防卡顿防线：仅预加载可视区外 150px (约 1 张卡片)，未滚动进入的图片不发起解码与下载
                    scrollCacheExtent: const ScrollCacheExtent.pixels(150),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      return _buildRankCard(context, widget.items[index], index);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          // 左侧："🏆 热门排行"大标题
          Text(
            '🏆 热门排行',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),

          const Spacer(),

          // 右侧：Anibaka 经典微胶囊选项卡切换器（TV / 剧场版 / OVA）
          _buildMiniCapsuleSelector(context, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildMiniCapsuleSelector(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      width: 168,
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(36)
            : Colors.black.withAlpha(18),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Stack(
        children: [
          // 平滑移动的微渐变高亮指示器药丸滑块（与顶部胶囊完全相同参数）
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: AlignmentDirectional(
              -1 + 2 * widget.selectedCategoryIndex / (RankHorizontalSection.categories.length - 1),
              0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / RankHorizontalSection.categories.length,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withAlpha(217),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(80),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 选项文字样式：100% 复制自顶部胶囊，确保字号、字重、字距、颜色完全一致
          Row(
            children: List.generate(RankHorizontalSection.categories.length, (index) {
              final isSelected = widget.selectedCategoryIndex == index;
              final text = RankHorizontalSection.categories[index];

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onCategoryChanged(index);
                  },
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                        letterSpacing: isSelected ? 1.2 : 0.8,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? Colors.white.withAlpha(217)
                                : Colors.black.withAlpha(191)),
                      ),
                      child: Text(
                        text,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRankCard(BuildContext context, BangumiItem item, int index) {
    final rank = index + 1;
    final rankColor = _getRankColor(rank);
    final stat = _resolveCardStat(item);

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => showAnimeDetailSheet(context, item),
        child: SizedBox(
          width: RankHorizontalSection.cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面图片区（带金银铜排名勋章、底部渐变、左下角热度/已看与右下角评分）
              SizedBox(
                height: RankHorizontalSection.cardHeight,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: RankHorizontalSection.cardAspectRatio,
                        child: CachedAnimeImage(
                          imageUrl: item.thumbnailUrl.isNotEmpty
                              ? item.thumbnailUrl
                              : item.coverUrl,
                          width: RankHorizontalSection.cardWidth,
                          height: RankHorizontalSection.cardHeight,
                          resizeWidth: 300,
                        ),
                      ),
                    ),
                    // 左上角排名勋章
                    _buildRankBadge(rank, rankColor),
                    // 右上角评分角标（保持原本样式）
                    if (item.ratingScore > 0)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(180),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                '${item.ratingScore}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // 封面底部暗色渐变遮罩（确保左下角热度/已看人数清晰锐利）
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 40,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withAlpha(200),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 左下角：热度值（TV热门分类优先）或已看人数（剧场版/OVA/其他分类，对齐 Animaku 规范）
                    if (stat != null)
                      Positioned(
                        left: 6,
                        bottom: 4,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              stat.count,
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              stat.label,
                              style: TextStyle(
                                color: Colors.white.withAlpha(210),
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // 标题固定 32px 高度（恒定容纳 2 行高度），杜绝不同条目标题行数差异造成的卡片垂直高度抖动
              SizedBox(
                height: 32,
                child: Text(
                  item.preferredName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank, Color rankColor) {
    return Positioned(
      top: 0,
      left: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: rankColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 3,
              offset: const Offset(1, 1),
            ),
          ],
        ),
        child: Text(
          '#$rank',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            fontSize: 11.5,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return RankHorizontalSection._goldColor;
    if (rank == 2) return RankHorizontalSection._silverColor;
    if (rank == 3) return RankHorizontalSection._bronzeColor;
    return Colors.blueGrey.withAlpha(200);
  }

  Widget _buildEmptyOrLoading(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: SizedBox(
            width: RankHorizontalSection.cardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: RankHorizontalSection.cardHeight,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 14,
                  width: 90,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
