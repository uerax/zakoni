import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme_color.dart';
import '../../../core/utils/appearance_manager.dart';
import 'm3_settings_card.dart';

/// 主题颜色设置项与交互面板
class ThemeColorTile extends StatelessWidget {
  const ThemeColorTile({super.key});

  void _showColorPickerModal(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: true,
      builder: (modalContext) {
        return ListenableBuilder(
          listenable: AppearanceManager.instance,
          builder: (ctx, _) {
            final activePreset = AppearanceManager.instance.currentThemePreset;
            final isCustomActive = activePreset.id == AppThemePreset.customId;

            // 拆分预设为 2 行，每行 5 个格子（严格对称）
            final row1Presets = AppThemePreset.presets.sublist(0, 5);
            final row2Presets = AppThemePreset.presets.sublist(5, 9);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 顶部标题栏
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              Text(
                                '个性化主题色',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: activePreset.color.withAlpha(isDark ? 36 : 22),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  activePreset.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: activePreset.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '全局强调色、底栏指示器、进度条及高亮按钮将实时联动',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // 第 1 行：前 5 个预设颜色（薄荷绿、极光青、深海蓝、樱花粉、绯红）
                        Row(
                          children: row1Presets.map((preset) {
                            final isSelected = !isCustomActive && preset.id == activePreset.id;
                            return Expanded(
                              child: _buildColorItem(
                                context: context,
                                color: preset.color,
                                label: preset.name,
                                isSelected: isSelected,
                                isDark: isDark,
                                theme: theme,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  AppearanceManager.instance.setThemePreset(preset);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // 第 2 行：后 4 个预设（日落橙、琥珀金、紫罗兰、石墨灰）+ 1 个自定义槽位
                        Row(
                          children: [
                            ...row2Presets.map((preset) {
                              final isSelected = !isCustomActive && preset.id == activePreset.id;
                              return Expanded(
                                child: _buildColorItem(
                                  context: context,
                                  color: preset.color,
                                  label: preset.name,
                                  isSelected: isSelected,
                                  isDark: isDark,
                                  theme: theme,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    AppearanceManager.instance.setThemePreset(preset);
                                  },
                                ),
                              );
                            }),
                            // 第 5 个：自定义颜色槽位
                            Expanded(
                              child: _buildCustomColorItem(
                                context: context,
                                activeColor: activePreset.color,
                                isSelected: isCustomActive,
                                isDark: isDark,
                                theme: theme,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _showCustomColorDialog(context);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 构建单个普通预设颜色单元格
  Widget _buildColorItem({
    required BuildContext context,
    required Color color,
    required String label,
    required bool isSelected,
    required bool isDark,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withAlpha(140),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                    border: isSelected
                        ? Border.all(
                            color: isDark ? Colors.white : Colors.black87,
                            width: 2.4,
                          )
                        : Border.all(
                            color: Colors.white.withAlpha(35),
                            width: 1.0,
                          ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black87)
                    : theme.colorScheme.onSurfaceVariant.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建“自定义”颜色单元格
  Widget _buildCustomColorItem({
    required BuildContext context,
    required Color activeColor,
    required bool isSelected,
    required bool isDark,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor : null,
                    gradient: isSelected
                        ? null
                        : const SweepGradient(
                            colors: [
                              Colors.red,
                              Colors.amber,
                              Colors.green,
                              Colors.cyan,
                              Colors.blue,
                              Colors.purple,
                              Colors.pink,
                              Colors.red,
                            ],
                          ),
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: activeColor.withAlpha(140),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                    border: isSelected
                        ? Border.all(
                            color: isDark ? Colors.white : Colors.black87,
                            width: 2.4,
                          )
                        : Border.all(
                            color: isDark ? Colors.white38 : Colors.black26,
                            width: 1.0,
                          ),
                  ),
                  child: isSelected
                      ? null
                      : Container(
                          margin: const EdgeInsets.all(3.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                          ),
                          child: Icon(
                            Icons.colorize_rounded,
                            size: 18,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '自定义',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black87)
                    : theme.colorScheme.onSurfaceVariant.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 弹出自定义调色盘对话框
  void _showCustomColorDialog(BuildContext context) {
    final currentColor = AppearanceManager.instance.primaryColor;

    showDialog(
      context: context,
      builder: (dialogCtx) => _CustomColorPickerDialog(initialColor: currentColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appMgr = AppearanceManager.instance;

    return ListenableBuilder(
      listenable: appMgr,
      builder: (context, _) {
        final currentPreset = appMgr.currentThemePreset;

        return M3SettingsTile(
          leading: M3SettingsIconBox(
            icon: Icons.palette_rounded,
            bg: currentPreset.color.withValues(alpha: 0.22),
            iconColor: currentPreset.color,
          ),
          title: '主题颜色',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: currentPreset.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withAlpha(80),
                    width: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                currentPreset.name,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
            ],
          ),
          onTap: () => _showColorPickerModal(context),
        );
      },
    );
  }
}

/// 自定义颜色选择器对话框（全角色相滑轨 + 亮度微调 + 16进制输入）
class _CustomColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const _CustomColorPickerDialog({required this.initialColor});

  @override
  State<_CustomColorPickerDialog> createState() => _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<_CustomColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor);
    _hue = hsv.hue;
    // 限制初始饱和度和明度在合理且有活力的视觉区间
    _saturation = hsv.saturation < 0.2 ? 0.8 : hsv.saturation;
    _value = hsv.value < 0.3 ? 0.85 : hsv.value;

    _hexController = TextEditingController(text: _colorToHex(_currentColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color get _currentColor {
    return HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
  }

  String _colorToHex(Color color) {
    final argb = color.toARGB32();
    return (argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  }

  void _onHexSubmitted(String input) {
    String cleanHex = input.replaceAll('#', '').trim();
    if (cleanHex.length == 6) {
      final parsed = int.tryParse('FF$cleanHex', radix: 16);
      if (parsed != null) {
        final newColor = Color(parsed);
        final hsv = HSVColor.fromColor(newColor);
        setState(() {
          _hue = hsv.hue;
          _saturation = hsv.saturation;
          _value = hsv.value;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = _currentColor;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF242426) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题与关闭
              Row(
                children: [
                  const Text(
                    '自定义主题颜色',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 预览大色块 + Hex 16进制输入
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: color.withAlpha(120),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HEX 颜色代码',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '#',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: TextField(
                                  controller: _hexController,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 2),
                                    border: InputBorder.none,
                                    hintText: 'RRGGBB',
                                  ),
                                  onChanged: _onHexSubmitted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 色相彩虹滑轨
              Text(
                '色相调节',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFFFFFF00),
                      Color(0xFF00FF00),
                      Color(0xFF00FFFF),
                      Color(0xFF0000FF),
                      Color(0xFFFF00FF),
                      Color(0xFFFF0000),
                    ],
                  ),
                ),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 28,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 14,
                      elevation: 2,
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: _hue,
                    min: 0.0,
                    max: 360.0,
                    onChanged: (newHue) {
                      setState(() {
                        _hue = newHue;
                        _hexController.text = _colorToHex(_currentColor);
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 明度/纯度调节
              Text(
                '明暗调节',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      Colors.black,
                      HSVColor.fromAHSV(1.0, _hue, _saturation, 1.0).toColor(),
                    ],
                  ),
                ),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 28,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 14,
                      elevation: 2,
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: _value,
                    min: 0.25,
                    max: 1.0,
                    onChanged: (newVal) {
                      setState(() {
                        _value = newVal;
                        _hexController.text = _colorToHex(_currentColor);
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 底部确认与应用
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        AppearanceManager.instance.setCustomColor(_currentColor);
                        Navigator.of(context).pop(); // 关闭调色对话框
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('确认应用', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
