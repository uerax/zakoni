import 'package:flutter/material.dart';

/// Bilibili 官方矢量的绝对精确底模（包含 TV 显示屏外框、正中「弹」字矢量字形与右下角精密六角螺母）
Path _buildBiliSettingsPath() {
  final p = Path()..fillType = PathFillType.evenOdd;
  p.moveTo(15.645, 4.881);
  p.lineTo(16.705, 3.408);
  p.arcToPoint(const Offset(15.083, 2.242), radius: const Radius.elliptical(0.998, 0.998), rotation: 0, largeArc: true, clockwise: false);
  p.lineTo(13.22, 4.835);
  p.arcToPoint(const Offset(12.120, 4.828), radius: const Radius.elliptical(110.67, 110.67), rotation: 0, largeArc: false, clockwise: false);
  p.lineTo(11.989, 4.828);
  p.cubicTo(11.519, 4.828, 11.014, 4.832, 10.474, 4.840);
  p.lineTo(8.783, 2.3);
  p.arcToPoint(const Offset(7.120, 3.408), radius: const Radius.elliptical(0.998, 0.998), rotation: 0, largeArc: false, clockwise: false);
  p.lineTo(8.108, 4.892);
  p.cubicTo(7.420, 4.911, 6.690, 4.934, 5.920, 4.961);
  p.arcToPoint(const Offset(2.090, 8.401), radius: const Radius.elliptical(4.013, 4.013), rotation: 0, largeArc: false, clockwise: false);
  p.cubicTo(1.925, 9.551, 1.845, 10.946, 1.845, 12.586);
  p.cubicTo(1.845, 14.551, 1.960, 16.256, 2.195, 17.702);
  p.arcToPoint(const Offset(5.958, 21.065), radius: const Radius.elliptical(4.012, 4.012), rotation: 0, largeArc: false, clockwise: false);
  p.cubicTo(7.861, 21.159, 9.275, 21.206, 11.471, 21.206);
  p.arcToPoint(const Offset(11.471, 19.231), radius: const Radius.elliptical(0.988, 0.988), rotation: 0, largeArc: false, clockwise: false);
  p.arcToPoint(const Offset(6.055, 19.092), radius: const Radius.elliptical(97.58, 97.58), rotation: 0, largeArc: false, clockwise: true);
  p.arcToPoint(const Offset(4.145, 17.384), radius: const Radius.elliptical(2.037, 2.037), rotation: 0, largeArc: false, clockwise: true);
  p.cubicTo(3.929, 16.060, 3.820, 14.460, 3.820, 12.586);
  p.cubicTo(3.820, 11.023, 3.896, 9.722, 4.045, 8.682);
  p.cubicTo(4.185, 7.705, 5.005, 6.969, 5.990, 6.935);
  p.cubicTo(8.434, 6.848, 10.455, 6.805, 12.053, 6.804);
  p.cubicTo(13.651, 6.804, 15.673, 6.848, 18.117, 6.934);
  p.cubicTo(19.077, 6.968, 19.827, 7.744, 19.972, 8.748);
  p.cubicTo(20.047, 9.272, 20.085, 10.710, 20.113, 11.813);
  p.lineTo(20.113, 11.815);
  p.cubicTo(20.118, 11.998, 20.123, 11.885, 20.127, 11.777);
  p.cubicTo(20.131, 11.681, 20.135, 11.588, 20.138, 11.696);
  p.arcToPoint(const Offset(22.112, 11.627), radius: const Radius.elliptical(0.987, 0.987), rotation: 0, largeArc: true, clockwise: false);
  p.cubicTo(22.108, 11.522, 22.105, 11.618, 22.101, 11.717);
  p.cubicTo(22.099, 11.773, 22.097, 11.829, 22.094, 11.852);
  p.lineTo(22.092, 11.862);
  p.arcToPoint(const Offset(22.087, 11.771), radius: const Radius.elliptical(0.574, 0.574), rotation: 0, largeArc: false, clockwise: true);
  p.lineTo(22.087, 11.744);
  p.cubicTo(22.057, 10.626, 22.014, 9.081, 21.927, 8.468);
  p.cubicTo(21.654, 6.562, 20.144, 5.030, 18.187, 4.961);
  p.cubicTo(17.282, 4.929, 16.435, 4.903, 15.644, 4.882);
  p.close();
  p.moveTo(12.532, 9.584);
  p.lineTo(11.225, 9.584);
  p.lineTo(11.225, 14.227);
  p.lineTo(13.425, 14.227);
  p.lineTo(13.425, 14.267);
  p.lineTo(14.076, 13.033);
  p.cubicTo(14.189, 12.818, 14.357, 12.644, 14.558, 12.524);
  p.lineTo(14.558, 12.414);
  p.lineTo(14.793, 12.414);
  p.cubicTo(14.930, 12.365, 15.076, 12.340, 15.226, 12.340);
  p.lineTo(16.779, 12.340);
  p.lineTo(16.779, 9.584);
  p.lineTo(15.515, 9.584);
  p.arcToPoint(const Offset(16.256, 8.179), radius: const Radius.elliptical(8.5, 8.5), rotation: 0, largeArc: false, clockwise: false);
  p.lineTo(15.178, 7.798);
  p.cubicTo(14.938, 8.429, 14.677, 9.028, 14.372, 9.584);
  p.lineTo(12.869, 9.584);
  p.lineTo(13.555, 9.279);
  p.cubicTo(13.327, 8.778, 13.055, 8.320, 12.749, 7.885);
  p.lineTo(11.715, 8.233);
  p.cubicTo(12.009, 8.625, 12.281, 9.072, 12.532, 9.583);
  p.close();
  p.moveTo(10.832, 15.086);
  p.lineTo(12.992, 15.086);
  p.lineTo(12.428, 16.154);
  p.lineTo(10.833, 16.154);
  p.lineTo(10.833, 15.086);
  p.close();
  p.moveTo(8.334, 13.223);
  p.lineTo(8.486, 11.662);
  p.lineTo(10.446, 11.662);
  p.lineTo(10.446, 8.289);
  p.lineTo(7.277, 8.289);
  p.lineTo(7.277, 9.258);
  p.lineTo(9.325, 9.258);
  p.lineTo(9.325, 10.693);
  p.lineTo(7.485, 10.693);
  p.lineTo(7.179, 14.203);
  p.lineTo(9.433, 14.203);
  p.cubicTo(9.433, 15.358, 9.390, 16.109, 9.313, 16.458);
  p.cubicTo(9.237, 16.806, 8.933, 16.981, 8.388, 16.981);
  p.cubicTo(8.083, 16.981, 7.778, 16.959, 7.495, 16.926);
  p.lineTo(7.789, 17.982);
  p.lineTo(7.850, 17.987);
  p.cubicTo(8.132, 18.007, 8.396, 18.026, 8.660, 18.026);
  p.cubicTo(9.651, 17.961, 10.207, 17.612, 10.337, 16.980);
  p.cubicTo(10.447, 16.349, 10.512, 15.097, 10.512, 13.223);
  p.lineTo(8.334, 13.223);
  p.close();
  p.moveTo(13.424, 12.423);
  p.lineTo(13.424, 13.273);
  p.lineTo(12.236, 13.273);
  p.lineTo(12.236, 12.423);
  p.lineTo(13.423, 12.423);
  p.close();
  p.moveTo(12.236, 11.468);
  p.lineTo(13.423, 11.468);
  p.lineTo(13.423, 10.575);
  p.lineTo(12.236, 10.575);
  p.lineTo(12.236, 11.468);
  p.close();
  p.moveTo(14.558, 11.475);
  p.lineTo(14.558, 10.582);
  p.lineTo(15.799, 10.582);
  p.lineTo(15.799, 11.475);
  p.lineTo(14.558, 11.475);
  p.close();
  p.moveTo(15.086, 14.232);
  p.arcToPoint(const Offset(16.173, 13.605), radius: const Radius.elliptical(1.26, 1.26), rotation: 0, largeArc: false, clockwise: true);
  p.lineTo(20.176, 13.596);
  p.arcToPoint(const Offset(21.270, 14.226), radius: const Radius.elliptical(1.26, 1.26), rotation: 0, largeArc: false, clockwise: true);
  p.lineTo(22.991, 17.208);
  p.cubicTo(23.217, 17.598, 23.216, 18.080, 22.990, 18.471);
  p.lineTo(21.247, 21.471);
  p.arcToPoint(const Offset(20.161, 22.099), radius: const Radius.elliptical(1.26, 1.26), rotation: 0, largeArc: false, clockwise: true);
  p.lineTo(16.158, 22.108);
  p.arcToPoint(const Offset(15.064, 21.478), radius: const Radius.elliptical(1.26, 1.26), rotation: 0, largeArc: false, clockwise: true);
  p.lineTo(13.342, 18.496);
  p.arcToPoint(const Offset(13.344, 17.233), radius: const Radius.elliptical(1.26, 1.26), rotation: 0, largeArc: false, clockwise: true);
  p.lineTo(15.086, 14.233);
  p.close();
  p.moveTo(17.053, 15.090);
  p.arcToPoint(const Offset(15.973, 15.704), radius: const Radius.elliptical(1.26, 1.26), rotation: 0, largeArc: false, clockwise: false);
  p.lineTo(15.070, 17.217);
  p.arcToPoint(const Offset(15.068, 18.506), radius: const Radius.elliptical(1.26, 1.26), rotation: 0, largeArc: false, clockwise: false);
  p.lineTo(15.953, 19.998);
  p.cubicTo(16.180, 20.382, 16.593, 20.618, 17.039, 20.616);
  p.lineTo(19.231, 20.611);
  p.arcToPoint(const Offset(20.311, 19.996), radius: const Radius.elliptical(1.26, 1.26), rotation: 0, largeArc: false, clockwise: false);
  p.lineTo(21.215, 18.478);
  p.arcToPoint(const Offset(21.216, 17.190), radius: const Radius.elliptical(1.26, 1.26), rotation: 0, largeArc: false, clockwise: false);
  p.lineTo(20.332, 15.701);
  p.arcToPoint(const Offset(19.246, 15.085), radius: const Radius.elliptical(1.26, 1.26), rotation: 0, largeArc: false, clockwise: false);
  p.lineTo(17.053, 15.090);
  p.close();
  p.moveTo(19.570, 17.850);
  p.arcToPoint(const Offset(16.770, 17.850), radius: const Radius.elliptical(1.4, 1.4), rotation: 0, largeArc: true, clockwise: true);
  p.arcToPoint(const Offset(19.570, 17.850), radius: const Radius.elliptical(1.4, 1.4), rotation: 0, largeArc: false, clockwise: true);
  p.close();
  return p;
}

