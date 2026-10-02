import 'package:flutter/material.dart';
import 'app_icon_tile.dart';
import 'ios_settings_card.dart';
import 'wallpaper_settings_tile.dart';

class AppearanceSettingsCard extends StatelessWidget {
  const AppearanceSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        IosSettingsSectionHeader(title: '个性化外观'),
        IosSettingsCard(
          children: [
            AppIconTile(),
            WallpaperSettingsTile(),
          ],
        ),
      ],
    );
  }
}
