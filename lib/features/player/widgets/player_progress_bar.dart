import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:zakoni/core/services/bangumi_oped_service.dart';
import 'package:zakoni/features/player/danmaku/danmaku.dart';

/// 复合型多功能播放进度条
/// 整合了：
/// 1. 弹幕高能热力波形图 (Danmaku Heatmap)
/// 2. OP 片头 (薄荷绿 #65D1C5) 与 ED 片尾 (暖橙色 #F2BA72) 彩色区间刻度
/// 3. 网络分级预读缓冲进度
/// 4. iOS 风格拟物流体进度条与拖拽感知
class PlayerProgressBar extends StatefulWidget {
  const PlayerProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.buffer,
    this.opedSegment,
    this.danmakuItems,
    this.primaryColor,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final Duration position;
  final Duration duration;
  final Duration buffer;
  final EpisodeOpedSegment? opedSegment;
  final List<DanmakuItem>? danmakuItems;
  final Color? primaryColor;

  final ValueChanged<Duration> onChangeStart;
  final ValueChanged<Duration> onChanged;
  final ValueChanged<Duration> onChangeEnd;

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  bool _isDragging = false;
  double _dragRatio = 0.0;

  List<double>? _cachedHeatmap;
  int _lastDanmakuCount = -1;
  int _lastDurationMs = -1;

  @override
  void didUpdateWidget(covariant PlayerProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final curCount = widget.danmakuItems?.length ?? 0;
    final curDur = widget.duration.inMilliseconds;
    if (curCount != _lastDanmakuCount || curDur != _lastDurationMs) {
      _recomputeHeatmap();
    }
  }

  void _recomputeHeatmap() {
    final items = widget.danmakuItems;
    final durMs = widget.duration.inMilliseconds;
    _lastDanmakuCount = items?.length ?? 0;
    _lastDurationMs = durMs;

    if (items == null || items.length < 5 || durMs <= 0) {
      _cachedHeatmap = null;
      return;
    }

    const numBuckets = 60;
    final buckets = List<double>.filled(numBuckets, 0.0);

    for (final item in items) {
      if (item.timeMs >= 0 && item.timeMs <= durMs) {
        final idx = ((item.timeMs / durMs) * numBuckets).floor().clamp(0, numBuckets - 1);
        buckets[idx] += 1.0;
      }
    }

    final maxVal = buckets.reduce(math.max);
    if (maxVal <= 1.0) {
      _cachedHeatmap = null;
      return;
    }

    // 3点滑动平均平滑算法 (3-point moving average)
    final smoothed = List<double>.generate(numBuckets, (i) {
      final prev = i > 0 ? buckets[i - 1] : buckets[i];
      final next = i < numBuckets - 1 ? buckets[i + 1] : buckets[i];
      return (prev + buckets[i] * 2 + next) / 4.0;
    });

    final smoothedMax = smoothed.reduce(math.max);
    if (smoothedMax <= 0) {
      _cachedHeatmap = null;
      return;
    }

    // 归一化为 0.0 ~ 1.0
    _cachedHeatmap = smoothed.map((v) => (v / smoothedMax).clamp(0.0, 1.0)).toList();
  }

  double _getRatioFromPosition(double localX, double totalWidth) {
    if (totalWidth <= 0) return 0.0;
    return (localX / totalWidth).clamp(0.0, 1.0);
  }

