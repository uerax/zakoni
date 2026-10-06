import 'package:flutter/material.dart';

/// 全局高性能流光骨架屏（Shimmer）组件：
/// 1. 采用单层 ShaderMask 架构：外层包裹单一 ShaderMask，子组件内所有占位块共享同一个渲染图层；
/// 2. 彻底消除同屏几十个独立 ShaderMask 离屏缓冲通道导致的显存压力与掉帧。
class Shimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const Shimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  });

  /// 判断当前构建上下文中是否已存在全局 Shimmer 父级
  static bool hasShimmerAncestor(BuildContext context) {
    return context.findAncestorWidgetOfExactType<Shimmer>() != null;
  }

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this)
      ..repeat(min: -0.5, max: 1.5, period: widget.duration);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFE5E5EA);
    final highlightColor = isDark
        ? const Color(0xFF3A3A3C)
        : const Color(0xFFF2F2F7);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final gradient = LinearGradient(
          colors: [baseColor, highlightColor, baseColor],
          stops: const [0.1, 0.5, 0.9],
          begin: const Alignment(-1.0, -0.3),
          end: const Alignment(1.0, 0.3),
          transform: _SlidingGradientTransform(slidePercent: _controller.value),
        );

        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => gradient.createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// 流光骨架占位块渲染器：
/// 当外层已有 Shimmer 时直接返回纯色占位块，零额外离屏缓冲通道；
/// 当孤立存在时自动轻量包装。
class ShimmerLoading extends StatelessWidget {
  final Widget child;

  const ShimmerLoading({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (Shimmer.hasShimmerAncestor(context)) {
      return child;
    }
    return Shimmer(child: child);
  }
}

/// 双列网格动漫卡片的 1:1 精确骨架屏占位卡片
class ShimmerAnimeCard extends StatelessWidget {
  const ShimmerAnimeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.colorScheme.surfaceContainerLow;
    final blockColor = theme.colorScheme.surfaceContainerHighest;

    final card = Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面区域占位
          Expanded(
            child: Container(color: blockColor),
          ),
          // 底部标题占位行
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 70,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (Shimmer.hasShimmerAncestor(context)) {
      return card;
    }
    return Shimmer(child: card);
  }
}

/// 热门排行单行横向卡片的 1:1 精确骨架屏占位卡片
class ShimmerRankCard extends StatelessWidget {
  static const double cardWidth = 136;
  static const double cardHeight = 204;

  const ShimmerRankCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blockColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    final card = Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面占位
            Container(
              height: cardHeight,
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 6),
            // 标题占位行 1
            Container(
              height: 12,
              width: 100,
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 4),
            // 标题占位行 2
            Container(
              height: 12,
              width: 60,
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );

    if (Shimmer.hasShimmerAncestor(context)) {
      return card;
    }
    return Shimmer(child: card);
  }
}
