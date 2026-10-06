import 'package:flutter/material.dart';

/// 参考 animaku IconDanmakuSettings 的自绘专属弹幕面板设置图标
///
/// 视觉构成：
/// 1. 外层圆角矩形描边（圆角半径 4.5，右下角向内开口留给齿轮）
/// 2. 居中「弹」字符 (加粗)
/// 3. 右下角开口处自绘精细小齿轮 (内嵌中心圆孔)
class DanmakuSettingsIcon extends StatelessWidget {
  const DanmakuSettingsIcon({
    super.key,
    this.size = 18.0,
    this.color = Colors.white,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _DanmakuSettingsIconPainter(color: color),
    );
  }
}

class _DanmakuSettingsIconPainter extends CustomPainter {
  _DanmakuSettingsIconPainter({required this.color});

  final Color color;

  static Path? _cachedFramePath;
  static Path? _cachedGearPath;

  static Path _buildFramePath() {
    if (_cachedFramePath != null) return _cachedFramePath!;
    // 对标 animaku: d="M13.5 22H6.5A4.5 4.5 0 0 1 2 17.5v-11A4.5 4.5 0 0 1 6.5 2h11A4.5 4.5 0 0 1 22 6.5V13.5"
    _cachedFramePath = Path()
      ..moveTo(13.5, 22.0)
      ..lineTo(6.5, 22.0)
      ..arcToPoint(
        const Offset(2.0, 17.5),
        radius: const Radius.circular(4.5),
      )
      ..lineTo(2.0, 6.5)
      ..arcToPoint(
        const Offset(6.5, 2.0),
        radius: const Radius.circular(4.5),
      )
      ..lineTo(17.5, 2.0)
      ..arcToPoint(
        const Offset(22.0, 6.5),
        radius: const Radius.circular(4.5),
      )
      ..lineTo(22.0, 13.5);
    return _cachedFramePath!;
  }

  static Path _buildGearPath() {
    if (_cachedGearPath != null) return _cachedGearPath!;
    // 对标 animaku:
    // d="M20.3 17.5l.6-.3c.2-.1.3-.4.2-.6l-.5-.9c-.1-.2-.4-.3-.6-.2l-.6.3c-.3-.2-.6-.3-.9-.4l-.1-.7c0-.3-.2-.5-.5-.5h-1c-.3 0-.5.2-.5.5l-.1.7c-.3.1-.6.2-.9.4l-.6-.3c-.2-.1-.5 0-.6.2l-.5.9c-.1.2 0 .5.2.6l.6.3c0 .3 0 .6 0 .9l-.6.3c-.2.1-.3.4-.2.6l.5.9c.1.2.4.3.6.2l.6-.3c.3.2.6.3.9.4l.1.7c0 .3.2.5.5.5h1c.3 0 .5-.2.5-.5l.1-.7c.3-.1.6-.2.9-.4l.6.3c.2.1.5 0 .6-.2l.5-.9c.1-.2 0-.5-.2-.6l-.6-.3c0-.3 0-.6 0-.9zm-2 1.5c-.6 0-1.1-.5-1.1-1.1s.5-1.1 1.1-1.1 1.1.5 1.1 1.1-.5 1.1-1.1 1.1z"
    const gearSvg =
        'M20.3 17.5l.6-.3c.2-.1.3-.4.2-.6l-.5-.9c-.1-.2-.4-.3-.6-.2l-.6.3c-.3-.2-.6-.3-.9-.4l-.1-.7c0-.3-.2-.5-.5-.5h-1c-.3 0-.5.2-.5.5l-.1.7c-.3.1-.6.2-.9.4l-.6-.3c-.2-.1-.5 0-.6.2l-.5.9c-.1.2 0 .5.2.6l.6.3c0 .3 0 .6 0 .9l-.6.3c-.2.1-.3.4-.2.6l.5.9c.1.2.4.3.6.2l.6-.3c.3.2.6.3.9.4l.1.7c0 .3.2.5.5.5h1c.3 0 .5-.2.5-.5l.1-.7c.3-.1.6-.2.9-.4l.6.3c.2.1.5 0 .6-.2l.5-.9c.1-.2 0-.5-.2-.6l-.6-.3c0-.3 0-.6 0-.9zm-2 1.5c-.6 0-1.1-.5-1.1-1.1s.5-1.1 1.1-1.1 1.1.5 1.1 1.1-.5 1.1-1.1 1.1z';
    _cachedGearPath = _parseSvgMiniPath(gearSvg);
    return _cachedGearPath!;
  }

