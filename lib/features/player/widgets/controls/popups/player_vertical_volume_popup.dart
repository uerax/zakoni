import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:zakoway/features/player/controller/playback_controller.dart';
import 'package:zakoway/features/player/controller/playback_state.dart';

/// 专用原生垂直音量滑槽组件：
/// 纯手势驱动（无需 RotatedBox），基于局部 Y 轴高度精准响应点击与上下拖动，
/// 完美解决 Windows 桌面端鼠标无法驱动旋转后水平 Slider 的顽疾。
class VerticalVolumeBar extends StatelessWidget {
  const VerticalVolumeBar({
    super.key,
    required this.volume,
    required this.activeColor,
    required this.onChanged,
  });

  final double volume; // 0.0 ~ 1.0
  final Color activeColor;
  final ValueChanged<double> onChanged;

  void _handleTouch(Offset localPosition, double height) {
    if (height <= 0) return;
    // 顶部 (y=0) 是 1.0，底部 (y=height) 是 0.0
    final val = (1.0 - (localPosition.dy / height)).clamp(0.0, 1.0);
    onChanged(val);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final clampedVol = volume.clamp(0.0, 1.0);
        final filledHeight = height * clampedVol;
        const trackWidth = 3.5;
        const thumbRadius = 6.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _handleTouch(details.localPosition, height),
          onVerticalDragUpdate: (details) =>
              _handleTouch(details.localPosition, height),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // 1. 底层轨道 (灰色)
                Container(
                  width: trackWidth,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(trackWidth / 2),
                  ),
                ),
                // 2. 已填充音量 (主题色)
                Container(
                  width: trackWidth,
                  height: filledHeight,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(trackWidth / 2),
                  ),
                ),
                // 3. 滑块圆球 (白色)
                Positioned(
                  bottom: (filledHeight - thumbRadius)
                      .clamp(0.0, height - thumbRadius * 2),
                  child: Container(
                    width: thumbRadius * 2,
                    height: thumbRadius * 2,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 垂直音量调节气泡浮层（带毛玻璃、当前音量数值与垂直滑轨）
class PlayerVerticalVolumePopup extends StatelessWidget {
  const PlayerVerticalVolumePopup({
    super.key,
    required this.controller,
    required this.primaryColor,
    required this.onVolumeChanged,
  });

  final ZakowayPlaybackController controller;
  final Color primaryColor;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlaybackCoreState>(
      valueListenable: controller.core,
      builder: (context, coreState, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: 36,
              height: 112,
              padding: const EdgeInsets.fromLTRB(4, 7, 4, 8),
              decoration: BoxDecoration(
                color: const Color(0xEE16161C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    '${(coreState.volume * 100).round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 5),
                  // 特殊处理说明：
                  // 彻底移除原先手势错位的 RotatedBox(quarterTurns: 3) + 水平 Slider，
                  // 改用原生基于 Y 轴坐标计算的专属垂直音量滑轨，完美支持鼠标任意点击与上下拖拽，
                  // 移除面板底部多余小喇叭，拉到底部即为 0 音量自动静音。
                  Expanded(
                    child: VerticalVolumeBar(
                      volume: coreState.volume,
                      activeColor: primaryColor,
                      onChanged: onVolumeChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
