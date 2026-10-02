import 'package:flutter/material.dart';

/// 全局高性能流光骨架屏（Shimmer）组件：
/// 1. 采用纯原生 AnimationController + ShaderMask 实现，无需引入臃肿第三方依赖；
/// 2. 动画控制器挂载于外层共享，子组件无论有多少个占位块均共享同一个着色器流动周期，性能极高。
class Shimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const Shimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  });

  static ShimmerState? of(BuildContext context) {
    return context.findAncestorStateOfType<ShimmerState>();
  }

  @override
  State<Shimmer> createState() => ShimmerState();
}

class ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Listenable get shimmerChanges => _controller;

  double get percent => _controller.value;

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

  LinearGradient get gradient {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFE5E5EA);
    final highlightColor = isDark
        ? const Color(0xFF3A3A3C)
        : const Color(0xFFF2F2F7);

    return LinearGradient(
      colors: [baseColor, highlightColor, baseColor],
      stops: const [0.1, 0.5, 0.9],
      begin: const Alignment(-1.0, -0.3),
      end: const Alignment(1.0, 0.3),
      transform: _SlidingGradientTransform(slidePercent: percent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
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

/// 流光骨架占位块渲染器：通过 ShaderMask 将父级 Shimmer 的流动高光映射到子组件上
class ShimmerLoading extends StatelessWidget {
  final Widget child;

  const ShimmerLoading({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final shimmer = Shimmer.of(context);
    if (shimmer == null) return child;

    return AnimatedBuilder(
      animation: shimmer.shimmerChanges,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return shimmer.gradient.createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

/// 双列网格动漫卡片的 1:1 精确骨架屏占位卡片
class ShimmerAnimeCard extends StatelessWidget {
  const ShimmerAnimeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final blockColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    return Card(
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: cardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面区域占位
          Expanded(
            child: ShimmerLoading(
              child: Container(
                color: blockColor,
              ),
            ),
          ),
          // 底部标题占位行
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoading(
                  child: Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: blockColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ShimmerLoading(
                  child: Container(
                    height: 10,
                    width: 70,
                    decoration: BoxDecoration(
                      color: blockColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面占位
            ShimmerLoading(
              child: Container(
                height: cardHeight,
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // 标题占位行 1
            ShimmerLoading(
              child: Container(
                height: 12,
                width: 100,
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // 标题占位行 2
            ShimmerLoading(
              child: Container(
                height: 12,
                width: 60,
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
