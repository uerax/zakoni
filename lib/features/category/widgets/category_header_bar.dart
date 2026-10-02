import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/category_controller.dart';
import '../models/category_constants.dart';

class CategoryHeaderBar extends ConsumerWidget {
  final String? initialCategory;

  const CategoryHeaderBar({super.key, this.initialCategory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCurrentSeason = ref.watch(
      categoryControllerProvider(initialCategory).select((s) => s.filter.isCurrentSeason),
    );
    final controller = ref.read(categoryControllerProvider(initialCategory).notifier);

    return Padding(
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
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: controller.resetToCurrentSeason,
              borderRadius: BorderRadius.circular(100),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isCurrentSeason
                      ? theme.colorScheme.primary.withAlpha(isDark ? 55 : 25)
                      : (isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10)),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isCurrentSeason
                        ? theme.colorScheme.primary
                        : (isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(15)),
                    width: isCurrentSeason ? 1.2 : 0.8,
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
                        color: isCurrentSeason
                            ? theme.colorScheme.primary
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isCurrentSeason
                            ? theme.colorScheme.primary
                            : (isDark ? Colors.white.withAlpha(30) : Colors.black.withAlpha(20)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${CategoryConstants.currentYear.toString().substring(2)}${CategoryConstants.seasonShortName(CategoryConstants.currentSeasonMonth).substring(0, 1)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isCurrentSeason
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
