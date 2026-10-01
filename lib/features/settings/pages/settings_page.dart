import 'package:flutter/material.dart';
import '../../../core/network/bangumi_client.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.settings_rounded, color: Color(0xFFE91E63)),
            SizedBox(width: 8),
            Text('设置', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: ListView(
        // 底部预留 96px 间距，适配悬浮毛玻璃底栏穿透
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          // 1. 网络与数据源
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
                    activeColor: Color(0xFFE91E63),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16),
                  RadioListTile<BangumiSourcePreset>(
                    value: BangumiSourcePreset.official,
                    title: Text('官方直连线路', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'API: api.bgm.tv\n图片: lain.bgm.tv\n海外直连官方源（网页调试可能受 CORS 限制）',
                      style: TextStyle(fontSize: 12),
                    ),
                    activeColor: Color(0xFFE91E63),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 2. 缓存管理
          _buildSectionHeader('缓存管理'),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.cleaning_services_rounded, color: Color(0xFFE91E63)),
              title: const Text('清空本地内存缓存'),
              subtitle: const Text('重置热门列表、每日时间表内存数据', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _clearCache,
            ),
          ),
          const SizedBox(height: 24),

          // 3. 关于 Zakoni
          _buildSectionHeader('关于应用'),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded, color: Color(0xFFE91E63)),
                  title: Text('应用版本'),
                  trailing: Text('v1.0.0 (Build 1)', style: TextStyle(color: Colors.grey)),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                const ListTile(
                  leading: Icon(Icons.api_rounded, color: Color(0xFFE91E63)),
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
          color: Color(0xFFE91E63),
        ),
      ),
    );
  }
}
