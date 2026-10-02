import 'package:flutter/material.dart';
import '../../../core/network/bangumi_client.dart';

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

class _CategoryPageState extends State<CategoryPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Animaku / Bangumi 经典热门分类题材标签
  static const _popularTags = [
    '全部',
    'TV',
    '剧场版',
    'OVA',
    '热血',
    '奇幻',
    '治愈',
    '校园',
    '日常',
    '科幻',
    '战斗',
    '悬疑',
    '恋爱',
    '搞笑',
  ];

  int _selectedTagIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      final index = _popularTags.indexOf(widget.initialCategory!);
      if (index >= 0) {
        _selectedTagIndex = index;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final safeTop = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 底层动态微弱环境光晕
          Positioned(
            top: -100,
            left: -60,
            right: -60,
            height: 380,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.25),
                    radius: 0.85,
                    colors: [
                      theme.colorScheme.primary.withAlpha(isDark ? 30 : 18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 顶部标题
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
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
                      ],
                    ),
                  ),
                ),

                // 热门标签横向胶囊筛选栏
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 42,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _popularTags.length,
                      itemBuilder: (context, index) {
                        final isSelected = _selectedTagIndex == index;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_popularTags[index]),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedTagIndex = index;
                                });
                              }
                            },
                            labelStyle: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                            selectedColor: theme.colorScheme.primary,
                            backgroundColor: isDark
                                ? Colors.white.withAlpha(20)
                                : Colors.black.withAlpha(12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : (isDark
                                        ? Colors.white.withAlpha(25)
                                        : Colors.black.withAlpha(15)),
                              ),
                            ),
                            showCheckmark: false,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),

                // 中间占位说明区域（预留多维分类与筛选接口）
                SliverToBoxAdapter(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withAlpha(isDark ? 40 : 20),
                          ),
                          child: Icon(
                            Icons.grid_view_rounded,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '「${_popularTags[_selectedTagIndex]}」分类检索中',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '后续将支持年份、季度、评分等多维聚合筛选',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 底部留出 96px 避让悬浮毛玻璃 Dock 栏
                const SliverToBoxAdapter(
                  child: SizedBox(height: 96),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
