import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/network/bangumi_client.dart';
import '../../../core/utils/font_manager.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontMgr = FontManager.instance;

    return Scaffold(
      appBar: AppBar(
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
          // 1. 字体与外观管理
          _buildSectionHeader('字体与外观 (支持上传与热替换)'),
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
