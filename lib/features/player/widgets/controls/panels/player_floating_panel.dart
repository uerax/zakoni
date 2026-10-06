import 'dart:ui';
import 'package:flutter/material.dart';

/// 全屏模式下的内置悬浮半透明毛玻璃面板容器外壳
class PlayerFloatingPanel extends StatelessWidget {
  const PlayerFloatingPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.primaryColor,
    required this.child,
    required this.onClose,
  });

  final String title;
  final IconData icon;
  final Color primaryColor;
  final Widget child;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final maxHeight = (screenSize.height * 0.65).clamp(240.0, 360.0);
    // 窄屏/小窗口下自适应收敛宽度，保证左右各预留 14px 边距，绝不横向溢出屏幕
    final panelWidth = (screenSize.width - 28.0).clamp(260.0, 310.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: panelWidth,
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
                      icon,
                      color: primaryColor,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
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
                      onPressed: onClose,
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
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
