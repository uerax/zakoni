import 'package:flutter/material.dart';

/// 单个 Telegram 风格 ActionSheet 操作项描述
class TgActionItem {
  final String label;
  final bool isDestructive;
  final VoidCallback? onTap;

  const TgActionItem({
    required this.label,
    this.isDestructive = false,
    this.onTap,
  });
}

/// Telegram/iOS 风格破坏性操作确认抽屉（1:1 对齐 [Image #2]）
class TgActionSheet extends StatelessWidget {
  final String? header;
  final String? title;
  final List<TgActionItem> actions;
  final String cancelLabel;

  const TgActionSheet({
    super.key,
    this.header,
    this.title,
    required this.actions,
    this.cancelLabel = '取消',
  });

  /// 便捷触发破坏性确认抽屉（如：清空缓存、删除线路、移除字体等）
  static Future<bool> showDestructive(
    BuildContext context, {
    String? header,
    required String title,
    required String destructiveLabel,
    String cancelLabel = '取消',
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => TgActionSheet(
        header: header,
        title: title,
        cancelLabel: cancelLabel,
        actions: [
          TgActionItem(
            label: destructiveLabel,
            isDestructive: true,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 通用展示 ActionSheet 抽屉
  static Future<T?> show<T>(
    BuildContext context, {
    String? header,
    String? title,
    required List<TgActionItem> actions,
    String cancelLabel = '取消',
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => TgActionSheet(
        header: header,
        title: title,
        cancelLabel: cancelLabel,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 特殊处理说明：卡片底色深色为 iOS 经典 #1C1C1E，浅色为纯白 #FFFFFF，
    // 与底层地台形成舒适反差，圆角严格锁定 14dp。
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. 上层操作卡片组
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (header != null || title != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (header != null) ...[
                            Text(
                              header!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            if (title != null) const SizedBox(height: 4),
                          ],
                          if (title != null)
                            Text(
                              title!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.normal,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                                height: 1.35,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Divider(height: 0.5, thickness: 0.5, color: dividerColor),
                  ],
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0)
                      Divider(height: 0.5, thickness: 0.5, color: dividerColor),
                    _buildActionButton(context, theme, actions[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 2. 下层独立“取消”胶囊卡片（与上卡片保持 8dp 间距）
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  splashColor: theme.colorScheme.primary.withValues(alpha: 0.10),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    child: Text(
                      cancelLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.normal,
                        color: isDark ? Colors.white : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, ThemeData theme, TgActionItem item) {
    const destructiveColor = Color(0xFFFF3B30);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (item.onTap != null) {
            item.onTap!();
          } else {
            Navigator.of(context).pop();
          }
        },
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.10),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            item.label,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              color: item.isDestructive ? destructiveColor : theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
