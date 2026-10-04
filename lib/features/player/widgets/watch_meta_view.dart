import 'package:flutter/material.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import '../../common/widgets/cached_anime_image.dart';

/// 参考 animaku WatchMeta 打造的番剧详情 Tab 组件
class WatchMetaView extends StatefulWidget {
  const WatchMetaView({
    super.key,
    required this.title,
    this.bangumiItem,
    this.coverUrl,
    this.episodeCount = 12,
  });

  final String title;
  final BangumiItem? bangumiItem;
  final String? coverUrl;
  final int episodeCount;

  @override
  State<WatchMetaView> createState() => _WatchMetaViewState();
}

class _WatchMetaViewState extends State<WatchMetaView> {
  bool _isSummaryExpanded = false;
  String _collectStatus = '在看';

  static const List<String> _collectOptions = ['想看', '在看', '看过', '搁置', '抛弃'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final item = widget.bangumiItem;

    final displayName = item?.preferredName ?? widget.title;
    final subName = (item != null && item.name != item.nameCn && item.name.isNotEmpty)
        ? item.name
        : null;

    final cover = (widget.coverUrl != null && widget.coverUrl!.isNotEmpty)
        ? widget.coverUrl!
        : (item?.coverUrl ?? '');

    final summary = (item?.summary != null && item!.summary.isNotEmpty)
        ? item.summary.trim()
        : '暂无番剧详细剧情简介。';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // 1. 顶部基础信息（封面 + 标题 + 评分 + 放送信息）
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 90,
                height: 125,
                child: cover.isNotEmpty
                    ? CachedAnimeImage(
                        imageUrl: cover,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: isDark ? Colors.white10 : Colors.black12,
                        child: const Icon(Icons.movie_outlined, size: 36),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subName != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subName,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  // 评分与排名标签
                  Row(
                    children: [
                      if (item != null && item.ratingScore > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Colors.amber, size: 14),
                              const SizedBox(width: 3),
                              Text(
                                item.ratingScore.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (item != null && item.rank > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#${item.rank}',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '共 ${item?.eps != null && item!.eps > 0 ? item.eps : widget.episodeCount} 话',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                  if (item != null && item.airDate.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '放送日期: ${item.airDate}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 2. 收藏状态切换栏（想看 / 在看 / 看过 / 搁置 / 抛弃）
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _collectOptions.map((opt) {
              final isSelected = _collectStatus == opt;
              return InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  setState(() => _collectStatus = opt);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已标记为: $opt'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // 3. 标签列表（Tags）
        if (item != null && item.tags.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: item.tags.take(12).map((t) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  t.name,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // 4. 剧情简介（支持展开/收起）
        const Text(
          '剧情简介',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => setState(() => _isSummaryExpanded = !_isSummaryExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.9),
                ),
                maxLines: _isSummaryExpanded ? null : 3,
                overflow: _isSummaryExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _isSummaryExpanded ? '收起 ⌃' : '展开详情 ⌄',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
