import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zakoni/features/player/controller/playback_controller.dart';
import 'package:zakoni/features/player/controller/playback_state.dart';
import 'package:zakoni/features/player/danmaku/danmaku.dart';
import 'package:zakoni/features/player/widgets/player_gesture_layer.dart';
import 'package:zakoni/features/player/widgets/player_indicators.dart';
import 'package:zakoni/features/player/widgets/player_progress_bar.dart';
import 'package:zakoni/features/player/widgets/player_side_panel.dart';
import 'package:zakoni/features/player/widgets/player_skip_toast.dart';
import 'package:zakoni/core/services/bangumi_oped_service.dart';

/// 工业级多端自适应播放器交互控制浮层
/// 整合了手势感知层、毛玻璃 HUD 反馈层、桌面键盘快捷键与软硬件亮度/音量控制
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
    this.onNextEpisode,
    this.onPrevEpisode,
    this.onOpenSidePanel,
    this.opedSegment,
    this.autoSkipOped = true,
  });

  final ZakoniPlaybackController controller;
  final String title;
  final DanmakuController? danmakuController;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onBackPressed;
  final VoidCallback? onOpenEpisodePicker;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPrevEpisode;
  final ValueChanged<PlayerSidePanelTab>? onOpenSidePanel;
  final EpisodeOpedSegment? opedSegment;
  final bool autoSkipOped;

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends State<PlayerControls> {
  bool _visible = true;
  bool _isLocked = false;
  bool _showLockButton = true;
  Timer? _hideTimer;
  Timer? _lockButtonHideTimer;
  bool _isSeekingSlider = false;

  late final FocusNode _keyboardFocusNode;

  // 软件亮度状态（1.0 为正常原画亮度，向下滑动平滑变暗，最低 0.05）
  final ValueNotifier<double> _brightnessNotifier = ValueNotifier<double>(1.0);

  // HUD 状态
  double _verticalIndicatorValue = 0.0;
  bool _isVerticalBrightness = false;
  bool _verticalIndicatorVisible = false;

  Duration _seekIndicatorTarget = Duration.zero;
  Duration _seekIndicatorTotal = Duration.zero;
  int _seekIndicatorDelta = 0;
  bool _seekIndicatorVisible = false;

  double _speedIndicatorValue = 2.0;
  bool _speedIndicatorVisible = false;

  // OP / ED 智能跳过状态
  bool _hasSkippedOp = false;
  bool _hasSkippedEd = false;
  bool _hasUndoneSkip = false;
  String _lastSkippedType = '';
  bool _skipToastVisible = false;
  String _skipToastMessage = '';
  Timer? _skipToastTimer;

  // 视频帧截图状态
  Uint8List? _lastScreenshotBytes;
  bool _screenshotFeedbackVisible = false;
  Timer? _screenshotFeedbackTimer;

  @override
  void initState() {
    super.initState();
    _keyboardFocusNode = FocusNode();
    _startHideTimer();
    widget.controller.timeline.addListener(_checkAutoSkip);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant PlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opedSegment != widget.opedSegment) {
      _hasSkippedOp = false;
      _hasSkippedEd = false;
      _hasUndoneSkip = false;
    }
  }

  @override
  void dispose() {
    widget.controller.timeline.removeListener(_checkAutoSkip);
    _skipToastTimer?.cancel();
    _screenshotFeedbackTimer?.cancel();
    _hideTimer?.cancel();
    _lockButtonHideTimer?.cancel();
    _keyboardFocusNode.dispose();
    _brightnessNotifier.dispose();
    super.dispose();
  }

  Future<void> _handleScreenshot() async {
    final bytes = await widget.controller.screenshot();
    if (bytes != null && mounted) {
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
      setState(() {
        _lastScreenshotBytes = bytes;
        _screenshotFeedbackVisible = true;
      });
      _screenshotFeedbackTimer?.cancel();
      _screenshotFeedbackTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _screenshotFeedbackVisible = false);
      });
    }
  }

  void _checkAutoSkip() {
    final seg = widget.opedSegment;
    if (seg == null || !widget.autoSkipOped || _hasUndoneSkip) return;
    if (!widget.controller.core.value.playing) return;

    final posSec = widget.controller.timeline.value.position.inSeconds;

    // OP 片头跳过
    if (seg.hasOp && !_hasSkippedOp) {
      if (posSec >= seg.opStart! && posSec <= seg.opStart! + 3) {
        _hasSkippedOp = true;
        _lastSkippedType = 'op';
        final dur = seg.opEnd! - seg.opStart!;
        widget.controller.seek(Duration(seconds: seg.opEnd!));
        _triggerSkipToast('已自动跳过片头 ${_formatSeconds(dur)}');
        return;
      }
    }

    // ED 片尾跳过
    if (seg.hasEd && !_hasSkippedEd) {
      if (posSec >= seg.edStart! && posSec <= seg.edStart! + 3) {
        _hasSkippedEd = true;
        _lastSkippedType = 'ed';
        final dur = seg.edEnd! - seg.edStart!;
        widget.controller.seek(Duration(seconds: seg.edEnd!));
        _triggerSkipToast('已自动跳过片尾 ${_formatSeconds(dur)}');
        return;
      }
    }
  }

  void _triggerSkipToast(String msg) {
    setState(() {
      _skipToastVisible = true;
      _skipToastMessage = msg;
    });
    _skipToastTimer?.cancel();
    _skipToastTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _skipToastVisible = false);
    });
  }

  void _handleUndoSkip() {
    _hasUndoneSkip = true;
    _skipToastTimer?.cancel();
    setState(() => _skipToastVisible = false);

    final seg = widget.opedSegment;
    if (seg == null) return;

    if (_lastSkippedType == 'op' && seg.hasOp) {
      widget.controller.seek(Duration(seconds: seg.opStart!));
    } else if (_lastSkippedType == 'ed' && seg.hasEd) {
      widget.controller.seek(Duration(seconds: seg.edStart!));
    }
  }

  String _formatSeconds(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted &&
          _visible &&
          widget.controller.core.value.playing &&
          !_isSeekingSlider &&
          !_isLocked) {
        setState(() {
          _visible = false;
          _showLockButton = false;
        });
      }
    });
  }

  void _toggleControls() {
    if (_isLocked) return;
    setState(() {
      _visible = !_visible;
      _showLockButton = _visible;
      if (_visible) {
        _startHideTimer();
        _keyboardFocusNode.requestFocus();
      } else {
        _hideTimer?.cancel();
      }
    });
  }

  void _handleShowLockedNotice() {
    // 锁屏状态下轻点屏幕，唤出锁形按钮 3.5 秒供用户解锁
    setState(() => _showLockButton = true);
    _lockButtonHideTimer?.cancel();
    _lockButtonHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isLocked) {
        setState(() => _showLockButton = false);
      }
    });
  }

  void _toggleLock() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    setState(() {
      _isLocked = !_isLocked;
      if (_isLocked) {
        _visible = false;
        _showLockButton = true;
        _handleShowLockedNotice();
      } else {
        _visible = true;
        _showLockButton = true;
        _startHideTimer();
      }
    });
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (_isLocked) return KeyEventResult.ignored;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final key = event.logicalKey;

      if (key == LogicalKeyboardKey.space) {
        widget.controller.togglePlay();
        _startHideTimer();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        widget.controller.seekBy(const Duration(seconds: -5));
        _startHideTimer();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowRight) {
        widget.controller.seekBy(const Duration(seconds: 5));
        _startHideTimer();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowUp) {
        final curVol = widget.controller.core.value.volume;
        widget.controller.setVolume((curVol + 0.05).clamp(0.0, 1.0));
        _startHideTimer();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowDown) {
        final curVol = widget.controller.core.value.volume;
        widget.controller.setVolume((curVol - 0.05).clamp(0.0, 1.0));
        _startHideTimer();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.keyF) {
        widget.onToggleFullscreen?.call();
        _startHideTimer();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.keyM) {
        widget.controller.toggleMute();
        _startHideTimer();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.keyC) {
        _handleScreenshot();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.escape && widget.isFullscreen) {
        widget.onToggleFullscreen?.call();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
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

  Widget _buildPillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 0.5,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(event),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 0. 软件亮度滤镜遮罩（当亮度低于 1.0 时平滑暗化底层视频）
          ValueListenableBuilder<double>(
            valueListenable: _brightnessNotifier,
            builder: (context, brightness, _) {
              if (brightness >= 0.99) return const SizedBox.shrink();
              final darkAlpha = (1.0 - brightness).clamp(0.0, 0.88);
              return IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: darkAlpha),
                ),
              );
            },
          ),

          // 1. 底层高敏手势感知层（三等分双击、水平 Seek、垂直音量亮度滑动、长按变速）
          Positioned.fill(
            child: PlayerGestureLayer(
              controller: widget.controller,
              isLocked: _isLocked,
              brightnessNotifier: _brightnessNotifier,
              onToggleControls: _toggleControls,
              onShowLockedNotice: _handleShowLockedNotice,
              onVerticalIndicatorUpdate: (val, isB, visible) {
                setState(() {
                  _verticalIndicatorValue = val;
                  _isVerticalBrightness = isB;
                  _verticalIndicatorVisible = visible;
                });
              },
              onSeekIndicatorUpdate: (target, total, delta, visible) {
                setState(() {
                  _seekIndicatorTarget = target;
                  _seekIndicatorTotal = total;
                  _seekIndicatorDelta = delta;
                  _seekIndicatorVisible = visible;
                });
              },
              onSpeedIndicatorUpdate: (speed, visible) {
                setState(() {
                  _speedIndicatorValue = speed;
                  _speedIndicatorVisible = visible;
                });
              },
            ),
          ),

          // 2. 屏幕中央/顶部 HUD 动态指示层
          // (1) 垂直亮度指示器（左半屏）
          if (_isVerticalBrightness)
            Positioned(
              left: 36,
              top: 0,
              bottom: 0,
              child: Center(
                child: PlayerVerticalLevelIndicator(
                  value: _verticalIndicatorValue,
                  isBrightness: true,
                  visible: _verticalIndicatorVisible,
                ),
              ),
            ),

          // (2) 垂直音量指示器（右半屏）
          if (!_isVerticalBrightness)
            Positioned(
              right: 36,
              top: 0,
              bottom: 0,
              child: Center(
                child: PlayerVerticalLevelIndicator(
                  value: _verticalIndicatorValue,
                  isBrightness: false,
                  visible: _verticalIndicatorVisible,
                ),
              ),
            ),

          // (3) 中央 Seek 预览卡片
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: PlayerSeekPreviewIndicator(
                  visible: _seekIndicatorVisible,
                  targetPosition: _seekIndicatorTarget,
                  totalDuration: _seekIndicatorTotal,
                  deltaSeconds: _seekIndicatorDelta,
                ),
              ),
            ),
          ),

          // (4) 顶部长按 2x 极速微光卡片
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: PlayerSpeedHoldIndicator(
                  visible: _speedIndicatorVisible,
                  speed: _speedIndicatorValue,
                ),
              ),
            ),
          ),

          // 3. 屏幕左侧防误触锁定浮动按钮
          Positioned(
            left: 18,
            top: 0,
            bottom: 0,
            child: Center(
              child: PlayerLockFloatingButton(
                isLocked: _isLocked,
                visible: _showLockButton,
                onTap: _toggleLock,
              ),
            ),
          ),

          // 4. 顶层主控制栏（顶部导航条 + 底部胶囊控制栏）
          AnimatedOpacity(
            opacity: (_visible && !_isLocked) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              ignoring: !_visible || _isLocked,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 顶部氛围自然阴影
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.72),
                            Colors.black.withValues(alpha: 0.28),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 底部氛围自然阴影
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.78),
                            Colors.black.withValues(alpha: 0.32),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 顶部 iOS 悬浮导航岛
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            if (widget.onBackPressed != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.35),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.16),
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
                            if (widget.onOpenEpisodePicker != null ||
                                widget.onOpenSidePanel != null) ...[
                              const SizedBox(width: 8),
                              _buildPillButton(
                                icon: Icons.video_library_rounded,
                                label: '选集',
                                onTap: () {
                                  if (widget.onOpenSidePanel != null) {
                                    widget.onOpenSidePanel!(PlayerSidePanelTab.episodes);
                                  } else {
                                    widget.onOpenEpisodePicker?.call();
                                  }
                                },
                              ),
                              if (widget.isFullscreen &&
                                  widget.onOpenSidePanel != null) ...[
                                const SizedBox(width: 6),
                                _buildPillButton(
                                  icon: Icons.swap_horiz_rounded,
                                  label: '换源',
                                  onTap: () {
                                    widget.onOpenSidePanel!(PlayerSidePanelTab.sources);
                                  },
                                ),
                                if (widget.danmakuController != null) ...[
                                  const SizedBox(width: 6),
                                  _buildPillButton(
                                    icon: Icons.tune_rounded,
                                    label: '弹幕',
                                    onTap: () {
                                      widget.onOpenSidePanel!(PlayerSidePanelTab.danmaku);
                                    },
                                  ),
                                ],
                              ],
                              // 截图按钮
                              const SizedBox(width: 6),
                              _buildPillButton(
                                icon: Icons.camera_alt_outlined,
                                label: '截图',
                                onTap: _handleScreenshot,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 底部播放控制与流体进度条
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 时间戳与进度条
                            ValueListenableBuilder<PlaybackTimelineState>(
                              valueListenable: widget.controller.timeline,
                              builder: (context, timelineState, _) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 时间标签 (当前播放时间 与 负倒计时)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _formatDuration(timelineState
                                                .displayPosition),
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.9),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures()
                                              ],
                                            ),
                                          ),
                                          Text(
                                            _formatRemaining(
                                                timelineState.displayPosition,
                                                timelineState.duration),
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.65),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures()
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    // 复合型进度条（弹幕波形图 + OP/ED 彩色区间 + 缓冲条 + 流体滑块）
                                    PlayerProgressBar(
                                      position: timelineState.displayPosition,
                                      duration: timelineState.duration,
                                      buffer: timelineState.buffer,
                                      opedSegment: widget.opedSegment,
                                      danmakuItems:
                                          widget.danmakuController?.items,
                                      primaryColor: primaryColor,
                                      onChangeStart: (dur) {
                                        setState(() => _isSeekingSlider = true);
                                        _startHideTimer();
                                      },
                                      onChanged: (dur) {
                                        _startHideTimer();
                                        widget.controller.updateSeekPreview(dur);
                                      },
                                      onChangeEnd: (dur) {
                                        setState(
                                            () => _isSeekingSlider = false);
                                        _startHideTimer();
                                        widget.controller.seek(dur);
                                      },
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
                                filter:
                                    ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                                child: Container(
                                  height: 46,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.42),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.16),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 快退 10 秒
                                      IconButton(
                                        iconSize: 22,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                            minWidth: 34, minHeight: 34),
                                        icon: const Icon(
                                          Icons.replay_10_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        tooltip: '快退 10 秒',
                                        onPressed: () {
                                          _startHideTimer();
                                          widget.controller.seekBy(
                                              const Duration(seconds: -10));
                                        },
                                      ),

                                      // 播放 / 暂停按钮
                                      ValueListenableBuilder<PlaybackCoreState>(
                                        valueListenable: widget.controller.core,
                                        builder: (context, coreState, _) {
                                          return IconButton(
                                            iconSize: 26,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                                minWidth: 38, minHeight: 38),
                                            icon: AnimatedSwitcher(
                                              duration: const Duration(
                                                  milliseconds: 150),
                                              child: Icon(
                                                coreState.playing
                                                    ? Icons.pause_rounded
                                                    : Icons.play_arrow_rounded,
                                                key: ValueKey(
                                                    coreState.playing),
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                            ),
                                            onPressed: () {
                                              _startHideTimer();
                                              widget.controller.togglePlay();
                                            },
                                          );
                                        },
                                      ),

                                      // 快进 10 秒
                                      IconButton(
                                        iconSize: 22,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                            minWidth: 34, minHeight: 34),
                                        icon: const Icon(
                                          Icons.forward_10_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        tooltip: '快进 10 秒',
                                        onPressed: () {
                                          _startHideTimer();
                                          widget.controller.seekBy(
                                              const Duration(seconds: 10));
                                        },
                                      ),

                                      Container(
                                        width: 1,
                                        height: 16,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        color: Colors.white
                                            .withValues(alpha: 0.18),
                                      ),

                                      // 弹幕开关
                                      if (widget.danmakuController != null)
                                        ListenableBuilder(
                                          listenable: widget.danmakuController!,
                                          builder: (context, _) {
                                            final isEnabled = widget
                                                .danmakuController!
                                                .settings
                                                .enabled;
                                            return IconButton(
                                              iconSize: 20,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                  minWidth: 34, minHeight: 34),
                                              icon: Icon(
                                                isEnabled
                                                    ? Icons.subtitles_rounded
                                                    : Icons
                                                        .subtitles_off_outlined,
                                                color: isEnabled
                                                    ? primaryColor
                                                    : Colors.white
                                                        .withValues(alpha: 0.5),
                                                size: 20,
                                              ),
                                              tooltip: isEnabled
                                                  ? '关闭弹幕'
                                                  : '开启弹幕',
                                              onPressed: () {
                                                _startHideTimer();
                                                final current = widget
                                                    .danmakuController!
                                                    .settings;
                                                widget.danmakuController!
                                                    .updateSettings(
                                                  current.copyWith(
                                                      enabled: !isEnabled),
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
                                            tooltip: '播放倍速',
                                            initialValue:
                                                coreState.playbackRate,
                                            elevation: 8,
                                            color: const Color(0xFF1E1E22),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              side: BorderSide(
                                                color: Colors.white
                                                    .withValues(alpha: 0.12),
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              child: Text(
                                                coreState.playbackRate == 1.0
                                                    ? '1.0x'
                                                    : '${coreState.playbackRate}x',
                                                style: TextStyle(
                                                  color: coreState
                                                              .playbackRate !=
                                                          1.0
                                                      ? primaryColor
                                                      : Colors.white.withValues(
                                                          alpha: 0.9),
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                            ),
                                            onSelected: (speed) {
                                              _startHideTimer();
                                              widget.controller
                                                  .setPlaybackRate(speed);
                                            },
                                            itemBuilder: (context) => [
                                              for (final speed in [
                                                0.5,
                                                0.75,
                                                1.0,
                                                1.25,
                                                1.5,
                                                2.0,
                                                3.0
                                              ])
                                                PopupMenuItem(
                                                  value: speed,
                                                  height: 38,
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        '${speed}x',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: speed ==
                                                                  coreState
                                                                      .playbackRate
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                  .normal,
                                                          color: speed ==
                                                                  coreState
                                                                      .playbackRate
                                                              ? primaryColor
                                                              : Colors.white,
                                                        ),
                                                      ),
                                                      if (speed ==
                                                          coreState
                                                              .playbackRate)
                                                        Icon(
                                                            Icons.check_rounded,
                                                            color: primaryColor,
                                                            size: 16),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),

                                      // 全屏切换
                                      if (widget.onToggleFullscreen !=
                                          null) ...[
                                        Container(
                                          width: 1,
                                          height: 16,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          color: Colors.white
                                              .withValues(alpha: 0.18),
                                        ),
                                        IconButton(
                                          iconSize: 22,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                              minWidth: 34, minHeight: 34),
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

          // 5. 自动跳过片头/片尾可撤销浮标 (放在控制栏之上，保证点击撤销可交互)
          Positioned(
            left: 20,
            bottom: widget.isFullscreen ? 90 : 70,
            child: PlayerSkipToast(
              visible: _skipToastVisible,
              message: _skipToastMessage,
              onUndo: _handleUndoSkip,
              onDismiss: () => setState(() => _skipToastVisible = false),
            ),
          ),

          // 6. 截图成功微光浮窗反馈 (带缩略图)
          if (_lastScreenshotBytes != null)
            Positioned(
              left: 20,
              bottom: widget.isFullscreen ? 140 : 110,
              child: AnimatedOpacity(
                opacity: _screenshotFeedbackVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _lastScreenshotBytes!,
                              width: 64,
                              height: 36,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '已捕获视频画面',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '截图已生成',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
