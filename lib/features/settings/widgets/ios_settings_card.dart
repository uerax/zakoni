import 'package:flutter/material.dart';

/// iOS 风格设置分组标题
class IosSettingsSectionHeader extends StatelessWidget {
  final String title;

  const IosSettingsSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(180),
        ),
      ),
    );
  }
}

/// iOS 风格设置卡片容器
class IosSettingsCard extends StatelessWidget {
  final List<Widget> children;
  final bool? isDark;

  const IosSettingsCard({
    super.key,
    required this.children,
    this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? (Theme.of(context).brightness == Brightness.dark);

    return Container(
      decoration: BoxDecoration(
        color: dark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(12),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// iOS 风格图标背景方块
class IosSettingsIconBox extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final double size;

  const IosSettingsIconBox({
    super.key,
    required this.icon,
    required this.bg,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: size * 0.57),
    );
  }
}

/// iOS 风格列表项
class IosSettingsTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const IosSettingsTile({
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
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: theme.colorScheme.primary.withAlpha(20),
        highlightColor: theme.colorScheme.primary.withAlpha(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                            ),
                            maxLines: 1,
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
                padding: EdgeInsets.only(left: leading != null ? 58 : 16),
                child: Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(15),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
