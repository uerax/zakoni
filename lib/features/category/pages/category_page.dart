import 'package:flutter/material.dart';
import '../../../core/models/bangumi/bangumi_item.dart';
import '../../../core/network/bangumi_client.dart';
import '../../common/widgets/anime_card.dart';
import '../../common/widgets/shimmer_loading.dart';

class CategoryPage extends StatefulWidget {
  final BangumiClient client;
  final String? initialCategory;

  const CategoryPage({
    super.key,
    required this.client,
    this.initialCategory,
  });

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Animaku / Bangumi 经典分类题材标签
  static const _popularTags = [
    '全部',
    'TV',
    '剧场版',
    'OVA',
    '热血',
    '奇幻',
    '战斗',
    '校园',
    '日常',
    '治愈',
    '科幻',
    '悬疑',
    '恋爱',
    '搞笑',
    '异世界',
    '机战',
    '音乐',
    '运动',
    '偶像',
    '冒险',
    '百合',
    '后宫',
    '致郁',
    '催泪',
  ];

  static const _sortOptions = [
    (key: 'heat', label: '热度优先', icon: '🔥'),
    (key: 'score', label: '评分最高', icon: '⭐'),
    (key: 'rank', label: '排名靠前', icon: '🏆'),
    (key: 'date', label: '最新放送', icon: '🕒'),
  ];

  // 季度简明标签：精简为 图标 + 月份，适配所有手机屏幕宽度，绝不溢出换行
  static const _seasons = [
    (month: 0, label: '全部'),
    (month: 1, label: '❄️ 1月'),
    (month: 4, label: '🌸 4月'),
    (month: 7, label: '☀️ 7月'),
    (month: 10, label: '🍁 10月'),
  ];

  static const int _pageSize = 24;

  static int get currentYear => DateTime.now().year;

  /// 计算当前现实播放季度的起始月份 (1/4/7/10)
  static int get currentSeasonMonth {
    final m = DateTime.now().month;
    if (m <= 3) return 1;
    if (m <= 6) return 4;
    if (m <= 9) return 7;
    return 10;
  }

  /// 季度名称简写
  static String seasonShortName(int month) {
    switch (month) {
      case 1:
        return '冬季番';
      case 4:
        return '春季番';
      case 7:
        return '夏季番';
      case 10:
        return '秋季番';
      default:
        return '全年';
    }
  }

  /// 构造 Bangumi 规范的季度放送日期连续区间表达式 (例如 4月季为 >=YYYY-04-01 到 <YYYY-07-01)
  static List<String> seasonAirDate(int year, int month) {
    switch (month) {
      case 1:
        return ['>=$year-01-01', '<$year-04-01'];
      case 4:
        return ['>=$year-04-01', '<$year-07-01'];
      case 7:
        return ['>=$year-07-01', '<$year-10-01'];
      case 10:
        return ['>=$year-10-01', '<${year + 1}-01-01'];
      default:
        return ['>=$year-01-01', '<=$year-12-31'];
    }
  }

  // 筛选状态
  String? _selectedTag;
  int? _selectedYear;
  int? _selectedMonth;
  String _selectedSort = 'heat';

  // 题材标签栏展开/收起状态
  bool _isTagExpanded = false;

