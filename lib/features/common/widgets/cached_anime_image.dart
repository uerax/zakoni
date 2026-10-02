import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/network/anime_image_cache_manager.dart';
import '../../../core/utils/image_utils.dart';

/// 高性能动漫封面图片组件：
/// 1. 采用专用的 AnimeImageCacheManager，磁盘容量达 3000 张，支持 60 天长效落盘存储；
/// 2. 使用 memCacheWidth 限制解码位图宽度，杜绝过量采样撑爆显存；
/// 3. 采用超快 120ms 平滑淡入，消除图片反复加载的灰色色块突兀闪烁感。
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
    this.resizeWidth = 220,
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

    Widget imageWidget = CachedNetworkImage(
      imageUrl: targetUrl,
      cacheManager: AnimeImageCacheManager.instance,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: resizeWidth,
      filterQuality: FilterQuality.medium,
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: const Duration(milliseconds: 120),
      useOldImageOnUrlChange: true,
      placeholder: (context, url) => _buildPlaceholder(context, theme),
      errorWidget: (context, url, error) => _buildPlaceholder(
        context,
        theme,
        child: const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 26),
      ),
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
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
