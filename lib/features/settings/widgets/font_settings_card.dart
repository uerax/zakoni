import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/font_manager.dart';
import '../../common/widgets/ios_swipe_action_tile.dart';
import 'ios_settings_card.dart';

class FontSettingsCard extends StatefulWidget {
  const FontSettingsCard({super.key});

  @override
  State<FontSettingsCard> createState() => _FontSettingsCardState();
}

class _FontSettingsCardState extends State<FontSettingsCard> {
  Future<void> _pickAndLoadCustomFont() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
        dialogTitle: '选择字体文件 (.ttf / .otf)',
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final success = await FontManager.instance.loadFontFromFile(path);
        if (!mounted) return;
        if (success) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已导入字体：${FontManager.instance.customFontName}'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('字体解析失败，请检查文件格式'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('选择字体失败: $e'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _confirmDeleteCustomFont(FontManager fontMgr) {
    final currentFont = FontManager.instance.activeFontFamily;
    final fontFallback = FontManager.fallbackFontFamilies;
    final baseStyle = TextStyle(
      fontFamily: currentFont,
      fontFamilyFallback: fontFallback,
    );

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoTheme(
        data: CupertinoTheme.of(ctx).copyWith(
          textTheme: CupertinoTextThemeData(
            textStyle: baseStyle,
            actionTextStyle: baseStyle,
          ),
        ),
        child: CupertinoAlertDialog(
          title: Text(
            '移除自定义字体',
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '确定要移除【${fontMgr.customFontName}】吗？字体将恢复为默认 MiSans。',
              style: baseStyle,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('取消', style: baseStyle),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                fontMgr.clearCustomFont();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已移除自定义字体'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Text(
                '确认移除',
                style: baseStyle.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fontMgr = FontManager.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const IosSettingsSectionHeader(title: '字体设置'),
        IosSettingsCard(
          children: [
            IosSettingsTile(
              leading: const IosSettingsIconBox(
                icon: Icons.font_download_rounded,
                bg: Color(0xFFE76F51),
              ),
              title: 'MiSans',
              trailing: fontMgr.currentType == AppFontType.misans
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary, size: 20)
                  : null,
              onTap: () => fontMgr.setFontType(AppFontType.misans),
            ),
            IosSettingsTile(
              leading: const IosSettingsIconBox(
                icon: Icons.text_fields_rounded,
                bg: Color(0xFF457B9D),
              ),
              title: '系统默认',
              trailing: fontMgr.currentType == AppFontType.system
                  ? Icon(Icons.check_rounded, color: theme.colorScheme.primary, size: 20)
                  : null,
              onTap: () => fontMgr.setFontType(AppFontType.system),
            ),
            if (fontMgr.customFontPath != null)
              IosSwipeActionTile(
                onDelete: () => _confirmDeleteCustomFont(fontMgr),
                child: IosSettingsTile(
                  leading: const IosSettingsIconBox(
                    icon: Icons.dashboard_customize_rounded,
                    bg: Color(0xFFF4A261),
                  ),
                  title: fontMgr.customFontName,
                  trailing: fontMgr.currentType == AppFontType.custom
                      ? Icon(Icons.check_rounded, color: theme.colorScheme.primary, size: 20)
                      : null,
                  onTap: () => fontMgr.setFontType(AppFontType.custom),
                ),
              ),
            IosSettingsTile(
              leading: const IosSettingsIconBox(
                icon: Icons.file_upload_outlined,
                bg: Color(0xFF8338EC),
              ),
              title: fontMgr.customFontPath != null ? '更换字体文件' : '导入字体文件',
              subtitle: '支持 .ttf / .otf 格式',
              showDivider: false,
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
              onTap: _pickAndLoadCustomFont,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 极简字体预览行
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.remove_red_eye_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '预览：10月新番 · 热门排行 · OVA',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(190),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
