import 'package:flutter/material.dart';
import '../../common/widgets/bouncing_scale_card.dart';
import '../source/utils/playable_slot_engine.dart';

/// 律动音波小动画（iOS 风格播放中音波指示器）
class _PlayingBarsAnimation extends StatefulWidget {
  const _PlayingBarsAnimation();

  @override
  State<_PlayingBarsAnimation> createState() => _PlayingBarsAnimationState();
}

class _PlayingBarsAnimationState extends State<_PlayingBarsAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final val = _animController.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar(2.5 + 4.5 * val),
            const SizedBox(width: 1.5),
            _buildBar(7.5 - 4.0 * val),
            const SizedBox(width: 1.5),
            _buildBar(3.5 + 4.0 * (1.0 - val)),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 1.8,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(1.0),
      ),
    );
  }
}

/// iOS 现代化流体选集组件 (Apple HIG Squircle & Bouncing Feedback)
class EpisodePickerSection extends StatefulWidget {
  const EpisodePickerSection({
    super.key,
    required this.episodeCount,
    this.currentEpisode,
    required this.onSelectEpisode,
    this.onSelectSlot,
    this.slots,
    this.onRefresh,
    this.roads = const ['官方主线路', '备用线路 2'],
    this.activeRoadIndex = 0,
    this.playingRoadIndex,
    this.onRoadSelected,
    this.episodeTitles,
    this.watchedEpisodes = const {},
  });

  final int episodeCount;
  final int? currentEpisode;
  final ValueChanged<int> onSelectEpisode;
  final ValueChanged<PlayableSlot>? onSelectSlot;
  final List<PlayableSlot>? slots;
  final VoidCallback? onRefresh;
  final List<String> roads;
  final int activeRoadIndex;
  final int? playingRoadIndex;
  final ValueChanged<int>? onRoadSelected;
  final List<String>? episodeTitles;
  final Set<int> watchedEpisodes;

  @override
  State<EpisodePickerSection> createState() => _EpisodePickerSectionState();
}

class _EpisodePickerSectionState extends State<EpisodePickerSection> {
  bool _isDescOrder = false;
  int _activeRoadIndex = 0;
  int _selectedRangeIndex = 0;

  static const int _rangeSize = 50;

  @override
  void initState() {
    super.initState();
    _activeRoadIndex = widget.activeRoadIndex;
  }

