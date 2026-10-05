import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:zakoni/features/player/controller/playback_controller.dart';

enum _ActiveVerticalGesture {
  none,
  brightness,
  volume,
}

Duration _clampDuration(Duration val, Duration min, Duration max) {
  if (val < min) return min;
  if (max > Duration.zero && val > max) return max;
  return val;
}

/// 播放器多功能手势感知与分发层
/// 支持：三等分双击、双侧垂直滑动、水平滑动 Seek Preview、长按动态变速与误触锁定
class PlayerGestureLayer extends StatefulWidget {
  const PlayerGestureLayer({
    super.key,
    required this.controller,
    required this.isLocked,
    required this.brightnessNotifier,
    required this.onToggleControls,
    required this.onShowLockedNotice,
    required this.onVerticalIndicatorUpdate,
    required this.onSeekIndicatorUpdate,
    required this.onSpeedIndicatorUpdate,
  });

  final ZakoniPlaybackController controller;
  final bool isLocked;
  final ValueNotifier<double> brightnessNotifier;
  final VoidCallback onToggleControls;
  final VoidCallback onShowLockedNotice;

  /// (value, isBrightness, visible)
  final void Function(double value, bool isBrightness, bool visible)
      onVerticalIndicatorUpdate;

  /// (targetPosition, totalDuration, deltaSeconds, visible)
  final void Function(
          Duration target, Duration total, int deltaSeconds, bool visible)
      onSeekIndicatorUpdate;

  /// (speed, visible)
  final void Function(double speed, bool visible) onSpeedIndicatorUpdate;

  @override
  State<PlayerGestureLayer> createState() => _PlayerGestureLayerState();
}

class _PlayerGestureLayerState extends State<PlayerGestureLayer> {
  _ActiveVerticalGesture _verticalGesture = _ActiveVerticalGesture.none;
  Timer? _verticalHideTimer;
  Timer? _doubleTapSeekDebounceTimer;

  // 垂直调节基底值
  double _initialVerticalValue = 0.0;

  // 双击快进快退累积秒数
  int _accumulatedDoubleTapSeconds = 0;

  // 水平滑动 Seek 状态
  Duration _horizontalSeekStartPos = Duration.zero;
  int _horizontalSeekDeltaSeconds = 0;
  bool _isHorizontalSeeking = false;

  // 长按倍速状态
  bool _isLongPressing = false;
  double _savedSpeedBeforeLongPress = 1.0;
  double _currentHoldSpeed = 2.0;

  @override
  void initState() {
    super.initState();
    // 隐藏系统原生音量浮窗，由播放器自带毛玻璃 HUD 完全接管
    try {
      FlutterVolumeController.updateShowSystemUI(false);
    } catch (_) {}
  }

  @override
  void dispose() {
    _verticalHideTimer?.cancel();
    _doubleTapSeekDebounceTimer?.cancel();
    super.dispose();
  }

  void _triggerHaptic() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  // -------------------------
  // 1. 点击与三等分双击处理
  // -------------------------

  void _handleTap() {
    if (widget.isLocked) {
      widget.onShowLockedNotice();
    } else {
      widget.onToggleControls();
    }
  }

