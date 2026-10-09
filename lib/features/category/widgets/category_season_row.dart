import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/category_controller.dart';
import '../controllers/category_state.dart';
import '../models/category_constants.dart';

class CategorySeasonRow extends ConsumerWidget {
  final CategoryInitialArgs initialArgs;

  const CategorySeasonRow({
    super.key,
    this.initialArgs = const CategoryInitialArgs(),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedMonth = ref.watch(
      categoryControllerProvider(initialArgs).select((s) => s.filter.selectedMonth),
    );
    final selectedYear = ref.watch(
      categoryControllerProvider(initialArgs).select((s) => s.filter.selectedYear),
    );
    final controller = ref.read(categoryControllerProvider(initialArgs).notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 500;

        final items = CategoryConstants.seasons.map((s) {
          final isSelected = (selectedMonth == null || selectedMonth == 0)
              ? (s.month == 0)
              : (selectedMonth == s.month);

          final isRealCurrentMonth = s.month == CategoryConstants.currentSeasonMonth &&
              (selectedYear == null || selectedYear == CategoryConstants.currentYear);

          final capsule = Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => controller.setMonth(s.month),
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
}