  // 列表数据与加载状态
  final List<BangumiItem> _items = [];
  int _total = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _requestSeq = 0; // 防抖序列号，防止快速切换筛选条件时发生响应竞态覆写

  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  /// 是否处于默认的“当季新番”状态
  bool get isCurrentSeason =>
      _selectedYear == currentYear &&
      _selectedMonth == currentSeasonMonth &&
      (_selectedTag == null || _selectedTag == '全部') &&
      _selectedSort == 'heat';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // 初始化筛选参数：若外部指定 initialCategory (如剧场版/OVA)，则聚焦该分类并展示全量历史
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _selectedTag = widget.initialCategory;
      _selectedYear = null;
      _selectedMonth = null;
    } else {
      // 默认核心体验：根据当前现实时间自动锁定【当前年份 + 当前季度】(当季新番)
      _selectedTag = null;
      _selectedYear = currentYear;
      _selectedMonth = currentSeasonMonth;
    }

    _fetchFirstPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CategoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当线路切换或初始分类变化时，自动重新加载最新数据
    if (oldWidget.client.sourcePreset != widget.client.sourcePreset ||
        oldWidget.initialCategory != widget.initialCategory) {
      if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
        _selectedTag = widget.initialCategory;
        _selectedYear = null;
        _selectedMonth = null;
      }
      _fetchFirstPage();
    }
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final shouldShowTop = offset > 450;
    if (shouldShowTop != _showBackToTop) {
      setState(() {
        _showBackToTop = shouldShowTop;
      });
    }

    // 触底预加载：距离底部不足 350px 时提前静默拉取下一页
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 350 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  /// 构建当前筛选条件的日期与参数，向 Bangumi 发起第一页请求
  Future<void> _fetchFirstPage() async {
    final seq = ++_requestSeq;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tagList = (_selectedTag != null && _selectedTag != '全部')
          ? [_selectedTag!]
          : null;

      List<String>? airDate;
      int? yearParam;

      if (_selectedMonth != null && _selectedMonth! > 0) {
        final targetYear = _selectedYear ?? currentYear;
        airDate = seasonAirDate(targetYear, _selectedMonth!);
      } else if (_selectedYear != null) {
        yearParam = _selectedYear;
      }

      final result = await widget.client.searchWithTotal(
        '',
        tags: tagList,
        year: yearParam,
        airDate: airDate,
        sort: _selectedSort,
        limit: _pageSize,
        offset: 0,
      );

      if (seq != _requestSeq || !mounted) return;

      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _total = result.total;
        _hasMore = result.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      if (seq != _requestSeq || !mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// 滚动触底加载下一页数据
  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final tagList = (_selectedTag != null && _selectedTag != '全部')
          ? [_selectedTag!]
          : null;

      List<String>? airDate;
      int? yearParam;

      if (_selectedMonth != null && _selectedMonth! > 0) {
        final targetYear = _selectedYear ?? currentYear;
        airDate = seasonAirDate(targetYear, _selectedMonth!);
      } else if (_selectedYear != null) {
        yearParam = _selectedYear;
      }

      final result = await widget.client.searchWithTotal(
        '',
        tags: tagList,
        year: yearParam,
        airDate: airDate,
        sort: _selectedSort,
        limit: _pageSize,
        offset: _items.length,
      );

      if (!mounted) return;

      setState(() {
        _items.addAll(result.items);
        _total = result.total;
        _hasMore = result.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  /// 一键复位至“当季新番”
  void _resetToCurrentSeason() {
    if (isCurrentSeason) return;
    setState(() {
      _selectedTag = null;
      _selectedYear = currentYear;
      _selectedMonth = currentSeasonMonth;
      _selectedSort = 'heat';
      _isTagExpanded = false;
    });
    _fetchFirstPage();
  }

  /// 清空所有筛选条件，查看全部历史番剧
  void _clearAllFilters() {
    setState(() {
      _selectedTag = null;
      _selectedYear = null;
      _selectedMonth = null;
      _selectedSort = 'heat';
      _isTagExpanded = false;
    });
    _fetchFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 顶部动态微弱环境光晕，营造轻奢通透质感
          Positioned(
            top: -120,
            left: -60,
            right: -60,
            height: 380,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 0.85,
                    colors: [
                      theme.colorScheme.primary.withAlpha(isDark ? 36 : 22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _fetchFirstPage,
              displacement: 20,
              color: theme.colorScheme.primary,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // 1. 顶部主标题与“🎯 当季”快捷复位按钮
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            '⊞ 分类索引',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                          ),
                          const Spacer(),
                          // 当季快速直达指示器
                          _buildSeasonAnchorButton(theme, isDark),
                        ],
                      ),
                    ),
                  ),

                  // 2. 第一行：题材分类栏（支持横向滑动 + 右侧【展开全览网格】）
                  SliverToBoxAdapter(
                    child: _buildGenreTagsSection(theme, isDark),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // 3. 第二行：年份与排序放在同一行（使用极速轻量原地 Dropdown 菜单）
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          // 左侧：年份下拉菜单
                          _buildYearDropdownMenu(theme, isDark),
                          const Spacer(),
                          // 中间：若非默认条件，展示快速“清空”小按钮
                          if (!isCurrentSeason) ...[
                            _buildResetActionChip(theme, isDark),
                            const SizedBox(width: 8),
                          ],
                          // 右侧：排序下拉菜单
                          _buildSortDropdownMenu(theme, isDark),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // 4. 第三行：春夏秋冬季度栏（手机窄屏均分整行，宽屏/平板固定宽度 74dp 紧凑居左不拉伸）
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: _buildSeasonsRow(theme, isDark),
                    ),
                  ),

                  // 5. 动态状态与数量摘要副标题
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        _buildFilterSummary(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant.withAlpha(200),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // 6. 内容主体区域
                  _buildContentSliver(theme, isDark),

                  // 7. 底部加载更多或触底提示
                  if (_isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                        ),
                      ),
                    )
                  else if (!_hasMore && _items.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            '已经翻到底啦 · 共 $_total 部',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 底部预留 96px 避让主导航栏悬浮毛玻璃胶囊 Dock
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              ),
            ),
          ),

          // 浮动返回顶部按钮
          if (_showBackToTop)
            Positioned(
              right: 18,
              bottom: 110,
              child: FloatingActionButton.small(
                onPressed: _scrollToTop,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                elevation: 3,
                child: const Icon(Icons.arrow_upward_rounded, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  /// 第一行：题材分类栏（支持横向滑动 + 右侧【展开全览网格】）
  Widget _buildGenreTagsSection(ThemeData theme, bool isDark) {
    if (_isTagExpanded) {
      // 展开状态：全量 24 个标签以网格/流式整齐平铺，方便一眼全览点选
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E22) : Colors.white.withAlpha(240),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 50 : 15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '全部题材分类',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleSmall?.color,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isTagExpanded = false;
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '收起',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _popularTags.map((tag) {
                final isSelected = (_selectedTag == null || _selectedTag == '全部')
                    ? (tag == '全部')
                    : (_selectedTag == tag);

                return ChoiceChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedTag = (tag == '全部') ? null : tag;
                        _isTagExpanded = false; // 选完自动优雅收起
                      });
                      _fetchFirstPage();
                    }
                  },
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  selectedColor: theme.colorScheme.primary,
                  backgroundColor: isDark
                      ? Colors.white.withAlpha(16)
                      : Colors.black.withAlpha(10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12)),
                    ),
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    // 常规收起状态：左侧横向滚动 + 右侧吸边【⊞ 展开】按钮
    return SizedBox(
      height: 36,
      child: Stack(
        children: [
          // 横向滚动的标签列表
          ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 14, right: 46),
            itemCount: _popularTags.length,
            itemBuilder: (context, index) {
              final tag = _popularTags[index];
              final isSelected = (_selectedTag == null || _selectedTag == '全部')
                  ? (index == 0)
                  : (_selectedTag == tag);

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedTag = (index == 0) ? null : tag;
                      });
                      _fetchFirstPage();
                    }
                  },
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  selectedColor: theme.colorScheme.primary,
                  backgroundColor: isDark
                      ? Colors.white.withAlpha(16)
                      : Colors.black.withAlpha(10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12)),
                    ),
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              );
            },
          ),

          // 右侧固定展开按钮 (带毛玻璃羽化遮罩)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.only(left: 12, right: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    theme.scaffoldBackgroundColor.withAlpha(0),
                    theme.scaffoldBackgroundColor.withAlpha(230),
                    theme.scaffoldBackgroundColor,
                  ],
                ),
              ),
              child: Center(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isTagExpanded = true;
                    });
                  },
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12),
                      border: Border.all(
                        color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(15),
                      ),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 第二行左侧：年份下拉选择器 (极速 0ms 展开轻量原生 Dropdown 菜单)
  Widget _buildYearDropdownMenu(ThemeData theme, bool isDark) {
    final label = _selectedYear == null ? '全部年份' : '$_selectedYear年';
    final isHighlight = _selectedYear != null;

    final years = <int?>[null];
    for (int y = currentYear; y >= 1980; y--) {
      years.add(y);
    }

    return _InstantDropdownButton<int?>(
      items: years,
      selectedValue: _selectedYear,
      menuWidth: 136,
      maxMenuHeight: 300,
      alignRight: false,
      onSelected: (y) {
        if (_selectedYear != y) {
          setState(() {
            _selectedYear = y;
          });
          _fetchFirstPage();
        }
      },
      itemBuilder: (context, y, isSelected) {
        return Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          color: isSelected
              ? theme.colorScheme.primary.withAlpha(isDark ? 35 : 18)
              : Colors.transparent,
          child: Row(
            children: [
              Text(
                y == null ? '全部年份' : '$y年',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isHighlight
              ? theme.colorScheme.primary.withAlpha(isDark ? 45 : 22)
              : (isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(10)),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isHighlight
                ? theme.colorScheme.primary.withAlpha(160)
                : (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12)),
            width: isHighlight ? 1.0 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 13,
              color: isHighlight
                  ? theme.colorScheme.primary
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                color: isHighlight
                    ? theme.colorScheme.primary
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: isHighlight
                  ? theme.colorScheme.primary
                  : (isDark ? Colors.white54 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  /// 第二行右侧：排序下拉选择器 (极速 0ms 展开轻量原生 Dropdown 菜单)
  Widget _buildSortDropdownMenu(ThemeData theme, bool isDark) {
    final curSort = _sortOptions.firstWhere((s) => s.key == _selectedSort);

    return _InstantDropdownButton<String>(
      items: _sortOptions.map((s) => s.key).toList(),
      selectedValue: _selectedSort,
      menuWidth: 128,
      maxMenuHeight: 200,
      alignRight: true,
      onSelected: (s) {
        if (_selectedSort != s) {
          setState(() {
            _selectedSort = s;
          });
          _fetchFirstPage();
        }
      },
      itemBuilder: (context, key, isSelected) {
        final opt = _sortOptions.firstWhere((s) => s.key == key);
        return Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          color: isSelected
              ? theme.colorScheme.primary.withAlpha(isDark ? 35 : 18)
              : Colors.transparent,
          child: Row(
            children: [
              Text(opt.icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Text(
                opt.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(10),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(curSort.icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(
              curSort.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  /// 第三行：春夏秋冬季度栏（手机窄屏均分整行，宽屏/平板固定宽度 74dp 紧凑居左不拉伸）
  Widget _buildSeasonsRow(ThemeData theme, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 500;

        final items = _seasons.map((s) {
          final isSelected = (_selectedMonth == null || _selectedMonth == 0)
              ? (s.month == 0)
              : (_selectedMonth == s.month);

          final isRealCurrentMonth = s.month == currentSeasonMonth &&
              (_selectedYear == null || _selectedYear == currentYear);

          final capsule = Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedMonth = s.month == 0 ? null : s.month;
                  // 友好联动：若此前为“全部年份”，点击具体季度自动对齐到今年
                  if (_selectedMonth != null && _selectedYear == null) {
                    _selectedYear = currentYear;
                  }
                });
                _fetchFirstPage();
              },
              borderRadius: BorderRadius.circular(100),
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : (isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(10)),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12)),
                    width: 0.8,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // 现实季节指示光环小圆点
                    if (isRealCurrentMonth && !isSelected)
                      Positioned(
                        top: 4,
                        right: 6,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );

          if (isMobile) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: capsule,
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 74,
                child: capsule,
              ),
            );
          }
        }).toList();

        return Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: items,
        );
      },
    );
  }

  /// 构造顶部筛选摘要副标题
  String _buildFilterSummary() {
    if (_isLoading) return '💡 正在检索 Bangumi 动画条目...';

    final parts = <String>[];
    if (_selectedTag != null && _selectedTag != '全部') {
      parts.add('标签: $_selectedTag');
    }
    if (_selectedMonth != null && _selectedMonth! > 0) {
      final y = _selectedYear ?? currentYear;
      parts.add('$y年 ${seasonShortName(_selectedMonth!)}');
    } else if (_selectedYear != null) {
      parts.add('$_selectedYear年');
    } else {
      parts.add('全部年份');
    }

    final sortItem = _sortOptions.firstWhere((s) => s.key == _selectedSort);
    parts.add(sortItem.label);

    if (_total > 0) {
      parts.add('共 $_total 部');
    } else if (!_isLoading && _errorMessage == null) {
      parts.add('暂无匹配结果');
    }

    return '💡 ${parts.join(' · ')}';
  }

  /// 顶部“🎯 当季新番”快捷切换锚点
  Widget _buildSeasonAnchorButton(ThemeData theme, bool isDark) {
    final active = isCurrentSeason;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _resetToCurrentSeason,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? theme.colorScheme.primary.withAlpha(isDark ? 55 : 25)
                : (isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10)),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: active
                  ? theme.colorScheme.primary
                  : (isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(15)),
              width: active ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🎯 当季',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? theme.colorScheme.primary
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? theme.colorScheme.primary
                      : (isDark ? Colors.white.withAlpha(30) : Colors.black.withAlpha(20)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${currentYear.toString().substring(2)}${seasonShortName(currentSeasonMonth).substring(0, 1)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 一键清空重置胶囊
  Widget _buildResetActionChip(ThemeData theme, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _clearAllFilters,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(10),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(18),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.refresh_rounded,
                size: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(width: 3),
              Text(
                '清空',
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 页面主体 Sliver (骨架屏 / 错误态 / 空态 / 正常自适应网格)
  Widget _buildContentSliver(ThemeData theme, bool isDark) {
    // 1. 初次或切换条件加载中：呈现与 AnimeCard 1:1 的高性能流光骨架屏
    if (_isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.crossAxisExtent;
            final count = width < 500 ? 3 : (width < 750 ? 4 : (width < 1000 ? 5 : 6));
            return SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                childAspectRatio: 0.58,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => const ShimmerAnimeCard(),
                childCount: 12,
              ),
            );
          },
        ),
      );
    }

    // 2. 异常失败状态
    if (_errorMessage != null && _items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                '获取番剧列表失败',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.redAccent),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _fetchFirstPage,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重新尝试'),
              ),
            ],
          ),
        ),
      );
    }

    // 3. 空结果状态
    if (_items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(10),
                ),
                child: Icon(
                  Icons.inbox_rounded,
                  size: 36,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '未找到匹配的番剧条目',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '可尝试放宽年份或切换为其他题材分类',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('清空筛选'),
              ),
            ],
          ),
        ),
      );
    }

    // 4. 正常数据呈现：自适应 3 列（移动端推荐）/ 4~6 列（宽屏）网格瀑布流
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final count = width < 500 ? 3 : (width < 750 ? 4 : (width < 1000 ? 5 : 6));

          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: count,
              childAspectRatio: 0.58,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _items[index];
                return AnimeCard(
                  key: ValueKey('anime_cat_${item.id}'),
                  item: item,
                  compact: true,
                );
              },
              childCount: _items.length,
            ),
          );
        },
      ),
    );
  }
}

