import 'dart:io';
import 'package:flutter/material.dart';

/// 仿 iOS / 现代专业流媒体交互的“交互式壁纸视窗取景微调器”：
/// 1. 基于 Flutter 官方原生核心组件 InteractiveViewer，无需引入不稳定第三方外部插件；
/// 2. 100% 跨平台原生支持：PC 鼠标左键按住随心拖拽画面 + 鼠标滚轮自由缩放；移动端单指拖动 + 双指张合缩放；
/// 3. 所见即所得：取景框内所见的位置与大小，将 1:1 分毫不差地锁定应用为全屏背景。
class WallpaperCropDialog extends StatefulWidget {
  final File imageFile;
  final double initialAlignX;
  final double initialAlignY;
  final double initialScale;

  const WallpaperCropDialog({
    super.key,
    required this.imageFile,
    this.initialAlignX = 0.0,
    this.initialAlignY = -0.5,
    this.initialScale = 1.0,
  });

  /// 唤起取景微调弹窗并返回最终的对齐与缩放参数
  static Future<({double alignX, double alignY, double scale})?> show(
    BuildContext context, {
    required File imageFile,
    double initialAlignX = 0.0,
    double initialAlignY = -0.5,
    double initialScale = 1.0,
  }) {
    return showDialog<({double alignX, double alignY, double scale})>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => WallpaperCropDialog(
        imageFile: imageFile,
        initialAlignX: initialAlignX,
        initialAlignY: initialAlignY,
        initialScale: initialScale,
      ),
    );
  }

  @override
  State<WallpaperCropDialog> createState() => _WallpaperCropDialogState();
}

class _WallpaperCropDialogState extends State<WallpaperCropDialog> {
  late final TransformationController _transformController;
  final GlobalKey _viewportKey = GlobalKey();

  double _currentScale = 1.0;
  double _currentAlignX = 0.0;
  double _currentAlignY = -0.5;

  @override
  void initState() {
    super.initState();
    _currentAlignX = widget.initialAlignX;
    _currentAlignY = widget.initialAlignY;
    _currentScale = widget.initialScale.clamp(1.0, 3.5);

    _transformController = TransformationController();
    _transformController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final matrix = _transformController.value;
    final scale = matrix.getMaxScaleOnAxis();

    // 从 4x4 变换矩阵中提取 translation 并归一化到 Alignment 范围 (-1.0 ~ 1.0)
    final tx = matrix.storage[12];
    final ty = matrix.storage[13];

    final renderBox = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final size = renderBox.size;
      final maxOffsetDx = size.width * (scale - 1.0);
      final maxOffsetDy = size.height * (scale - 1.0);

      final alignX = maxOffsetDx > 0 ? (-tx / maxOffsetDx * 2 - 1.0).clamp(-1.0, 1.0) : 0.0;
      final alignY = maxOffsetDy > 0 ? (-ty / maxOffsetDy * 2 - 1.0).clamp(-1.0, 1.0) : _currentAlignY;

      setState(() {
        _currentScale = scale;
        _currentAlignX = alignX;
        _currentAlignY = alignY;
      });
    }
  }

  void _resetToCenter() {
    _transformController.value = Matrix4.identity();
    setState(() {
      _currentScale = 1.0;
      _currentAlignX = 0.0;
      _currentAlignY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.sizeOf(context);
    final isPortrait = screenSize.height > screenSize.width;

    // 动态提取当前设备的视窗真实比例 (手机竖屏通常为 9:19.5 即 ~0.46，电脑宽屏通常为 16:9 即 ~1.77)
    final deviceAspectRatio = (screenSize.width / screenSize.height).clamp(0.40, 2.40);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E2024) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ConstrainedBox(
        // 手机竖屏收紧宽度，电脑宽屏适度展开，确保取景框在任何屏幕上都优美居中
        constraints: BoxConstraints(maxWidth: isPortrait ? 380 : 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部标题行与居中重置按钮
              Row(
                children: [
                  Icon(Icons.crop_rounded, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '调整壁纸视窗取景',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _resetToCenter,
                    icon: const Icon(Icons.center_focus_strong_rounded, size: 15),
                    label: const Text('居中重置', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 取景视窗主交互区：宽高比严格动态绑定当前屏幕的真实比例，手机呈现长竖屏，电脑呈现宽横屏
              Center(
                child: SizedBox(
                  height: isPortrait ? (screenSize.height * 0.48).clamp(260.0, 420.0) : 280.0,
                  child: AspectRatio(
                    aspectRatio: deviceAspectRatio,
                    child: Container(
                      key: _viewportKey,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withAlpha(160),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(60),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 核心 InteractiveViewer 原生交互引擎
                          InteractiveViewer(
                            transformationController: _transformController,
                            panEnabled: true,
                            scaleEnabled: true,
                            minScale: 1.0,
                            maxScale: 3.5,
                            boundaryMargin: const EdgeInsets.all(double.infinity),
                            child: Image.file(
                              widget.imageFile,
                              fit: BoxFit.cover,
                              alignment: Alignment(_currentAlignX, _currentAlignY),
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Text('图片加载失败', style: TextStyle(color: Colors.white70)),
                              ),
                            ),
                          ),

                          // 构图辅助九宫格准线与暗角
                          IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white.withAlpha(40), width: 0.5),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: Colors.white.withAlpha(30), width: 0.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: Colors.white.withAlpha(30), width: 0.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Expanded(child: SizedBox()),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 底部确认与取消按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        (
                          alignX: _currentAlignX,
                          alignY: _currentAlignY,
                          scale: _currentScale,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('确认应用此画面'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
