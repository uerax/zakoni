import 'dart:ui';
import 'package:flutter/material.dart';

/// 播放器指示器通用毛玻璃磨砂容器
class PlayerIndicatorFrostedCard extends StatelessWidget {
  const PlayerIndicatorFrostedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.borderRadius = 16.0,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 垂直音量 / 亮度胶囊指示器
class PlayerVerticalLevelIndicator extends StatelessWidget {
  const PlayerVerticalLevelIndicator({
    super.key,
    required this.value,
    required this.isBrightness,
    required this.visible,
  });

  /// 归一化数值 (0.0 ~ 1.0)
  final double value;

  /// true 为亮度，false 为音量
  final bool isBrightness;

  /// 是否可见
  final bool visible;

  IconData _getIcon() {
    if (isBrightness) {
      if (value <= 0.25) return Icons.brightness_low_rounded;
      if (value <= 0.7) return Icons.brightness_medium_rounded;
      return Icons.brightness_high_rounded;
    } else {
      if (value <= 0.0) return Icons.volume_off_rounded;
      if (value <= 0.5) return Icons.volume_down_rounded;
      return Icons.volume_up_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final clampedVal = value.clamp(0.0, 1.0);
    final percent = (clampedVal * 100).round();

    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: visible ? 1.0 : 0.9,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: PlayerIndicatorFrostedCard(
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIcon(),
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(height: 10),
              // 垂直电平条槽位
              Container(
                width: 6,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 60),
                  width: 6,
                  height: 84 * clampedVal,
                  decoration: BoxDecoration(
                    color: isBrightness ? Colors.amberAccent : primaryColor,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: (isBrightness ? Colors.amberAccent : primaryColor)
                            .withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 进度拖拽或双击快进快退时的中央微光卡片
class PlayerSeekPreviewIndicator extends StatelessWidget {
  const PlayerSeekPreviewIndicator({
    super.key,
    required this.visible,
    required this.targetPosition,
    required this.totalDuration,
    required this.deltaSeconds,
  });

  final bool visible;
  final Duration targetPosition;
  final Duration totalDuration;
  final int deltaSeconds;

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
    final isForward = deltaSeconds >= 0;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final deltaStr = isForward ? '+$deltaSeconds' : '$deltaSeconds';

    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: visible ? 1.0 : 0.88,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: PlayerIndicatorFrostedCard(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isForward
                        ? Icons.fast_forward_rounded
                        : Icons.fast_rewind_rounded,
                    color: isForward ? primaryColor : Colors.orangeAccent,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${deltaStr}s',
                    style: TextStyle(
                      color: isForward ? primaryColor : Colors.orangeAccent,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDuration(targetPosition),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    ' / ${_formatDuration(totalDuration)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 长按快速播放微光浮标
class PlayerSpeedHoldIndicator extends StatelessWidget {
  const PlayerSpeedHoldIndicator({
    super.key,
    required this.visible,
    required this.speed,
  });

  final bool visible;
  final double speed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -0.2),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: PlayerIndicatorFrostedCard(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fast_forward_rounded,
                color: primaryColor,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '${speed.toStringAsFixed(1)}x 极速播放中',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 屏幕误触锁定按钮
class PlayerLockFloatingButton extends StatelessWidget {
  const PlayerLockFloatingButton({
    super.key,
    required this.isLocked,
    required this.visible,
    required this.onTap,
  });

  final bool isLocked;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !visible,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isLocked
                        ? primaryColor.withValues(alpha: 0.35)
                        : Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isLocked
                          ? primaryColor.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.2),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        isLocked
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        key: ValueKey(isLocked),
                        color: isLocked ? primaryColor : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
