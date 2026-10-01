import 'package:flutter/material.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import 'cached_anime_image.dart';

class AnimeCard extends StatelessWidget {
  final BangumiItem item;
  final VoidCallback? onTap;

  const AnimeCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap ?? () => showAnimeDetailSheet(context, item),
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
                    resizeWidth: 320,
                  ),
                  // 封面底部暗色渐变遮罩
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 38,
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
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(180),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              '${item.ratingScore}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // 左下角状态/已看/在看/热度角标（Animaku 原生规范，优先展示已看人数）
                  if (_buildBottomBadgeText() != null)
                    Positioned(
                      bottom: 5,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(140),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _buildBottomBadgeText()!,
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.preferredName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
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

  String? _buildBottomBadgeText() {
    if (item.collect != null && item.collect! > 0) {
      return '${formatCompactCount(item.collect)} 已看';
    }
    if (item.doing != null && item.doing! > 0) {
      return '${formatCompactCount(item.doing)} 在看';
    }
    if (item.heat != null && item.heat! > 0) {
      return '${formatCompactCount(item.heat)} 热度';
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
