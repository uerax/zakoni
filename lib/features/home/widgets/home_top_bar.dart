import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/responsive.dart';

/// 现代响应式顶部导航栏：
/// 1. 桌面/宽屏端（≥840px）：常驻吸顶（Sticky Header，绝不收起隐藏），采用“左品牌 + 居中 440px 搜索台 (带快捷键提示) + 右侧头像”；
/// 2. 移动端（<840px）：B站式通栏 Quick-Return 架构，采用“左头像 + 右侧通栏搜索条”，下滑阅读时自动上收让出视口，上滑微动时快速召回；
/// 3. 自屏幕顶端（top: 0）全宽延伸，自然包裹状态栏，彻底杜绝四周漏风与图文重叠打架；
/// 4. 支持桌面端快捷键绑定（Ctrl+K / ⌘K）直达搜索。
class HomeTopBar extends StatelessWidget {
  final bool isVisible;
  final ValueListenable<double>? scrollOffsetNotifier;
  final VoidCallback? onSearchTap;
  final VoidCallback? onAvatarTap;

  const HomeTopBar({
    super.key,
    this.isVisible = true,
    this.scrollOffsetNotifier,
    this.onSearchTap,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = context.isDesktop;

    // 桌面端无条件常驻吸顶 (Offset.zero)，移动端按滑动意图平滑收起 (-1.0) 或唤出 (0.0)
    final effectiveOffset = isDesktop
        ? Offset.zero
        : (isVisible ? Offset.zero : const Offset(0, -1));

    Widget buildBar(double offset) {
      final progress = (offset / 30.0).clamp(0.0, 1.0);

      Widget barContent = AnimatedSlide(
        // Quick-Return 动画：1:1 参考 B 站移动端实机约 200ms 敏捷平滑升降动画与 easeOutCubic 阻尼收敛
        offset: effectiveOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1C1C1E).withAlpha((185 * progress).toInt())
                : Colors.white.withAlpha((190 * progress).toInt()),
            border: Border(
              bottom: BorderSide(
                color: (isDark ? Colors.white : Colors.black)
                    .withAlpha((20 * progress).toInt()),
                width: 0.5,
              ),
            ),
          ),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 20 * progress,
                sigmaY: 20 * progress,
              ),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 42,
                  child: isDesktop
                      ? _buildDesktopContent(context, theme, isDark)
                      : _buildMobileContent(context, theme, isDark),
                ),
              ),
            ),
          ),
        ),
      );

      // 桌面端支持 Ctrl+K / ⌘K 全局搜索快捷键
      if (isDesktop) {
        barContent = CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
              onSearchTap?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
              onSearchTap?.call();
            },
          },
          child: Focus(
            autofocus: false,
            child: barContent,
          ),
        );
      }

      return barContent;
    }

    if (scrollOffsetNotifier != null) {
      return ValueListenableBuilder<double>(
        valueListenable: scrollOffsetNotifier!,
        builder: (context, offset, _) => buildBar(offset),
      );
    }

    return buildBar(0.0);
  }

  /// 桌面端 Hero 顶部排版：左品牌 + 居中 440px 搜索台 + 右侧用户头像
  Widget _buildDesktopContent(BuildContext context, ThemeData theme, bool isDark) {
    final isMac = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    final shortcutText = isMac ? '⌘ K' : 'Ctrl K';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppBreakpoints.maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // 左侧：品牌纯粹优雅排印
              Text(
                'zakoni',
                style: TextStyle(
                  fontFamily: theme.textTheme.titleLarge?.fontFamily ?? 'MiSans',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),

              // 中间：居中 440px 胶囊搜索控制台
              SizedBox(
                width: 440,
                child: _buildSearchBar(
                  theme: theme,
                  isDark: isDark,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(14),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(15),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      shortcutText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSearchTap?.call();
                  },
                ),
              ),
              const Spacer(),

              // 右侧：用户登录头像插槽（包裹 44×44pt 规范触控热区）
              _buildUserAvatar(
                context: context,
                theme: theme,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 移动端顶部排版：1:1 参考 B 站实机（左头像 + 右侧通栏胶囊搜索条）
  Widget _buildMobileContent(BuildContext context, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // 左侧：用户登录头像插槽（包裹 44×44pt 规范触控热区，36×36 视觉圆形）
          _buildUserAvatar(
            context: context,
            theme: theme,
            isDark: isDark,
          ),
          const SizedBox(width: 10),

          // 右侧：横向撑满的胶囊形搜索条
          Expanded(
            child: _buildSearchBar(
              theme: theme,
              isDark: isDark,
              onTap: () {
                HapticFeedback.selectionClick();
                onSearchTap?.call();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 铺满式胶囊搜索栏：等高 30px，与左侧 30×30 头像精细对齐
  Widget _buildSearchBar({
    required ThemeData theme,
    required bool isDark,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(22)
                : Colors.black.withAlpha(12),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(20)
                  : Colors.black.withAlpha(10),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 16,
                color: isDark ? Colors.white60 : Colors.black45,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '搜索番剧、剧场版、特别篇...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: theme.textTheme.bodyMedium?.fontFamily ?? 'MiSans',
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Tooltip(
      message: '个人中心',
      child: Material(
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
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 30,
                height: 30,
                padding: const EdgeInsets.all(1.2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary.withAlpha(128),
                    width: 1.0,
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
                      size: 16.5,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
