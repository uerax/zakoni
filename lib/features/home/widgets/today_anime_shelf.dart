import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import '../../common/widgets/anime_card.dart';
import '../../common/widgets/shimmer_loading.dart';

/// 首页“今日放送”专属模块：
/// 1. 纯净矢量图标 + 规范排印，无冗余 Emoji；
/// 2. 采用与连载周历完全一致的紧凑小卡片 (compact: true)，尺寸收敛至 108×188px，视觉轻盈；
/// 3. 支持桌面端鼠标滚轮横向平滑滚动 + 阻尼弹性滑动 + 惰性预加载。
class TodayAnimeShelf extends StatefulWidget {
  final List<BangumiItem> items;
  final String weekdayName;

  const TodayAnimeShelf({
    super.key,
    required this.items,
    required this.weekdayName,
  });

  @override
  State<TodayAnimeShelf> createState() => _TodayAnimeShelfState();
}

class _TodayAnimeShelfState extends State<TodayAnimeShelf> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏：轻量矢量图标 + 规范排印
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Row(
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
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.weekdayName} · ${widget.items.length} 部更新',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // 小尺寸紧凑卡片横向滚动轨道
        SizedBox(
          height: 188,
          child: Listener(
            // 针对桌面端（Windows/macOS）普通滚轮上下平滑映射至横向滚动
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
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              scrollCacheExtent: const ScrollCacheExtent.pixels(150),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 108,
                    child: AnimeCard(
                      item: item,
                      compact: true,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// 1:1 今日放送流光骨架屏
class ShimmerTodayShelf extends StatelessWidget {
  const ShimmerTodayShelf({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
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
          height: 188,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 108,
                child: const ShimmerAnimeCard(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
