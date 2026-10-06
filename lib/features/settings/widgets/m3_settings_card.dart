import 'package:flutter/material.dart';
import '../../../core/theme/m3_surface.dart';

/// Material 3 Expressive 设置分组标题
class M3SettingsSectionHeader extends StatelessWidget {
  final String title;

  const M3SettingsSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 20, 10, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// Material 3 Expressive 设置分组卡片容器（24dp 大圆角，色调表面）
class M3SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const M3SettingsCard({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final containerColor = M3Surface.container(
      context,
      level: M3ContainerLevel.low,
      pageKey: 'settings',
    );
    final border = M3Surface.border(
      context,
      pageKey: 'settings',
    );

    return Container(
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(24),
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Material 3 Expressive 风格图标背景容器（36dp 圆形/药丸高对比色托）
class M3SettingsIconBox extends StatelessWidget {
  final IconData icon;
  final Color? bg;
  final Color? iconColor;
  final double size;

  const M3SettingsIconBox({
    super.key,
    required this.icon,
    this.bg,
    this.iconColor,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBg = bg ?? theme.colorScheme.primaryContainer;
    final effectiveIconColor = iconColor ?? theme.colorScheme.onPrimaryContainer;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: effectiveIconColor,
        size: size * 0.56,
      ),
    );
  }
}

/// Material 3 Expressive 列表设置项
class M3SettingsTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const M3SettingsTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.06),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (leading != null) ...[
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(child: leading!),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
            if (showDivider)
              Padding(
                padding: EdgeInsets.only(left: leading != null ? 66 : 16, right: 16),
                child: Divider(
                  height: 1,
                  thickness: 0.8,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
