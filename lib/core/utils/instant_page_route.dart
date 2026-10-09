import 'package:flutter/material.dart';

/// 零动画瞬时直切路由（与 IndexedStack 刷新展示体验对齐）：
///
/// 特殊处理说明：
/// 1. 将 transitionDuration 与 reverseTransitionDuration 均显式设定为 Duration.zero；
/// 2. 规避常规 PageRoute 自带的水平滑动位移动画（Slide Transition），实现无缝瞬时“刷新展示”；
/// 3. 同时完整保留 Flutter 导航栈生命周期、页面传参及 Pop 返回机制。
class InstantPageRoute<T> extends PageRouteBuilder<T> {
  InstantPageRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
}
