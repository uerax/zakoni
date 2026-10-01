import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppFloatingNavItem {
  final IconData unselectedIcon;
  final IconData selectedIcon;
  final String label;

  const AppFloatingNavItem({
    required this.unselectedIcon,
    required this.selectedIcon,
    required this.label,
  });
}

/// 苹果悬浮胶囊底栏（Apple Floating Frosted Glass Bar）：
/// 1. 外层 Container 负责扩散阴影，内层通过 ClipRRect + BackdropFilter 实现纯正的高斯模糊毛玻璃；
///    之所以分两层，是因为 ClipRRect 会直接裁切掉同层级的 BoxShadow 投影，导致弥散悬浮阴影丢失。
/// 2. 内部带有跟随当前 Tab 平滑滑动的微透指示器滑块（AnimatedAlign）；
/// 3. 与 Scaffold(extendBody: true) 配合使用，使滚动列表内容在底栏下方穿透并呈现动态磨砂质感。
class AppFloatingBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppFloatingNavItem> items;

  const AppFloatingBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          safeBottom < 10 ? 12 : safeBottom + 2,
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 460,
              minHeight: 64,
              maxHeight: 64,
            ),
            // 外层：提供悬浮弥散阴影
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 80 : 25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              // 内层：高斯模糊毛玻璃裁剪
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      // 通透的磨砂半透底色：暗色 80% 黑，浅色 80% 白
                      color: isDark
                          ? const Color(0xCC1B1B1F)
                          : Colors.white.withAlpha(205),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withAlpha(36)
                            : Colors.black.withAlpha(18),
                        width: 1.2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // 平滑移动的跟随高亮指示器滑块
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          alignment: items.length > 1
                              ? AlignmentDirectional(
                                  -1 + 2 * currentIndex / (items.length - 1),
                                  0,
                                )
                              : Alignment.center,
                          child: FractionallySizedBox(
                            widthFactor: 1 / items.length,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: isDark
                                      ? primaryColor.withAlpha(55)
                                      : primaryColor.withAlpha(28),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 各导航项图标与文本
                        Row(
                          children: List.generate(items.length, (i) {
                            final isSelected = currentIndex == i;
                            final item = items[i];
                            final itemColor = isSelected
                                ? primaryColor
                                : (isDark ? Colors.white60 : const Color(0xFF6B7280));

                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (currentIndex == i) return;
                                  HapticFeedback.lightImpact();
                                  onTap(i);
                                },
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isSelected ? item.selectedIcon : item.unselectedIcon,
                                      color: itemColor,
                                      size: 22,
                                    ),
                                    const SizedBox(height: 2),
                                    AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 180),
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.2,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: itemColor,
                                      ),
                                      child: Text(
                                        item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