/// 高性能极速原地下拉菜单组件：
/// 1. 彻底规避 Flutter 原生 PopupMenuButton 的 300ms 路由 push 延迟与全量同步 layout 掉帧；
/// 2. 采用纯 OverlayEntry 原位弹窗 + 定高 ListView.builder 懒加载 (O(1) 绘制)，50 年份秒开无卡顿；
/// 3. 支持自动定位到当前选中项的滚动偏移，点击外部瞬间移除。
class _InstantDropdownButton<T> extends StatefulWidget {
  final Widget child;
  final List<T> items;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final Widget Function(BuildContext context, T value, bool isSelected) itemBuilder;
  final double menuWidth;
  final double maxMenuHeight;
  final bool alignRight;

  const _InstantDropdownButton({
    required this.child,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    required this.itemBuilder,
    this.menuWidth = 136,
    this.maxMenuHeight = 280,
    this.alignRight = false,
  });

  @override
  State<_InstantDropdownButton<T>> createState() => _InstantDropdownButtonState<T>();
}

class _InstantDropdownButtonState<T> extends State<_InstantDropdownButton<T>>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlayEntry;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _closeMenu(immediately: true);
    _animController.dispose();
    super.dispose();
  }

  void _closeMenu({bool immediately = false}) {
    if (_overlayEntry == null) return;
    if (immediately) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    } else {
      _animController.reverse().then((_) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      });
    }
  }

  void _toggleMenu() {
    if (_overlayEntry != null) {
      _closeMenu();
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    double left = widget.alignRight
        ? (offset.dx + size.width - widget.menuWidth)
        : offset.dx;

    // 屏幕边缘安全间距
    if (left < 10) left = 10;
    if (left + widget.menuWidth > screenWidth - 10) {
      left = screenWidth - widget.menuWidth - 10;
    }

    double top = offset.dy + size.height + 4;
    // 如果底部空间不足，向上弹出
    if (top + widget.maxMenuHeight > screenHeight - 60) {
      top = offset.dy - widget.maxMenuHeight - 4;
    }

    final selectedIndex = widget.items.indexOf(widget.selectedValue);
    final initialOffset = selectedIndex > 0
        ? (selectedIndex * 38.0).clamp(0.0, widget.items.length * 38.0)
        : 0.0;
    final scrollController = ScrollController(
      initialScrollOffset: initialOffset > 80 ? initialOffset - 38.0 : 0.0,
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // 全屏透明遮罩，点击外部瞬间关闭
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _closeMenu(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: widget.menuWidth,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  alignment: widget.alignRight ? Alignment.topRight : Alignment.topLeft,
                  child: Material(
                    elevation: 10,
                    color: isDark ? const Color(0xFF222226) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      constraints: BoxConstraints(maxHeight: widget.maxMenuHeight),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(15),
                        ),
                      ),
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shrinkWrap: true,
                        itemCount: widget.items.length,
                        itemExtent: 38,
                        itemBuilder: (context, index) {
                          final item = widget.items[index];
                          final isSelected = item == widget.selectedValue;
                          return InkWell(
                            onTap: () {
                              _closeMenu();
                              widget.onSelected(item);
                            },
                            child: widget.itemBuilder(context, item, isSelected),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    _animController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleMenu,
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}
