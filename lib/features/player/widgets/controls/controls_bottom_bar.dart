import 'package:flutter/material.dart';
import 'package:zakoni/core/services/bangumi_oped_service.dart';
import 'package:zakoni/features/player/controller/playback_controller.dart';
import 'package:zakoni/features/player/controller/playback_state.dart';
import 'package:zakoni/features/player/danmaku/danmaku.dart';
import 'package:zakoni/features/player/widgets/player_progress_bar.dart';
import 'danmaku_settings_icon.dart';

/// 播放器底部控制通栏（包含全宽流体进度条与主流对齐的经典通栏控制行）
class PlayerControlsBottomBar extends StatelessWidget {
  const PlayerControlsBottomBar({
    super.key,
    required this.controller,
    required this.primaryColor,
    this.danmakuController,
    this.opedSegment,
    this.isFullscreen = false,
    this.onToggleFullscreen,
    this.onSeekingSliderChanged,
    required this.onUserInteraction,
    this.showSpeedPopup = false,
    required this.onToggleSpeedPopup,
    this.showVolumeSlider = false,
    required this.onToggleVolumeSlider,
    this.isSettingsPanelActive = false,
    this.isDanmakuPanelActive = false,
    required this.onOpenSettingsPanel,
    required this.onOpenDanmakuPanel,
  });

  final ZakoniPlaybackController controller;
  final Color primaryColor;
  final DanmakuController? danmakuController;
  final EpisodeOpedSegment? opedSegment;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;
  final ValueChanged<bool>? onSeekingSliderChanged;
  final VoidCallback onUserInteraction;

  final bool showSpeedPopup;
  final VoidCallback onToggleSpeedPopup;
  final bool showVolumeSlider;
  final VoidCallback onToggleVolumeSlider;
  final bool isSettingsPanelActive;
  final bool isDanmakuPanelActive;
  final VoidCallback onOpenSettingsPanel;
  final VoidCallback onOpenDanmakuPanel;

