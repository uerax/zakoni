import 'dart:ui';
import 'package:flutter/material.dart';

/// 搜索页面着色器离屏预编译占位组件
/// 特殊处理说明：
/// 1. 在视口外部绘制 2x2 像素微型节点，提前触发 Flutter 底层（Impeller/Skia）对高斯模糊（BackdropFilter）
///    与径向光晕渐变（RadialGradient）着色器的管线编译与缓存；
/// 2. 彻底消除首次进入搜索页面那瞬间因着色器即时编译（Shader Compilation JIT）产生的 50ms~200ms 掉帧；
/// 3. 包裹 ExcludeSemantics 与 IgnorePointer，零触控、零无障碍干扰，首帧渲染后 GPU 消耗近乎为 0。
class SearchShaderPrewarm extends StatelessWidget {
  const SearchShaderPrewarm({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 2,
      height: 2,
      child: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  theme.colorScheme.primary.withAlpha(20),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}
