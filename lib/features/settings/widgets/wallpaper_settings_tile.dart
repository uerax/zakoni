import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/appearance_manager.dart';
import '../../../core/utils/font_manager.dart';
import '../../common/widgets/wallpaper_crop_dialog.dart';
import 'ios_settings_card.dart';

class WallpaperSettingsTile extends StatefulWidget {
  const WallpaperSettingsTile({super.key});

  @override
  State<WallpaperSettingsTile> createState() => _WallpaperSettingsTileState();
}

class _WallpaperSettingsTileState extends State<WallpaperSettingsTile> {
  String _wallpaperScope = 'all'; // 'all', 'home', 'category', 'settings'

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 500;

        final selector = Container(
          height: 32,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(10),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
            children: scopes.map((item) {
              final isSelected = _wallpaperScope == item.$1;
              final button = GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _wallpaperScope = item.$1;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: isMobile ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14),
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
              );

              if (isMobile) {
                return Expanded(child: button);
              } else {
                return SizedBox(
                  width: 80,
                  child: button,
                );
              }
            }).toList(),
          ),
        );

        if (!isMobile) {
          return Center(
            child: selector,
          );
        }
        return selector;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appMgr = AppearanceManager.instance;

    final activeWallpaperFile = appMgr.getWallpaperFileForPage(
      _wallpaperScope == 'all' ? null : _wallpaperScope,
    );
    final hasWallpaperImg = activeWallpaperFile != null && activeWallpaperFile.existsSync();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IosSettingsTile(
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
              : const IosSettingsIconBox(
                  icon: Icons.wallpaper_rounded,
                  bg: Color(0xFF3A86FF),
                ),
          title: '背景壁纸',
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
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWallpaperScopeSelector(theme),
              if (appMgr.hasWallpaperForPage(_wallpaperScope == 'all' ? null : _wallpaperScope)) ...[
                const SizedBox(height: 10),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: SizedBox(
                      height: 36,
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: FilledButton.tonalIcon(
                                onPressed: _reopenCropDialog,
                                icon: const Icon(Icons.crop_free_rounded, size: 16),
                                label: const Text('调整画面取景', style: TextStyle(fontSize: 12)),
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ),
                          if (_hasCurrentScopeWallpaper(appMgr)) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: OutlinedButton(
                                onPressed: _confirmClearWallpaper,
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  side: BorderSide(color: Colors.redAccent.withAlpha(100)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
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
    );
  }
}
