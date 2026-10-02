import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// 全局外观与个性化管理器：
/// 1. 管理应用图标（默认内置泡面猫耳 Logo，支持上传自定义图片与一键恢复默认）；
/// 2. 管理全屏背景壁纸（支持“全局一键应用”或“各页面单独设置”多级继承）；
/// 3. 支持壁纸视窗垂直对齐/裁剪定位（AlignmentY: -1.0 偏顶 .. 1.0 偏底，避免二次元插画人物被裁面部）；
/// 4. 支持壁纸不透明度 (Opacity) 与高斯模糊 (Blur) 平滑微调；
/// 5. 继承 ChangeNotifier，通过全局 ListenableBuilder 即时响应，免重启生效。
class AppearanceManager extends ChangeNotifier {
  static final AppearanceManager instance = AppearanceManager._internal();

  AppearanceManager._internal();

  static const String defaultLogoAsset = 'assets/images/app_logo.png';

  // 自定义应用图标 / Logo 本地文件路径（null 表示使用内置默认 Logo）
  String? _customIconPath;

  // 全局默认壁纸路径（所有未单独指定壁纸的页面将自动继承它）
  String? _globalWallpaperPath;

  // 各子页面专属壁纸字典：key 为 'home', 'category', 'settings'
  final Map<String, String> _pageWallpapers = {};

  // 壁纸视窗交互式裁剪与平移矩阵参数 (由 WallpaperCropDialog 自由拖拽生成)
  double _wallpaperAlignX = 0.0;
  double _wallpaperAlignY = -0.5;
  double _wallpaperScale = 1.0;

  // 壁纸视觉调节参数
  double _wallpaperOpacity = 0.18;
  double _wallpaperBlur = 1.0;

  String? get customIconPath => _customIconPath;
  String? get globalWallpaperPath => _globalWallpaperPath;
  Map<String, String> get pageWallpapers => Map.unmodifiable(_pageWallpapers);
  double get wallpaperAlignX => _wallpaperAlignX;
  double get wallpaperAlignY => _wallpaperAlignY;
  double get wallpaperScale => _wallpaperScale;
  double get wallpaperOpacity => _wallpaperOpacity;
  double get wallpaperBlur => _wallpaperBlur;

  bool get hasCustomIcon => _customIconPath != null;

  /// 获取指定页面实际生效的壁纸路径（优先级：页面独立指定 > 全局默认壁纸）
  String? getWallpaperForPage(String? pageKey) {
    if (pageKey != null && _pageWallpapers.containsKey(pageKey)) {
      return _pageWallpapers[pageKey];
    }
    return _globalWallpaperPath;
  }

  /// 检查某页面是否有壁纸生效（包含继承全局）
  bool hasWallpaperForPage(String? pageKey) {
    return getWallpaperForPage(pageKey) != null;
  }

  /// 检查某页面是否单独设置了专属壁纸（覆盖全局）
  bool isPageOverridden(String pageKey) {
    return _pageWallpapers.containsKey(pageKey);
  }

  // --- 应用图标相关方法 ---

  Future<bool> pickAndSetCustomIcon() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        dialogTitle: '选择应用图标图片 (.png / .jpg / .webp)',
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        if (await file.exists()) {
          _customIconPath = path;
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('选择自定义图标失败: $e');
      return false;
    }
  }

  void resetDefaultIcon() {
    if (_customIconPath == null) return;
    _customIconPath = null;
    notifyListeners();
  }

  // --- 背景壁纸相关方法 ---

  /// 直接设置已选中的壁纸路径（避免二次唤起 FilePicker）
  void setWallpaperPath(String path, {String? pageKey}) {
    if (pageKey == null || pageKey == 'all') {
      _globalWallpaperPath = path;
    } else {
      _pageWallpapers[pageKey] = path;
    }
    notifyListeners();
  }

  /// 为全局或指定页面选择并设置壁纸（pageKey 为 null 或 'all' 时代表设置全局）
  Future<bool> pickAndSetWallpaper({String? pageKey}) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        dialogTitle: '选择壁纸图片 (.png / .jpg / .webp)',
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        if (await file.exists()) {
          if (pageKey == null || pageKey == 'all') {
            _globalWallpaperPath = path;
          } else {
            _pageWallpapers[pageKey] = path;
          }
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('选择自定义壁纸失败: $e');
      return false;
    }
  }

  /// 清除壁纸（若 pageKey 为 'all' 或 null 则清除全局，否则清除对应页面的单独覆盖）
  void clearWallpaper({String? pageKey}) {
    if (pageKey == null || pageKey == 'all') {
      _globalWallpaperPath = null;
    } else {
      _pageWallpapers.remove(pageKey);
    }
    notifyListeners();
  }

  /// 获取指定页面实际生效的壁纸文件对象
  File? getWallpaperFileForPage(String? pageKey) {
    final path = getWallpaperForPage(pageKey);
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  /// 设置壁纸视窗交互式裁剪平移与缩放矩阵
  void setWallpaperTransform({
    required double alignX,
    required double alignY,
    required double scale,
  }) {
    _wallpaperAlignX = alignX.clamp(-1.0, 1.0);
    _wallpaperAlignY = alignY.clamp(-1.0, 1.0);
    _wallpaperScale = scale.clamp(1.0, 3.5);
    notifyListeners();
  }

  /// 设置壁纸不透明度 (0.05 ~ 0.60)
  void setWallpaperOpacity(double val) {
    _wallpaperOpacity = val.clamp(0.05, 0.60);
    notifyListeners();
  }

  /// 设置壁纸高斯模糊度 (0.0 ~ 20.0)
  void setWallpaperBlur(double val) {
    _wallpaperBlur = val.clamp(0.0, 20.0);
    notifyListeners();
  }

  /// 统一图标构建器：自动依据当前配置渲染圆形或圆角 App Logo
  Widget buildAppLogoWidget({
    double size = 32,
    double borderRadius = 8,
    BoxBorder? border,
  }) {
    Widget imageWidget;
    if (_customIconPath != null) {
      imageWidget = Image.file(
        File(_customIconPath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          defaultLogoAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } else {
      imageWidget = Image.asset(
        defaultLogoAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageWidget,
    );
  }

  /// 全屏背景壁纸层构建器：按页面解析有效壁纸，结合用户在取景框中亲手微调的 Transform 视角与 ImageFiltered 滤镜稳定呈现
  Widget buildWallpaperLayer({String? pageKey}) {
    final wallpaperPath = getWallpaperForPage(pageKey);
    if (wallpaperPath == null) {
      return const SizedBox.shrink();
    }

    final file = File(wallpaperPath);

    // 核心渲染管线：先依据 Alignment 对齐用户选择的焦点，再等比缩放矩阵呈现，最后挂载原生高斯模糊滤镜
    Widget imageWidget = Transform.scale(
      scale: _wallpaperScale,
      alignment: Alignment(_wallpaperAlignX, _wallpaperAlignY),
      child: Image.file(
        file,
        fit: BoxFit.cover,
        alignment: Alignment(_wallpaperAlignX, _wallpaperAlignY),
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );

    if (_wallpaperBlur > 0) {
      imageWidget = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: _wallpaperBlur,
          sigmaY: _wallpaperBlur,
        ),
        child: imageWidget,
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: _wallpaperOpacity,
          child: imageWidget,
        ),
      ),
    );
  }
}
