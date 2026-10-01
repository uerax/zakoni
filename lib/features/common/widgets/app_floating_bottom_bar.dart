import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppFloatingNavItem {
  final IconData unselectedIcon;
  final IconData selectedIcon;

  const AppFloatingNavItem({
    required this.unselectedIcon,
    required this.selectedIcon,
  });
}

/// 苹果悬浮极简纯图标毛玻璃胶囊底栏（Apple Floating Frosted Dock）：
/// 1. 外层扩散阴影，内层通过 ClipRRect + BackdropFilter(sigma: 20) 实现通透的苹果磨砂毛玻璃质感；
/// 2. 纯图标极简布局，移除多余文字，高度精简为 52px，最大宽度 280px；
/// 3. 通透半透明底色（约 68% 透明度），结合 Scaffold(extendBody: true) 实现内容穿透与动态高斯模糊。
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
              maxWidth: 280,
              minHeight: 52,
              maxHeight: 52,
            ),
            // 外层：提供悬浮弥散阴影
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
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
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    decoration: BoxDecoration(
                      // 高透磨砂质感底色：约 68%~70% 不透明度，确保底层卡片与内容色彩能清晰折射透出
                      color: isDark
                          ? const Color(0xB31C1C1E)
                          : Colors.white.withAlpha(175),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withAlpha(30)
                            : Colors.black.withAlpha(15),
                        width: 1.2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // 平滑跟随的药丸指示器滑块
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 240),
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
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: isDark
                                      ? primaryColor.withAlpha(55)
                                      : primaryColor.withAlpha(28),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 各导航项纯图标展示
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
                                child: Center(
                                  child: Icon(
                                    isSelected ? item.selectedIcon : item.unselectedIcon,
                                    color: itemColor,
                                    size: 24,
                                  ),
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
