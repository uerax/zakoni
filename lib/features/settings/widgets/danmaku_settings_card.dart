import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:zakoni/core/utils/font_manager.dart';
import 'package:zakoni/features/player/danmaku/source/dandan_config_manager.dart';
import 'ios_settings_card.dart';

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

    showCupertinoDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentFont = FontManager.instance.activeFontFamily;
          final fontFallback = FontManager.fallbackFontFamilies;
          final baseStyle = TextStyle(
            fontFamily: currentFont,
            fontFamilyFallback: fontFallback,
          );

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

          return CupertinoAlertDialog(
            title: Text(
              '弹弹 play 凭证配置',
              style: baseStyle.copyWith(fontWeight: FontWeight.bold),
            ),
            content: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '留空则使用内置通用凭据；若内置失效可前往 open.dandanplay.com 免费申请开发者凭证填入。',
                    style: baseStyle.copyWith(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: appIdController,
                    placeholder: 'App ID (如 hvf6pzvxcm)',
                    style: baseStyle.copyWith(fontSize: 13),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: appSecretController,
                    placeholder: 'App Secret (开放平台私钥)',
                    obscureText: true,
                    style: baseStyle.copyWith(fontSize: 13),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: endpointController,
                    placeholder: 'API 地址 (选填，默认官方节点)',
                    style: baseStyle.copyWith(fontSize: 13),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        onPressed: isTesting ? null : runTest,
                        child: isTesting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CupertinoActivityIndicator(radius: 7),
                              )
                            : Text(
                                '测试连接',
                                style: baseStyle.copyWith(
                                  fontSize: 12,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      if (testResult != null)
                        Expanded(
                          child: Text(
                            testResult!,
                            style: baseStyle.copyWith(
                              fontSize: 11,
                              color: testSuccess == true ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
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
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('取消', style: baseStyle),
              ),
              CupertinoDialogAction(
                onPressed: () async {
                  await _config.resetToDefault();
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已恢复为内置默认弹弹凭证')),
                    );
                  }
                },
                child: Text('恢复默认', style: baseStyle.copyWith(color: Colors.orange)),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
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
                child: Text('保存', style: baseStyle.copyWith(fontWeight: FontWeight.bold)),
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
        const IosSettingsSectionHeader(title: '弹幕服务'),
        IosSettingsCard(
          children: [
            IosSettingsTile(
              leading: const IosSettingsIconBox(
                icon: Icons.subtitles_rounded,
                bg: Color(0xFF00B4D8),
              ),
              title: '弹弹 play API 凭证',
              subtitle: isCustom ? '已启用自定义开放平台凭证 (SHA-256 签名)' : '使用内置通用凭据，点击可自定义防失效',
              showDivider: false,
              onTap: _openConfigDialog,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isCustom ? const Color(0xFF34C759) : theme.colorScheme.primary)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
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
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
