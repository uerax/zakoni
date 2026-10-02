import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/appearance_manager.dart';
import '../../../core/utils/font_manager.dart';
import 'ios_settings_card.dart';

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

  void _showIconActionSheet(BuildContext context) {
    final appMgr = AppearanceManager.instance;
    final currentFont = FontManager.instance.activeFontFamily;
    final fontFallback = FontManager.fallbackFontFamilies;
    final baseStyle = TextStyle(
      fontFamily: currentFont,
      fontFamilyFallback: fontFallback,
    );

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoTheme(
        data: CupertinoTheme.of(ctx).copyWith(
          textTheme: CupertinoTextThemeData(
            textStyle: baseStyle,
            actionTextStyle: baseStyle,
          ),
        ),
        child: CupertinoActionSheet(
          title: Text('应用图标设置', style: baseStyle),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _pickCustomIcon(context);
              },
              child: Text('上传自定义图标', style: baseStyle),
            ),
            if (appMgr.hasCustomIcon)
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _resetDefaultIcon(context);
                },
                child: Text('恢复默认图标', style: baseStyle),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('取消', style: baseStyle),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appMgr = AppearanceManager.instance;

    return IosSettingsTile(
      leading: appMgr.buildAppLogoWidget(
        size: 28,
        borderRadius: 7,
      ),
      title: '应用图标',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            appMgr.hasCustomIcon ? '自定义' : '默认',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
        ],
      ),
      onTap: () => _showIconActionSheet(context),
    );
  }
}
