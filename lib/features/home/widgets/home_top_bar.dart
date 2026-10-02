import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeTopBar extends StatelessWidget {
  final int selectedIndex; // 0: 番剧, 1: 连载
  final ValueChanged<int>? onTabChanged;
  final VoidCallback? onSearchTap;
  final VoidCallback? onAvatarTap;

  const HomeTopBar({
    super.key,
    this.selectedIndex = 0,
    this.onTabChanged,
    this.onSearchTap,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      // 瘦身后的外边距：从 8px 收紧至 4px，降低对顶部的视觉占据
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Center(
        // 外层 Container 提供悬浮阴影，内层通过 ClipRRect 裁剪毛玻璃；
        // 之所以拆分两层，是因为 ClipRRect 会裁切掉同一层级的 BoxShadow 投影，导致弥散悬浮阴影丢失。
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 45 : 12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                // 极致简约控制栏：高度从 52px 瘦身至 40px，内部各操作组件等高统一为 30px
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                decoration: BoxDecoration(
                  // 高透磨砂质感底色：约 68%~70% 不透明度，确保底层卡片与内容色彩在滚动经过时清晰折射出高斯模糊
                  color: isDark
                      ? const Color(0xB31C1C1E)
                      : Colors.white.withAlpha(175),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withAlpha(30)
                        : Colors.black.withAlpha(15),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 左侧：【番剧】与【连载】胶囊轨道切换按钮
                    _buildNavSegmentedTabs(theme: theme, isDark: isDark),
                    const SizedBox(width: 6),

                    // 右侧 1：搜索圆形按钮
                    _buildCircleIconButton(
                      icon: Icons.search_rounded,
                      tooltip: '搜索番剧',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSearchTap?.call();
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),

                    // 右侧 2：用户登录头像插槽
                    _buildUserAvatar(
                      context: context,
                      theme: theme,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavSegmentedTabs({
    required ThemeData theme,
    required bool isDark,
  }) {
    return Container(
      width: 108,
      height: 30,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(36)
            : Colors.black.withAlpha(18),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Stack(
        children: [
          // 平滑滑动的微渐变指示器滑块
          AnimatedAlign(
            alignment: selectedIndex == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withAlpha(217),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(50),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 左右 Tab 标签点击区域
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTabChanged?.call(0);
                  },
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontFamily: theme.textTheme.bodyMedium?.fontFamily ?? 'MiSans',
                        fontSize: 12.5,
                        // 采用 w600 保持饱满立体，避免 w700 在小字号下浓重糊墨；保留字体自然行高以呈现舒展字形
                        fontWeight: selectedIndex == 0
                            ? FontWeight.w600
                            : FontWeight.w400,
                        letterSpacing: 0.2,
                        color: selectedIndex == 0
                            ? Colors.white
                            : (isDark
                                ? Colors.white.withAlpha(220)
                                : Colors.black87),
                      ),
                      child: const Text('番剧'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTabChanged?.call(1);
                  },
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontFamily: theme.textTheme.bodyMedium?.fontFamily ?? 'MiSans',
                        fontSize: 12.5,
                        fontWeight: selectedIndex == 1
                            ? FontWeight.w600
                            : FontWeight.w400,
                        letterSpacing: 0.2,
                        color: selectedIndex == 1
                            ? Colors.white
                            : (isDark
                                ? Colors.white.withAlpha(220)
                                : Colors.black87),
                      ),
                      child: const Text('连载'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    String? tooltip,
    double iconSize = 16.5,
  }) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          // 等高 30px，与左侧分段滑块和右侧头像严格对齐
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(31)
                : Colors.black.withAlpha(18),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  Widget _buildUserAvatar({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          if (onAvatarTap != null) {
            onAvatarTap!();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('用户登录功能暂未开放'),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(100),
        child: Container(
          // 等高 30px，与整个极简控制条融为一体
          width: 30,
          height: 30,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.primary.withAlpha(128),
              width: 1.2,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0xFF2C2C2E)
                  : const Color(0xFFF2F2F7),
            ),
            child: const ClipOval(
              child: Icon(
                Icons.person_rounded,
                size: 16,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
