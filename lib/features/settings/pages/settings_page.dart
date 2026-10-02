import 'package:flutter/material.dart';
import '../../../core/network/bangumi_client.dart';
import '../../../core/utils/appearance_manager.dart';
import '../../../core/utils/font_manager.dart';
import '../widgets/about_settings_card.dart';
import '../widgets/appearance_settings_card.dart';
import '../widgets/cache_settings_card.dart';
import '../widgets/font_settings_card.dart';
import '../widgets/network_settings_card.dart';

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

  void _onPresetChanged(BangumiSourcePreset preset) {
    setState(() {
      _currentPreset = preset;
    });
    widget.onSettingsChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final fontMgr = FontManager.instance;
    final appMgr = AppearanceManager.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([appMgr, fontMgr]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              '设置',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            centerTitle: true,
          ),
          body: ListView(
            // 底部预留 96px 间距，适配悬浮毛玻璃底栏穿透
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              // 1. 网络线路
              NetworkSettingsCard(
                client: widget.client,
                currentPreset: _currentPreset,
                onPresetChanged: _onPresetChanged,
              ),

              // 2. 缓存管理
              CacheSettingsCard(client: widget.client),

              // 3. 字体设置
              const FontSettingsCard(),

              // 4. 个性化外观 (图标与壁纸)
              const AppearanceSettingsCard(),

              // 5. 关于应用
              const AboutSettingsCard(),
            ],
          ),
        );
      },
    );
  }
}
