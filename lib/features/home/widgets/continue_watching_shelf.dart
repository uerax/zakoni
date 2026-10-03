import 'package:flutter/material.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import '../../common/widgets/bouncing_scale_card.dart';
import '../../common/widgets/cached_anime_image.dart';

/// 播放进度记录实体：
/// 用于表达用户最近观看的集数进度与时间，供“继续追番”模块消费。
class WatchProgressItem {
  final BangumiItem item;
  final int episodeNumber;
  final double progress; // 0.0 ~ 1.0
  final String positionText; // "18:24 / 24:00"
  final DateTime lastWatchTime;

  const WatchProgressItem({
    required this.item,
    required this.episodeNumber,
    required this.progress,
    required this.positionText,
    required this.lastWatchTime,
  });
}

/// 首页“继续追番”模块：
/// 1. 数据驱动：当 records 为空时直接返回 SizedBox.shrink()，0 像素占位，零视觉副作用；
/// 2. 紧凑横卡：单张卡片控制在 74px 高度，左侧缩略封面 + 右侧剧集名称/进度条，紧凑且信息明确；
/// 3. 支持点击直达播放，桌面端支持鼠标 Hover 播放光标动效。
class ContinueWatchingShelf extends StatelessWidget {
  final List<WatchProgressItem> records;
  final ValueChanged<WatchProgressItem>? onResumeWatch;
  final VoidCallback? onViewAllHistory;

  const ContinueWatchingShelf({
    super.key,
    required this.records,
    this.onResumeWatch,
    this.onViewAllHistory,
  });

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 7),
                Text(
                  '继续追番',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
                const Spacer(),
                if (onViewAllHistory != null)
                  InkWell(
                    onTap: onViewAllHistory,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '历史记录',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 卡片横向滑动列表
          SizedBox(
            height: 76,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final record = records[index];
                return _buildWatchCard(context, theme, isDark, record);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    WatchProgressItem record,
  ) {
    final item = record.item;

    return BouncingScaleCard(
      onTap: () => onResumeWatch?.call(record),
      child: Container(
        width: 220,
        height: 76,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1E22).withAlpha(220)
              : Colors.white.withAlpha(240),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(20)
                : Colors.black.withAlpha(14),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 40 : 10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 封面与播放微胶囊
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SizedBox(
                width: 48,
                height: 62,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedAnimeImage(
                      imageUrl: item.thumbnailUrl.isNotEmpty
                          ? item.thumbnailUrl
                          : item.coverUrl,
                      fit: BoxFit.cover,
                    ),
                    ColoredBox(color: Colors.black.withAlpha(35)),
                    const Center(
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // 信息与进度条
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.preferredName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.titleSmall?.color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '看到第 ${record.episodeNumber} 话 · ${record.positionText}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 紧凑播放进度条
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: record.progress.clamp(0.0, 1.0),
                      minHeight: 3.5,
                      backgroundColor: isDark
                          ? Colors.white.withAlpha(30)
                          : Colors.black.withAlpha(20),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
