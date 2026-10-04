import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef NavItemWidgetBuilder = Widget Function(
  BuildContext context,
  Color color,
  bool isSelected,
);

class AppFloatingNavItem {
  final IconData? unselectedIcon;
  final IconData? selectedIcon;
  final NavItemWidgetBuilder? builder;

  const AppFloatingNavItem({
    this.unselectedIcon,
    this.selectedIcon,
    this.builder,
  }) : assert(
          builder != null || (unselectedIcon != null && selectedIcon != null),
          'Either builder or both unselectedIcon and selectedIcon must be provided',
        );

  const AppFloatingNavItem.builder({
    required NavItemWidgetBuilder this.builder,
  })  : unselectedIcon = null,
        selectedIcon = null;

  Widget buildIcon(BuildContext context, Color color, bool isSelected) {
    if (builder != null) {
      return builder!(context, color, isSelected);
    }
    return Icon(
      isSelected ? selectedIcon : unselectedIcon,
      color: color,
      size: 24,
    );
  }
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
                        // 平滑且带物理惯性回弹的药丸指示器滑块（Curves.easeOutBack 模拟物理过冲定格）
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
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

                        // 各导航项纯图标展示（结合 iOS 经典果冻弹簧微交互）
                        Row(
                          children: List.generate(items.length, (i) {
                            final isSelected = currentIndex == i;
                            final item = items[i];
                            final itemColor = isSelected
                                ? primaryColor
                                : (isDark ? Colors.white60 : const Color(0xFF6B7280));

                            return Expanded(
                              child: _BouncingNavItem(
                                isSelected: isSelected,
                                item: item,
                                color: itemColor,
                                onTap: () {
                                  if (currentIndex == i) return;
                                  HapticFeedback.lightImpact();
                                  onTap(i);
                                },
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

/// 仿 iOS 经典物理触控弹簧动效组件：
/// 当 Tab 被选中激活时，执行“下压(0.88) -> 过冲放大(1.18) -> 弹性回落(1.0)”的三段式果冻动效，
/// 带来如同真实物理按钮一般的 Q 弹触感。
class _BouncingNavItem extends StatefulWidget {
  final bool isSelected;
  final AppFloatingNavItem item;
  final Color color;
  final VoidCallback onTap;

  const _BouncingNavItem({
    required this.isSelected,
    required this.item,
    required this.color,
    required this.onTap,
  });

  @override
  State<_BouncingNavItem> createState() => _BouncingNavItemState();
}

class _BouncingNavItemState extends State<_BouncingNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    // 三段式弹簧曲线：瞬时轻压下陷 -> 弹性过冲冲起 -> 阻尼收敛回落
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.88)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.88, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 48,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutQuad)),
        weight: 30,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _BouncingNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 从未选中切换为选中时，即刻触发弹性弹跳
    if (!oldWidget.isSelected && widget.isSelected) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.item.buildIcon(
            context,
            widget.color,
            widget.isSelected,
          ),
        ),
      ),
    );
  }
}
