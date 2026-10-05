import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:zakoni/features/player/controller/playback_controller.dart';
import 'package:zakoni/features/player/controller/playback_state.dart';

/// 垂直倍速选择气泡浮层（带毛玻璃背景、降序排布与选中勾选指示）
class PlayerSpeedPopup extends StatelessWidget {
  const PlayerSpeedPopup({
    super.key,
    required this.controller,
    required this.primaryColor,
    required this.onSelectSpeed,
  });

  final ZakoniPlaybackController controller;
  final Color primaryColor;
  final ValueChanged<double> onSelectSpeed;

  // 特殊处理说明：
  // 向上展开的气泡按降序排列：顶部 2.0x -> 底部 0.75x，贴合由低到高靠近 1x 按钮的直觉排布；
  // 移除极少使用的 0.5x 与 3.0x，只保留 5 档核心倍速，更显小巧克制
  static const List<double> supportedSpeeds = [2.0, 1.5, 1.25, 1.0, 0.75];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlaybackCoreState>(
      valueListenable: controller.core,
      builder: (context, coreState, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: 82,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xEE16161C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final speed in supportedSpeeds)
                    _buildSpeedItem(speed, coreState.playbackRate),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpeedItem(double speed, double currentRate) {
    final isSelected = speed == currentRate;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelectSpeed(speed),
      child: Container(
        height: 25,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${speed}x',
              style: TextStyle(
                color: isSelected
                    ? primaryColor
                    : Colors.white.withValues(alpha: 0.9),
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, color: primaryColor, size: 12),
          ],
        ),
      ),
    );
  }
}