  static Path _parseSvgMiniPath(String d) {
    final path = Path()..fillType = PathFillType.evenOdd;
    final regExp = RegExp(r'([MmlcshvzZ])|(-?\d*\.?\d+(?:e[-+]?\d+)?)');
    final matches = regExp.allMatches(d).toList();

    double curX = 0;
    double curY = 0;
    double lastC2X = 0;
    double lastC2Y = 0;
    String currentCmd = '';
    int i = 0;

    while (i < matches.length) {
      final str = matches[i].group(0)!;
      if (RegExp(r'^[MmlcshvzZ]$').hasMatch(str)) {
        currentCmd = str;
        i++;
        if (i >= matches.length) break;
      }

      if (currentCmd == 'z' || currentCmd == 'Z') {
        path.close();
        continue;
      }

      if (currentCmd == 'M') {
        final x = double.parse(matches[i++].group(0)!);
        final y = double.parse(matches[i++].group(0)!);
        path.moveTo(x, y);
        curX = x;
        curY = y;
        lastC2X = curX;
        lastC2Y = curY;
        currentCmd = 'L';
      } else if (currentCmd == 'm') {
        final dx = double.parse(matches[i++].group(0)!);
        final dy = double.parse(matches[i++].group(0)!);
        curX += dx;
        curY += dy;
        path.moveTo(curX, curY);
        lastC2X = curX;
        lastC2Y = curY;
        currentCmd = 'l';
      } else if (currentCmd == 'l') {
        final dx = double.parse(matches[i++].group(0)!);
        final dy = double.parse(matches[i++].group(0)!);
        curX += dx;
        curY += dy;
        path.lineTo(curX, curY);
        lastC2X = curX;
        lastC2Y = curY;
      } else if (currentCmd == 'h') {
        final dx = double.parse(matches[i++].group(0)!);
        curX += dx;
        path.lineTo(curX, curY);
        lastC2X = curX;
        lastC2Y = curY;
      } else if (currentCmd == 'v') {
        final dy = double.parse(matches[i++].group(0)!);
        curY += dy;
        path.lineTo(curX, curY);
        lastC2X = curX;
        lastC2Y = curY;
      } else if (currentCmd == 'c') {
        final dx1 = double.parse(matches[i++].group(0)!);
        final dy1 = double.parse(matches[i++].group(0)!);
        final dx2 = double.parse(matches[i++].group(0)!);
        final dy2 = double.parse(matches[i++].group(0)!);
        final dx = double.parse(matches[i++].group(0)!);
        final dy = double.parse(matches[i++].group(0)!);
        final c1x = curX + dx1;
        final c1y = curY + dy1;
        final c2x = curX + dx2;
        final c2y = curY + dy2;
        curX += dx;
        curY += dy;
        path.cubicTo(c1x, c1y, c2x, c2y, curX, curY);
        lastC2X = c2x;
        lastC2Y = c2y;
      } else if (currentCmd == 's') {
        final c1x = 2 * curX - lastC2X;
        final c1y = 2 * curY - lastC2Y;
        final dx2 = double.parse(matches[i++].group(0)!);
        final dy2 = double.parse(matches[i++].group(0)!);
        final dx = double.parse(matches[i++].group(0)!);
        final dy = double.parse(matches[i++].group(0)!);
        final c2x = curX + dx2;
        final c2y = curY + dy2;
        curX += dx;
        curY += dy;
        path.cubicTo(c1x, c1y, c2x, c2y, curX, curY);
        lastC2X = c2x;
        lastC2Y = c2y;
      }
    }

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    // 1. 绘制外层圆角方框描边
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_buildFramePath(), strokePaint);

    // 2. 绘制中间「弹」字
    final textPainter = TextPainter(
      text: TextSpan(
        text: '弹',
        style: TextStyle(
          color: color,
          fontSize: 12.0,
          fontWeight: FontWeight.w700,
          fontFamily: 'MiSans',
          fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei', 'sans-serif'],
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // 汉字「弹」全位于基线之上，无西文下降部。为了确保其像素视觉中心与 24x24 外框正中心 (12.0, 12.0)
    // 严格吻合（四周等距留白 5.0px），加入 +0.5 的 X 轴与 +1.8 的 Y 轴补偿。
    // 右下角被齿轮自然遮挡，整体字形骨架端正对齐。
    textPainter.paint(
      canvas,
      Offset(
        12.0 - (textPainter.width / 2) + 0.5,
        12.0 - (textPainter.height / 2) + 1.8,
      ),
    );

    // 3. 绘制右下角小齿轮
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(_buildGearPath(), fillPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DanmakuSettingsIconPainter oldDelegate) {
    return true;
  }
}

/// 自绘专属弹幕开关图标
///
/// 视觉构成：
/// 1. 外层完整的圆角矩形描边（24x24 视口下无右下角齿轮缺口）
/// 2. 正中心居中「弹」字符
/// 3. 关闭状态下由圆角斜杠贯穿划过「弹」字
class DanmakuToggleIcon extends StatelessWidget {
  const DanmakuToggleIcon({
    super.key,
    required this.enabled,
    this.size = 18.0,
    this.color = Colors.white,
    this.slashColor,
  });

  final bool enabled;
  final double size;
  final Color color;
  final Color? slashColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _DanmakuToggleIconPainter(
        enabled: enabled,
        color: color,
        slashColor: slashColor ?? color,
      ),
    );
  }
}

class _DanmakuToggleIconPainter extends CustomPainter {
  _DanmakuToggleIconPainter({
    required this.enabled,
    required this.color,
    required this.slashColor,
  });

  final bool enabled;
  final Color color;
  final Color slashColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    // 1. 绘制闭合圆角方框描边 (24x24 视口，完整圆角矩形)
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final frameRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(2.0, 2.0, 20.0, 20.0),
      const Radius.circular(4.5),
    );
    canvas.drawRRect(frameRRect, strokePaint);

    // 2. 绘制正中心「弹」字
    final textPainter = TextPainter(
      text: TextSpan(
        text: '弹',
        style: TextStyle(
          color: color,
          fontSize: 12.0,
          fontWeight: FontWeight.w700,
          fontFamily: 'MiSans',
          fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei', 'sans-serif'],
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 补偿下降部与字模偏移，保持与 DanmakuSettingsIcon 完全一致的居中与粗细
    textPainter.paint(
      canvas,
      Offset(
        12.0 - (textPainter.width / 2) + 0.5,
        12.0 - (textPainter.height / 2) + 1.8,
      ),
    );

    // 3. 关闭状态下，绘制利落划过「弹」字的对角斜线
    if (!enabled) {
      final slashPaint = Paint()
        ..color = slashColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      // 从左上圆角内侧 (3.0, 3.0) 划过中心至右下 (21.0, 21.0)
      canvas.drawLine(
        const Offset(3.0, 3.0),
        const Offset(21.0, 21.0),
        slashPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DanmakuToggleIconPainter oldDelegate) {
    return true;
  }
}

