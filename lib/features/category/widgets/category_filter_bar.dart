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
    final selectedSort = ref.watch(
      categoryControllerProvider(initialCategory).select((s) => s.filter.selectedSort),
    );
    final isDefaultState = ref.watch(
      categoryControllerProvider(initialCategory).select((s) => s.filter.isDefaultState),
    );
    final controller = ref.read(categoryControllerProvider(initialCategory).notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // 左侧：年份下拉菜单
          _buildYearDropdownMenu(context, ref, controller, selectedYear, theme, isDark),
          const Spacer(),
          // 中间：若非默认条件，展示快速“重置”小按钮，点击复原回初始状态
          if (!isDefaultState) ...[
            _buildResetActionChip(controller, theme, isDark),
            const SizedBox(width: 8),
          ],
          // 右侧：排序下拉菜单
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

    final years = <int?>[null];
    for (int y = CategoryConstants.currentYear; y >= 1980; y--) {
      years.add(y);
    }

    return InstantDropdownButton<int?>(
      items: years,
      selectedValue: selectedYear,
      menuWidth: 136,
      maxMenuHeight: 300,
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
      menuWidth: 128,
      maxMenuHeight: 200,
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

  Widget _buildResetActionChip(
    CategoryController controller,
    ThemeData theme,
    bool isDark,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: controller.resetToDefault,
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
                Icons.restart_alt_rounded,
                size: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(width: 3),
              Text(
                '重置',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
