import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common/widgets/instant_dropdown_button.dart';
import '../controllers/category_controller.dart';
import '../models/category_constants.dart';

class CategoryFilterBar extends ConsumerWidget {
  final String? initialCategory;

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

    // 采用 Row + Expanded 均分 3 列布局：
    // 在所有手机屏幕宽度（360dp~430dp）上整齐自适应排满整行，彻底消除横向滚动与溢出
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // 1. 年份下拉菜单
          Expanded(
            child: _buildYearDropdownMenu(context, ref, controller, selectedYear, theme, isDark),
          ),
          const SizedBox(width: 8),
          // 2. 季度下拉菜单（全部、春、夏、秋、冬）
          Expanded(
            child: _buildSeasonDropdownMenu(context, ref, controller, selectedMonth, theme, isDark),
          ),
          const SizedBox(width: 8),
          // 3. 排序下拉菜单（热度、评分、时间）
          Expanded(
            child: _buildSortDropdownMenu(context, ref, controller, selectedSort, theme, isDark),
          ),
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

    final years = <int?>[null];
    for (int y = CategoryConstants.currentYear; y >= 1980; y--) {
      years.add(y);
    }

    return InstantDropdownButton<int?>(
      items: years,
      selectedValue: selectedYear,
      menuWidth: 120,
      maxMenuHeight: 280,
      alignRight: false,
      onSelected: controller.setYear,
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
        height: 32,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                  color: isHighlight
                      ? theme.colorScheme.primary
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
      menuWidth: 140,
      maxMenuHeight: 240,
      alignRight: false,
      onSelected: controller.setMonth,
      itemBuilder: (context, m, isSelected) {
        final opt = seasonOptions.firstWhere((s) => s.month == m);
        return Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          color: isSelected
              ? theme.colorScheme.primary.withAlpha(isDark ? 35 : 18)
              : Colors.transparent,
          child: Row(
            children: [
              Text(
                opt.name,
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
        height: 32,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                  color: isHighlight
                      ? theme.colorScheme.primary
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
      menuWidth: 110,
      maxMenuHeight: 180,
      alignRight: true,
      onSelected: controller.setSort,
      itemBuilder: (context, key, isSelected) {
        final opt = CategoryConstants.sortOptions.firstWhere((s) => s.key == key);
        return Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          color: isSelected
              ? theme.colorScheme.primary.withAlpha(isDark ? 35 : 18)
              : Colors.transparent,
          child: Row(
            children: [
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
        height: 32,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(10),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                '排序: ${curSort.label}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
}
