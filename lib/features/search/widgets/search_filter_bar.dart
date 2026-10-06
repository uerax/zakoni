import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/search_types.dart';

/// 搜索结果分类标签（全部/动漫/非动漫，带条目数量徽标）与排序切换栏
class SearchFilterBar extends StatelessWidget {
  final SearchFilterType currentFilter;
  final int allCount;
  final int animeCount;
  final int nonAnimeCount;
  final ValueChanged<SearchFilterType> onFilterChanged;

  final SearchSortType currentSort;
  final ValueChanged<SearchSortType> onSortChanged;

  const SearchFilterBar({
    super.key,
    required this.currentFilter,
    required this.allCount,
    required this.animeCount,
    required this.nonAnimeCount,
    required this.onFilterChanged,
    required this.currentSort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 500;

    final filterTabs = [
      (type: SearchFilterType.anime, label: '动漫', count: animeCount),
      (type: SearchFilterType.nonAnime, label: '非动漫', count: nonAnimeCount),
      (type: SearchFilterType.all, label: '全部', count: allCount),
    ];

    final sortOptions = [
      (type: SearchSortType.dateDesc, label: '最新放送'),
      (type: SearchSortType.defaultMatch, label: '默认匹配'),
      (type: SearchSortType.dateAsc, label: '最早放送'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 1. 分类标签胶囊组（动漫、非动漫、全部）
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: filterTabs.map((tab) {
                      final isActive = currentFilter == tab.type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onFilterChanged(tab.type);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? theme.colorScheme.secondaryContainer
                                  : theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tab.label,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isActive
                                        ? theme.colorScheme.onSecondaryContainer
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${tab.count})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                                    color: isActive
                                        ? theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.8)
                                        : theme.colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // 2. 排序控制组
              if (!isCompact) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '排序:',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ...sortOptions.map((opt) {
                      final isActive = currentSort == opt.type;
                      return Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onSortChanged(opt.type);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              opt.label,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isActive
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ] else ...[
                // 小屏下使用紧凑排序按钮 (M3 胶囊)
                PopupMenuButton<SearchSortType>(
                  initialValue: currentSort,
                  tooltip: '排序方式',
                  onSelected: (sort) {
                    HapticFeedback.selectionClick();
                    onSortChanged(sort);
                  },
                  position: PopupMenuPosition.under,
                  itemBuilder: (context) => sortOptions
                      .map(
                        (opt) => PopupMenuItem(
                          value: opt.type,
                          height: 38,
                          child: Text(
                            opt.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: currentSort == opt.type
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: currentSort == opt.type
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentSort.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
