import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../core/network/bangumi_client.dart';
import '../../../core/utils/font_manager.dart';
import 'ios_settings_card.dart';

class CacheSettingsCard extends StatefulWidget {
  final BangumiClient client;

  const CacheSettingsCard({super.key, required this.client});

  @override
  State<CacheSettingsCard> createState() => _CacheSettingsCardState();
}

class _CacheSettingsCardState extends State<CacheSettingsCard> {
  String _cacheSizeStr = '计算中...';

  @override
  void initState() {
    super.initState();
    _updateCacheSize();
  }

  Future<void> _updateCacheSize() async {
    try {
      final sizeInBytes = await DefaultCacheManager().store.getCacheSize();
      if (!mounted) return;
      setState(() {
        if (sizeInBytes <= 0) {
          _cacheSizeStr = '0.0 MB';
        } else if (sizeInBytes < 1024 * 1024) {
          _cacheSizeStr = '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
        } else {
          _cacheSizeStr = '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _cacheSizeStr = '0.0 MB';
        });
      }
    }
  }

  Future<void> _performClearCache() async {
    try {
      await DefaultCacheManager().emptyCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      widget.client.clearCache();
      await _updateCacheSize();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已清空本地缓存'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('清理缓存失败: $e'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmClearCache() {
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
          title: Text(
            '清空本地缓存',
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '当前缓存占用 $_cacheSizeStr。\n清空后将释放本地存储空间，重新浏览时将拉取最新数据。',
              style: baseStyle,
            ),
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
                _performClearCache();
              },
              child: Text(
                '确认清空',
                style: baseStyle.copyWith(fontWeight: FontWeight.bold),
              ),
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
                icon: Icons.cleaning_services_rounded,
                bg: Color(0xFFE63946),
              ),
              title: '本地缓存',
              showDivider: false,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _cacheSizeStr,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                ],
              ),
              onTap: _confirmClearCache,
            ),
          ],
        ),
      ],
    );
  }
}
