import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../core/network/anime_image_cache_manager.dart';
import '../../../core/network/bangumi_client.dart';
import '../../../core/network/player_media_disk_cache_manager.dart';
import '../../../core/utils/font_manager.dart';
import '../../player/danmaku/source/bilibili_danmaku_client.dart';
import '../../player/danmaku/source/dandan_client.dart';
import '../../player/source/source_bundle_manager.dart';
import 'ios_settings_card.dart';

class CacheSettingsCard extends StatefulWidget {
  final BangumiClient client;

  const CacheSettingsCard({super.key, required this.client});

  @override
  State<CacheSettingsCard> createState() => _CacheSettingsCardState();
}

class _CacheSettingsCardState extends State<CacheSettingsCard> {
  String _imageCacheSizeStr = '0.0 MB';
  String _dataCacheSizeStr = '0.0 MB';

  @override
  void initState() {
    super.initState();
    _updateCacheSizes();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0.0 MB';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _updateCacheSizes() async {
    int imgBytes = 0;
    try {
      imgBytes += await DefaultCacheManager().store.getCacheSize();
      imgBytes += await AnimeImageCacheManager.instance.store.getCacheSize();
    } catch (_) {}

    int dataBytes = widget.client.dataCacheSizeBytes;
    try {
      dataBytes += await widget.client.getDiskDataCacheSizeBytes();
    } catch (_) {}

    try {
      final playerDisk = PlayerMediaDiskCacheManager.instance;
      if (playerDisk != null) {
        dataBytes += await playerDisk.getDiskSizeBytes();
      }
    } catch (_) {}

    dataBytes += SourceBundleManager.instance.runtime.memoryCacheSizeBytes;
    dataBytes += DandanClient.instance.memoryCacheSizeBytes;
    dataBytes += BilibiliDanmakuClient.instance.memoryCacheSizeBytes;

    if (!mounted) return;
    setState(() {
      _imageCacheSizeStr = _formatBytes(imgBytes);
      _dataCacheSizeStr = _formatBytes(dataBytes);
    });
  }

  Future<void> _performClearImageCache() async {
    try {
      await DefaultCacheManager().emptyCache();
      try {
        await AnimeImageCacheManager.instance.emptyCache();
      } catch (_) {}
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await _updateCacheSizes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已清空图片缓存'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('清理图片缓存失败: $e'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _performClearDataCache() async {
    try {
      widget.client.clearCache();
      await PlayerMediaDiskCacheManager.instance?.clearAll();
      SourceBundleManager.instance.runtime.clearMemoryCache();
      DandanClient.instance.clearMemoryCache();
      BilibiliDanmakuClient.instance.clearMemoryCache();
      await _updateCacheSizes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已清空数据与媒体缓存'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('清理数据缓存失败: $e'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmClearImageCache() {
    final currentFont = FontManager.instance.activeFontFamily;
    final fontFallback = FontManager.fallbackFontFamilies;
    final baseStyle = TextStyle(
      fontFamily: currentFont,
      fontFamilyFallback: fontFallback,
    );

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoTheme(
        data: CupertinoTheme.of(ctx).copyWith(
          textTheme: CupertinoTextThemeData(
            textStyle: baseStyle,
            actionTextStyle: baseStyle,
          ),
        ),
        child: CupertinoAlertDialog(
          title: Text('清空图片缓存', style: baseStyle.copyWith(fontWeight: FontWeight.bold)),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('当前图片缓存占用 $_imageCacheSizeStr，确认清空？', style: baseStyle),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('取消', style: baseStyle),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                _performClearImageCache();
              },
              child: Text('确认清空', style: baseStyle.copyWith(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearDataCache() {
    final currentFont = FontManager.instance.activeFontFamily;
    final fontFallback = FontManager.fallbackFontFamilies;
    final baseStyle = TextStyle(
      fontFamily: currentFont,
      fontFamilyFallback: fontFallback,
    );

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoTheme(
        data: CupertinoTheme.of(ctx).copyWith(
          textTheme: CupertinoTextThemeData(
            textStyle: baseStyle,
            actionTextStyle: baseStyle,
          ),
        ),
        child: CupertinoAlertDialog(
          title: Text('清空数据缓存', style: baseStyle.copyWith(fontWeight: FontWeight.bold)),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('当前数据缓存占用 $_dataCacheSizeStr，确认清空？', style: baseStyle),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('取消', style: baseStyle),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                _performClearDataCache();
              },
              child: Text('确认清空', style: baseStyle.copyWith(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const IosSettingsSectionHeader(title: '存储与缓存'),
        IosSettingsCard(
          children: [
            IosSettingsTile(
              leading: const IosSettingsIconBox(
                icon: Icons.image_outlined,
                bg: Color(0xFFE63946),
              ),
              title: '图片缓存',
              showDivider: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _imageCacheSizeStr,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                ],
              ),
              onTap: _confirmClearImageCache,
            ),
            IosSettingsTile(
              leading: const IosSettingsIconBox(
                icon: Icons.storage_rounded,
                bg: Color(0xFF0077B6),
              ),
              title: '数据缓存',
              showDivider: false,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _dataCacheSizeStr,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                ],
              ),
              onTap: _confirmClearDataCache,
            ),
          ],
        ),
      ],
    );
  }
}
