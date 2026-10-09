import 'package:flutter/material.dart';

/// Telegram 风格表单分组标题
class TgInputSectionHeader extends StatelessWidget {
  final String title;

  const TgInputSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
          fontWeight: FontWeight.normal,
          fontSize: 13,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

/// Telegram 风格表单分组输入卡片容器（14dp 紧凑圆角、纯白/深灰底板）
class TgInputGroup extends StatelessWidget {
  final List<Widget> children;

  const TgInputGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Divider(height: 0.5, thickness: 0.5, color: dividerColor),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Telegram 风格无边框卡片内嵌输入项
class TgInputField extends StatelessWidget {
  final TextEditingController? controller;
  final String? placeholder;
  final String? label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;
  final bool autofocus;

  const TgInputField({
    super.key,
    this.controller,
    this.placeholder,
    this.label,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.trailing,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: Row(
        children: [
          if (label != null) ...[
            SizedBox(
              width: 80,
              child: Text(
                label!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 15.5,
                  fontWeight: FontWeight.normal,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              obscureText: obscureText,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15.5,
                fontWeight: FontWeight.normal,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                // 特殊处理说明：显式强制关闭 filled，严防继承全局 inputDecorationTheme
                // 所注入的灰色矩形底色（surfaceContainerHigh），确保输入框绝对纯净通透地浮在卡片底板上。
                filled: false,
                fillColor: Colors.transparent,
                hintText: placeholder,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 15.5,
                  fontWeight: FontWeight.normal,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Telegram 风格模态表单面板（1:1 对齐 [Image #3]：顶栏圆形 ✕ / ✓ 按钮 + Grouped 嵌入式表单）
class TgFormSheet extends StatelessWidget {
  final String title;
  final Widget Function(BuildContext ctx) bodyBuilder;
  final VoidCallback? onConfirm;
  final bool isConfirmLoading;

  const TgFormSheet({
    super.key,
    required this.title,
    required this.bodyBuilder,
    this.onConfirm,
    this.isConfirmLoading = false,
  });

  /// 便捷触发模态表单面板
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget Function(BuildContext ctx) bodyBuilder,
    VoidCallback? onConfirm,
    bool isConfirmLoading = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TgFormSheet(
        title: title,
        bodyBuilder: bodyBuilder,
        onConfirm: onConfirm,
        isConfirmLoading: isConfirmLoading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // 页面背景底色深色为纯黑 #000000 / 浅色为 surfaceContainer，顶角 16dp
    final sheetBg = isDark ? const Color(0xFF000000) : theme.scaffoldBackgroundColor;
    final circleBtnBg = isDark ? Colors.white.withValues(alpha: 0.16) : Colors.black.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 顶部导航栏：左圆纽 ✕ + 居中标题 + 右圆纽 ✓
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                // 左侧圆形关闭按钮 ✕
                _buildCircleIconButton(
                  key: const ValueKey('tg_form_close_btn'),
                  icon: Icons.close_rounded,
                  bg: circleBtnBg,
                  iconColor: isDark ? Colors.white : Colors.black87,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                // 居中标题
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                // 右侧圆形完成按钮 ✓
                if (onConfirm != null)
                  _buildCircleIconButton(
                    key: const ValueKey('tg_form_confirm_btn'),
                    icon: Icons.check_rounded,
                    bg: isDark ? Colors.white.withValues(alpha: 0.22) : theme.colorScheme.primary.withValues(alpha: 0.15),
                    iconColor: isDark ? Colors.white : theme.colorScheme.primary,
                    isLoading: isConfirmLoading,
                    onTap: onConfirm,
                  )
                else
                  const SizedBox(width: 32),
              ],
            ),
          ),

          // 2. 表单内容流
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              child: bodyBuilder(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIconButton({
    Key? key,
    required IconData icon,
    required Color bg,
    required Color iconColor,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return SizedBox(
      key: key,
      width: 32,
      height: 32,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  )
                : Icon(icon, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }
}