/// Bilibili 官方矢量的绝对精确底模（包含 TV 显示屏外框、正中「弹」字矢量字形与打勾开槽）
Path _buildBiliTogglePath() {
  final p = Path()..fillType = PathFillType.evenOdd;
  p.moveTo(11.989, 4.828);
  p.cubicTo(11.519, 4.828, 11.014, 4.832, 10.474, 4.840);
  p.lineTo(8.764, 2.274);
  p.arcToPoint(const Offset(7.086, 3.392), radius: const Radius.elliptical(1.008, 1.008), rotation: 0, largeArc: false, clockwise: false);
  p.lineTo(8.085, 4.892);
  p.cubicTo(7.404, 4.910, 6.682, 4.932, 5.921, 4.960);
  p.arcToPoint(const Offset(2.091, 8.400), radius: const Radius.elliptical(4.013, 4.013), rotation: 0, largeArc: false, clockwise: false);
  p.cubicTo(1.926, 9.550, 1.846, 10.945, 1.846, 12.585);
  p.cubicTo(1.846, 14.550, 1.961, 16.255, 2.196, 17.701);
  p.arcToPoint(const Offset(5.959, 21.064), radius: const Radius.elliptical(4.012, 4.012), rotation: 0, largeArc: false, clockwise: false);
  p.lineTo(6.865, 21.110);
  p.cubicTo(8.070, 21.173, 8.673, 21.205, 10.472, 21.205);
  p.arcToPoint(const Offset(10.472, 19.230), radius: const Radius.elliptical(0.988, 0.988), rotation: 0, largeArc: false, clockwise: false);
  p.cubicTo(8.714, 19.230, 8.133, 19.200, 6.971, 19.138);
  p.lineTo(6.056, 19.091);
  p.arcToPoint(const Offset(4.146, 17.383), radius: const Radius.elliptical(2.037, 2.037), rotation: 0, largeArc: false, clockwise: true);
  p.cubicTo(3.930, 16.059, 3.821, 14.459, 3.821, 12.585);
  p.cubicTo(3.821, 11.022, 3.897, 9.721, 4.046, 8.681);
  p.cubicTo(4.186, 7.704, 5.006, 6.968, 5.991, 6.934);
  p.cubicTo(8.435, 6.847, 10.456, 6.804, 12.054, 6.803);
  p.cubicTo(13.652, 6.803, 15.674, 6.847, 18.118, 6.933);
  p.cubicTo(19.078, 6.967, 19.828, 7.743, 19.973, 8.747);
  p.cubicTo(20.048, 9.271, 20.086, 10.709, 20.114, 11.812);
  p.lineTo(20.114, 11.814);
  p.cubicTo(20.124, 12.156, 20.131, 12.464, 20.139, 12.694);
  p.arcToPoint(const Offset(22.113, 12.626), radius: const Radius.elliptical(0.987, 0.987), rotation: 0, largeArc: true, clockwise: false);
  p.cubicTo(22.105, 12.400, 22.097, 12.103, 22.088, 11.770);
  p.lineTo(22.088, 11.743);
  p.cubicTo(22.058, 10.625, 22.015, 9.080, 21.928, 8.467);
  p.cubicTo(21.655, 6.561, 20.145, 5.029, 18.188, 4.960);
  p.cubicTo(17.288, 4.928, 16.445, 4.902, 15.657, 4.882);
  p.lineTo(16.707, 3.422);
  p.arcToPoint(const Offset(15.069, 2.245), radius: const Radius.elliptical(1.008, 1.008), rotation: 0, largeArc: false, clockwise: false);
  p.lineTo(13.207, 4.835);
  p.cubicTo(12.827, 4.831, 12.463, 4.828, 12.119, 4.828);
  p.lineTo(11.989, 4.828);
  p.close();
  p.moveTo(12.510, 9.603);
  p.lineTo(11.190, 9.603);
  p.lineTo(11.190, 14.234);
  p.lineTo(13.412, 14.234);
  p.lineTo(13.412, 15.081);
  p.lineTo(10.794, 15.081);
  p.lineTo(10.794, 16.159);
  p.lineTo(13.412, 16.159);
  p.lineTo(13.415, 16.837);
  p.cubicTo(13.775, 16.863, 14.129, 17.000, 14.425, 17.244);
  p.lineTo(14.535, 17.244);
  p.lineTo(14.535, 16.159);
  p.lineTo(17.229, 16.159);
  p.lineTo(17.229, 15.081);
  p.lineTo(14.534, 15.081);
  p.lineTo(14.534, 14.234);
  p.lineTo(16.800, 14.234);
  p.lineTo(16.800, 9.604);
  p.lineTo(15.524, 9.604);
  p.arcToPoint(const Offset(16.272, 8.184), radius: const Radius.elliptical(8.59, 8.59), rotation: 0, largeArc: false, clockwise: false);
  p.lineTo(15.183, 7.800);
  p.arcToPoint(const Offset(14.369, 9.604), radius: const Radius.elliptical(14.232, 14.232), rotation: 0, largeArc: false, clockwise: true);
  p.lineTo(12.851, 9.604);
  p.lineTo(13.544, 9.296);
  p.arcToPoint(const Offset(12.730, 7.888), radius: const Radius.elliptical(8.862, 8.862), rotation: 0, largeArc: false, clockwise: false);
  p.lineTo(11.685, 8.240);
  p.cubicTo(11.982, 8.636, 12.257, 9.087, 12.510, 9.604);
  p.close();
  p.moveTo(8.330, 13.167);
  p.lineTo(8.484, 11.682);
  p.lineTo(10.464, 11.682);
  p.lineTo(10.464, 8.294);
  p.lineTo(7.264, 8.294);
  p.lineTo(7.264, 9.274);
  p.lineTo(9.330, 9.274);
  p.lineTo(9.330, 10.704);
  p.lineTo(7.472, 10.704);
  p.lineTo(7.164, 14.157);
  p.lineTo(9.441, 14.157);
  p.cubicTo(9.441, 15.323, 9.397, 16.082, 9.321, 16.434);
  p.cubicTo(9.243, 16.786, 8.935, 16.962, 8.385, 16.962);
  p.cubicTo(8.077, 16.962, 7.769, 16.940, 7.483, 16.907);
  p.lineTo(7.780, 17.974);
  p.lineTo(7.842, 17.979);
  p.cubicTo(8.127, 17.999, 8.393, 18.019, 8.660, 18.019);
  p.cubicTo(9.661, 17.952, 10.222, 17.600, 10.354, 16.962);
  p.cubicTo(10.464, 16.324, 10.530, 15.059, 10.530, 13.167);
  p.lineTo(8.330, 13.167);
  p.close();
  p.moveTo(15.788, 13.277);
  p.lineTo(15.788, 12.419);
  p.lineTo(14.534, 12.419);
  p.lineTo(14.534, 13.277);
  p.lineTo(15.788, 13.277);
  p.close();
  p.moveTo(13.412, 12.419);
  p.lineTo(13.412, 13.277);
  p.lineTo(12.213, 13.277);
  p.lineTo(12.213, 12.419);
  p.lineTo(13.413, 12.419);
  p.close();
  p.moveTo(12.213, 11.473);
  p.lineTo(13.413, 11.473);
  p.lineTo(13.413, 10.571);
  p.lineTo(12.213, 10.571);
  p.lineTo(12.213, 11.473);
  p.close();
  p.moveTo(14.534, 11.473);
  p.lineTo(14.534, 10.571);
  p.lineTo(15.788, 10.571);
  p.lineTo(15.788, 11.473);
  p.lineTo(14.534, 11.473);
  p.close();
  return p;
}

