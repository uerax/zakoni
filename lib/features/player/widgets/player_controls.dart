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

enum _ActiveControlPanel {
  none,
  settings,
  danmaku,
}

class _PlayerControlsState extends State<PlayerControls> {
  bool _visible = true;
  bool _isLocked = false;
  bool _showLockButton = true;
  Timer? _hideTimer;
  Timer? _lockButtonHideTimer;
  bool _isSeekingSlider = false;
  bool _lastPlaying = false;

  late final ValueNotifier<bool> _autoSkipOpedNotifier;
  _ActiveControlPanel _activePanel = _ActiveControlPanel.none;
  bool _showVolumeSlider = false;

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
    _autoSkipOpedNotifier = ValueNotifier<bool>(widget.autoSkipOped);
    _keyboardFocusNode = FocusNode();
    _lastPlaying = widget.controller.core.value.playing;
    widget.controller.timeline.addListener(_checkAutoSkip);
    widget.controller.core.addListener(_onCoreStateChanged);
    _startHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
  }

  void _onCoreStateChanged() {
    final isPlaying = widget.controller.core.value.playing;
    if (isPlaying != _lastPlaying) {
      _lastPlaying = isPlaying;
      if (isPlaying) {
        // 视频进入播放状态，立即调度自动隐藏，杜绝起播前未播放导致的永久停留
        _startHideTimer();
      }
    }
  }

  @override
  void didUpdateWidget(covariant PlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opedSegment != widget.opedSegment) {
      _hasSkippedOp = false;
      _hasSkippedEd = false;
      _hasUndoneSkip = false;
    }
    if (oldWidget.autoSkipOped != widget.autoSkipOped) {
      _autoSkipOpedNotifier.value = widget.autoSkipOped;
    }
  }

  @override
  void dispose() {
    widget.controller.timeline.removeListener(_checkAutoSkip);
    widget.controller.core.removeListener(_onCoreStateChanged);
    _skipToastTimer?.cancel();
    _screenshotFeedbackTimer?.cancel();
    _hideTimer?.cancel();
    _lockButtonHideTimer?.cancel();
    _keyboardFocusNode.dispose();
    _brightnessNotifier.dispose();
    _autoSkipOpedNotifier.dispose();
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
    if (seg == null || !_autoSkipOpedNotifier.value || _hasUndoneSkip) return;
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

  bool get _isCurrentlyInOp {
    final seg = widget.opedSegment;
    if (seg == null || !seg.hasOp) return false;
    final pos = widget.controller.timeline.value.position.inSeconds;
    return pos >= seg.opStart! && pos < seg.opEnd!;
  }

  bool get _isCurrentlyInEd {
    final seg = widget.opedSegment;
    if (seg == null || !seg.hasEd) return false;
    final pos = widget.controller.timeline.value.position.inSeconds;
    return pos >= seg.edStart! && pos < seg.edEnd!;
  }

  void _skipCurrentSegment() {
    final seg = widget.opedSegment;
    if (seg == null) return;
    if (_isCurrentlyInOp) {
      widget.controller.seek(Duration(seconds: seg.opEnd!));
      _triggerSkipToast('已跳过片头');
    } else if (_isCurrentlyInEd) {
      widget.controller.seek(Duration(seconds: seg.edEnd!));
      _triggerSkipToast('已跳过片尾');
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
    _hideTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted &&
          _visible &&
          !_isSeekingSlider &&
          !_isLocked &&
          _activePanel == _ActiveControlPanel.none) {
        if (widget.controller.core.value.playing) {
          setState(() {
            _visible = false;
            _showLockButton = false;
            _showVolumeSlider = false;
          });
        }
      }
    });
  }

  void _handlePointerHover() {
    if (_isLocked) return;
    if (!_visible) {
      setState(() {
        _visible = true;
        _showLockButton = true;
      });
    }
    _startHideTimer();
  }

  void _toggleControls() {
    if (_isLocked) return;
    setState(() {
      _visible = !_visible;
      _showLockButton = _visible;
      if (!_visible) {
        _activePanel = _ActiveControlPanel.none;
        _showVolumeSlider = false;
      }
      if (_visible) {
        _startHideTimer();
        _keyboardFocusNode.requestFocus();
      } else {
        _hideTimer?.cancel();
      }
    });
  }

  void _handleShowLockedNotice() {
    // 锁屏状态下轻点屏幕，唤出锁形按钮 3 秒供用户解锁
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
        _activePanel = _ActiveControlPanel.none;
        _showVolumeSlider = false;
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

    return MouseRegion(
      cursor: (_visible || _isLocked || _activePanel != _ActiveControlPanel.none)
          ? SystemMouseCursors.basic
          : SystemMouseCursors.none,
      onHover: (_) => _handlePointerHover(),
      child: Focus(
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

          // (5) 屏幕中央居中暂停标识（暂停时优雅淡入呈现，点击直接继续播放）
          ValueListenableBuilder<PlaybackCoreState>(
            valueListenable: widget.controller.core,
            builder: (context, coreState, _) {
              final isPaused = !coreState.playing &&
                  !coreState.loading &&
                  !_isLocked &&
                  coreState.firstFrameRendered;

              return AnimatedOpacity(
                opacity: isPaused ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !isPaused,
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        widget.controller.play();
                        _startHideTimer();
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 38,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // 3. 屏幕左侧防误触锁定浮动按钮（严格仅在全屏模式下显示）
          if (widget.isFullscreen)
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

          // 4. 顶层主控制栏（顶部导航条 + 底部极简通栏控制条）
          AnimatedOpacity(
            opacity: (_visible && !_isLocked) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: IgnorePointer(
              ignoring: !_visible || _isLocked,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 顶部氛围自然阴影（加 IgnorePointer 避免吞掉触屏点击）
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 100,
                    child: IgnorePointer(
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
                  ),

                  // 底部氛围自然阴影（加 IgnorePointer 避免吞掉触屏点击）
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 120,
                    child: IgnorePointer(
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
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. 复合型全宽进度条（弹幕波形图 + OP/ED 彩色区间 + 缓冲条 + 流体滑块）
                            ValueListenableBuilder<PlaybackTimelineState>(
                              valueListenable: widget.controller.timeline,
                              builder: (context, timelineState, _) {
                                return PlayerProgressBar(
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
                                    valueListenable: widget.controller.core,
                                    builder: (context, coreState, _) {
                                      return Material(
                                        color: Colors.white.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(6),
                                          onTap: () {
                                            _startHideTimer();
                                            widget.controller.togglePlay();
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
                                  if (widget.onPrevEpisode != null) ...[
                                    IconButton(
                                      iconSize: 18,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 24, minHeight: 26),
                                      icon: const Icon(
                                        Icons.skip_previous_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      tooltip: '上一集',
                                      onPressed: () {
                                        _startHideTimer();
                                        widget.onPrevEpisode!();
                                      },
                                    ),
                                    const SizedBox(width: 1),
                                  ],

                                  // (3) 下一集按钮
                                  if (widget.onNextEpisode != null) ...[
                                    IconButton(
                                      iconSize: 18,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 24, minHeight: 26),
                                      icon: const Icon(
                                        Icons.skip_next_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      tooltip: '下一集',
                                      onPressed: () {
                                        _startHideTimer();
                                        widget.onNextEpisode!();
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                  ],

                                  // (4) 时间戳展示：0:01 / 23:42
                                  ValueListenableBuilder<PlaybackTimelineState>(
                                    valueListenable: widget.controller.timeline,
                                    builder: (context, timelineState, _) {
                                      final pos = _formatDuration(
                                          timelineState.displayPosition);
                                      final total = _formatDuration(
                                          timelineState.duration);
                                      return Text(
                                        '$pos / $total',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: -0.2,
                                          fontFeatures: [
                                            FontFeature.tabularFigures()
                                          ],
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
                                  if (widget.danmakuController != null) ...[
                                    ListenableBuilder(
                                      listenable: widget.danmakuController!,
                                      builder: (context, _) {
                                        final isEnabled = widget
                                            .danmakuController!
                                            .settings
                                            .enabled;
                                        return InkWell(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          onTap: () {
                                            _startHideTimer();
                                            final current = widget
                                                .danmakuController!.settings;
                                            widget.danmakuController!
                                                .updateSettings(
                                              current.copyWith(
                                                  enabled: !isEnabled),
                                            );
                                          },
                                          child: Container(
                                            width: 22,
                                            height: 20,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: isEnabled
                                                    ? primaryColor
                                                    : Colors.white54,
                                                width: 1.0,
                                              ),
                                              color: isEnabled
                                                  ? primaryColor.withValues(
                                                      alpha: 0.25)
                                                  : Colors.black.withValues(
                                                      alpha: 0.2),
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
                                      constraints: const BoxConstraints(
                                          minWidth: 26, minHeight: 26),
                                      icon: Icon(
                                        Icons.tune_rounded,
                                        size: 18,
                                        color: (_activePanel ==
                                                    _ActiveControlPanel.danmaku &&
                                                widget.isFullscreen)
                                            ? primaryColor
                                            : Colors.white,
                                      ),
                                      tooltip: '弹幕设置',
                                      onPressed: () => _openPanel(
                                          context,
                                          primaryColor,
                                          _ActiveControlPanel.danmaku),
                                    ),
                                    const SizedBox(width: 2),
                                  ],

                                  // (7) 倍速选择 [1x]
                                  _buildSpeedMenu(primaryColor),

                                  const SizedBox(width: 2),

                                  // (8) 播放设置按钮 [⚙]（内聚：超分/片头片尾/画幅比例）
                                  IconButton(
                                    iconSize: 19,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 26, minHeight: 26),
                                    icon: Icon(
                                      Icons.settings_outlined,
                                      color: (_activePanel ==
                                                  _ActiveControlPanel.settings &&
                                              widget.isFullscreen)
                                          ? primaryColor
                                          : Colors.white,
                                      size: 19,
                                    ),
                                    tooltip: '播放设置（超分/片头片尾/画幅）',
                                    onPressed: () => _openPanel(
                                        context,
                                        primaryColor,
                                        _ActiveControlPanel.settings),
                                  ),

                                  const SizedBox(width: 2),

                                  // (9) 竖式音量控制按钮 [🔊]（在按钮正上方悬浮垂直滑块，0 偏移）
                                  _buildVolumeButton(primaryColor),

                                  // (10) 全屏切换按钮 [⛶]
                                  if (widget.onToggleFullscreen != null) ...[
                                    const SizedBox(width: 3),
                                    IconButton(
                                      iconSize: 19,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 26, minHeight: 26),
                                      icon: Icon(
                                        widget.isFullscreen
                                            ? Icons.fullscreen_exit_rounded
                                            : Icons.fullscreen_rounded,
                                        color: Colors.white,
                                        size: 19,
                                      ),
                                      tooltip: widget.isFullscreen
                                          ? '退出全屏'
                                          : '进入全屏',
                                      onPressed: () {
                                        _startHideTimer();
                                        widget.onToggleFullscreen?.call();
                                      },
                                    ),
                                  ],
                                ],
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

          // 7. 垂直音量调节透明点击遮罩（点击外部关闭垂直音量条）
          if (_showVolumeSlider)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _showVolumeSlider = false);
                  _startHideTimer();
                },
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),

          // 8. 全屏模式下内置悬浮「播放设置」与「弹幕设置」半透明毛玻璃浮层面板
          if (widget.isFullscreen && _activePanel != _ActiveControlPanel.none) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _activePanel = _ActiveControlPanel.none);
                  _startHideTimer();
                },
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            Positioned(
              right: 14,
              bottom: 50,
              child: _buildActivePanel(context, primaryColor),
            ),
          ],
        ],
      ),
    ),
  );
}

  // ==========================================
  // 控制栏各功能子组件实现
  // ==========================================

  void _openPanel(BuildContext context, Color primaryColor,
      _ActiveControlPanel panel) {
    if (widget.isFullscreen) {
      // 全屏模式下：在右下角以毛玻璃浮层卡片展开
      setState(() {
        _activePanel = _activePanel == panel ? _ActiveControlPanel.none : panel;
        _showVolumeSlider = false;
        if (_activePanel != _ActiveControlPanel.none) {
          _hideTimer?.cancel();
        } else {
          _startHideTimer();
        }
      });
    } else {
      // 非全屏模式下：展开到播放器外部，使用底部抽屉 (showModalBottomSheet)
      _hideTimer?.cancel();
      setState(() {
        _activePanel = _ActiveControlPanel.none;
        _showVolumeSlider = false;
      });

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) {
          final isSettings = panel == _ActiveControlPanel.settings;
          return ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(22)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 400,
                decoration: BoxDecoration(
                  color: const Color(0xF216161E),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
                      child: Row(
                        children: [
                          Icon(
                            isSettings
                                ? Icons.tune_rounded
                                : Icons.subtitles_rounded,
                            color: primaryColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isSettings ? '播放设置' : '弹幕设置',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white70, size: 20),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                        color: Color(0x22FFFFFF), height: 1, thickness: 0.5),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: isSettings
                            ? _buildSettingsPanelBody(primaryColor,
                                onDismiss: () =>
                                    Navigator.of(sheetContext).pop())
                            : _buildDanmakuPanelBody(primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ).then((_) {
        _startHideTimer();
      });
    }
  }

  Widget _buildVolumeButton(Color primaryColor) {
    return ValueListenableBuilder<PlaybackCoreState>(
      valueListenable: widget.controller.core,
      builder: (context, coreState, _) {
        final isMuted = coreState.muted || coreState.volume <= 0.001;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            IconButton(
              iconSize: 19,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
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
              onPressed: () {
                setState(() {
                  _showVolumeSlider = !_showVolumeSlider;
                  if (_showVolumeSlider) {
                    _activePanel = _ActiveControlPanel.none;
                  }
                });
                _startHideTimer();
              },
            ),
            // 垂直毛玻璃音量滑块：精准挂在音量按钮正上方，0 偏差！
            if (_showVolumeSlider)
              Positioned(
                bottom: 30,
                child: _buildVerticalVolumePopup(primaryColor),
              ),
          ],
        );
      },
    );
  }

  Widget _buildVerticalVolumePopup(Color primaryColor) {
    return ValueListenableBuilder<PlaybackCoreState>(
      valueListenable: widget.controller.core,
      builder: (context, coreState, _) {
        final isMuted = coreState.muted || coreState.volume <= 0.001;
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: 36,
              height: 125,
              padding: const EdgeInsets.symmetric(vertical: 8),
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
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 8),
                          activeTrackColor: primaryColor,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: coreState.volume.clamp(0.0, 1.0),
                          onChanged: (val) {
                            _startHideTimer();
                            widget.controller.setVolume(val);
                          },
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _startHideTimer();
                      widget.controller.toggleMute();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        isMuted
                            ? Icons.volume_off_rounded
                            : Icons.volume_down_rounded,
                        color: Colors.white70,
                        size: 14,
                      ),
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

  Widget _buildSpeedMenu(Color primaryColor) {
    return ValueListenableBuilder<PlaybackCoreState>(
      valueListenable: widget.controller.core,
      builder: (context, coreState, _) {
        return PopupMenuButton<double>(
          tooltip: '播放倍速',
          initialValue: coreState.playbackRate,
          elevation: 6,
          color: const Color(0xFF1E1E22).withValues(alpha: 0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          constraints: const BoxConstraints(minWidth: 84, maxWidth: 96),
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            child: Text(
              coreState.playbackRate == 1.0
                  ? '1x'
                  : '${coreState.playbackRate}x',
              style: TextStyle(
                color: coreState.playbackRate != 1.0
                    ? primaryColor
                    : Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
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
            // 特殊处理说明：
            // 精简倍速面板选项，移除不常用的 3.0x，保留 0.5x~2.0x 常用档位，
            // 并采用高度 30 的轻量小弹层排布，避免大幅遮挡正在播放的画面
            for (final speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
              PopupMenuItem(
                value: speed,
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${speed}x',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: speed == coreState.playbackRate
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: speed == coreState.playbackRate
                            ? primaryColor
                            : Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    if (speed == coreState.playbackRate)
                      Icon(Icons.check_rounded, color: primaryColor, size: 14),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // ==========================================
  // 内置浮层面板（播放设置 & 弹幕设置）
  // ==========================================

  Widget _buildActivePanel(BuildContext context, Color primaryColor) {
    final isSettings = _activePanel == _ActiveControlPanel.settings;
    final screenHeight = MediaQuery.of(context).size.height;
    // 自适应最大高度：占屏幕高度约 65%，clamp 限制在 240 ~ 360 之间，绝不溢出或被裁切
    final maxHeight = (screenHeight * 0.65).clamp(240.0, 360.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: 310,
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: const Color(0xEE16161C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 面板顶栏
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                child: Row(
                  children: [
                    Icon(
                      isSettings ? Icons.tune_rounded : Icons.subtitles_rounded,
                      color: primaryColor,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isSettings ? '播放设置' : '弹幕设置',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70, size: 17),
                      onPressed: () {
                        setState(() => _activePanel = _ActiveControlPanel.none);
                        _startHideTimer();
                      },
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0x22FFFFFF), height: 1, thickness: 0.5),
              // 面板内容（使用 RawScrollbar 保证可直观顺滑滚动，绝不截断）
              Flexible(
                child: RawScrollbar(
                  thumbColor: Colors.white30,
                  radius: const Radius.circular(4),
                  thickness: 3,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: isSettings
                        ? _buildSettingsPanelBody(primaryColor, onDismiss: () {
                            setState(
                                () => _activePanel = _ActiveControlPanel.none);
                            _startHideTimer();
                          })
                        : _buildDanmakuPanelBody(primaryColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsPanelBody(Color primaryColor, {VoidCallback? onDismiss}) {
    final seg = widget.opedSegment;
    String opedSubtitle = '未配置片头片尾时间戳';
    if (seg != null && (seg.hasOp || seg.hasEd)) {
      final List<String> parts = [];
      if (seg.hasOp) {
        parts.add(
            'OP ${_formatSeconds(seg.opStart!)}-${_formatSeconds(seg.opEnd!)}');
      }
      if (seg.hasEd) {
        parts.add(
            'ED ${_formatSeconds(seg.edStart!)}-${_formatSeconds(seg.edEnd!)}');
      }
      opedSubtitle = parts.join(' · ');
    }

    final isInside = _isCurrentlyInOp || _isCurrentlyInEd;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 片头片尾跳过
          _buildPanelSectionHeader('片头片尾智能跳过'),
          ValueListenableBuilder<bool>(
            valueListenable: _autoSkipOpedNotifier,
            builder: (context, autoSkip, _) {
              return _buildSwitchRow(
                title: '自动跳过片头片尾',
                subtitle: opedSubtitle,
                value: autoSkip,
                primaryColor: primaryColor,
                onChanged: (val) {
                  _autoSkipOpedNotifier.value = val;
                  _triggerSkipToast(
                      val ? '已开启自动跳过片头片尾' : '已关闭自动跳过片头片尾');
                },
              );
            },
          ),
          if (isInside) ...[
            const SizedBox(height: 4),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.withValues(alpha: 0.22),
                foregroundColor: Colors.amber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.amber, width: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
              icon: const Icon(Icons.fast_forward_rounded, size: 15),
              label: Text(
                _isCurrentlyInOp ? '立即跳过片头' : '立即跳过片尾',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: () {
                _skipCurrentSegment();
                onDismiss?.call();
                _startHideTimer();
              },
            ),
          ],

          const SizedBox(height: 10),

          // 2. 动漫超分辨率 Anime4K
          _buildPanelSectionHeader('动漫超分辨率 (Anime4K)'),
          ValueListenableBuilder<PlaybackCoreState>(
            valueListenable: widget.controller.core,
            builder: (context, coreState, _) {
              final cur = coreState.superResolution;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildOptionChip(
                      label: '关闭',
                      selected: cur == SuperResolutionMode.off,
                      primaryColor: primaryColor,
                      onTap: () => widget.controller
                          .setSuperResolution(SuperResolutionMode.off),
                    ),
                    _buildOptionChip(
                      label: '效率档',
                      selected: cur == SuperResolutionMode.efficiency,
                      primaryColor: primaryColor,
                      onTap: () => widget.controller
                          .setSuperResolution(SuperResolutionMode.efficiency),
                    ),
                    _buildOptionChip(
                      label: '质量档',
                      selected: cur == SuperResolutionMode.quality,
                      primaryColor: primaryColor,
                      onTap: () => widget.controller
                          .setSuperResolution(SuperResolutionMode.quality),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // 3. 画面画幅比例
          _buildPanelSectionHeader('画面填充比例'),
          ValueListenableBuilder<PlaybackCoreState>(
            valueListenable: widget.controller.core,
            builder: (context, coreState, _) {
              final cur = coreState.videoFit;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildOptionChip(
                      label: '默认(16:9)',
                      selected: cur == BoxFit.contain,
                      primaryColor: primaryColor,
                      onTap: () => widget.controller.setVideoFit(BoxFit.contain),
                    ),
                    _buildOptionChip(
                      label: '铺满裁剪',
                      selected: cur == BoxFit.cover,
                      primaryColor: primaryColor,
                      onTap: () => widget.controller.setVideoFit(BoxFit.cover),
                    ),
                    _buildOptionChip(
                      label: '全屏拉伸',
                      selected: cur == BoxFit.fill,
                      primaryColor: primaryColor,
                      onTap: () => widget.controller.setVideoFit(BoxFit.fill),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDanmakuPanelBody(Color primaryColor) {
    final danmaku = widget.danmakuController;
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
              _buildPanelSectionHeader('弹幕基础开关'),
              _buildSwitchRow(
                title: '显示弹幕',
                subtitle: '开启或关闭屏幕所有弹幕',
                value: cfg.enabled,
                primaryColor: primaryColor,
                onChanged: (val) =>
                    danmaku.updateSettings(cfg.copyWith(enabled: val)),
              ),
              _buildSwitchRow(
                title: '智能精简',
                subtitle: '自动抑制重复刷屏与重叠',
                value: cfg.simplify,
                primaryColor: primaryColor,
                onChanged: (val) =>
                    danmaku.updateSettings(cfg.copyWith(simplify: val)),
              ),
              _buildSwitchRow(
                title: '屏蔽彩色弹幕',
                subtitle: '统一渲染为高对比度白色',
                value: cfg.hideColor,
                primaryColor: primaryColor,
                onChanged: (val) =>
                    danmaku.updateSettings(cfg.copyWith(hideColor: val)),
              ),

              const SizedBox(height: 10),
              _buildPanelSectionHeader('显示范围'),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildOptionChip(
                      label: '半屏 (50%)',
                      selected: (cfg.area - 0.5).abs() < 0.05,
                      primaryColor: primaryColor,
                      onTap: () => danmaku.updateSettings(cfg.copyWith(area: 0.5)),
                    ),
                    _buildOptionChip(
                      label: '3/4 屏',
                      selected: (cfg.area - 0.75).abs() < 0.05,
                      primaryColor: primaryColor,
                      onTap: () => danmaku.updateSettings(cfg.copyWith(area: 0.75)),
                    ),
                    _buildOptionChip(
                      label: '全屏',
                      selected: (cfg.area - 1.0).abs() < 0.05,
                      primaryColor: primaryColor,
                      onTap: () => danmaku.updateSettings(cfg.copyWith(area: 1.0)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              _buildPanelSectionHeader('视觉调节'),
              _buildSliderRow(
                title: '不透明度',
                valText: '${(cfg.opacity * 100).round()}%',
                value: cfg.opacity,
                min: 0.2,
                max: 1.0,
                primaryColor: primaryColor,
                onChanged: (v) => danmaku.updateSettings(cfg.copyWith(opacity: v)),
              ),
              _buildSliderRow(
                title: '弹幕字号',
                valText: '${(cfg.fontSizeScale * 100).round()}%',
                value: cfg.fontSizeScale,
                min: 0.7,
                max: 1.4,
                primaryColor: primaryColor,
                onChanged: (v) =>
                    danmaku.updateSettings(cfg.copyWith(fontSizeScale: v)),
              ),
              _buildSliderRow(
                title: '飞行速度',
                valText: '${cfg.speed.toStringAsFixed(1)}x',
                value: cfg.speed,
                min: 0.6,
                max: 1.6,
                primaryColor: primaryColor,
                onChanged: (v) => danmaku.updateSettings(cfg.copyWith(speed: v)),
              ),

              const SizedBox(height: 10),
              _buildPanelSectionHeader('弹幕类型屏蔽'),
              Row(
                children: [
                  Expanded(
                    child: _buildCheckboxChip(
                      label: '屏蔽滚动',
                      checked: cfg.hideScroll,
                      primaryColor: primaryColor,
                      onTap: () => danmaku
                          .updateSettings(cfg.copyWith(hideScroll: !cfg.hideScroll)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildCheckboxChip(
                      label: '屏蔽顶部',
                      checked: cfg.hideTop,
                      primaryColor: primaryColor,
                      onTap: () => danmaku
                          .updateSettings(cfg.copyWith(hideTop: !cfg.hideTop)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildCheckboxChip(
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

  // ==========================================
  // 面板内通用组件辅助小方法
  // ==========================================

  Widget _buildPanelSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required Color primaryColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: primaryColor,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionChip({
    required String label,
    required bool selected,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: selected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckboxChip({
    required String label,
    required bool checked,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: checked
              ? primaryColor.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: checked
                ? primaryColor.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: checked ? Colors.white : Colors.white60,
            fontSize: 10.5,
            fontWeight: checked ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String title,
    required String valText,
    required double value,
    required double min,
    required double max,
    required Color primaryColor,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5)),
              Text(valText,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
              activeTrackColor: primaryColor,
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