  Duration _getDurationFromRatio(double ratio) {
    final totalMs = widget.duration.inMilliseconds;
    return Duration(milliseconds: (totalMs * ratio).round());
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primaryColor ?? Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final totalMs = widget.duration.inMilliseconds.toDouble();

        final currentRatio = _isDragging
            ? _dragRatio
            : (totalMs > 0
                ? (widget.position.inMilliseconds / totalMs).clamp(0.0, 1.0)
                : 0.0);

        final bufferRatio = totalMs > 0
            ? (widget.buffer.inMilliseconds / totalMs).clamp(0.0, 1.0)
            : 0.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            setState(() {
              _isDragging = true;
              _dragRatio = _getRatioFromPosition(details.localPosition.dx, totalWidth);
            });
            widget.onChangeStart(_getDurationFromRatio(_dragRatio));
          },
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragRatio = _getRatioFromPosition(details.localPosition.dx, totalWidth);
            });
            widget.onChanged(_getDurationFromRatio(_dragRatio));
          },
          onHorizontalDragEnd: (details) {
            final finalRatio = _dragRatio;
            setState(() => _isDragging = false);
            widget.onChangeEnd(_getDurationFromRatio(finalRatio));
          },
          onTapDown: (details) {
            final tapRatio = _getRatioFromPosition(details.localPosition.dx, totalWidth);
            final target = _getDurationFromRatio(tapRatio);
            widget.onChangeStart(target);
            widget.onChangeEnd(target);
          },
          child: SizedBox(
            height: 38,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // 1. 弹幕高能波形图 (Danmaku Heatmap Wave)
                if (_cachedHeatmap != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 2,
                    height: 18,
                    child: CustomPaint(
                      painter: _DanmakuHeatmapPainter(
                        heatmap: _cachedHeatmap!,
                        color: primary.withValues(alpha: 0.35),
                      ),
                    ),
                  ),

                // 2. 底层未播放底轨
                Positioned(
                  left: 0,
                  right: 0,
                  child: Container(
                    height: _isDragging ? 6.0 : 4.0,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // 3. 网络缓冲进度轨
                if (bufferRatio > 0)
                  Positioned(
                    left: 0,
                    width: totalWidth * bufferRatio,
                    child: Container(
                      height: _isDragging ? 6.0 : 4.0,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                // 4. OP / ED 彩色区间高亮刻度
                if (widget.opedSegment != null && totalMs > 0)
                  ..._buildOpedMarkers(totalWidth, totalMs),

                // 5. 当前播放进度轨
                Positioned(
                  left: 0,
                  width: totalWidth * currentRatio,
                  child: Container(
                    height: _isDragging ? 6.0 : 4.0,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.45),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),

                // 6. 可拖动滑块 Thumb
                Positioned(
                  left: (totalWidth * currentRatio - (_isDragging ? 8.5 : 6.0)).clamp(
                    0.0,
                    math.max(0.0, totalWidth - (_isDragging ? 17.0 : 12.0)),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: _isDragging ? 17.0 : 12.0,
                    height: _isDragging ? 17.0 : 12.0,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: _isDragging ? 6.0 : 3.0,
                          offset: const Offset(0, 1.5),
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

  List<Widget> _buildOpedMarkers(double totalWidth, double totalMs) {
    final seg = widget.opedSegment!;
    final totalSec = totalMs / 1000.0;
    final widgets = <Widget>[];

    // OP 片头高亮 (薄荷青色 #65D1C5)
    if (seg.hasOp) {
      final startRatio = (seg.opStart! / totalSec).clamp(0.0, 1.0);
      final endRatio = (seg.opEnd! / totalSec).clamp(0.0, 1.0);
      final left = totalWidth * startRatio;
      final width = (totalWidth * (endRatio - startRatio)).clamp(2.0, totalWidth);

      widgets.add(
        Positioned(
          left: left,
          width: width,
          child: Container(
            height: _isDragging ? 6.0 : 4.0,
            decoration: BoxDecoration(
              color: const Color(0xFF65D1C5).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    // ED 片尾高亮 (暖淡橙色 #F2BA72)
    if (seg.hasEd) {
      final startRatio = (seg.edStart! / totalSec).clamp(0.0, 1.0);
      final endRatio = (seg.edEnd! / totalSec).clamp(0.0, 1.0);
      final left = totalWidth * startRatio;
      final width = (totalWidth * (endRatio - startRatio)).clamp(2.0, totalWidth);

      widgets.add(
        Positioned(
          left: left,
          width: width,
          child: Container(
            height: _isDragging ? 6.0 : 4.0,
            decoration: BoxDecoration(
              color: const Color(0xFFF2BA72).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}

/// 弹幕高能波形图绘制器
class _DanmakuHeatmapPainter extends CustomPainter {
  const _DanmakuHeatmapPainter({
    required this.heatmap,
    required this.color,
  });

  final List<double> heatmap;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (heatmap.length < 2) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final h = size.height;
    final w = size.width;
    final count = heatmap.length;
    final stepX = w / (count - 1);

    path.moveTo(0, h);

    // 绘制波形曲线
    for (int i = 0; i < count; i++) {
      final x = i * stepX;
      final normalized = math.pow(heatmap[i], 0.85).toDouble();
      final y = h - normalized * (h - 2.0);

      if (i == 0) {
        path.lineTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevNorm = math.pow(heatmap[i - 1], 0.85).toDouble();
        final prevY = h - prevNorm * (h - 2.0);
        final cx = (prevX + x) / 2.0;
        path.cubicTo(cx, prevY, cx, y, x, y);
      }
    }

    path.lineTo(w, h);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DanmakuHeatmapPainter oldDelegate) {
    return oldDelegate.heatmap != heatmap || oldDelegate.color != color;
  }
}
