import 'package:flutter/material.dart';
import '../../../core/network/bangumi_client.dart';
import '../../../core/utils/appearance_manager.dart';
import '../../../core/utils/font_manager.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/about_settings_card.dart';
import '../widgets/appearance_settings_card.dart';
import '../widgets/cache_settings_card.dart';
import '../widgets/danmaku_settings_card.dart';
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

class _SettingsPageState extends State<SettingsPage> with AutomaticKeepAliveClientMixin {
  late BangumiSourcePreset _currentPreset;

  @override
  bool get wantKeepAlive => true;

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
    super.build(context);
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
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppBreakpoints.maxSettingsWidth),
              child: ListView(
                // 底部预留 96px 间距，适配悬浮毛玻璃底栏穿透
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  // 1. 网络线路
                  NetworkSettingsCard(
                    client: widget.client,
                    currentPreset: _currentPreset,
                    onPresetChanged: _onPresetChanged,
                    onRouteChanged: () => widget.onSettingsChanged?.call(),
                  ),

                  // 2. 缓存管理
                  CacheSettingsCard(client: widget.client),

                  // 3. 弹幕服务
                  const DanmakuSettingsCard(),

                  // 4. 字体设置
                  const FontSettingsCard(),

                  // 4. 个性化外观 (图标与壁纸)
                  const AppearanceSettingsCard(),

                  // 5. 关于应用
                  const AboutSettingsCard(),

                  // 注释预留：后续正式引入用户/个人中心页面 (ProfilePage) 时，
                  // 将在此处或用户中心挂载“播放历史”入口：
                  // Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryPage()));
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
