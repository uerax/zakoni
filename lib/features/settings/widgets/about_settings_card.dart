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
          children: [
            M3SettingsTile(
              leading: M3SettingsIconBox(
                icon: Icons.info_outline_rounded,
                bg: theme.colorScheme.surfaceContainerHighest,
                iconColor: theme.colorScheme.onSurfaceVariant,
              ),
              title: '版本号',
              showDivider: false,
              trailing: Text(
                'v${AppConstants.appVersion} (Build ${AppConstants.buildNumber})',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
