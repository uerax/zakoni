import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../core/models/bangumi/bangumi_calendar.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import '../../common/widgets/anime_card.dart';
import '../../common/widgets/shimmer_loading.dart';

/// 首页“新番每日放送”专属模块：
/// 1. 支持传入全周 7 天数据 (calendarDays)，提供周一至周日胶囊切换条，0 额外网络开销；
/// 2. 向后兼容单天 items 注入；
/// 3. 采用紧凑小卡片 (compact: true)，尺寸收敛至 108×188px，视觉轻盈；
/// 4. 支持桌面端鼠标滚轮横向平滑滚动 + 阻尼弹性滑动 + 惰性预加载。
class TodayAnimeShelf extends StatefulWidget {
  final List<BangumiCalendarDay>? calendarDays;
  final List<BangumiItem>? items;
  final String? weekdayName;

  const TodayAnimeShelf({
    super.key,
    this.calendarDays,
    this.items,
    this.weekdayName,
  });

  @override
  State<TodayAnimeShelf> createState() => _TodayAnimeShelfState();
}

class _TodayAnimeShelfState extends State<TodayAnimeShelf> {
  final ScrollController _scrollController = ScrollController();
  late int _selectedDayIndex; // 0=Mon .. 6=Sun
  late final int _todayWeekdayIndex;

  static const _weekLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  void initState() {
    super.initState();
    final todayWeekday = DateTime.now().weekday; // 1=Mon .. 7=Sun
    _todayWeekdayIndex = (todayWeekday - 1).clamp(0, 6);
    _selectedDayIndex = _todayWeekdayIndex;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<BangumiItem> get _currentItems {
    final days = widget.calendarDays;
    if (days != null && days.isNotEmpty) {
      final targetDayId = _selectedDayIndex + 1;
      final matchedDay = days.firstWhere(
        (d) => d.weekday.id == targetDayId,
        orElse: () => BangumiCalendarDay(
          weekday: BangumiWeekday(
            id: targetDayId,
            en: '',
            cn: _weekLabels[_selectedDayIndex],
            ja: '',
          ),
          items: const [],
        ),
      );
      return matchedDay.items;
    }
    return widget.items ?? const [];
  }

  String get _currentWeekdayLabel {
    return _weekLabels[_selectedDayIndex.clamp(0, 6)];
  }

  void _onSelectDay(int index) {
    if (index == _selectedDayIndex) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedDayIndex = index;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _currentItems;
    final hasDays = widget.calendarDays != null && widget.calendarDays!.isNotEmpty;
    if (items.isEmpty && !hasDays) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isToday = _selectedDayIndex == _todayWeekdayIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏：轻量矢量图标 + 规范排印
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Text(
                '新番每日放送',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_currentWeekdayLabel · ${isToday ? '今日 ' : ''}${items.length} 部更新',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),

        // 周一至周日全周胶囊切换条（当提供 calendarDays 时展示）
        if (hasDays) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: 7,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedDayIndex;
                  final isCurrentDay = index == _todayWeekdayIndex;

                  return InkWell(
                    onTap: () => _onSelectDay(index),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (isDark
                                ? Colors.white.withAlpha(14)
                                : Colors.black.withAlpha(8)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCurrentDay && !isSelected) ...[
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            _weekLabels[index],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? theme.colorScheme.onPrimary
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: 4),

        // 小尺寸紧凑卡片横向滚动轨道
        SizedBox(
          height: 188,
          child: items.isEmpty
              ? Center(
                  child: Text(
                    '当天暂无番剧放送',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : Listener(
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
                    key: ValueKey('week_shelf_$_selectedDayIndex'),
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    scrollCacheExtent: const ScrollCacheExtent.pixels(150),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
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
