import 'package:flutter/material.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import 'bouncing_scale_card.dart';
import 'cached_anime_image.dart';

class AnimeCard extends StatelessWidget {
  final BangumiItem item;
  final VoidCallback? onTap;
  final bool compact;

  const AnimeCard({
    super.key,
    required this.item,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomStat = _resolveBottomStat();

    return BouncingScaleCard(
      onTap: onTap ?? () => showAnimeDetailSheet(context, item),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 50 : 15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(20)
                : Colors.black.withAlpha(12),
            width: 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedAnimeImage(
                    imageUrl: item.thumbnailUrl.isNotEmpty
                        ? item.thumbnailUrl
                        : item.coverUrl,
                    fit: BoxFit.cover,
                    resizeWidth: compact ? 220 : 360,
                  ),
                  // 封面底部暗色渐变遮罩
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: compact ? 28 : 38,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(180),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 右上角评分角标
                  if (item.ratingScore > 0)
                    Positioned(
                      top: compact ? 4 : 6,
                      right: compact ? 4 : 6,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 4 : 6,
                          vertical: compact ? 1.5 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(180),
                          borderRadius: BorderRadius.circular(compact ? 3 : 4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: compact ? 10 : 13,
                              color: Colors.amber,
                            ),
                            SizedBox(width: compact ? 1.5 : 2),
                            Text(
                              '${item.ratingScore}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 9.5 : 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // 左下角状态/已看/在看/热度角标（Animaku 原生三色语义规范）
                  if (bottomStat != null)
                    Positioned(
                      bottom: compact ? 4 : 5,
                      left: compact ? 4 : 6,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 4 : 5,
                          vertical: compact ? 1.5 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(140),
                          borderRadius: BorderRadius.circular(compact ? 3 : 4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              bottomStat.count,
                              style: TextStyle(
                                color: bottomStat.color,
                                fontSize: compact ? 8.5 : 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: compact ? 1.5 : 2),
                            Text(
                              bottomStat.label,
                              style: TextStyle(
                                color: Colors.white.withAlpha(210),
                                fontSize: compact ? 8 : 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: compact
                  ? const EdgeInsets.symmetric(horizontal: 6.0, vertical: 5.0)
                  : const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.preferredName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: compact ? 11.5 : 12.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: compact ? 9 : 10,
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

  ({String count, String label, Color color})? _resolveBottomStat() {
    if (item.collect != null && item.collect! > 0) {
      return (
        count: formatCompactCount(item.collect),
        label: '已看',
        color: const Color(0xFF34D399), // 翡翠翠绿 (Animaku 规范: emerald-400)
      );
    }
    if (item.doing != null && item.doing! > 0) {
      return (
        count: formatCompactCount(item.doing),
        label: '在看',
        color: const Color(0xFFFBBF24), // 琥珀金黄 (Animaku 规范: amber-400)
      );
    }
    if (item.heat != null && item.heat! > 0) {
      return (
        count: formatCompactCount(item.heat),
        label: '热度',
        color: const Color(0xFFFB7185), // 玫瑰火红 (Animaku 规范: rose-400)
      );
    }
    return null;
  }
}

/// 底部弹出番剧详情抽屉
void showAnimeDetailSheet(BuildContext context, BangumiItem item) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 100,
                        height: 140,
                        child: CachedAnimeImage(
                          imageUrl: item.thumbnailUrl.isNotEmpty
                              ? item.thumbnailUrl
                              : item.coverUrl,
                          width: 100,
                          height: 140,
                          resizeWidth: 300,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.preferredName,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.name,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (item.ratingScore > 0)
                                Chip(
                                  avatar: const Icon(Icons.star, size: 14, color: Colors.amber),
                                  label: Text('${item.ratingScore}分 (${item.votes}人评)'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (item.rank > 0)
                                Chip(
                                  label: Text('Rank #${item.rank}'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (item.airDate.isNotEmpty)
                                Chip(
                                  label: Text('首播: ${item.airDate}'),
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const Text('剧情简介', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  item.summary.isNotEmpty ? item.summary : '暂无剧情简介。',
                  style: const TextStyle(height: 1.5, fontSize: 13),
                ),
                if (item.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('标签', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: item.tags.take(12).map((tag) {
                      return Chip(
                        label: Text(tag.name, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}
