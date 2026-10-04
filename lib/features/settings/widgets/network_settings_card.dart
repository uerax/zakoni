import 'package:flutter/material.dart';
import '../../../core/network/bangumi_client.dart';
import '../../../core/utils/image_utils.dart';
import 'ios_settings_card.dart';

class NetworkSettingsCard extends StatelessWidget {
  final BangumiClient client;
  final BangumiSourcePreset currentPreset;
  final ValueChanged<BangumiSourcePreset> onPresetChanged;

  const NetworkSettingsCard({
    super.key,
    required this.client,
    required this.currentPreset,
    required this.onPresetChanged,
  });

  void _handlePresetChanged(BuildContext context, BangumiSourcePreset preset) {
    if (preset == currentPreset) return;

    onPresetChanged(preset);
    client.setSourcePreset(preset);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    debugPrint('【网络线路切换成功】生效预设: ${preset.name}, API Base: ${client.baseUrl}, 当前图片Host: $currentBangumiImageHost');

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const IosSettingsSectionHeader(title: '网络线路'),
        IosSettingsCard(
          children: [
            IosSettingsTile(
              leading: const IosSettingsIconBox(
                icon: Icons.bolt_rounded,
                bg: Color(0xFF0077B6),
              ),
              title: '镜像加速',
              subtitle: '国内 CDN 加速',
              trailing: currentPreset == BangumiSourcePreset.mirror
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary, size: 20)
                  : null,
              onTap: () => _handlePresetChanged(context, BangumiSourcePreset.mirror),
            ),
            IosSettingsTile(
              leading: const IosSettingsIconBox(
                icon: Icons.public_rounded,
                bg: Color(0xFF2A9D8F),
              ),
              title: '官方直连',
              subtitle: '海外直连官方源',
              showDivider: false,
              trailing: currentPreset == BangumiSourcePreset.official
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary, size: 20)
                  : null,
              onTap: () => _handlePresetChanged(context, BangumiSourcePreset.official),
            ),
          ],
        ),
      ],
    );
  }
}
