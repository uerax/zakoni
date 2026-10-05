import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:zakoni/features/player/controller/playback_controller.dart';
import 'package:zakoni/features/player/controller/playback_state.dart';
import 'package:zakoni/features/player/danmaku/danmaku.dart';

/// iOS 现代风格播放器交互控制浮层 (Apple AVPlayer & HIG Style)
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
  bool _isSeeking = false;

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
      if (mounted && _visible && widget.controller.core.value.playing && !_isSeeking) {
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

  String _formatRemaining(Duration pos, Duration total) {
    if (total <= Duration.zero) return '--:--';
    final remaining = total - pos;
    if (remaining.isNegative) return '-00:00';
    return '-${_formatDuration(remaining)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleVisibility,
      onDoubleTap: () => widget.controller.togglePlay(),
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: IgnorePointer(
          ignoring: !_visible,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. 顶部氛围软渐变遮罩 (自然阴影非生硬纯黑)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 96,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.black.withValues(alpha: 0.25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // 2. 底部氛围软渐变遮罩
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 110,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.72),
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // 3. 顶部 iOS 悬浮导航岛
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        if (widget.onBackPressed != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    width: 0.5,
                                  ),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  onPressed: widget.onBackPressed,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 6,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (widget.onOpenEpisodePicker != null) ...[
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                height: 34,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    width: 0.5,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: widget.onOpenEpisodePicker,
                                  borderRadius: BorderRadius.circular(18),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.video_library_rounded,
                                        color: Colors.white,
                                        size: 15,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '选集',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // 4. 底部播放控制与 iOS 拟物流体进度条
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 时间戳与进度条
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

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 时间标签 (经典 iOS: 当前播放时间 与 负倒计时)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(timelineState.displayPosition),
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      Text(
                                        _formatRemaining(
                                            timelineState.displayPosition, timelineState.duration),
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.65),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // iOS 拟物流体胶囊进度滑块
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: _isSeeking ? 6.0 : 4.0,
                                    thumbShape: RoundSliderThumbShape(
                                      enabledThumbRadius: _isSeeking ? 8.0 : 6.0,
                                      elevation: 3.0,
                                      pressedElevation: 6.0,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 14.0,
                                    ),
                                    activeTrackColor: primaryColor,
                                    inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
                                    thumbColor: Colors.white,
                                    trackShape: const RoundedRectSliderTrackShape(),
                                  ),
                                  child: Slider(
                                    value: currentVal,
                                    max: maxVal,
                                    onChangeStart: (_) {
                                      setState(() => _isSeeking = true);
                                      _startHideTimer();
                                    },
                                    onChanged: (val) {
                                      _startHideTimer();
                                      widget.controller.updateSeekPreview(
                                        Duration(milliseconds: val.round()),
                                      );
                                    },
                                    onChangeEnd: (val) {
                                      setState(() => _isSeeking = false);
                                      _startHideTimer();
                                      widget.controller.seek(
                                        Duration(milliseconds: val.round()),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 4),

                        // 底部毛玻璃控制胶囊 (Floating Frosted Capsule)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.38),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 播放 / 暂停按钮
                                  ValueListenableBuilder<PlaybackCoreState>(
                                    valueListenable: widget.controller.core,
                                    builder: (context, coreState, _) {
                                      return IconButton(
                                        iconSize: 24,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                        icon: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 150),
                                          child: Icon(
                                            coreState.playing
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            key: ValueKey(coreState.playing),
                                            color: Colors.white,
                                            size: 26,
                                          ),
                                        ),
                                        onPressed: () {
                                          _startHideTimer();
                                          widget.controller.togglePlay();
                                        },
                                      );
                                    },
                                  ),

                                  Container(
                                    width: 1,
                                    height: 16,
                                    margin: const EdgeInsets.symmetric(horizontal: 6),
                                    color: Colors.white.withValues(alpha: 0.18),
                                  ),

                                  // 弹幕开关
                                  if (widget.danmakuController != null)
                                    ListenableBuilder(
                                      listenable: widget.danmakuController!,
                                      builder: (context, _) {
                                        final isEnabled =
                                            widget.danmakuController!.settings.enabled;
                                        return IconButton(
                                          iconSize: 20,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                          icon: Icon(
                                            isEnabled
                                                ? Icons.subtitles_rounded
                                                : Icons.subtitles_off_outlined,
                                            color: isEnabled
                                                ? primaryColor
                                                : Colors.white.withValues(alpha: 0.5),
                                            size: 20,
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

                                  // 倍速选择 (iOS 风格下拉微菜单)
                                  ValueListenableBuilder<PlaybackCoreState>(
                                    valueListenable: widget.controller.core,
                                    builder: (context, coreState, _) {
                                      return PopupMenuButton<double>(
                                        tooltip: '播放倍速',
                                        initialValue: coreState.playbackRate,
                                        elevation: 8,
                                        color: const Color(0xFF1E1E22),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          side: BorderSide(
                                            color: Colors.white.withValues(alpha: 0.12),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          child: Text(
                                            coreState.playbackRate == 1.0
                                                ? '1.0x'
                                                : '${coreState.playbackRate}x',
                                            style: TextStyle(
                                              color: coreState.playbackRate != 1.0
                                                  ? primaryColor
                                                  : Colors.white.withValues(alpha: 0.9),
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -0.2,
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
                                              height: 38,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    '${speed}x',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: speed == coreState.playbackRate
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: speed == coreState.playbackRate
                                                          ? primaryColor
                                                          : Colors.white,
                                                    ),
                                                  ),
                                                  if (speed == coreState.playbackRate)
                                                    Icon(Icons.check_rounded,
                                                        color: primaryColor, size: 16),
                                                ],
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),

                                  // 全屏切换
                                  if (widget.onToggleFullscreen != null) ...[
                                    Container(
                                      width: 1,
                                      height: 16,
                                      margin: const EdgeInsets.symmetric(horizontal: 6),
                                      color: Colors.white.withValues(alpha: 0.18),
                                    ),
                                    IconButton(
                                      iconSize: 22,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                      icon: Icon(
                                        widget.isFullscreen
                                            ? Icons.fullscreen_exit_rounded
                                            : Icons.fullscreen_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      onPressed: () {
                                        _startHideTimer();
                                        widget.onToggleFullscreen?.call();
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