/// 头顶补充的两根猫耳外廓线条（从机身肩部自然升起，与原版天线构成完整的二次元猫耳）
Path _buildCatEarStrokesPath() {
  final p = Path();
  // 左猫耳外廓：从机身左肩 (4.6, 5.0) 向上升至左耳尖 (7.4, 2.3)
  p.moveTo(4.6, 5.0);
  p.cubicTo(5.2, 3.6, 6.2, 2.6, 7.4, 2.3);
  // 右猫耳外廓：从机身右肩 (19.4, 5.0) 向上升至右耳尖 (16.6, 2.3)
  p.moveTo(19.4, 5.0);
  p.cubicTo(18.8, 3.6, 17.8, 2.6, 16.6, 2.3);
  return p;
}

/// 右下角微光主题色对勾
Path _buildCheckmarkPath() {
  return Path()
    ..moveTo(13.8, 16.5)
    ..lineTo(16.0, 18.7)
    ..lineTo(20.8, 13.9);
}

/// 弹幕设置面板图标（基于 B 站高精工底模 + 头顶补充猫耳）
class DanmakuSettingsIcon extends StatelessWidget {
  const DanmakuSettingsIcon({
    super.key,
    this.size = 20.0,
    this.color = Colors.white,
  });

  final double size;
  final Color color;

