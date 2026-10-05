import 'package:flutter/material.dart';
import 'package:zakoni/features/player/danmaku/danmaku.dart';
import 'player_panel_widgets.dart';

/// 播放器弹幕设置面板主体（屏蔽、不透明度、字号、速度、同屏密度等）
class PlayerDanmakuPanelBody extends StatelessWidget {
  const PlayerDanmakuPanelBody({
    super.key,
    required this.danmakuController,
    required this.primaryColor,
  });

  final DanmakuController? danmakuController;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final danmaku = danmakuController;
    if (danmaku == null) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(
          child: Text(
            '当前未挂载弹幕组件',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: danmaku,
      builder: (context, _) {
        final cfg = danmaku.settings;
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const PanelSectionHeader(title: '弹幕基础开关'),
              PanelSwitchRow(
                title: '显示弹幕',
                subtitle: '开启或关闭屏幕所有弹幕',
                value: cfg.enabled,
                primaryColor: primaryColor,
                onChanged: (val) =>
                    danmaku.updateSettings(cfg.copyWith(enabled: val)),
              ),
              PanelSwitchRow(
                title: '智能精简',
                subtitle: '自动抑制重复刷屏与重叠',
                value: cfg.simplify,
                primaryColor: primaryColor,
                onChanged: (val) =>
                    danmaku.updateSettings(cfg.copyWith(simplify: val)),
              ),
              PanelSwitchRow(
                title: '屏蔽彩色弹幕',
                subtitle: '统一渲染为高对比度白色',
                value: cfg.hideColor,
                primaryColor: primaryColor,
                onChanged: (val) =>
                    danmaku.updateSettings(cfg.copyWith(hideColor: val)),
              ),

              const SizedBox(height: 10),
              const PanelSectionHeader(title: '显示范围'),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    PanelOptionChip(
                      label: '半屏 (50%)',
                      selected: (cfg.area - 0.5).abs() < 0.05,
                      primaryColor: primaryColor,
                      onTap: () => danmaku.updateSettings(cfg.copyWith(area: 0.5)),
                    ),
                    PanelOptionChip(
                      label: '3/4 屏',
                      selected: (cfg.area - 0.75).abs() < 0.05,
                      primaryColor: primaryColor,
                      onTap: () => danmaku.updateSettings(cfg.copyWith(area: 0.75)),
                    ),
                    PanelOptionChip(
                      label: '全屏',
                      selected: (cfg.area - 1.0).abs() < 0.05,
                      primaryColor: primaryColor,
                      onTap: () => danmaku.updateSettings(cfg.copyWith(area: 1.0)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              const PanelSectionHeader(title: '视觉调节'),
              PanelSliderRow(
                title: '不透明度',
                valText: '${(cfg.opacity * 100).round()}%',
                value: cfg.opacity,
                min: 0.2,
                max: 1.0,
                primaryColor: primaryColor,
                onChanged: (v) => danmaku.updateSettings(cfg.copyWith(opacity: v)),
              ),
              PanelSliderRow(
                title: '弹幕字号',
                valText: '${(cfg.fontSizeScale * 100).round()}%',
                value: cfg.fontSizeScale,
                min: 0.7,
                max: 1.4,
                primaryColor: primaryColor,
                onChanged: (v) =>
                    danmaku.updateSettings(cfg.copyWith(fontSizeScale: v)),
              ),
              PanelSliderRow(
                title: '飞行速度',
                valText: '${cfg.speed.toStringAsFixed(1)}x',
                value: cfg.speed,
                min: 0.6,
                max: 1.6,
                primaryColor: primaryColor,
                onChanged: (v) => danmaku.updateSettings(cfg.copyWith(speed: v)),
              ),

              const SizedBox(height: 10),
              const PanelSectionHeader(title: '弹幕类型屏蔽'),
              Row(
                children: [
                  Expanded(
                    child: PanelCheckboxChip(
                      label: '屏蔽滚动',
                      checked: cfg.hideScroll,
                      primaryColor: primaryColor,
                      onTap: () => danmaku
                          .updateSettings(cfg.copyWith(hideScroll: !cfg.hideScroll)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: PanelCheckboxChip(
                      label: '屏蔽顶部',
                      checked: cfg.hideTop,
                      primaryColor: primaryColor,
                      onTap: () => danmaku
                          .updateSettings(cfg.copyWith(hideTop: !cfg.hideTop)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: PanelCheckboxChip(
                      label: '屏蔽底部',
                      checked: cfg.hideBottom,
                      primaryColor: primaryColor,
                      onTap: () => danmaku
                          .updateSettings(cfg.copyWith(hideBottom: !cfg.hideBottom)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
