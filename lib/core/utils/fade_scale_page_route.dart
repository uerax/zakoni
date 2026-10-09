import 'package:flutter/material.dart';

/// Material 3 现代化极速淡入微缩放路由（消除左右水平侧滑，适配跨平台大屏与移动端）：
///
/// 特殊处理说明：
/// 1. 入场时长设为 260ms，出场时长设为 200ms：
///    留出充足的时间窗口对抗首帧构建与着色器预热开销，让人眼清晰捕捉到平滑展开的呼吸过程；
/// 2. 透明度区间解耦：入场前 45% 时间（~110ms）通过 Interval 完成 0.0 -> 1.0 快速淡入，
///    后 55% 时间在完全清晰明亮的状态下继续呈现 0.90 -> 1.00 的微膨胀展开，动作清晰可见且无眩晕感；
/// 3. 缩放幅度设定为 0.90 -> 1.00（Curves.easeOutCubic），提供清晰的原地聚焦展开感，
///    彻底替代笨重的全屏左右侧滑；
/// 4. 出场时以 1.00 -> 0.90 平滑收缩并淡出，完整保留 Flutter 导航栈生命周期与参数机制。
class FadeScalePageRoute<T> extends PageRouteBuilder<T> {
  FadeScalePageRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fadeAnimation = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
              reverseCurve: Curves.easeInQuad,
            );

            final scaleAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(fadeAnimation),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.90, end: 1.0).animate(scaleAnimation),
                child: child,
              ),
            );
          },
        );
}
