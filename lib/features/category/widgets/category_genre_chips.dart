import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/category_controller.dart';
import '../models/category_constants.dart';

class CategoryGenreChips extends ConsumerWidget {
  final String? initialCategory;

  const CategoryGenreChips({super.key, this.initialCategory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedTag = ref.watch(
      categoryControllerProvider(initialCategory).select((s) => s.filter.selectedTag),
    );
    final isExpanded = ref.watch(
      categoryControllerProvider(initialCategory).select((s) => s.isTagExpanded),
    );
    final controller = ref.read(categoryControllerProvider(initialCategory).notifier);

    if (isExpanded) {
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
                  onTap: () => controller.toggleTagExpanded(false),
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
              children: CategoryConstants.popularTags.map((tag) {
                final isSelected = (selectedTag == null || selectedTag == '全部')
                    ? (tag == '全部')
                    : (selectedTag == tag);

                return ChoiceChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      controller.setTag(tag);
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
            itemCount: CategoryConstants.popularTags.length,
            itemBuilder: (context, index) {
              final tag = CategoryConstants.popularTags[index];
              final isSelected = (selectedTag == null || selectedTag == '全部')
                  ? (index == 0)
                  : (selectedTag == tag);

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      controller.setTag(tag);
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
                  onTap: () => controller.toggleTagExpanded(true),
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
}
