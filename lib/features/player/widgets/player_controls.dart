import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zakoni/features/player/controller/playback_controller.dart';
import 'package:zakoni/features/player/controller/playback_state.dart';
import 'package:zakoni/features/player/danmaku/danmaku.dart';

/// 播放器交互控制浮层
class PlayerControls extends StatefulWidget {
  const PlayerControls({
    super.key,
    required this.controller,
    this.title = '',
    this.danmakuController,
    this.isFullscreen = false,
    this.onToggleFullscreen,
    this.onBackPressed,
    this.onOpenEpisodePicker,
  });

  final ZakoniPlaybackController controller;
  final String title;
  final DanmakuController? danmakuController;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onBackPressed;
  final VoidCallback? onOpenEpisodePicker;

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  bool _visible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _visible && widget.controller.core.value.playing) {
        setState(() => _visible = false);
      }
    });
  }

  void _toggleVisibility() {
    setState(() {
      _visible = !_visible;
      if (_visible) {
        _startHideTimer();
      } else {
        _hideTimer?.cancel();
      }
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleVisibility,
      onDoubleTap: () => widget.controller.togglePlay(),
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: IgnorePointer(
          ignoring: !_visible,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. 顶部渐变与顶部控制条
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      if (widget.onBackPressed != null)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 20),
                          onPressed: widget.onBackPressed,
                        ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (widget.onOpenEpisodePicker != null)
                        TextButton.icon(
                          icon: const Icon(Icons.video_library_outlined,
                              color: Colors.white, size: 18),
                          label: const Text('选集',
                              style: TextStyle(color: Colors.white, fontSize: 13)),
                          onPressed: widget.onOpenEpisodePicker,
                        ),
                    ],
                  ),
                ),
              ),

              // 2. 底部渐变与底部控制条
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 进度滑块（通过 timeline 单独驱动，不让整页重绘）
                      ValueListenableBuilder<PlaybackTimelineState>(
                        valueListenable: widget.controller.timeline,
                        builder: (context, timelineState, _) {
                          final durationMs =
                              timelineState.duration.inMilliseconds.toDouble();
                          final posMs = timelineState
                              .displayPosition.inMilliseconds
                              .toDouble();
                          final maxVal = durationMs > 0 ? durationMs : 1.0;
                          final currentVal =
                              posMs.clamp(0.0, maxVal).toDouble();

                          return Row(
                            children: [
                              Text(
                                _formatDuration(timelineState.displayPosition),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3.0,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6.0,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 14.0,
                                    ),
                                    activeTrackColor:
                                        Theme.of(context).colorScheme.primary,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: Colors.white,
                                  ),
                                  child: Slider(
                                    value: currentVal,
                                    max: maxVal,
                                    onChanged: (val) {
                                      _startHideTimer();
                                      widget.controller.updateSeekPreview(
                                        Duration(milliseconds: val.round()),
                                      );
                                    },
                                    onChangeEnd: (_) {
                                      _startHideTimer();
                                      widget.controller.endSeekPreview();
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                _formatDuration(timelineState.duration),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          );
                        },
                      ),

                      // 底部按钮操作行
                      Row(
                        children: [
                          // 播放 / 暂停按钮
                          ValueListenableBuilder<PlaybackCoreState>(
                            valueListenable: widget.controller.core,
                            builder: (context, coreState, _) {
                              return IconButton(
                                icon: Icon(
                                  coreState.playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: () {
                                  _startHideTimer();
                                  widget.controller.togglePlay();
                                },
                              );
                            },
                          ),

                          const Spacer(),

                          // 弹幕开关
                          if (widget.danmakuController != null)
                            ListenableBuilder(
                              listenable: widget.danmakuController!,
                              builder: (context, _) {
                                final isEnabled =
                                    widget.danmakuController!.settings.enabled;
                                return IconButton(
                                  icon: Icon(
                                    isEnabled
                                        ? Icons.subtitles_rounded
                                        : Icons.subtitles_off_outlined,
                                    color: isEnabled
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.white54,
                                    size: 22,
                                  ),
                                  tooltip: isEnabled ? '关闭弹幕' : '开启弹幕',
                                  onPressed: () {
                                    _startHideTimer();
                                    final current =
                                        widget.danmakuController!.settings;
                                    widget.danmakuController!.updateSettings(
                                      current.copyWith(enabled: !isEnabled),
                                    );
                                  },
                                );
                              },
                            ),

                          // 倍速选择
                          ValueListenableBuilder<PlaybackCoreState>(
                            valueListenable: widget.controller.core,
                            builder: (context, coreState, _) {
                              return PopupMenuButton<double>(
                                tooltip: '倍速',
                                initialValue: coreState.playbackRate,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: Text(
                                    coreState.playbackRate == 1.0
                                        ? '倍速'
                                        : '${coreState.playbackRate}x',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                onSelected: (speed) {
                                  _startHideTimer();
                                  widget.controller.setPlaybackRate(speed);
                                },
                                itemBuilder: (context) => [
                                  for (final speed in [0.75, 1.0, 1.25, 1.5, 2.0, 3.0])
                                    PopupMenuItem(
                                      value: speed,
                                      child: Text('${speed}x'),
                                    ),
                                ],
                              );
                            },
                          ),

                          // 全屏切换
                          if (widget.onToggleFullscreen != null)
                            IconButton(
                              icon: Icon(
                                widget.isFullscreen
                                    ? Icons.fullscreen_exit_rounded
                                    : Icons.fullscreen_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                              onPressed: () {
                                _startHideTimer();
                                widget.onToggleFullscreen?.call();
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
