import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import 'm3_settings_card.dart';

class AboutSettingsCard extends StatelessWidget {
  const AboutSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const M3SettingsSectionHeader(title: '关于应用'),
        M3SettingsCard(
          footerText: 'Zakoni - 跨平台动漫流媒体播放与番剧追踪客户端',
          children: [
            M3SettingsTile(
              leading: const M3SettingsIconBox(
                icon: Icons.info_outline_rounded,
                bg: Color(0xFF8E8E93),
              ),
              title: '版本号',
              showDivider: false,
              trailing: Text(
                'v${AppConstants.appVersion}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                  fontWeight: FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
