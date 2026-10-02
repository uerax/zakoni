import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 专为动漫封面定制的磁盘文件缓存：
/// 1. 将磁盘最大缓存数量从默认的 200 张提升至 3000 张，防止长列表滑动时过早被自动清理删盘；
/// 2. 缓存有效期延长至 60 天，让已浏览的封面长期保留在本地磁盘；
/// 3. 图片为公开静态资源，直接以原生文件方式落盘存储。
class AnimeImageCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'anime_image_disk_cache';

  static final AnimeImageCacheManager instance = AnimeImageCacheManager._();

  AnimeImageCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 60),
            maxNrOfCacheObjects: 3000,
          ),
        );
}
