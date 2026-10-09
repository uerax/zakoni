import 'package:flutter/material.dart';
import '../../../core/utils/appearance_manager.dart';
import 'm3_settings_card.dart';
import 'tg_action_sheet.dart';

class AppIconTile extends StatelessWidget {
  const AppIconTile({super.key});

  Future<void> _pickCustomIcon(BuildContext context) async {
    final success = await AppearanceManager.instance.pickAndSetCustomIcon();
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('应用图标已替换'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _resetDefaultIcon(BuildContext context) {
    AppearanceManager.instance.resetDefaultIcon();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已恢复为默认图标'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showIconModalSheet(BuildContext context) {
    final appMgr = AppearanceManager.instance;

    TgActionSheet.show(
      context,
      title: '应用图标设置（支持 png / jpg / webp 格式）',
      actions: [
        TgActionItem(
          label: '上传自定义图标',
          onTap: () {
            Navigator.of(context).pop();
            _pickCustomIcon(context);
          },
        ),
        if (appMgr.hasCustomIcon)
          TgActionItem(
            label: '恢复默认图标',
            isDestructive: true,
            onTap: () {
              Navigator.of(context).pop();
              _resetDefaultIcon(context);
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appMgr = AppearanceManager.instance;

    return ListenableBuilder(
      listenable: appMgr,
      builder: (context, _) {
        return M3SettingsTile(
          leading: appMgr.buildAppLogoWidget(
            size: 30,
            borderRadius: 7.2,
          ),
          title: '应用图标',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                appMgr.hasCustomIcon ? '自定义' : '默认',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                  fontWeight: FontWeight.normal,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 18,
              ),
            ],
          ),
          onTap: () => _showIconModalSheet(context),
        );
      },
    );
  }
}
