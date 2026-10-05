import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 工业级弹幕排版与双层渲染单元
/// 负责处理文字度量、圆角柔和描边与内容更新
class DanmakuTextLayout {
  DanmakuTextLayout({
    required this.text,
    required this.color,
    required this.fontSize,
    required this.strokeWidth,
    this.fontFamily,
  }) {
    _layout();
  }

  String text;
  final Color color;
  final double fontSize;
  final double strokeWidth;
  final String? fontFamily;

  late TextPainter _fillPainter;
  TextPainter? _strokePainter;
  Size _size = Size.zero;

  /// 测量出的完整弹幕尺寸
  Size get size => _size;

  void _layout() {
    final effectiveFontFamily = fontFamily ?? 'MiSans';
    // 黄金描边比例：约 1.2~1.4px，精致贴边，绝不侵蚀汉字内部笔画空间
    final effectiveStroke = strokeWidth > 0
        ? math.min(1.4, math.max(1.1, fontSize * 0.075))
        : 0.0;

    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      fontFamily: effectiveFontFamily,
      fontFamilyFallback: const [
        'MiSans',
        'Microsoft YaHei',
        'PingFang SC',
        'SimHei',
        'sans-serif',
      ],
      letterSpacing: 0.2,
      height: 1.18,
    );

    // 1. 底层描边绘制器（设置 StrokeJoin.round，彻底消除文字拐角尖刺毛刺）
    if (effectiveStroke > 0) {
      _strokePainter = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = effectiveStroke
              ..strokeJoin = StrokeJoin.round // 核心：消除折角尖刺
              ..strokeCap = StrokeCap.round
              // 0.85 柔和黑，避免 100% 死黑产生的生硬铁丝感
              ..color = const Color(0xD9000000),
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        maxLines: 1,
      )..layout();
    } else {
      _strokePainter = null;
    }

    // 2. 表层文字填充绘制器
    _fillPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
    )..layout();

    _size = _fillPainter.size;
  }

  /// 飞行中动态合流（xN）时更新文本并重新计算尺寸
  void updateText(String newText) {
    if (text == newText) return;
    text = newText;
    _fillPainter.dispose();
    _strokePainter?.dispose();
    _layout();
  }

  /// 提交至 Canvas 绘制
  void paint(Canvas canvas, Offset offset) {
    _strokePainter?.paint(canvas, offset);
    _fillPainter.paint(canvas, offset);
  }

  /// 资源回收
  void dispose() {
    _fillPainter.dispose();
    _strokePainter?.dispose();
  }
}