  @override
  void didUpdateWidget(covariant EpisodePickerSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeRoadIndex != oldWidget.activeRoadIndex) {
      _activeRoadIndex = widget.activeRoadIndex;
    }
    // 当外部选中新集数时，自动对齐到对应区间分页
    if (widget.currentEpisode != null &&
        widget.currentEpisode != oldWidget.currentEpisode &&
        widget.episodeCount > 40) {
      final targetRange = (widget.currentEpisode! - 1) ~/ _rangeSize;
      if (targetRange != _selectedRangeIndex) {
        setState(() => _selectedRangeIndex = targetRange);
      }
    }
  }

  String _resolveTitle(int ep) {
    if (widget.episodeTitles != null &&
        ep - 1 >= 0 &&
        ep - 1 < widget.episodeTitles!.length) {
      return widget.episodeTitles![ep - 1];
    }
    return '第 $ep 话';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    final slots = widget.slots;
    final hasSlots = slots != null && slots.isNotEmpty;
    final total = hasSlots ? slots.length : widget.episodeCount;
    final isMultiRange = total > 40;
    final numRanges = isMultiRange ? (total / _rangeSize).ceil() : 1;

    // 计算当前区间中的集数
    final startEp = isMultiRange ? (_selectedRangeIndex * _rangeSize + 1) : 1;
    final endEp = isMultiRange
        ? ((_selectedRangeIndex + 1) * _rangeSize > total
            ? total
            : (_selectedRangeIndex + 1) * _rangeSize)
        : total;

    // 生成当前区间集数列表（考虑正倒序）
    List<int> epList = [];
    for (int i = startEp; i <= endEp; i++) {
      epList.add(i);
    }
    if (_isDescOrder) {
      epList = epList.reversed.toList();
    }

    final currentEpLabel = widget.currentEpisode != null
        ? '${widget.currentEpisode}/$total 话'
        : '共 $total 话';

    return Column(
      children: [
        // 1. 顶部 iOS 选集状态操作栏
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                '选集',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(14),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  currentEpLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodySmall?.color,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              const Spacer(),
              if (widget.onRefresh != null)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: '刷新选集',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onRefresh,
                ),
              // 正/倒序切换胶囊 (带 iOS 弹性按压动效)
              BouncingScaleCard(
                scaleDown: 0.94,
                onTap: () => setState(() => _isDescOrder = !_isDescOrder),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(12),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isDescOrder
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        size: 13,
                        color: _isDescOrder
                            ? primaryColor
                            : theme.textTheme.bodyMedium?.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isDescOrder ? '倒序' : '正序',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _isDescOrder ? FontWeight.w700 : FontWeight.w500,
                          color: _isDescOrder
                              ? primaryColor
                              : theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. 多线路切换 iOS 胶囊条 (Roads Pills)
        if (widget.roads.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            child: Row(
              children: List.generate(widget.roads.length, (idx) {
                final isRoadActive = idx == _activeRoadIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  // 线路切换胶囊：采用即时响应的 InkWell，消除 BouncingScaleCard 按压回弹等待锁 (~300ms)
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() => _activeRoadIndex = idx);
                      widget.onRoadSelected?.call(idx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: isRoadActive
                            ? primaryColor.withValues(alpha: isDark ? 0.24 : 0.14)
                            : (isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isRoadActive
                              ? primaryColor.withValues(alpha: 0.5)
                              : (isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(10)),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isRoadActive) ...[
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            widget.roads[idx],
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isRoadActive ? FontWeight.w600 : FontWeight.normal,
                              color: isRoadActive ? primaryColor : theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

        // 3. 长番剧区间分页胶囊 (1-50, 51-100...)
        if (isMultiRange && numRanges > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            child: Row(
              children: List.generate(numRanges, (rIdx) {
                final rStart = rIdx * _rangeSize + 1;
                final rEnd = (rIdx + 1) * _rangeSize > total
                    ? total
                    : (rIdx + 1) * _rangeSize;
                final isRangeActive = rIdx == _selectedRangeIndex;
                final containsPlaying = widget.currentEpisode != null &&
                    widget.currentEpisode! >= rStart &&
                    widget.currentEpisode! <= rEnd;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  // 分页胶囊：采用即时响应的 InkWell，消除 300ms 点击等待延迟
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _selectedRangeIndex = rIdx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isRangeActive
                            ? primaryColor.withValues(alpha: isDark ? 0.22 : 0.12)
                            : (isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(6)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isRangeActive
                              ? primaryColor.withValues(alpha: 0.45)
                              : (isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(8)),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$rStart-$rEnd',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isRangeActive ? FontWeight.w600 : FontWeight.normal,
                              color: isRangeActive ? primaryColor : theme.textTheme.bodySmall?.color,
                            ),
                          ),
                          if (containsPlaying && !isRangeActive) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 4.5,
                              height: 4.5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

        const SizedBox(height: 4),

        // 4. 选集网格 (iOS 精致轻量卡片)
        Expanded(
          child: epList.isEmpty
              ? Center(
                  child: Text(
                    '暂无可用分集',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final crossAxisCount = maxWidth >= 520
                        ? (maxWidth / 90).floor().clamp(4, 8)
                        : 4;
                    const double spacing = 8.0;
                    const double horizontalPadding = 32.0; // 16 * 2
                    final itemWidth = (maxWidth -
                            horizontalPadding -
                            (crossAxisCount - 1) * spacing) /
                        crossAxisCount;
                    // 保持高度在精致小巧的 34px
                    final childAspectRatio = (itemWidth / 34.0).clamp(1.5, 3.2);

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: epList.length,
                      itemBuilder: (context, index) {
                        final ep = epList[index];
                        final itemIdx = ep - 1;
                        PlayableSlot? slot;
                        if (hasSlots && itemIdx >= 0 && itemIdx < slots.length) {
                          slot = slots[itemIdx];
                        }

                        // 线路在播隔离：仅当当前查看的线路与实际在播线路一致时才标记在播态；
                        // 多线路存在时若未指定 playingRoadIndex 绝不盲目全线路高亮
                        final isCurrentRoadPlaying = widget.playingRoadIndex != null
                            ? widget.playingRoadIndex == _activeRoadIndex
                            : (widget.roads.length <= 1);
                        final isPlaying = isCurrentRoadPlaying &&
                            (slot != null
                                ? (slot.canonicalEp == widget.currentEpisode)
                                : (ep == widget.currentEpisode));
                        final isWatched = !isPlaying &&
                            widget.watchedEpisodes.contains(slot?.canonicalEp ?? ep);
                        final cardTitle = slot != null ? slot.cardLabel : _resolveTitle(ep);

                        return BouncingScaleCard(
                          scaleDown: 0.95,
                          onTap: () {
                            if (slot != null) {
                              widget.onSelectSlot?.call(slot);
                              widget.onSelectEpisode(slot.canonicalEp);
                            } else {
                              widget.onSelectEpisode(ep);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isPlaying
                                  ? primaryColor
                                  : (isDark
                                      ? Colors.white.withAlpha(14)
                                      : Colors.black.withAlpha(7)),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: isPlaying
                                    ? primaryColor
                                    : (isDark
                                        ? Colors.white.withAlpha(18)
                                        : Colors.black.withAlpha(12)),
                                width: isPlaying ? 1.2 : 0.5,
                              ),
                              boxShadow: isPlaying
                                  ? [
                                      BoxShadow(
                                        color: primaryColor.withValues(alpha: 0.28),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isPlaying) ...[
                                      const _PlayingBarsAnimation(),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      cardTitle,
                                      style: TextStyle(
                                        color: isPlaying
                                            ? Colors.white
                                            : (isWatched
                                                ? theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6)
                                                : theme.textTheme.bodyMedium?.color),
                                        fontWeight: isPlaying
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        fontSize: 12.0,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