  static String _formatDuration(Duration duration, {bool showHours = false}) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    if (showHours || hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildBarButton({
    required Widget icon,
    required VoidCallback? onTap,
    String? tooltip,
  }) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: SizedBox(
          width: 21,
          height: 21,
          child: Center(child: icon),
        ),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final horizontalPad = totalWidth < 400 ? 3.0 : 12.0;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 复合型全宽进度条（弹幕波形图 + OP/ED 彩色区间 + 缓冲条 + 流体滑块）
                ValueListenableBuilder<PlaybackTimelineState>(
                  valueListenable: controller.timeline,
                  builder: (context, timelineState, _) {
                    return PlayerProgressBar(
                      position: timelineState.displayPosition,
                      duration: timelineState.duration,
                      buffer: timelineState.buffer,
                      opedSegment: opedSegment,
                      danmakuItems: danmakuController?.items,
                      primaryColor: primaryColor,
                      onChangeStart: (dur) {
                        onSeekingSliderChanged?.call(true);
                        onUserInteraction();
                      },
                      onChanged: (dur) {
                        onUserInteraction();
                        controller.updateSeekPreview(dur);
                      },
                      onChangeEnd: (dur) {
                        onSeekingSliderChanged?.call(false);
                        onUserInteraction();
                        controller.seek(dur);
                      },
                    );
                  },
                ),

                const SizedBox(height: 1),

                // 2. 现代经典通栏控制行：左侧 2 个元素（播放键 + 时间）靠左，其余全部靠右
                Row(
                  children: [
                    // (1) 播放 / 暂停按钮（左1）
                    ValueListenableBuilder<PlaybackCoreState>(
                      valueListenable: controller.core,
                      builder: (context, coreState, _) {
                        return Material(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: () {
                              onUserInteraction();
                              controller.togglePlay();
                            },
                            child: Container(
                              width: 22,
                              height: 20,
                              alignment: Alignment.center,
                              child: Icon(
                                coreState.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                key: ValueKey(coreState.playing),
                                color: Colors.white,
                                size: 15,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 4),

                    // (2) 时间戳展示：00:03 / 23:42（左2）
                    ValueListenableBuilder<PlaybackTimelineState>(
                      valueListenable: controller.timeline,
                      builder: (context, timelineState, _) {
                        final hasHours = timelineState.duration.inHours > 0;
                        final pos = _formatDuration(
                            timelineState.displayPosition,
                            showHours: hasHours);
                        final total = _formatDuration(timelineState.duration,
                            showHours: hasHours);
                        return Text(
                          '$pos / $total',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.0,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                            fontFeatures: [FontFeature.tabularFigures()],
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // 中间弹性空间，把后面全部元素顶到最右端
                    const Spacer(),

                    // (3) 弹幕开关药丸 [弹]
                    if (danmakuController != null) ...[
                      ListenableBuilder(
                        listenable: danmakuController!,
                        builder: (context, _) {
                          final isEnabled =
                              danmakuController!.settings.enabled;
                          return InkWell(
                            borderRadius: BorderRadius.circular(3),
                            onTap: () {
                              onUserInteraction();
                              final current = danmakuController!.settings;
                              danmakuController!.updateSettings(
                                current.copyWith(enabled: !isEnabled),
                              );
                            },
                            child: Container(
                              width: 17,
                              height: 16,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: isEnabled
                                      ? primaryColor
                                      : Colors.white54,
                                  width: 0.8,
                                ),
                                color: isEnabled
                                    ? primaryColor.withValues(alpha: 0.25)
                                    : Colors.black.withValues(alpha: 0.2),
                              ),
                              child: Text(
                                '弹',
                                style: TextStyle(
                                  color: isEnabled
                                      ? primaryColor
                                      : Colors.white70,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 2),

                      // (4) 弹幕设置面板按钮 [自绘 animaku 专属图标]
                      _buildBarButton(
                        icon: DanmakuSettingsIcon(
                          size: 15,
                          color: (isDanmakuPanelActive && isFullscreen)
                              ? primaryColor
                              : Colors.white,
                        ),
                        tooltip: '弹幕设置',
                        onTap: onOpenDanmakuPanel,
                      ),
                      const SizedBox(width: 1),
                    ],

                    // (5) 倍速选择 [1x / 1.25x ...]
                    ValueListenableBuilder<PlaybackCoreState>(
                      valueListenable: controller.core,
                      builder: (context, coreState, _) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onToggleSpeedPopup,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 2.5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: showSpeedPopup
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              coreState.playbackRate == 1.0
                                  ? '1x'
                                  : '${coreState.playbackRate}x',
                              style: TextStyle(
                                color: (showSpeedPopup ||
                                        coreState.playbackRate != 1.0)
                                    ? primaryColor
                                    : Colors.white.withValues(alpha: 0.9),
                                fontSize: 10.0,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(width: 1),

                    // (6) 播放设置按钮 [⚙]
                    _buildBarButton(
                      icon: Icon(
                        Icons.settings_outlined,
                        color: (isSettingsPanelActive && isFullscreen)
                            ? primaryColor
                            : Colors.white,
                        size: 15,
                      ),
                      tooltip: '播放设置',
                      onTap: onOpenSettingsPanel,
                    ),

                    const SizedBox(width: 1),

                    // (7) 竖式音量控制按钮 [🔊]
                    ValueListenableBuilder<PlaybackCoreState>(
                      valueListenable: controller.core,
                      builder: (context, coreState, _) {
                        final isMuted =
                            coreState.muted || coreState.volume <= 0.001;
                        return _buildBarButton(
                          icon: Icon(
                            isMuted
                                ? Icons.volume_off_rounded
                                : (coreState.volume > 0.5
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_down_rounded),
                            color: isMuted ? Colors.white54 : Colors.white,
                            size: 15,
                          ),
                          tooltip: isMuted ? '取消静音' : '音量调节',
                          onTap: onToggleVolumeSlider,
                        );
                      },
                    ),

                    // (8) 全屏切换按钮 [⛶]
                    if (onToggleFullscreen != null) ...[
                      const SizedBox(width: 1),
                      _buildBarButton(
                        icon: Icon(
                          isFullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        tooltip: isFullscreen ? '退出全屏' : '进入全屏',
                        onTap: () {
                          onUserInteraction();
                          onToggleFullscreen?.call();
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
