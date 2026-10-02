import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../core/network/bangumi_client.dart';
import '../../../core/utils/appearance_manager.dart';
import '../../../core/utils/font_manager.dart';
import '../../common/widgets/wallpaper_crop_dialog.dart';

class SettingsPage extends StatefulWidget {
  final BangumiClient client;
  final VoidCallback? onSettingsChanged;

  const SettingsPage({
    super.key,
    required this.client,
    this.onSettingsChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late BangumiSourcePreset _currentPreset;
  String _wallpaperScope = 'all'; // 'all', 'home', 'category', 'settings'
  String _cacheSizeStr = '计算中...';

  @override
  void initState() {
    super.initState();
    _currentPreset = widget.client.sourcePreset;
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

  void _onPresetChanged(BangumiSourcePreset preset) {
    if (preset == _currentPreset) return;

    setState(() {
      _currentPreset = preset;
    });
    widget.client.setSourcePreset(preset);
    widget.onSettingsChanged?.call();
    _updateCacheSize();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          preset == BangumiSourcePreset.mirror ? '已切换至镜像加速' : '已切换至官方直连',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  Future<void> _pickAndLoadCustomFont() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
        dialogTitle: '选择字体文件 (.ttf / .otf)',
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final success = await FontManager.instance.loadFontFromFile(path);
        if (!mounted) return;
        if (success) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已导入字体：${FontManager.instance.customFontName}'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('字体解析失败，请检查文件格式'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('选择字体失败: $e'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmDeleteCustomFont(FontManager fontMgr) {
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
            '移除自定义字体',
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '确定要移除【${fontMgr.customFontName}】吗？字体将恢复为默认鸿蒙黑体。',
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
                fontMgr.clearCustomFont();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已移除自定义字体'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Text(
                '确认移除',
                style: baseStyle.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomIcon() async {
    final success = await AppearanceManager.instance.pickAndSetCustomIcon();
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('应用图标已替换'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _resetDefaultIcon() {
    AppearanceManager.instance.resetDefaultIcon();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已恢复为默认图标'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showIconActionSheet() {
    final appMgr = AppearanceManager.instance;
    final currentFont = FontManager.instance.activeFontFamily;
    final fontFallback = FontManager.fallbackFontFamilies;
    final baseStyle = TextStyle(
      fontFamily: currentFont,
      fontFamilyFallback: fontFallback,
    );

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoTheme(
        data: CupertinoTheme.of(ctx).copyWith(
          textTheme: CupertinoTextThemeData(
            textStyle: baseStyle,
            actionTextStyle: baseStyle,
          ),
        ),
        child: CupertinoActionSheet(
          title: Text('应用图标设置', style: baseStyle),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _pickCustomIcon();
              },
              child: Text('上传自定义图标', style: baseStyle),
            ),
            if (appMgr.hasCustomIcon)
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _resetDefaultIcon();
                },
                child: Text('恢复默认图标', style: baseStyle),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('取消', style: baseStyle),
          ),
        ),
      ),
    );
  }

  Future<void> _pickCustomWallpaper() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        dialogTitle: '选择壁纸图片',
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      if (!await file.exists()) return;
      if (!mounted) return;

      final appMgr = AppearanceManager.instance;
      final cropResult = await WallpaperCropDialog.show(
        context,
        imageFile: file,
        initialAlignX: appMgr.wallpaperAlignX,
        initialAlignY: appMgr.wallpaperAlignY,
        initialScale: appMgr.wallpaperScale,
      );

      if (cropResult == null || !mounted) return;

      appMgr.setWallpaperPath(file.path, pageKey: _wallpaperScope);
      appMgr.setWallpaperTransform(
        alignX: cropResult.alignX,
        alignY: cropResult.alignY,
        scale: cropResult.scale,
      );

      final scopeName = switch (_wallpaperScope) {
        'all' => '全局',
        'home' => '首页',
        'category' => '分类',
        'settings' => '设置',
        _ => '',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已设置【$scopeName】背景壁纸'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('上传壁纸失败: $e');
    }
  }

