import 'package:flutter/material.dart';
import 'package:zakoni/features/player/source/source_bundle_manager.dart';
import 'ios_settings_card.dart';

class SourceSettingsCard extends StatefulWidget {
  const SourceSettingsCard({super.key});

  @override
  State<SourceSettingsCard> createState() => _SourceSettingsCardState();
}

class _SourceSettingsCardState extends State<SourceSettingsCard> {
  final SourceBundleManager _manager = SourceBundleManager.instance;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    if (!_manager.isReady) {
      _manager.initialize();
    }
    _manager.addListener(_onManagerChanged);
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerChanged);
    super.dispose();
  }

  void _onManagerChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _handleCheckUpdate() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    final res = await _manager.checkUpdate();
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (res.hasUpdate && res.downloadUrl != null) {
      final shouldUpdate = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('发现解析器新版本'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前版本：v${res.currentVersion}'),
              Text('最新版本：v${res.latestVersion}'),
              if (res.changelog != null) ...[
                const SizedBox(height: 10),
                const Text('更新日志：', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(res.changelog!),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('暂不更新'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('立即无感更新'),
            ),
          ],
        ),
      );

      if (shouldUpdate == true) {
        final ok = await _manager.applyUpdate(res.downloadUrl!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ok ? '解析器已无感更新至 v${res.latestVersion}' : '更新失败: ${_manager.lastError}'),
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.changelog?.contains('失败') == true ? res.changelog! : '当前解析器已是最新版本 (v${res.currentVersion})'),
        ),
      );
    }
  }

  Future<void> _handleResetFactory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置解析器'),
        content: const Text('确定要清除外部更新包，恢复至应用出厂内置版本吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定重置')),
        ],
      ),
    );

    if (confirm == true) {
      await _manager.resetToFactory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已恢复至出厂解析器')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _manager.meta;
    final sources = _manager.sources;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const IosSettingsSectionHeader(title: '视频源与解析器'),
        IosSettingsCard(
          children: [
            // 1. 版本号
            IosSettingsTile(
              leading: const IosSettingsIconBox(
                icon: Icons.extension_rounded,
                bg: Color(0xFF5856D6),
              ),
              title: '解析器核心版本',
              showDivider: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'v${meta?.version ?? '1.0.0'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. 在线适配器数量
            IosSettingsTile(
              leading: const IosSettingsIconBox(
                icon: Icons.tv_rounded,
                bg: Color(0xFF34C759),
              ),
              title: '内置视频源集合',
              subtitle: '支持稀饭Next、次元城、girigiri、月之祠等',
              showDivider: true,
              trailing: Text(
                '${sources.length} 个就绪',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                ),
              ),
            ),

            // 3. 检查更新
            IosSettingsTile(
              leading: const IosSettingsIconBox(
                icon: Icons.system_update_rounded,
                bg: Color(0xFF007AFF),
              ),
              title: '检查解析器更新',
              subtitle: '一键云端无感拉取最新反爬规则，无需更新 App',
              showDivider: true,
              onTap: _handleCheckUpdate,
              trailing: _isChecking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded),
            ),

            // 4. 重置出厂
            IosSettingsTile(
              leading: const IosSettingsIconBox(
                icon: Icons.restore_rounded,
                bg: Color(0xFFFF9500),
              ),
              title: '恢复出厂解析器',
              showDivider: false,
              onTap: _handleResetFactory,
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }
}
