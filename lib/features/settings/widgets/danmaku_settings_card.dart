import 'package:flutter/material.dart';
import 'package:zakoni/features/player/danmaku/source/dandan_config_manager.dart';
import 'm3_settings_card.dart';

/// 弹弹 play 弹幕服务设置卡片
class DanmakuSettingsCard extends StatefulWidget {
  const DanmakuSettingsCard({super.key});

  @override
  State<DanmakuSettingsCard> createState() => _DanmakuSettingsCardState();
}

class _DanmakuSettingsCardState extends State<DanmakuSettingsCard> {
  final DandanConfigManager _config = DandanConfigManager.instance;

  @override
  void initState() {
    super.initState();
    if (!_config.isInitialized) {
      _config.initialize();
    }
    _config.addListener(_onConfigChanged);
  }

  @override
  void dispose() {
    _config.removeListener(_onConfigChanged);
    super.dispose();
  }

  void _onConfigChanged() {
    if (mounted) setState(() {});
  }

  void _openConfigDialog() {
    final theme = Theme.of(context);
    final appIdController = TextEditingController(text: _config.appId);
    final appSecretController = TextEditingController(text: _config.appSecret);
    final endpointController = TextEditingController(
      text: _config.apiEndpoint == DandanConfigManager.defaultEndpoint ? '' : _config.apiEndpoint,
    );

    bool isTesting = false;
    String? testResult;
    bool? testSuccess;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> runTest() async {
            setDialogState(() {
              isTesting = true;
              testResult = null;
              testSuccess = null;
            });

            final res = await _config.testConnection(
              testAppId: appIdController.text,
              testAppSecret: appSecretController.text,
              testEndpoint: endpointController.text,
            );

            setDialogState(() {
              isTesting = false;
              testSuccess = res.success;
              testResult = res.message;
            });
          }

          return AlertDialog(
            icon: Icon(
              Icons.key_rounded,
              color: theme.colorScheme.primary,
              size: 28,
            ),
            title: const Text('弹弹 play 凭证配置'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '留空则使用内置通用凭据；若内置失效可前往 open.dandanplay.com 免费申请开发者凭证填入。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: appIdController,
                    decoration: const InputDecoration(
                      labelText: 'App ID',
                      hintText: '如 hvf6pzvxcm',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: appSecretController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'App Secret',
                      hintText: '开放平台私钥',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: endpointController,
                    decoration: const InputDecoration(
                      labelText: 'API 地址',
                      hintText: '选填，默认官方节点',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: isTesting ? null : runTest,
                        child: isTesting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('测试连接'),
                      ),
                      const SizedBox(width: 10),
                      if (testResult != null)
                        Expanded(
                          child: Text(
                            testResult!,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: testSuccess == true
                                  ? const Color(0xFF34C759)
                                  : theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () async {
                  await _config.resetToDefault();
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已恢复为内置默认弹弹凭证')),
                    );
                  }
                },
                child: Text(
                  '恢复默认',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              FilledButton(
                onPressed: () async {
                  await _config.saveConfig(
                    appId: appIdController.text,
                    appSecret: appSecretController.text,
                    apiEndpoint: endpointController.text,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_config.isCustomCredentials
                            ? '已启用自定义弹弹 play 开放平台凭证'
                            : '已保存（使用内置通用凭据）'),
                      ),
                    );
                  }
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCustom = _config.isCustomCredentials;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const M3SettingsSectionHeader(title: '弹幕服务'),
        M3SettingsCard(
          children: [
            M3SettingsTile(
              leading: M3SettingsIconBox(
                icon: Icons.subtitles_rounded,
                bg: theme.colorScheme.primaryContainer,
                iconColor: theme.colorScheme.onPrimaryContainer,
              ),
              title: '弹弹 play API 凭证',
              subtitle: isCustom ? '已启用自定义开放平台凭证 (SHA-256 签名)' : '使用内置通用凭据，点击可自定义防失效',
              showDivider: false,
              onTap: _openConfigDialog,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isCustom ? const Color(0xFF34C759) : theme.colorScheme.primary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isCustom ? '自定义' : '默认',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCustom ? const Color(0xFF34C759) : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
