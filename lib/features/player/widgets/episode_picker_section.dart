import 'package:flutter/material.dart';

/// 律动音波小动画（参考 animaku 正在播放时的 3 条律动小柱子）
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
      duration: const Duration(milliseconds: 900),
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
            _buildBar(4.0 + 8.0 * val),
            const SizedBox(width: 2),
            _buildBar(12.0 - 7.0 * val),
            const SizedBox(width: 2),
            _buildBar(6.0 + 6.0 * (1.0 - val)),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2.5,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

/// 参考 animaku MobileEpsSection 的选集组件
class EpisodePickerSection extends StatefulWidget {
  const EpisodePickerSection({
    super.key,
    required this.episodeCount,
    this.currentEpisode,
    required this.onSelectEpisode,
    this.onRefresh,
    this.roads = const ['官方主线路', '备用线路 2'],
    this.activeRoadIndex = 0,
    this.onRoadSelected,
    this.episodeTitles,
    this.watchedEpisodes = const {},
  });

  final int episodeCount;
  final int? currentEpisode;
  final ValueChanged<int> onSelectEpisode;
  final VoidCallback? onRefresh;
  final List<String> roads;
  final int activeRoadIndex;
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
    // 当外部选中新集数时，自动对其到对应区间分页
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

    final total = widget.episodeCount;
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
        ? '${widget.currentEpisode}/$total'
        : '共 $total 话';

    return Column(
      children: [
        // 1. 顶部操作栏（选集标题计数 + 刷新 + 正倒序切换）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Text(
                '选集',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  currentEpLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodySmall?.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              if (widget.onRefresh != null)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: '刷新选集',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onRefresh,
                ),
              // 正/倒序切换按钮
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => setState(() => _isDescOrder = !_isDescOrder),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _isDescOrder
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        size: 14,
                        color: _isDescOrder
                            ? theme.colorScheme.primary
                            : theme.textTheme.bodyMedium?.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isDescOrder ? '倒序' : '正序',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _isDescOrder
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _isDescOrder
                              ? theme.colorScheme.primary
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

        // 2. 多线路切换 Tabs（Roads Pills）
        if (widget.roads.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: List.generate(widget.roads.length, (idx) {
                final isRoadActive = idx == _activeRoadIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(widget.roads[idx]),
                    selected: isRoadActive,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _activeRoadIndex = idx);
                        widget.onRoadSelected?.call(idx);
                      }
                    },
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isRoadActive ? FontWeight.bold : FontWeight.normal,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }),
            ),
          ),

        // 3. 长番剧区间分页 Tabs (1-50, 51-100...)
        if (isMultiRange && numRanges > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$rStart-$rEnd'),
                        if (containsPlaying && !isRangeActive) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    selected: isRangeActive,
                    onSelected: (_) =>
                        setState(() => _selectedRangeIndex = rIdx),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }),
            ),
          ),

        const Divider(height: 1, thickness: 0.5),

        // 4. 选集网格
        Expanded(
          child: epList.isEmpty
              ? const Center(child: Text('暂无可用分集'))
              : GridView.builder(
                  padding: const EdgeInsets.all(14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.55,
                  ),
                  itemCount: epList.length,
                  itemBuilder: (context, index) {
                    final ep = epList[index];
                    final isPlaying = ep == widget.currentEpisode;
                    final isWatched =
                        !isPlaying && widget.watchedEpisodes.contains(ep);
                    final primaryColor = theme.colorScheme.primary;

                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => widget.onSelectEpisode(ep),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? primaryColor
                              : (isDark
                                  ? const Color(0xFF222226)
                                  : const Color(0xFFF0F1F5)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isPlaying
                                ? primaryColor
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.04)),
                            width: isPlaying ? 1.5 : 1.0,
                          ),
                          boxShadow: isPlaying
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.35),
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
                                  const SizedBox(width: 5),
                                ],
                                Text(
                                  _resolveTitle(ep),
                                  style: TextStyle(
                                    color: isPlaying
                                        ? Colors.white
                                        : (isWatched
                                            ? theme.textTheme.bodySmall?.color
                                            : theme.textTheme.bodyMedium?.color),
                                    fontWeight: isPlaying
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
