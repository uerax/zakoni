import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AppFontType {
  harmony('HarmonyOS Sans', '鸿蒙黑体'),
  system('Microsoft YaHei', '系统默认'),
  custom('CustomFont', '自定义导入字体');

  final String fontFamily;
  final String label;

  const AppFontType(this.fontFamily, this.label);
}

/// 全局字体管理器：
/// 1. 默认内置使用鸿蒙黑体 (HarmonyOS Sans)；
/// 2. 支持切回系统默认无衬线字体（Windows 采用微软雅黑，规避回退至中易宋体）；
/// 3. 支持在运行时通过 FontLoader 动态载入用户上传的本地 .ttf / .otf 字体文件，免重启即时全局生效。
class FontManager extends ChangeNotifier {
  static final FontManager instance = FontManager._internal();

  FontManager._internal();

  static const List<String> fallbackFontFamilies = [
    'Microsoft YaHei',
    'PingFang SC',
    'Noto Sans SC',
    'sans-serif',
  ];

  AppFontType _currentType = AppFontType.harmony;
  String? _customFontPath;
  String _customFontName = '未选择文件';

  AppFontType get currentType => _currentType;
  String? get customFontPath => _customFontPath;
  String get customFontName => _customFontName;

  /// 当前生效的全局 fontFamily 标识符
  String? get activeFontFamily {
    switch (_currentType) {
      case AppFontType.harmony:
        return AppFontType.harmony.fontFamily;
      case AppFontType.system:
        if (kIsWeb) return 'sans-serif';
        if (defaultTargetPlatform == TargetPlatform.windows) {
          return 'Microsoft YaHei';
        } else if (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.iOS) {
          return 'PingFang SC';
        }
        return 'Noto Sans SC';
      case AppFontType.custom:
        return AppFontType.custom.fontFamily;
    }
  }

  /// 切换字体类型
  void setFontType(AppFontType type) {
    if (_currentType == type) return;
    _currentType = type;
    notifyListeners();
  }

  /// 从本地文件动态热加载字体
  Future<bool> loadFontFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final bytes = await file.readAsBytes();
      final fontLoader = FontLoader(AppFontType.custom.fontFamily);
      fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await fontLoader.load();

      _customFontPath = filePath;
      _customFontName = file.uri.pathSegments.last;
      _currentType = AppFontType.custom;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('加载自定义字体失败: $e');
      return false;
    }
  }

  /// 移除已导入的自定义字体并自动切回默认推荐字体
  void clearCustomFont() {
    _customFontPath = null;
    _customFontName = '未选择文件';
    if (_currentType == AppFontType.custom) {
      _currentType = AppFontType.harmony;
    }
    notifyListeners();
  }
}
