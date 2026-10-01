import 'package:flutter/material.dart';
import '../../../core/models/bangumi/bangumi_calendar.dart';
import '../../../core/network/bangumi_client.dart';
import '../../common/widgets/anime_card.dart';

class TimelinePage extends StatefulWidget {
  final BangumiClient client;

  const TimelinePage({
    super.key,
    required this.client,
  });

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> with AutomaticKeepAliveClientMixin {
  late Future<List<BangumiCalendarDay>> _calendarFuture;
  int _selectedDayIndex = 0;

  static const _weekLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  // 保证时间表页面切走后再切回时不重新销毁、不重新触发网络请求
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 默认高亮今天 (1=Mon .. 7=Sun)
    final todayWeekday = DateTime.now().weekday;
    _selectedDayIndex = (todayWeekday - 1).clamp(0, 6);
    _loadCalendar();
  }

  void _loadCalendar({bool forceRefresh = false}) {
    setState(() {
      _calendarFuture = widget.client.getCalendar(forceRefresh: forceRefresh);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: Color(0xFFE91E63)),
            SizedBox(width: 8),
            Text('每日放送', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新时间表',
            onPressed: () => _loadCalendar(forceRefresh: true),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: List.generate(7, (index) {
                final isSelected = _selectedDayIndex == index;
                final isToday = (DateTime.now().weekday - 1) == index;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          _weekLabels[index],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : (isToday ? const Color(0xFFE91E63) : null),
                          ),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFFE91E63),
                      showCheckmark: false,
                      padding: EdgeInsets.zero,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedDayIndex = index;
                          });
                        }
                      },
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<BangumiCalendarDay>>(
        future: _calendarFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在加载时间表...'),
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
                      '数据获取失败',
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
                      onPressed: () => _loadCalendar(forceRefresh: true),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }

          final calendarList = snapshot.data ?? [];
          if (calendarList.isEmpty) {
            return const Center(child: Text('暂无每日放送数据'));
          }

          // 核心优化：使用 IndexedStack 替代 TabBarView
          // 1. 点击周一到周日时直接即点即切，不再强行在 300ms 内连环滑动排版上百个卡片
          // 2. 7 个子页面一旦排版完成全部常驻内存，二次切换时 0ms 瞬间显示，永无白屏
          return IndexedStack(
            index: _selectedDayIndex,
            children: List.generate(7, (index) {
              final weekdayId = index + 1; // 1=Mon .. 7=Sun
              final dayData = calendarList.firstWhere(
                (d) => d.weekday.id == weekdayId,
                orElse: () => calendarList.length > index
                    ? calendarList[index]
                    : BangumiCalendarDay(
                        weekday: BangumiWeekday(
                          id: weekdayId,
                          en: '',
                          cn: _weekLabels[index],
                          ja: '',
                        ),
                        items: const [],
                      ),
              );

              return _KeepAliveDayView(dayData: dayData);
            }),
          );
        },
      ),
    );
  }
}

class _KeepAliveDayView extends StatefulWidget {
  final BangumiCalendarDay dayData;

  const _KeepAliveDayView({required this.dayData});

  @override
  State<_KeepAliveDayView> createState() => _KeepAliveDayViewState();
}

class _KeepAliveDayViewState extends State<_KeepAliveDayView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.dayData.items.isEmpty) {
      return Center(
        child: Text('【${widget.dayData.weekday.cn}】今日暂无放送'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth ~/ 180).clamp(2, 6);

        return GridView.builder(
          key: PageStorageKey<String>('day_${widget.dayData.weekday.id}'),
          // 底部留出 96px，配合底栏 extendBody: true 悬浮毛玻璃穿透
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.62,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: widget.dayData.items.length,
          itemBuilder: (context, index) {
            final item = widget.dayData.items[index];
            return AnimeCard(item: item);
          },
        );
      },
    );
  }
}
