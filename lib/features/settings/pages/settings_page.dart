import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _currentPreset = widget.client.sourcePreset;
  }

  void _onPresetChanged(BangumiSourcePreset? preset) {
    if (preset == null || preset == _currentPreset) return;

    setState(() {
      _currentPreset = preset;
    });
    widget.client.setSourcePreset(preset);
    widget.onSettingsChanged?.call();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已切换至：${preset.label}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
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
              content: Text('已成功导入并切换字体：${FontManager.instance.customFontName}'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('字体文件解析失败，请检查文件是否为有效的 TTF/OTF'),
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

  void _clearCache() {
    widget.client.clearCache();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已清空内存临时缓存，下次浏览将重新拉取最新数据'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickCustomIcon() async {
    final success = await AppearanceManager.instance.pickAndSetCustomIcon();
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('应用图标已成功替换并即时生效'),
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
        content: Text('已恢复为默认泡面猫耳 Logo'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickCustomWallpaper() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        dialogTitle: '选择壁纸图片 (.png / .jpg / .webp)',
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      if (!await file.exists()) return;
      if (!mounted) return;

      // 选图成功后，立即唤起原生交互式取景框，供用户随心拖动画面对焦与缩放
      final appMgr = AppearanceManager.instance;
      final cropResult = await WallpaperCropDialog.show(
        context,
        imageFile: file,
        initialAlignX: appMgr.wallpaperAlignX,
        initialAlignY: appMgr.wallpaperAlignY,
        initialScale: appMgr.wallpaperScale,
      );

      if (cropResult == null || !mounted) return;

      // 直接应用已选中的文件路径并锁定取景参数，绝不发生二次文件选择
      appMgr.setWallpaperPath(file.path, pageKey: _wallpaperScope);
      appMgr.setWallpaperTransform(
        alignX: cropResult.alignX,
        alignY: cropResult.alignY,
        scale: cropResult.scale,
      );

      final scopeName = switch (_wallpaperScope) {
        'all' => '全局所有页面',
        'home' => '首页',
        'category' => '分类页',
        'settings' => '设置页',
        _ => '',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已成功设置【$scopeName】背景壁纸并锁定取景视窗'),
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
          content: Text('已更新壁纸取景视窗'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _clearCustomWallpaper() {
    AppearanceManager.instance.clearWallpaper(pageKey: _wallpaperScope);
    final scopeName = switch (_wallpaperScope) {
      'all' => '全局壁纸',
      'home' => '首页专属壁纸',
      'category' => '分类页专属壁纸',
      'settings' => '设置页专属壁纸',
      _ => '',
    };
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
    final fontMgr = FontManager.instance;
    final appMgr = AppearanceManager.instance;

    return ListenableBuilder(
      listenable: appMgr,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: const Row(
              children: [
                Icon(Icons.settings_rounded, color: Color(0xFF0077B6)),
                SizedBox(width: 8),
                Text('设置', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          body: ListView(
            // 底部预留 96px 间距，适配悬浮毛玻璃底栏穿透
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              // 1. 个性化图标与壁纸
              _buildSectionHeader('个性化定制 (图标与背景壁纸)'),
              _buildAppearanceCard(theme, appMgr),
              const SizedBox(height: 24),

              // 2. 字体与外观管理
              _buildSectionHeader('字体管理 (支持上传与热替换)'),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: RadioGroup<AppFontType>(
              groupValue: fontMgr.currentType,
              onChanged: (val) {
                if (val != null) {
                  setState(() => fontMgr.setFontType(val));
                }
              },
              child: Column(
                children: [
                  RadioListTile<AppFontType>(
                    value: AppFontType.harmony,
                    title: const Text('鸿蒙黑体 (HarmonyOS Sans · 内置推荐)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('精美细腻，官方完整字重，中英文视觉平衡度极高', style: TextStyle(fontSize: 12)),
                    activeColor: theme.colorScheme.primary,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  RadioListTile<AppFontType>(
                    value: AppFontType.system,
                    title: const Text('系统默认字体', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('跟随操作系统当前设定的字体族', style: TextStyle(fontSize: 12)),
                    activeColor: theme.colorScheme.primary,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  RadioListTile<AppFontType>(
                    value: AppFontType.custom,
                    title: Text(
                      '自定义外部字体${fontMgr.customFontPath != null ? " (${fontMgr.customFontName})" : ""}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      fontMgr.customFontPath != null
                          ? '路径: ${fontMgr.customFontPath}'
                          : '尚未导入外部字体，请点击下方按钮上传 .ttf 或 .otf 文件',
                      style: const TextStyle(fontSize: 12),
                    ),
                    activeColor: theme.colorScheme.primary,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickAndLoadCustomFont,
                            icon: const Icon(Icons.file_upload_outlined, size: 18),
                            label: Text(
                              fontMgr.customFontPath == null ? '上传并替换字体 (.ttf / .otf)' : '重新选择并替换字体',
                              style: const TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 字体实时预览卡片
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.preview_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '当前字体实时预览效果',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '【示例】10月新番 · 热门排行 · 剧场版 · OVA 1080P 高清原画',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                const Text(
                  'The quick brown fox jumps over the lazy dog. 0123456789',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. 网络与数据源
          _buildSectionHeader('Bangumi 网络线路'),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: RadioGroup<BangumiSourcePreset>(
              groupValue: _currentPreset,
              onChanged: _onPresetChanged,
              child: const Column(
                children: [
                  RadioListTile<BangumiSourcePreset>(
                    value: BangumiSourcePreset.mirror,
                    title: Text('镜像加速线路（推荐）', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'API: bgmapi.anibt.net\n图片: bgmimg.anibt.net\n国内 Anycast CDN 加速，支持浏览器跨域',
                      style: TextStyle(fontSize: 12),
                    ),
                    activeColor: Color(0xFF0077B6),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16),
                  RadioListTile<BangumiSourcePreset>(
                    value: BangumiSourcePreset.official,
                    title: Text('官方直连线路', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'API: api.bgm.tv\n图片: lain.bgm.tv\n海外直连官方源（网页调试可能受 CORS 限制）',
                      style: TextStyle(fontSize: 12),
                    ),
                    activeColor: Color(0xFF0077B6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 3. 缓存管理
          _buildSectionHeader('缓存管理'),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.cleaning_services_rounded, color: Color(0xFF0077B6)),
              title: const Text('清空本地内存缓存'),
              subtitle: const Text('重置热门列表、每日时间表内存数据', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _clearCache,
            ),
          ),
          const SizedBox(height: 24),

          // 4. 关于 Zakoni
          _buildSectionHeader('关于应用'),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline_rounded, color: Color(0xFF0077B6)),
                  title: Text('应用版本'),
                  trailing: Text('v1.0.0 (Build 1)', style: TextStyle(color: Colors.grey)),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.api_rounded, color: Color(0xFF0077B6)),
                  title: Text('元数据来源'),
                  subtitle: Text('Bangumi 番组计划 开放平台 API', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  },
);
}

  Widget _buildAppearanceCard(ThemeData theme, AppearanceManager appMgr) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 图标自定义行
            Row(
              children: [
                appMgr.buildAppLogoWidget(
                  size: 42,
                  borderRadius: 10,
                  border: Border.all(
                    color: theme.colorScheme.primary.withAlpha(120),
                    width: 1.0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '应用图标',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        appMgr.hasCustomIcon ? '当前使用自定义图片' : '默认：内置Logo',
                        style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickCustomIcon,
                    icon: const Icon(Icons.image_outlined, size: 16),
                    label: const Text('上传自定义图标', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                if (appMgr.hasCustomIcon) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _resetDefaultIcon,
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text('恢复默认', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ],
              ],
            ),

            const Divider(height: 24),

            // 2. 背景壁纸自定义行
            Row(
              children: [
                Icon(
                  Icons.wallpaper_rounded,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '背景壁纸',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getWallpaperStatusText(appMgr),
                        style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 页面作用域分段切换胶囊
            _buildWallpaperScopeSelector(theme),
            const SizedBox(height: 12),

            // 操作按钮行
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickCustomWallpaper,
                    icon: const Icon(Icons.file_upload_outlined, size: 16),
                    label: Text(
                      _wallpaperScope == 'all' ? '上传壁纸 (全部应用)' : '设置当前页面专属壁纸',
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
                  TextButton.icon(
                    onPressed: _clearCustomWallpaper,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                    label: Text(
                      _wallpaperScope == 'all' ? '清除全局' : '恢复跟随全局',
                      style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ],
              ],
            ),

            // 若当前页面或全局有壁纸生效，展示【交互式取景调整按钮】与视觉调节滑块
            if (appMgr.hasWallpaperForPage(_wallpaperScope == 'all' ? null : _wallpaperScope)) ...[
              const SizedBox(height: 14),

              // 交互式取景框唤起入口
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _reopenCropDialog,
                  icon: const Icon(Icons.crop_free_rounded, size: 18),
                  label: const Text('调整画面取景'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 不透明度调节
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '壁纸不透明度',
                    style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    '${(appMgr.wallpaperOpacity * 100).toInt()}%',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
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

              // 高斯模糊度调节
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '高斯模糊程度',
                    style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    '${appMgr.wallpaperBlur.toStringAsFixed(1)} px',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
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
    );
  }

  String _getWallpaperStatusText(AppearanceManager appMgr) {
    if (_wallpaperScope == 'all') {
      return appMgr.globalWallpaperPath != null ? '已设置全局默认壁纸' : '未设置全局壁纸';
    }
    if (appMgr.isPageOverridden(_wallpaperScope)) {
      return '当前页面已单独定制专属壁纸';
    }
    if (appMgr.globalWallpaperPath != null) {
      return '当前跟随全局默认壁纸';
    }
    return '未设置壁纸 (纯净环境光)';
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
      height: 34,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12),
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
                      fontSize: 12,
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }
}