  static Path? _cachedSettingsPath;
  static Path? _cachedEarsPath;

  @override
  Widget build(BuildContext context) {
    _cachedSettingsPath ??= _buildBiliSettingsPath();
    _cachedEarsPath ??= _buildCatEarStrokesPath();

    return CustomPaint(
      size: Size(size, size),
      painter: _DanmakuSettingsIconPainter(
        color: color,
        basePath: _cachedSettingsPath!,
        earsPath: _cachedEarsPath!,
      ),
    );
  }
}

class _DanmakuSettingsIconPainter extends CustomPainter {
  _DanmakuSettingsIconPainter({
    required this.color,
    required this.basePath,
    required this.earsPath,
  });

  final Color color;
  final Path basePath;
  final Path earsPath;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    // 1. 绘制 B 站原装高精工矢量（包含对称机身、居中「弹」字与六角螺母）
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(basePath, fillPaint);

    // 2. 头顶补充猫耳外廓线条（形成完美猫耳 /\  /\）
    final earStrokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(earsPath, earStrokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DanmakuSettingsIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// 弹幕开关图标（基于 B 站高精工底模 + 头顶补充猫耳 + 开启主题色对勾）
class DanmakuToggleIcon extends StatelessWidget {
  const DanmakuToggleIcon({
    super.key,
    required this.enabled,
    this.size = 20.0,
    this.color = Colors.white,
    this.checkColor,
  });

  final bool enabled;
  final double size;
  final Color color;
  final Color? checkColor;

  static Path? _cachedTogglePath;
  static Path? _cachedEarsPath;
  static Path? _cachedCheckmarkPath;

  @override
  Widget build(BuildContext context) {
    _cachedTogglePath ??= _buildBiliTogglePath();
    _cachedEarsPath ??= _buildCatEarStrokesPath();
    _cachedCheckmarkPath ??= _buildCheckmarkPath();

    return CustomPaint(
      size: Size(size, size),
      painter: _DanmakuToggleIconPainter(
        enabled: enabled,
        color: color,
        checkColor: checkColor ?? Theme.of(context).colorScheme.primary,
        basePath: _cachedTogglePath!,
        earsPath: _cachedEarsPath!,
        checkmarkPath: _cachedCheckmarkPath!,
      ),
    );
  }
}

class _DanmakuToggleIconPainter extends CustomPainter {
  _DanmakuToggleIconPainter({
    required this.enabled,
    required this.color,
    required this.checkColor,
    required this.basePath,
    required this.earsPath,
    required this.checkmarkPath,
  });

  final bool enabled;
  final Color color;
  final Color checkColor;
  final Path basePath;
  final Path earsPath;
  final Path checkmarkPath;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final effectiveColor = enabled ? color : color.withValues(alpha: 0.38);

    // 1. 绘制机身与正中「弹」字底模
    final fillPaint = Paint()
      ..color = effectiveColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(basePath, fillPaint);

    // 2. 绘制头顶猫耳外廓线条
    final earStrokePaint = Paint()
      ..color = effectiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(earsPath, earStrokePaint);

    // 3. 开启状态：在右下角开槽处绘制鲜艳主题色对勾
    if (enabled) {
      final checkPaint = Paint()
        ..color = checkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(checkmarkPath, checkPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DanmakuToggleIconPainter oldDelegate) {
    return oldDelegate.enabled != enabled ||
        oldDelegate.color != color ||
        oldDelegate.checkColor != checkColor;
  }
}
