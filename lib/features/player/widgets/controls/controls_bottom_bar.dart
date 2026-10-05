import 'package:flutter/material.dart';
import 'package:zakoni/core/services/bangumi_oped_service.dart';
import 'package:zakoni/features/player/controller/playback_controller.dart';
import 'package:zakoni/features/player/controller/playback_state.dart';
import 'package:zakoni/features/player/danmaku/danmaku.dart';
import 'package:zakoni/features/player/widgets/player_progress_bar.dart';

/// 播放器底部控制通栏（包含全宽流体进度条与主流对齐的经典通栏控制行）
class PlayerControlsBottomBar extends StatelessWidget {
  const PlayerControlsBottomBar({
    super.key,
    required this.controller,
    required this.primaryColor,
    this.danmakuController,
    this.opedSegment,
    this.isFullscreen = false,
    this.onPrevEpisode,
    this.onNextEpisode,
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
  final VoidCallback? onPrevEpisode;
  final VoidCallback? onNextEpisode;
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

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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

            // 2. 现代经典通栏控制行（对标 Bilibili/主流播放器底栏排布，紧凑适配手机竖屏）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: [
                  // (1) 播放 / 暂停按钮（圆角微高亮卡片）
                  ValueListenableBuilder<PlaybackCoreState>(
                    valueListenable: controller.core,
                    builder: (context, coreState, _) {
                      return Material(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            onUserInteraction();
                            controller.togglePlay();
                          },
                          child: Container(
                            width: 28,
                            height: 26,
                            alignment: Alignment.center,
                            child: Icon(
                              coreState.playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              key: ValueKey(coreState.playing),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 4),

                  // (2) 上一集按钮
                  if (onPrevEpisode != null) ...[
                    IconButton(
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 26),
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      tooltip: '上一集',
                      onPressed: () {
                        onUserInteraction();
                        onPrevEpisode!();
                      },
                    ),
                    const SizedBox(width: 1),
                  ],

                  // (3) 下一集按钮
                  if (onNextEpisode != null) ...[
                    IconButton(
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 26),
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      tooltip: '下一集',
                      onPressed: () {
                        onUserInteraction();
                        onNextEpisode!();
                      },
                    ),
                    const SizedBox(width: 4),
                  ],

                  // (4) 时间戳展示：0:01 / 23:42
                  ValueListenableBuilder<PlaybackTimelineState>(
                    valueListenable: controller.timeline,
                    builder: (context, timelineState, _) {
                      final pos =
                          _formatDuration(timelineState.displayPosition);
                      final total = _formatDuration(timelineState.duration);
                      return Text(
                        '$pos / $total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
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

                  const Spacer(),

                  // (5) 弹幕开关药丸 [弹]
                  if (danmakuController != null) ...[
                    ListenableBuilder(
                      listenable: danmakuController!,
                      builder: (context, _) {
                        final isEnabled =
                            danmakuController!.settings.enabled;
                        return InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () {
                            onUserInteraction();
                            final current = danmakuController!.settings;
                            danmakuController!.updateSettings(
                              current.copyWith(enabled: !isEnabled),
                            );
                          },
                          child: Container(
                            width: 22,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isEnabled
                                    ? primaryColor
                                    : Colors.white54,
                                width: 1.0,
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
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 3),

                    // (6) 弹幕设置面板按钮 [弹⚙]
                    IconButton(
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: (isDanmakuPanelActive && isFullscreen)
                            ? primaryColor
                            : Colors.white,
                      ),
                      tooltip: '弹幕设置',
                      onPressed: onOpenDanmakuPanel,
                    ),
                    const SizedBox(width: 2),
                  ],

                  // (7) 倍速选择 [1x]
                  ValueListenableBuilder<PlaybackCoreState>(
                    valueListenable: controller.core,
                    builder: (context, coreState, _) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onToggleSpeedPopup,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 4),
                          decoration: BoxDecoration(
                            color: showSpeedPopup
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
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
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 2),

                  // (8) 播放设置按钮 [⚙]（内聚：超分/片头片尾/画幅比例）
                  IconButton(
                    iconSize: 19,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 26, minHeight: 26),
                    icon: Icon(
                      Icons.settings_outlined,
                      color: (isSettingsPanelActive && isFullscreen)
                          ? primaryColor
                          : Colors.white,
                      size: 19,
                    ),
                    tooltip: '播放设置（超分/片头片尾/画幅）',
                    onPressed: onOpenSettingsPanel,
                  ),

                  const SizedBox(width: 2),

                  // (9) 竖式音量控制按钮 [🔊]（在按钮正上方悬浮垂直滑块，0 偏移）
                  ValueListenableBuilder<PlaybackCoreState>(
                    valueListenable: controller.core,
                    builder: (context, coreState, _) {
                      final isMuted =
                          coreState.muted || coreState.volume <= 0.001;
                      return IconButton(
                        iconSize: 19,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 26, minHeight: 26),
                        icon: Icon(
                          isMuted
                              ? Icons.volume_off_rounded
                              : (coreState.volume > 0.5
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_down_rounded),
                          color: isMuted ? Colors.white54 : Colors.white,
                          size: 19,
                        ),
                        tooltip: isMuted ? '取消静音' : '音量调节',
                        onPressed: onToggleVolumeSlider,
                      );
                    },
                  ),

                  // (10) 全屏切换按钮 [⛶]
                  if (onToggleFullscreen != null) ...[
                    const SizedBox(width: 3),
                    IconButton(
                      iconSize: 19,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: Icon(
                        isFullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                      tooltip: isFullscreen ? '退出全屏' : '进入全屏',
                      onPressed: () {
                        onUserInteraction();
                        onToggleFullscreen?.call();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
