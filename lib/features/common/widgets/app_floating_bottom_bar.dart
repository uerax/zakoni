import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/m3_surface.dart';

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

/// Material 3 Expressive 悬浮药丸导航底栏（M3 Expressive Floating Dock）：
/// 1. 外层悬浮弥散微光，支持背景壁纸时 Material You 色相通透折射；
/// 2. 58px 黄金悬浮高度，29px 饱满全药丸轮廓 (StadiumBorder)；
/// 3. 采用 Material 3 标志性的横向活动药丸指示器（Active Pill Indicator），
///    以 theme.colorScheme.secondaryContainer 配合平滑物理过冲定格；
/// 4. 激活项采用 onSecondaryContainer 高对比度强调色，未激活项使用 onSurfaceVariant。
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
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    final dockBg = M3Surface.container(context, level: M3ContainerLevel.highest);
    final dockBorder = M3Surface.border(context);

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
              maxWidth: 290,
              minHeight: 58,
              maxHeight: 58,
            ),
            // 外层：提供悬浮弥散阴影
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(29),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              // 内层：高斯模糊毛玻璃裁剪与 M3 表现力底色
              child: ClipRRect(
                borderRadius: BorderRadius.circular(29),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: dockBg,
                      borderRadius: BorderRadius.circular(29),
                      border: dockBorder,
                    ),
                    child: Stack(
                      children: [
                        // M3 标准横向活动药丸滑块（secondaryContainer 色彩）
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
                                height: 38,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(19),
                                  color: theme.colorScheme.secondaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 各导航项图标（选中态为 onSecondaryContainer，未选中态为 onSurfaceVariant）
                        Row(
                          children: List.generate(items.length, (i) {
                            final isSelected = currentIndex == i;
                            final item = items[i];
                            final itemColor = isSelected
                                ? theme.colorScheme.onSecondaryContainer
                                : theme.colorScheme.onSurfaceVariant;

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
