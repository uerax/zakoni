import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/widgets/instant_dropdown_button.dart';
import '../controllers/category_controller.dart';
import '../models/category_constants.dart';

class CategoryFilterBar extends ConsumerWidget {
  final String? initialCategory;

  static final List<int?> _yearList = [
    null,
    for (int y = CategoryConstants.currentYear; y >= 1980; y--) y,
  ];

  const CategoryFilterBar({super.key, this.initialCategory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedYear = ref.watch(
      categoryControllerProvider(initialCategory).select((s) => s.filter.selectedYear),
    );
    final selectedMonth = ref.watch(
      categoryControllerProvider(initialCategory).select((s) => s.filter.selectedMonth),
    );
    final selectedSort = ref.watch(
      categoryControllerProvider(initialCategory).select((s) => s.filter.selectedSort),
    );
    final controller = ref.read(categoryControllerProvider(initialCategory).notifier);

    // 左侧紧凑放置【年份】+【季度】，右侧放置【排序】，中间弹性留白
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // 1. 年份下拉菜单
          _buildYearDropdownMenu(context, ref, controller, selectedYear, theme, isDark),
          const SizedBox(width: 8),
          // 2. 季度下拉菜单（全部、春、夏、秋、冬）
          _buildSeasonDropdownMenu(context, ref, controller, selectedMonth, theme, isDark),
          // 3. 中间弹性留白
          const Spacer(),
          // 4. 排序下拉菜单（热度、评分、时间）
          _buildSortDropdownMenu(context, ref, controller, selectedSort, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildYearDropdownMenu(
    BuildContext context,
    WidgetRef ref,
    CategoryController controller,
    int? selectedYear,
    ThemeData theme,
    bool isDark,
  ) {
    final label = selectedYear == null ? '全部年份' : '$selectedYear年';
    final isHighlight = selectedYear != null;

    return InstantDropdownButton<int?>(
      items: _yearList,
      selectedValue: selectedYear,
      menuWidth: 110,
      maxMenuHeight: 280,
      alignRight: false,
      onSelected: controller.setYear,
      itemBuilder: (context, y, isSelected) {
        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          color: isSelected
              ? theme.colorScheme.primary.withAlpha(isDark ? 35 : 18)
              : Colors.transparent,
          child: Row(
            children: [
              Text(
                y == null ? '全部年份' : '$y年',
                style: TextStyle(
                  fontSize: 12,
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
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        );
      },
      child: Container(
        height: 30,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isHighlight
              ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.14)
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                color: isHighlight
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: isHighlight
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonDropdownMenu(
    BuildContext context,
    WidgetRef ref,
    CategoryController controller,
    int? selectedMonth,
    ThemeData theme,
    bool isDark,
  ) {
    final effectiveMonth = selectedMonth ?? 0;
    final isHighlight = effectiveMonth > 0;

    String label;
    switch (effectiveMonth) {
      case 1:
        label = '1月 · 冬';
        break;
      case 4:
        label = '4月 · 春';
        break;
      case 7:
        label = '7月 · 夏';
        break;
      case 10:
        label = '10月 · 秋';
        break;
      default:
        label = '全部季度';
    }

    final seasonOptions = <({int month, String name})>[
      (month: 0, name: '全部季度'),
      (month: 4, name: '4月 · 春季'),
      (month: 7, name: '7月 · 夏季'),
      (month: 10, name: '10月 · 秋季'),
      (month: 1, name: '1月 · 冬季'),
    ];

    return InstantDropdownButton<int>(
      items: seasonOptions.map((s) => s.month).toList(),
      selectedValue: effectiveMonth,
      menuWidth: 125,
      maxMenuHeight: 240,
      alignRight: false,
      onSelected: controller.setMonth,
      itemBuilder: (context, m, isSelected) {
        final opt = seasonOptions.firstWhere((s) => s.month == m);
        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          color: isSelected
              ? theme.colorScheme.primary.withAlpha(isDark ? 35 : 18)
              : Colors.transparent,
          child: Row(
            children: [
              Text(
                opt.name,
                style: TextStyle(
                  fontSize: 12,
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
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        );
      },
      child: Container(
        height: 30,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isHighlight
              ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.14)
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                color: isHighlight
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: isHighlight
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortDropdownMenu(
    BuildContext context,
    WidgetRef ref,
    CategoryController controller,
    String selectedSort,
    ThemeData theme,
    bool isDark,
  ) {
    final curSort = CategoryConstants.sortOptions.firstWhere(
      (s) => s.key == selectedSort,
      orElse: () => CategoryConstants.sortOptions.first,
    );

    return InstantDropdownButton<String>(
      items: CategoryConstants.sortOptions.map((s) => s.key).toList(),
      selectedValue: selectedSort,
      menuWidth: 100,
      maxMenuHeight: 180,
      alignRight: true,
      onSelected: controller.setSort,
      itemBuilder: (context, key, isSelected) {
        final opt = CategoryConstants.sortOptions.firstWhere((s) => s.key == key);
        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          color: isSelected
              ? theme.colorScheme.primary.withAlpha(isDark ? 35 : 18)
              : Colors.transparent,
          child: Row(
            children: [
              Text(
                opt.label,
                style: TextStyle(
                  fontSize: 12,
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
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        );
      },
      child: Container(
        height: 30,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort_rounded,
              size: 15,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              curSort.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
