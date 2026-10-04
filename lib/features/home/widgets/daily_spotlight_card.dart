import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/home/recommend_item.dart';
import '../../common/widgets/anime_card.dart';
import '../../common/widgets/bouncing_scale_card.dart';
import '../../common/widgets/cached_anime_image.dart';

/// 移动端/窄屏专用的“今日推荐 · 算法推荐精选”大卡片：
/// 1. 杂志图文混排：左侧呈现标准 2:3 原始无畸变海报，右侧展示标题、评分与人话化推荐理由；
/// 2. 算法可解释性：显式渲染契合度百分比徽章与推荐来源逻辑；
/// 3. 支持“换一部 ↻”平滑切片动效与震动反馈。
class DailySpotlightCard extends StatefulWidget {
  final List<RecommendItem> recommendations;

  const DailySpotlightCard({
    super.key,
    required this.recommendations,
  });

  @override
  State<DailySpotlightCard> createState() => _DailySpotlightCardState();
}

class _DailySpotlightCardState extends State<DailySpotlightCard> {
  int _currentIndex = 0;

  void _switchNext() {
    if (widget.recommendations.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.recommendations.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.recommendations.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final current = widget.recommendations[_currentIndex.clamp(0, widget.recommendations.length - 1)];
    final item = current.item;

    // 视觉舒适的琥珀金色阶：浅色模式采用深琥珀金 (amber-600) 避免白底刺眼，深色模式采用明朗金 (amber-400)
    final amberColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    final amberBgColor = isDark ? const Color(0xFFFBBF24).withAlpha(35) : const Color(0xFFD97706).withAlpha(24);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部标题与“换一部”微操作
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Text(
                '今日推荐',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: theme.textTheme.titleMedium?.color,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(isDark ? 36 : 22),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '算法精选',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              if (widget.recommendations.length > 1)
                InkWell(
                  onTap: _switchNext,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '换一部',
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
            ],
          ),
          const SizedBox(height: 8),

          // 精选卡片主体
          BouncingScaleCard(
            onTap: () => navigateToVideoPlayer(context, item),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: Container(
                key: ValueKey('spotlight_${item.id}_$_currentIndex'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E22).withAlpha(235)
                      : Colors.white.withAlpha(245),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withAlpha(24)
                        : Colors.black.withAlpha(16),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 45 : 12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左侧：2:3 原始海报
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: SizedBox(
                        width: 90,
                        height: 126,
                        child: CachedAnimeImage(
                          imageUrl: item.thumbnailUrl.isNotEmpty
                              ? item.thumbnailUrl
                              : item.coverUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 右侧：标题、标签、推荐理由与评分（锁定 126px 高度并通过 Spacer 让理由气泡稳固置底）
                    Expanded(
                      child: SizedBox(
                        height: 126,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 契合度与特色标签
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: amberBgColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.stars_rounded,
                                        size: 11,
                                        color: amberColor,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${current.matchRate}% 契合',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: amberColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.onSurfaceVariant.withAlpha(20),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    current.tag,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // 作品名
                            Text(
                              item.preferredName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: theme.textTheme.titleMedium?.color,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // 评分
                            if (item.ratingScore > 0)
                              Row(
                                children: [
                                  Icon(Icons.star_rounded, size: 14, color: amberColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    item.ratingScore.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: amberColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${item.votes}人评)',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),

                            // 核心：弹性填充间隙，将推荐理由气泡推至最底部与左侧海报底沿平齐
                            const Spacer(),

                            // 显式推荐理由气泡
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withAlpha(isDark ? 22 : 12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '💡 ',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  Expanded(
                                    child: Text(
                                      current.reason,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.35,
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