  Future<void> _reopenCropDialog() async {
    final appMgr = AppearanceManager.instance;
    final file = appMgr.getWallpaperFileForPage(
      _wallpaperScope == 'all' ? null : _wallpaperScope,
    );
    if (file == null || !mounted) return;

    final cropResult = await WallpaperCropDialog.show(
      context,
      imageFile: file,
      initialAlignX: appMgr.wallpaperAlignX,
      initialAlignY: appMgr.wallpaperAlignY,
      initialScale: appMgr.wallpaperScale,
    );

    if (cropResult != null) {
      appMgr.setWallpaperTransform(
        alignX: cropResult.alignX,
        alignY: cropResult.alignY,
        scale: cropResult.scale,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已更新壁纸取景'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmClearWallpaper() {
    final currentFont = FontManager.instance.activeFontFamily;
    final fontFallback = FontManager.fallbackFontFamilies;
    final baseStyle = TextStyle(
      fontFamily: currentFont,
      fontFamilyFallback: fontFallback,
    );

    final scopeName = switch (_wallpaperScope) {
      'all' => '全局壁纸',
      'home' => '首页专属壁纸',
      'category' => '分类页专属壁纸',
      'settings' => '设置页专属壁纸',
      _ => '背景壁纸',
    };

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
            '清除背景壁纸',
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '确定要清除【$scopeName】吗？',
              style: baseStyle,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: Text('取消', style: baseStyle),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                _performClearWallpaper(scopeName);
              },
              child: Text(
                '确认清除',
                style: baseStyle.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _performClearWallpaper(String scopeName) {
    AppearanceManager.instance.clearWallpaper(pageKey: _wallpaperScope);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已清除【$scopeName】'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fontMgr = FontManager.instance;
    final appMgr = AppearanceManager.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([appMgr, fontMgr]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: const Text('设置', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            centerTitle: true,
          ),
          body: ListView(
            // 底部预留 96px 间距，适配悬浮毛玻璃底栏穿透
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              // 1. 网络线路
              _buildSectionHeader('网络线路'),
              _buildIosCard(
                isDark: isDark,
                children: [
                  _buildIosTile(
                    context: context,
                    leading: _buildIconBox(Icons.bolt_rounded, const Color(0xFF0077B6)),
                    title: '镜像加速',
                    subtitle: '国内 CDN 加速',
                    trailing: _currentPreset == BangumiSourcePreset.mirror
                        ? const Icon(Icons.check_rounded, color: Color(0xFF0077B6), size: 20)
                        : null,
                    onTap: () => _onPresetChanged(BangumiSourcePreset.mirror),
                  ),
                  _buildIosTile(
                    context: context,
                    leading: _buildIconBox(Icons.public_rounded, const Color(0xFF2A9D8F)),
                    title: '官方直连',
                    subtitle: '海外直连官方源',
                    showDivider: false,
                    trailing: _currentPreset == BangumiSourcePreset.official
                        ? const Icon(Icons.check_rounded, color: Color(0xFF0077B6), size: 20)
                        : null,
                    onTap: () => _onPresetChanged(BangumiSourcePreset.official),
                  ),
                ],
              ),

              // 2. 缓存管理
              _buildSectionHeader('存储与缓存'),
              _buildIosCard(
                isDark: isDark,
                children: [
                  _buildIosTile(
                    context: context,
                    leading: _buildIconBox(Icons.cleaning_services_rounded, const Color(0xFFE63946)),
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

              // 3. 字体设置
              _buildSectionHeader('字体设置'),
              _buildIosCard(
                isDark: isDark,
                children: [
                  _buildIosTile(
                    context: context,
                    leading: _buildIconBox(Icons.font_download_rounded, const Color(0xFFE76F51)),
                    title: '鸿蒙黑体',
                    trailing: fontMgr.currentType == AppFontType.harmony
                        ? const Icon(Icons.check_rounded, color: Color(0xFF0077B6), size: 20)
                        : null,
                    onTap: () {
                      fontMgr.setFontType(AppFontType.harmony);
                    },
                  ),
                  _buildIosTile(
                    context: context,
                    leading: _buildIconBox(Icons.text_fields_rounded, const Color(0xFF457B9D)),
                    title: '系统默认',
                    trailing: fontMgr.currentType == AppFontType.system
                        ? const Icon(Icons.check_rounded, color: Color(0xFF0077B6), size: 20)
                        : null,
                    onTap: () {
                      fontMgr.setFontType(AppFontType.system);
                    },
                  ),
                  if (fontMgr.customFontPath != null)
                    _IosSwipeActionTile(
                      onDelete: () => _confirmDeleteCustomFont(fontMgr),
                      child: _buildIosTile(
                        context: context,
                        leading: _buildIconBox(Icons.dashboard_customize_rounded, const Color(0xFFF4A261)),
                        title: fontMgr.customFontName,
                        trailing: fontMgr.currentType == AppFontType.custom
                            ? const Icon(Icons.check_rounded, color: Color(0xFF0077B6), size: 20)
                            : null,
                        onTap: () {
                          fontMgr.setFontType(AppFontType.custom);
                        },
                      ),
                    ),
                  _buildIosTile(
                    context: context,
                    leading: _buildIconBox(Icons.file_upload_outlined, const Color(0xFF8338EC)),
                    title: fontMgr.customFontPath != null ? '更换字体文件' : '导入字体文件',
                    subtitle: '支持 .ttf / .otf 格式',
                    showDivider: false,
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                    onTap: _pickAndLoadCustomFont,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 极简字体预览行
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.remove_red_eye_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '预览：10月新番 · 热门排行 · OVA',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurfaceVariant.withAlpha(190),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // 4. 外观定制 (图标与壁纸)
              _buildSectionHeader('个性化外观'),
              _buildIosCard(
                isDark: isDark,
                children: [
                  _buildIosTile(
                    context: context,
                    leading: appMgr.buildAppLogoWidget(
                      size: 28,
                      borderRadius: 7,
                    ),
                    title: '应用图标',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          appMgr.hasCustomIcon ? '自定义' : '默认',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                      ],
                    ),
                    onTap: _showIconActionSheet,
                  ),
                  () {
                    final activeWallpaperFile = appMgr.getWallpaperFileForPage(
                      _wallpaperScope == 'all' ? null : _wallpaperScope,
                    );
                    final hasWallpaperImg =
                        activeWallpaperFile != null && activeWallpaperFile.existsSync();

                    return _buildIosTile(
                      context: context,
                      leading: hasWallpaperImg
                          ? Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withAlpha(120),
                                  width: 0.8,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.file(
                                activeWallpaperFile,
                                fit: BoxFit.cover,
                              ),
                            )
                          : _buildIconBox(Icons.wallpaper_rounded, const Color(0xFF3A86FF)),
                      title: '背景壁纸',
                      subtitle: _getWallpaperStatusText(appMgr),
                      showDivider: false,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_hasCurrentScopeWallpaper(appMgr))
                            const Icon(Icons.check_rounded, color: Color(0xFF0077B6), size: 18),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                        ],
                      ),
                      onTap: _pickCustomWallpaper,
                    );
                  }(),
                  // 壁纸分段切换与快捷操作
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWallpaperScopeSelector(theme),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickCustomWallpaper,
                                icon: const Icon(Icons.photo_outlined, size: 15),
                                label: Text(
                                  _wallpaperScope == 'all' ? '设置全局壁纸' : '设置本页壁纸',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            if (_hasCurrentScopeWallpaper(appMgr)) ...[
                              const SizedBox(width: 8),
                              IconButton.outlined(
                                onPressed: _confirmClearWallpaper,
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                tooltip: '清除壁纸',
                                style: IconButton.styleFrom(
                                  side: BorderSide(color: Colors.redAccent.withAlpha(90)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.all(7),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (appMgr.hasWallpaperForPage(_wallpaperScope == 'all' ? null : _wallpaperScope)) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonalIcon(
                              onPressed: _reopenCropDialog,
                              icon: const Icon(Icons.crop_free_rounded, size: 16),
                              label: const Text('调整壁纸取景', style: TextStyle(fontSize: 12)),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '不透明度',
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                              ),
                              Text(
                                '${(appMgr.wallpaperOpacity * 100).toInt()}%',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Slider(
                            value: appMgr.wallpaperOpacity,
                            min: 0.05,
                            max: 0.60,
                            divisions: 55,
                            onChanged: (val) => appMgr.setWallpaperOpacity(val),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '高斯模糊',
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                              ),
                              Text(
                                '${appMgr.wallpaperBlur.toStringAsFixed(1)} px',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Slider(
                            value: appMgr.wallpaperBlur,
                            min: 0.0,
                            max: 20.0,
                            divisions: 40,
                            onChanged: (val) => appMgr.setWallpaperBlur(val),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // 5. 关于应用
              _buildSectionHeader('关于应用'),
              _buildIosCard(
                isDark: isDark,
                children: [
                  _buildIosTile(
                    context: context,
                    leading: _buildIconBox(Icons.info_outline_rounded, const Color(0xFF6C757D)),
                    title: '版本号',
                    trailing: Text(
                      'v1.0.0 (Build 1)',
                      style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant.withAlpha(160)),
                    ),
                  ),
                  _buildIosTile(
                    context: context,
                    leading: _buildIconBox(Icons.api_rounded, const Color(0xFF6C757D)),
                    title: '数据来源',
                    showDivider: false,
                    trailing: Text(
                      'Bangumi API',
                      style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant.withAlpha(160)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(180),
        ),
      ),
    );
  }

  Widget _buildIosCard({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(12),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildIconBox(IconData icon, Color bg) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }

  Widget _buildIosTile({
    required BuildContext context,
    Widget? leading,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: theme.colorScheme.primary.withAlpha(20),
        highlightColor: theme.colorScheme.primary.withAlpha(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading,
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing,
                  ],
                ],
              ),
            ),
            if (showDivider)
              Padding(
                padding: EdgeInsets.only(left: leading != null ? 58 : 16),
                child: Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(15),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getWallpaperStatusText(AppearanceManager appMgr) {
    if (_wallpaperScope == 'all') {
      return appMgr.globalWallpaperPath != null ? '已设置全局壁纸' : '未设置全局壁纸';
    }
    if (appMgr.isPageOverridden(_wallpaperScope)) {
      return '已设置本页专属壁纸';
    }
    if (appMgr.globalWallpaperPath != null) {
      return '当前跟随全局壁纸';
    }
    return '未设置壁纸';
  }

  bool _hasCurrentScopeWallpaper(AppearanceManager appMgr) {
    if (_wallpaperScope == 'all') {
      return appMgr.globalWallpaperPath != null;
    }
    return appMgr.isPageOverridden(_wallpaperScope);
  }

  Widget _buildWallpaperScopeSelector(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    const scopes = [
      ('all', '全部应用'),
      ('home', '首页'),
      ('category', '分类'),
      ('settings', '设置'),
    ];

    return Container(
      height: 32,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: scopes.map((item) {
          final isSelected = _wallpaperScope == item.$1;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _wallpaperScope = item.$1;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 仿 iOS 原生列表项向左滑动露出删除按钮的操作组件
class _IosSwipeActionTile extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  final double actionWidth;

  const _IosSwipeActionTile({
    required this.child,
    required this.onDelete,
    this.actionWidth = 72.0,
  });

  @override
  State<_IosSwipeActionTile> createState() => _IosSwipeActionTileState();
}

class _IosSwipeActionTileState extends State<_IosSwipeActionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _dragExtent = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    _animateTo(-widget.actionWidth);
  }

  void _close() {
    _animateTo(0.0);
  }

  void _animateTo(double target) {
    _animation = Tween<double>(
      begin: _dragExtent,
      end: target,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ))..addListener(() {
      setState(() {
        _dragExtent = _animation.value;
      });
    });
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final revealWidth = (-_dragExtent).clamp(0.0, widget.actionWidth);

    return TapRegion(
      onTapOutside: (_) {
        if (_dragExtent < 0) {
          _close();
        }
      },
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 浮层：随着水平手势滑动的卡片行主体
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragExtent += details.primaryDelta!;
                _dragExtent = _dragExtent.clamp(-widget.actionWidth * 1.15, 0.0);
              });
            },
            onHorizontalDragEnd: (details) {
              if (_dragExtent < -widget.actionWidth / 2 || details.primaryVelocity! < -250) {
                _open();
              } else {
                _close();
              }
            },
            child: Transform.translate(
              offset: Offset(_dragExtent, 0),
              child: widget.child,
            ),
          ),

          // 右侧露出的 iOS 经典红色删除块（宽度随滑动动态展开，不透底）
          if (revealWidth > 0)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: revealWidth,
              child: ClipRect(
                child: Material(
                  color: const Color(0xFFFF3B30),
                  child: InkWell(
                    onTap: () {
                      _close();
                      widget.onDelete();
                    },
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                          SizedBox(height: 2),
                          Text(
                            '删除',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 当已经滑开展开删除按钮时，点击左侧非按钮区域自动回弹关闭
          if (_dragExtent < 0)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: revealWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
              ),
            ),
        ],
      ),
    );
  }
}
