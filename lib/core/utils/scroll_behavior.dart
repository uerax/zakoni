import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';

/// 桌面与触屏通用的全局滚动行为（对齐 Anibaka 桌面端标准）：
/// 1. Flutter 默认的 MaterialScrollBehavior 在 Windows/桌面端排除了鼠标（mouse）拖拽；
/// 2. 此处显式将 PointerDeviceKind.mouse 与 trackpad 加入 dragDevices，
///    使用户在 Windows 等桌面平台能直接用鼠标左键拖拽横向与纵向列表。
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
