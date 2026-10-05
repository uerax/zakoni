import 'package:flutter/material.dart';

/// 全屏横屏布局（全宽播放器 + 浮层侧边抽屉面板）
class VideoPlayerFullscreenLayout extends StatelessWidget {
  const VideoPlayerFullscreenLayout({
    super.key,
    required this.playerWidget,
    required this.sidePanelWidget,
  });

  final Widget playerWidget;
  final Widget sidePanelWidget;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: playerWidget,
        ),
        sidePanelWidget,
      ],
    );
  }
}

/// 桌面端/宽屏分栏并排布局（左侧 16:9 播放器卡片，右侧分段 Tab 栏）
class VideoPlayerDesktopLayout extends StatelessWidget {
  const VideoPlayerDesktopLayout({
    super.key,
    required this.title,
    required this.onBackPressed,
    required this.playerWidget,
    required this.tabSection,
  });

  final String title;
  final VoidCallback onBackPressed;
  final Widget playerWidget;
  final Widget tabSection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: onBackPressed,
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  // 特殊处理说明：
                  // 必须显式指定 Clip.antiAliasWithSaveLayer，严禁使用默认的 Clip.antiAlias。
                  // 播放器在暂停或呼出控制条时，内部浮层（如居中暂停卡片、顶栏按钮等）包含 BackdropFilter 毛玻璃，
                  // 默认剪裁在遇到子级 BackdropFilter 时会被渲染管线击穿导致圆角退化为直角；
                  // 开启 antiAliasWithSaveLayer 强制分配独立离屏合成层，确保全生命周期严格保持 16px 圆角约束。
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    child: playerWidget,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: tabSection,
          ),
        ],
      ),
    );
  }
}

/// 移动端/窄屏流式上下布局（上方 16:9 播放器，下方分段 Tab 栏）
class VideoPlayerMobileLayout extends StatelessWidget {
  const VideoPlayerMobileLayout({
    super.key,
    required this.playerWidget,
    required this.tabSection,
  });

  final Widget playerWidget;
  final Widget tabSection;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: playerWidget,
          ),
          Expanded(
            child: tabSection,
          ),
        ],
      ),
    );
  }
}
