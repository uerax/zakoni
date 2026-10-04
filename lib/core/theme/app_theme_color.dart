import 'package:flutter/material.dart';

/// 全局主题色彩预设方案
class AppThemePreset {
  final String id;
  final String name;
  final Color color;

  const AppThemePreset({
    required this.id,
    required this.name,
    required this.color,
  });

  /// 默认主题色（薄荷绿）
  static const Color defaultColor = Color(0xFF2A9D8F);
  static const String defaultId = 'mint';

  /// 自定义颜色标识
  static const String customId = 'custom';

  /// 内置精选二次元/现代主题色列表（共 9 款预设，薄荷绿居首，与 1 个自定义槽位凑满 2x5 绝对对称网格）
  static const List<AppThemePreset> presets = [
    AppThemePreset(id: 'mint', name: '薄荷绿', color: Color(0xFF2A9D8F)),
    AppThemePreset(id: 'cyan', name: '极光青', color: Color(0xFF00B4D8)),
    AppThemePreset(id: 'ocean', name: '深海蓝', color: Color(0xFF0077B6)),
    AppThemePreset(id: 'sakura', name: '樱花粉', color: Color(0xFFFF6B81)),
    AppThemePreset(id: 'crimson', name: '绯红', color: Color(0xFFE63946)),
    AppThemePreset(id: 'sunset', name: '日落橙', color: Color(0xFFF77F00)),
    AppThemePreset(id: 'amber', name: '琥珀金', color: Color(0xFFE09F3E)),
    AppThemePreset(id: 'violet', name: '紫罗兰', color: Color(0xFF7B2CBF)),
    AppThemePreset(id: 'graphite', name: '石墨灰', color: Color(0xFF495057)),
  ];

  /// 创建自定义主题预设
  static AppThemePreset custom(Color color) {
    return AppThemePreset(
      id: customId,
      name: '自定义',
      color: color,
    );
  }

  /// 根据 ID 查找预设，支持传入自定义颜色兜底，缺省返回薄荷绿
  static AppThemePreset findById(String? id, {Color? customColor}) {
    if (id == customId && customColor != null) {
      return custom(customColor);
    }
    if (id == null) return presets.first;
    return presets.firstWhere(
      (p) => p.id == id,
      orElse: () => presets.first,
    );
  }
}
