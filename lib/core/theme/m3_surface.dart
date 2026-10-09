import 'package:flutter/material.dart';
import '../utils/appearance_manager.dart';

/// M3 表面色阶枚举
enum M3ContainerLevel {
  lowest,
  low,
  standard,
  high,
  highest,
}

/// Material 3 Expressive 表面层级与壁纸自适应融合工具
class M3Surface {
  const M3Surface._();

  /// 解析指定色阶的 M3 表面颜色（未设置壁纸时为纯实色，激活壁纸时自动计算色调透明度以透出背景）
  static Color container(
    BuildContext context, {
    M3ContainerLevel level = M3ContainerLevel.low,
    String? pageKey,
    double? customAlphaFraction,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // 特殊处理说明：对齐 Apple HIG 与视听流媒体主流地台体系（Scheme 1: 地台沉降 + 纯白高光卡片）。
    // 在深色模式下，背景为深暗 surface (Tone 6)，卡片采用 surfaceContainerLow (Tone 10) 向上提亮；
    // 在浅色模式下，背景沉降为地台 surfaceContainer (Tone 94)，卡片则采用纯白 surfaceContainerLowest (Tone 100) 向上提亮。
    // 这保证了深浅两端保持一致的感知层级：内容卡片永远比背景画布更加高光凸显，彻底杜绝浅色下融为一体。
    final Color baseColor = switch (level) {
      M3ContainerLevel.lowest => colorScheme.surfaceContainerLowest,
      M3ContainerLevel.low => isDark
          ? colorScheme.surfaceContainerLow
          : colorScheme.surfaceContainerLowest,
      M3ContainerLevel.standard => colorScheme.surfaceContainer,
      M3ContainerLevel.high => colorScheme.surfaceContainerHigh,
      M3ContainerLevel.highest => colorScheme.surfaceContainerHighest,
    };

    final hasWallpaper = AppearanceManager.instance.hasWallpaperForPage(pageKey);
    if (!hasWallpaper) {
      return baseColor;
    }

    // 壁纸激活状态：采用 Material You 色调融色方案，赋予 78%~84% 的色调通透度
    final double alphaFraction = customAlphaFraction ?? (isDark ? 0.80 : 0.85);
    return baseColor.withValues(alpha: alphaFraction);
  }

  /// 壁纸激活状态下的辅助边界轮廓（用于在色彩繁杂的二次元插画壁纸上维持容器可读性）
  static Border? border(
    BuildContext context, {
    String? pageKey,
    bool forceBorder = false,
  }) {
    final hasWallpaper = AppearanceManager.instance.hasWallpaperForPage(pageKey);
    if (!hasWallpaper && !forceBorder) {
      return null;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Border.all(
      color: theme.colorScheme.outlineVariant.withValues(
        alpha: isDark ? 0.28 : 0.22,
      ),
      width: 0.8,
    );
  }
}
