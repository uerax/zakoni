import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/bangumi_client.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/utils/image_utils.dart';
import '../../common/widgets/ios_swipe_action_tile.dart';
import 'm3_settings_card.dart';

class NetworkSettingsCard extends StatefulWidget {
  final BangumiClient client;
  final BangumiSourcePreset currentPreset;
  final ValueChanged<BangumiSourcePreset> onPresetChanged;
  final VoidCallback? onRouteChanged;

  const NetworkSettingsCard({
    super.key,
    required this.client,
    required this.currentPreset,
    required this.onPresetChanged,
    this.onRouteChanged,
  });

  @override
  State<NetworkSettingsCard> createState() => _NetworkSettingsCardState();
}

class _NetworkSettingsCardState extends State<NetworkSettingsCard> {
  late String _activeRouteId;
  late List<CustomNetworkRoute> _customRoutes;

  @override
  void initState() {
    super.initState();
    _activeRouteId = widget.client.activeRouteId;
    _customRoutes = AppPreferences.getCustomNetworkRoutes();
  }

  @override
  void didUpdateWidget(covariant NetworkSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client.activeRouteId != widget.client.activeRouteId) {
      _activeRouteId = widget.client.activeRouteId;
    }
  }

  void _handlePresetChanged(
    BuildContext context,
    BangumiSourcePreset preset, {
    bool showSnack = true,
  }) {
    if (_activeRouteId == preset.name) return;

    setState(() {
      _activeRouteId = preset.name;
    });
    widget.onPresetChanged(preset);
    widget.client.setSourcePreset(preset);
    widget.onRouteChanged?.call();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    debugPrint(
      '【网络线路切换成功】生效预设: ${preset.name}, API Base: ${widget.client.baseUrl}, 当前图片Host: $currentBangumiImageHost',
    );

    if (showSnack) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              preset == BangumiSourcePreset.mirror ? '已切换至镜像加速' : '已切换至官方直连',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  void _handleCustomRouteChanged(BuildContext context, CustomNetworkRoute route) {
    if (_activeRouteId == route.id) return;

    setState(() {
      _activeRouteId = route.id;
    });
    widget.client.setCustomRoute(route);
    widget.onPresetChanged(widget.client.sourcePreset);
    widget.onRouteChanged?.call();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    debugPrint(
      '【网络线路切换成功】生效自定义线路: ${route.name}, URL: ${route.url}, 当前图片Host: $currentBangumiImageHost',
    );

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('已切换至自定义线路【${route.name}】'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _confirmDeleteRoute(CustomNetworkRoute route) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.error,
          size: 28,
        ),
        title: const Text('移除自定义线路'),
        content: Text('确定要移除【${route.name}】吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteRoute(route);
            },
            child: const Text('确认移除'),
          ),
        ],
      ),
    );
  }

  void _deleteRoute(CustomNetworkRoute route) {
    setState(() {
      _customRoutes.removeWhere((r) => r.id == route.id);
    });
    AppPreferences.saveCustomNetworkRoutes(_customRoutes);

    final wasActive = _activeRouteId == route.id;
    if (wasActive) {
      _handlePresetChanged(context, BangumiSourcePreset.mirror, showSnack: false);
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(wasActive ? '已移除线路【${route.name}】，并恢复至镜像加速' : '已移除线路【${route.name}】'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showAddRouteDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            icon: Icon(
              Icons.add_link_rounded,
              color: theme.colorScheme.primary,
              size: 28,
            ),
            title: const Text('添加自定义线路'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '线路名称（选填）',
                    hintText: '如：备用节点',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: '反代 URL 或仓库链接',
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      setDialogState(() {
                        urlController.text = AppConstants.defaultRoutesRepoUrl;
                        if (nameController.text.trim().isEmpty) {
                          nameController.text = '内置仓库线路';
                        }
                      });
                    },
                    child: const Text('点击填入内置仓库链接'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () async {
                    var rawUrl = urlController.text.trim();
                    if (rawUrl.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('请输入反代 URL 或链接'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
                      rawUrl = 'https://$rawUrl';
                    }
                    rawUrl = rawUrl.replaceFirst(RegExp(r'/+$'), '');

                    final rawName = nameController.text.trim();

                    // 【核心区分】：判断是 JSON 仓库配置文件，还是普通反代 Base URL
                    final isJsonRepo = rawUrl.endsWith('.json') ||
                        rawUrl.contains('routes.json') ||
                        rawUrl == AppConstants.defaultRoutesRepoUrl;

                    if (isJsonRepo) {
                      // 分支 A：从 JSON 仓库配置文件导入线路
                      List<CustomNetworkRoute> parsedRoutes = [];
                      try {
                        final dio = Dio(
                          BaseOptions(
                            connectTimeout: const Duration(seconds: 5),
                            receiveTimeout: const Duration(seconds: 5),
                          ),
                        );
                        final res = await dio.get(rawUrl);
                        final data = res.data;
                        List<dynamic> items = [];
                        if (data is List) {
                          items = data;
                        } else if (data is Map && data['routes'] is List) {
                          items = data['routes'] as List;
                        }

                        final now = DateTime.now().millisecondsSinceEpoch;
                        for (var i = 0; i < items.length; i++) {
                          final item = items[i];
                          if (item is Map) {
                            final n = (item['name'] ?? item['label'] ?? '仓库节点 ${i + 1}').toString().trim();
                            final u = (item['url'] ?? item['apiBase'] ?? '').toString().trim();
                            if (u.isNotEmpty) {
                              parsedRoutes.add(CustomNetworkRoute(
                                id: 'custom_${now}_$i',
                                name: n,
                                url: u,
                              ));
                            }
                          }
                        }
                      } catch (_) {
                        // 远端仓库尚未编写/暂不可达时的安全占位回退
                        if (rawUrl == AppConstants.defaultRoutesRepoUrl) {
                          final now = DateTime.now().millisecondsSinceEpoch;
                          parsedRoutes = [
                            CustomNetworkRoute(
                              id: 'custom_${now}_0',
                              name: rawName.isNotEmpty ? rawName : '内置社区线路 (占位)',
                              url: 'https://bgmapi.anibt.net',
                            ),
                          ];
                        }
                      }

                      if (parsedRoutes.isEmpty) {
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                            ..clearSnackBars()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text('解析仓库链接失败，未找到有效节点'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                        }
                        return;
                      }

                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                      }

                      if (!mounted) return;

                      setState(() {
                        _customRoutes.addAll(parsedRoutes);
                      });
                      AppPreferences.saveCustomNetworkRoutes(_customRoutes);

                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            content: Text('已成功从仓库导入 ${parsedRoutes.length} 条线路'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                    } else {
                      // 分支 B：普通反代 Base URL（如 https://my-proxy.com）
                      final displayName = rawName.isNotEmpty
                          ? rawName
                          : (Uri.tryParse(rawUrl)?.host.isNotEmpty == true
                              ? Uri.tryParse(rawUrl)!.host
                              : '自定义线路 ${_customRoutes.length + 1}');

                      final newRoute = CustomNetworkRoute(
                        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                        name: displayName,
                        url: rawUrl,
                      );

                      Navigator.of(ctx).pop();

                      setState(() {
                        _customRoutes.add(newRoute);
                      });
                      AppPreferences.saveCustomNetworkRoutes(_customRoutes);

                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            content: Text('已添加线路【$displayName】'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                    }
                  },
                  child: const Text('确认添加'),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const M3SettingsSectionHeader(title: '网络线路'),
        M3SettingsCard(
          children: [
            M3SettingsTile(
              leading: M3SettingsIconBox(
                icon: Icons.bolt_rounded,
                bg: theme.colorScheme.primaryContainer,
                iconColor: theme.colorScheme.onPrimaryContainer,
              ),
              title: '镜像加速',
              subtitle: '国内 CDN 加速',
              trailing: _activeRouteId == BangumiSourcePreset.mirror.name
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary, size: 20)
                  : null,
              onTap: () => _handlePresetChanged(context, BangumiSourcePreset.mirror),
            ),
            M3SettingsTile(
              leading: M3SettingsIconBox(
                icon: Icons.public_rounded,
                bg: theme.colorScheme.secondaryContainer,
                iconColor: theme.colorScheme.onSecondaryContainer,
              ),
              title: '官方直连',
              subtitle: '海外直连官方源',
              trailing: _activeRouteId == BangumiSourcePreset.official.name
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary, size: 20)
                  : null,
              onTap: () => _handlePresetChanged(context, BangumiSourcePreset.official),
            ),
            ..._customRoutes.map((route) {
              return IosSwipeActionTile(
                onDelete: () => _confirmDeleteRoute(route),
                child: M3SettingsTile(
                  leading: M3SettingsIconBox(
                    icon: Icons.alt_route_rounded,
                    bg: theme.colorScheme.tertiaryContainer,
                    iconColor: theme.colorScheme.onTertiaryContainer,
                  ),
                  title: route.name,
                  subtitle: route.url,
                  trailing: _activeRouteId == route.id
                      ? Icon(Icons.check_rounded, color: theme.colorScheme.primary, size: 20)
                      : null,
                  onTap: () => _handleCustomRouteChanged(context, route),
                ),
              );
            }),
            M3SettingsTile(
              leading: M3SettingsIconBox(
                icon: Icons.add_rounded,
                bg: theme.colorScheme.surfaceContainerHighest,
                iconColor: theme.colorScheme.onSurfaceVariant,
              ),
              title: '添加自定义线路',
              subtitle: '输入反代或从 URL 导入',
              showDivider: false,
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                size: 20,
              ),
              onTap: _showAddRouteDialog,
            ),
          ],
        ),
      ],
    );
  }
}
