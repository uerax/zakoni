import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';

/// 截图成功微光浮窗反馈卡片 (带缩略图与高斯模糊)
class PlayerScreenshotFeedback extends StatelessWidget {
  const PlayerScreenshotFeedback({
    super.key,
    required this.bytes,
    required this.visible,
    this.isFullscreen = false,
  });

  final Uint8List? bytes;
  final bool visible;
  final bool isFullscreen;

  @override
  Widget build(BuildContext context) {
    if (bytes == null) return const SizedBox.shrink();

    return Positioned(
      left: 20,
      bottom: isFullscreen ? 140 : 110,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
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
                      bytes!,
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
    );
  }
}
