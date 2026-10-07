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
  final bool isVisible;

  const SettingsPage({
    super.key,
    required this.client,
    this.onSettingsChanged,
    this.isVisible = false,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with AutomaticKeepAliveClientMixin {
  late BangumiSourcePreset _currentPreset;
  bool _hasBeenVisible = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentPreset = widget.client.sourcePreset;
    if (widget.isVisible) {
      _hasBeenVisible = true;
    }
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      if (!_hasBeenVisible) {
        // 进入可视区后，下一帧异步将真实设置卡片挂载上屏，彻底消除切页阻塞
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasBeenVisible) {
            setState(() {
              _hasBeenVisible = true;
            });
          }
        });
      }
    }
  }

  void _onPresetChanged(BangumiSourcePreset preset) {
    setState(() {
      _currentPreset = preset;
    });
    widget.onSettingsChanged?.call();
  }

  Widget _buildSettingsSkeleton(ThemeData theme) {
    Widget buildSkeletonCard(double height) {
      return Container(
        height: height,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
      );
    }

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        buildSkeletonCard(110),
        buildSkeletonCard(96),
        buildSkeletonCard(120),
        buildSkeletonCard(88),
        buildSkeletonCard(96),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
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
              child: !_hasBeenVisible
                  ? _buildSettingsSkeleton(theme)
                  : ListView(
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
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