  void _handleDoubleTapDown(TapDownDetails details, double screenWidth) {
    if (widget.isLocked) {
      widget.onShowLockedNotice();
      return;
    }

    final x = details.localPosition.dx;
    final sectionWidth = screenWidth / 3;

    if (x >= sectionWidth && x < sectionWidth * 2) {
      // 中间 1/3：切换播放 / 暂停
      _triggerHaptic();
      widget.controller.togglePlay();
      return;
    }

    // 左右 1/3：步进快退 (-10s) 或快进 (+10s)
    final isForward = x >= sectionWidth * 2;
    final step = isForward ? 10 : -10;

    _triggerHaptic();

    if (_accumulatedDoubleTapSeconds.sign == step.sign) {
      _accumulatedDoubleTapSeconds += step;
    } else {
      _accumulatedDoubleTapSeconds = step;
    }

    final timeline = widget.controller.timeline.value;
    final currentPos = timeline.position;
    final totalDur = timeline.duration;
    final targetPos = _clampDuration(
      currentPos + Duration(seconds: _accumulatedDoubleTapSeconds),
      Duration.zero,
      totalDur,
    );

    widget.onSeekIndicatorUpdate(
      targetPos,
      totalDur,
      _accumulatedDoubleTapSeconds,
      true,
    );

    _doubleTapSeekDebounceTimer?.cancel();
    _doubleTapSeekDebounceTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      widget.controller.seek(targetPos);
      widget.onSeekIndicatorUpdate(
        targetPos,
        totalDur,
        _accumulatedDoubleTapSeconds,
        false,
      );
      _accumulatedDoubleTapSeconds = 0;
    });
  }

  // -------------------------
  // 2. 双侧垂直滑动（音量 & 亮度）
  // -------------------------

  void _handleVerticalDragStart(DragStartDetails details, double screenWidth) {
    if (widget.isLocked) return;

    final x = details.localPosition.dx;
    final isLeft = x < screenWidth / 2;

    _verticalGesture = isLeft
        ? _ActiveVerticalGesture.brightness
        : _ActiveVerticalGesture.volume;

    _initialVerticalValue = isLeft
        ? widget.brightnessNotifier.value
        : widget.controller.core.value.volume;

    _verticalHideTimer?.cancel();
    widget.onVerticalIndicatorUpdate(
      _initialVerticalValue,
      isLeft,
      true,
    );
  }

  void _handleVerticalDragUpdate(
      DragUpdateDetails details, double screenHeight) {
    if (widget.isLocked || _verticalGesture == _ActiveVerticalGesture.none) return;

    // 向上滑动为正，向下滑动为负
    final deltaNormalized = -details.delta.dy / (screenHeight * 0.65);
    final isBrightness = _verticalGesture == _ActiveVerticalGesture.brightness;

    if (isBrightness) {
      final current = widget.brightnessNotifier.value;
      // 保持最低 0.05 亮度，避免黑屏不可逆
      final next = (current + deltaNormalized).clamp(0.05, 1.0);
      widget.brightnessNotifier.value = next;
      widget.onVerticalIndicatorUpdate(next, true, true);
    } else {
      final current = widget.controller.core.value.volume;
      final next = (current + deltaNormalized).clamp(0.0, 1.0);
      widget.controller.setVolume(next);
      try {
        FlutterVolumeController.setVolume(next);
      } catch (_) {}
      widget.onVerticalIndicatorUpdate(next, false, true);
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_verticalGesture == _ActiveVerticalGesture.none) return;
    final isBrightness = _verticalGesture == _ActiveVerticalGesture.brightness;
    final val = isBrightness
        ? widget.brightnessNotifier.value
        : widget.controller.core.value.volume;

    _verticalGesture = _ActiveVerticalGesture.none;
    _verticalHideTimer?.cancel();
    _verticalHideTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        widget.onVerticalIndicatorUpdate(val, isBrightness, false);
      }
    });
  }

  // -------------------------
  // 3. 水平滑动 Seek Preview
  // -------------------------

  void _handleHorizontalDragStart(DragStartDetails details) {
    if (widget.isLocked) return;

    _isHorizontalSeeking = true;
    _horizontalSeekStartPos = widget.controller.timeline.value.position;
    _horizontalSeekDeltaSeconds = 0;
  }

  void _handleHorizontalDragUpdate(
      DragUpdateDetails details, double screenWidth) {
    if (widget.isLocked || !_isHorizontalSeeking) return;

    final timeline = widget.controller.timeline.value;
    final totalDur = timeline.duration;
    final totalSeconds = totalDur.inSeconds > 0 ? totalDur.inSeconds : 1440;

    // 动态灵敏度映射：横滑整个屏幕跨越当前总时长的 1/2（最少 90 秒，最多 180 秒）
    final maxSeekSpan = totalSeconds.clamp(90, 600) * 0.35;
    final stepPerPixel = maxSeekSpan / screenWidth;

    _horizontalSeekDeltaSeconds += (details.delta.dx * stepPerPixel).round();

    final target = _clampDuration(
      _horizontalSeekStartPos + Duration(seconds: _horizontalSeekDeltaSeconds),
      Duration.zero,
      totalDur,
    );

    widget.controller.updateSeekPreview(target);
    widget.onSeekIndicatorUpdate(
      target,
      totalDur,
      _horizontalSeekDeltaSeconds,
      true,
    );
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (!_isHorizontalSeeking) return;
    _isHorizontalSeeking = false;

    final timeline = widget.controller.timeline.value;
    final target = timeline.displayPosition;

    widget.controller.endSeekPreview();
    widget.onSeekIndicatorUpdate(
      target,
      timeline.duration,
      _horizontalSeekDeltaSeconds,
      false,
    );
    _horizontalSeekDeltaSeconds = 0;
  }

  // -------------------------
  // 4. 长按无级快速播放
  // -------------------------

  void _handleLongPressStart(LongPressStartDetails details) {
    if (widget.isLocked || !widget.controller.core.value.playing) return;

    _isLongPressing = true;
    _savedSpeedBeforeLongPress = widget.controller.core.value.playbackRate;
    _currentHoldSpeed = 2.0;

    _triggerHaptic();
    widget.controller.setPlaybackRate(2.0);
    widget.onSpeedIndicatorUpdate(2.0, true);
  }

  void _handleLongPressMoveUpdate(
      LongPressMoveUpdateDetails details, double screenWidth) {
    if (!_isLongPressing) return;

    // 水平滑动微调倍速：左右横滑动态调整 1.0x ~ 4.0x
    final deltaRatio = details.offsetFromOrigin.dx / (screenWidth * 0.4);
    final targetSpeed = ((2.0 + deltaRatio * 1.5) * 2).round() / 2; // 0.5 步进
    final clampedSpeed = targetSpeed.clamp(1.0, 4.0);

    if (clampedSpeed != _currentHoldSpeed) {
      _currentHoldSpeed = clampedSpeed;
      widget.controller.setPlaybackRate(clampedSpeed);
      widget.onSpeedIndicatorUpdate(clampedSpeed, true);
    }
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    if (!_isLongPressing) return;
    _isLongPressing = false;

    widget.controller.setPlaybackRate(_savedSpeedBeforeLongPress);
    widget.onSpeedIndicatorUpdate(_currentHoldSpeed, false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          onDoubleTapDown: (details) =>
              _handleDoubleTapDown(details, screenWidth),
          onVerticalDragStart: (details) =>
              _handleVerticalDragStart(details, screenWidth),
          onVerticalDragUpdate: (details) =>
              _handleVerticalDragUpdate(details, screenHeight),
          onVerticalDragEnd: _handleVerticalDragEnd,
          onHorizontalDragStart: _handleHorizontalDragStart,
          onHorizontalDragUpdate: (details) =>
              _handleHorizontalDragUpdate(details, screenWidth),
          onHorizontalDragEnd: _handleHorizontalDragEnd,
          onLongPressStart: _handleLongPressStart,
          onLongPressMoveUpdate: (details) =>
              _handleLongPressMoveUpdate(details, screenWidth),
          onLongPressEnd: _handleLongPressEnd,
          child: const SizedBox.expand(),
        );
      },
    );
  }
}
