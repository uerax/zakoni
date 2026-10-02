import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import 'ios_settings_card.dart';

class AboutSettingsCard extends StatelessWidget {
  const AboutSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const IosSettingsSectionHeader(title: '关于应用'),
        IosSettingsCard(
          children: [
            IosSettingsTile(
              leading: const IosSettingsIconBox(
                icon: Icons.info_outline_rounded,
                bg: Color(0xFF6C757D),
              ),
              title: '版本号',
              trailing: Text(
                'v${AppConstants.appVersion} (Build ${AppConstants.buildNumber})',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                ),
              ),
            ),
            IosSettingsTile(
              leading: const IosSettingsIconBox(
                icon: Icons.api_rounded,
                bg: Color(0xFF6C757D),
              ),
              title: '数据来源',
              showDivider: false,
              trailing: Text(
                'Bangumi API',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
