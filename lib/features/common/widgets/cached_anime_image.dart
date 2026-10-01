import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/image_utils.dart';

/// 高性能动漫封面图片组件：
/// 1. 采用原生 Image + CachedNetworkImageProvider 双层架构；
///    之所以不使用封装的 CachedNetworkImage 部件，是因为原生 Image 能够利用 Flutter 渲染管线的
///    绘制延迟机制（仅当 Widget 即将绘制进入视口时才触发解码），并且避免为每个卡片实例化两套动画控制器与状态。
/// 2. 使用 ResizeImage.resizeIfNeeded 将解码宽度限制在合理像素，杜绝数十张大图打爆显存与 GC 卡顿。
/// 3. 搭配轻量 frameBuilder 即时占位色块，首屏与高速滚动 0 掉帧。
class CachedAnimeImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int resizeWidth;
  final BorderRadius? borderRadius;

  const CachedAnimeImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.resizeWidth = 300,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetUrl = preferResizedCover(imageUrl, maxEdge: resizeWidth);

    if (targetUrl.isEmpty) {
      return _buildPlaceholder(
        context,
        theme,
        child: const Icon(Icons.movie_rounded, color: Colors.grey, size: 28),
      );
    }

    final imageWidget = Image(
      image: ResizeImage.resizeIfNeeded(
        resizeWidth,
        null,
        CachedNetworkImageProvider(targetUrl),
      ),
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        // 同步从内存/已解码帧直接秒出，不走任何过渡；未载入时呈现纯色骨架底色
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return _buildPlaceholder(context, theme);
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholder(
          context,
          theme,
          child: const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 26),
        );
      },
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder(
    BuildContext context,
    ThemeData theme, {
    Widget? child,
  }) {
    return Container(
      width: width,
      height: height,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
      child: child != null ? Center(child: child) : null,
    );
  }
}
