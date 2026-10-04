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
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      fontFamily: fontFamily,
      // 保持自然紧凑字距，不人为拉大破坏可读性
      letterSpacing: 0.0,
      height: 1.15,
    );

    // 1. 底层描边绘制器（设置 StrokeJoin.round，彻底消除文字拐角尖刺毛刺）
    if (strokeWidth > 0) {
      _strokePainter = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
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
